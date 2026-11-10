import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/encrypted_gmx_scan_store.dart';
import 'package:ydi_app/data/gmx_account_store.dart';
import 'package:ydi_app/data/scan_data_store.dart';
import 'package:ydi_app/main.dart';
import 'package:ydi_app/models/gmx_account.dart';
import 'package:ydi_app/models/gmx_sync_state.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/models/service_category.dart';
import 'package:ydi_app/models/service_item.dart';
import 'package:ydi_app/services/gmx_credential_manager.dart';

class _MemoryPreferences implements ScanPreferences, GmxAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _MemorySecureStorage implements GmxSecureStorage {
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;
  bool hideReads = false;
  int deleteCount = 0;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('Key temporarily unavailable');
    return hideReads ? null : values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Key write failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    values.remove(key);
  }
}

class _MemoryGmxScanFile implements GmxScanFile {
  List<int>? bytes;
  var readCount = 0;
  bool failWrites = false;
  int deleteCount = 0;
  bool failReads = false;
  Completer<void>? readBarrier;

  @override
  Future<List<int>?> read() async {
    readCount++;
    if (readBarrier != null) await readBarrier!.future;
    if (failReads) throw StateError('Snapshot temporarily unavailable');
    return bytes == null ? null : List<int>.from(bytes!);
  }

  @override
  Future<void> write(List<int> value) async {
    if (failWrites) throw StateError('Snapshot write failed');
    bytes = List<int>.from(value);
  }

  @override
  Future<void> delete() async {
    deleteCount++;
    bytes = null;
  }
}

const _account = 'GMX · private-test@example.com';
const _tokenUrl = 'https://example.com/unsubscribe/private-token';

ScanDataset _dataset() => const ScanDataset(
  services: [
    ServiceItem(
      id: 'synthetic_service',
      name: 'Synthetic Service',
      categoryId: ServiceCategory.shopping,
      mailCounts: {_account: 2},
      color: Colors.blue,
      monogram: 'SS',
      domains: ['example.com'],
      unsubscribeByAccount: {_account: true},
      unsubscribeUrlsByAccount: {_account: _tokenUrl},
    ),
  ],
  sourceFiles: ['gmx-imap:$_account'],
);

EncryptedGmxScanPersistence _encryptedPersistence(
  _MemoryGmxScanFile file,
  _MemorySecureStorage secureStorage,
) => EncryptedGmxScanPersistence(file, secureStorage);

void main() {
  for (final failure in ['key', 'decryption', 'file']) {
    testWidgets(
      'Real startup survives $failure failure and recovers on retry',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        scanDataNotifier.value = null;
        gmxAccountsNotifier.value = const [];
        addTearDown(() {
          scanDataNotifier.value = null;
          gmxAccountsNotifier.value = const [];
        });
        final file = _MemoryGmxScanFile();
        final keys = _MemorySecureStorage();
        final preferences = _MemoryPreferences();
        final persistence = _encryptedPersistence(file, keys);
        final store = ScanDataStore(
          preferences: preferences,
          gmxPersistence: persistence,
          notifier: scanDataNotifier,
          clearAccountScanTimes: () async {},
          removeAccountScanTime: (_) async {},
        );
        late List<int> originalBytes;
        late Map<String, String> originalKeys;
        var otherServicesInitialized = false;
        await tester.runAsync(() async {
          await persistence.saveWithSyncState(
            _dataset(),
            _account,
            const GmxSyncState(uidValidity: 42, lastProcessedUid: 5000),
          );
          originalBytes = List<int>.from(file.bytes!);
          originalKeys = Map<String, String>.from(keys.values);
          if (failure == 'key') keys.failReads = true;
          if (failure == 'file') file.failReads = true;
          if (failure == 'decryption') {
            final envelope =
                jsonDecode(utf8.decode(file.bytes!)) as Map<String, dynamic>;
            final mac = base64Decode(envelope['mac'] as String);
            mac[0] ^= 1;
            envelope['mac'] = base64Encode(mac);
            file.bytes = utf8.encode(jsonEncode(envelope));
          }
          // Use the initialization path called by main(), including runApp().
          await startYdiApp(
            dataStore: store,
            initializeOtherServices: () async =>
                otherServicesInitialized = true,
          );
        });
        await tester.pumpAndSettle();
        expect(otherServicesInitialized, isTrue);
        expect(tester.takeException(), isNull);
        expect(
          find.text('Gespeicherte Scandaten konnten nicht geladen werden.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Die vorhandenen Daten bleiben unverändert.'),
          findsOneWidget,
        );
        expect(store.loadFailed.value, isTrue);
        final failedBytes = List<int>.from(file.bytes!);

        // A failed load must never be mistaken for an empty, writable store.
        await expectLater(
          store.save(const ScanDataset(services: [], sourceFiles: [])),
          throwsStateError,
        );
        await expectLater(
          store.saveGmxDataset(_account, _dataset()),
          throwsStateError,
        );
        await expectLater(store.clear(), throwsStateError);
        await expectLater(store.removeAccount(_account), throwsStateError);
        await tester.tap(find.text('Erneut laden'));
        await tester.pumpAndSettle();
        expect(store.loadFailed.value, isTrue);
        expect(find.text('Erneut laden'), findsOneWidget);
        expect(file.bytes, failedBytes);
        expect(keys.values, originalKeys);
        expect(file.deleteCount, 0);
        expect(keys.deleteCount, 0);
        expect(scanDataNotifier.value, isNull);

        keys.failReads = false;
        file.failReads = false;
        // A corrupted file requires a valid copy, not an automatic deletion.
        file.bytes = originalBytes;
        await tester.runAsync(() async {
          await tester.tap(find.text('Erneut laden'));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(store.loadFailed.value, isFalse);
        expect(
          find.text('Gespeicherte Scandaten konnten nicht geladen werden.'),
          findsNothing,
        );
        expect(find.text('Your Digital Identity'), findsOneWidget);
        expect(scanDataNotifier.value?.accounts, contains(_account));
        expect(
          scanDataNotifier.value?.services.single.unsubscribeUrlFor(_account),
          _tokenUrl,
        );
        await tester.runAsync(() async {
          expect(
            (await store.loadGmxSyncState(_account))?.lastProcessedUid,
            5000,
          );
          expect(file.bytes, originalBytes);
          expect(keys.values, originalKeys);
          // Successful recovery releases the write protection.
          await store.saveGmxDataset(
            _account,
            _dataset(),
            syncState: const GmxSyncState(
              uidValidity: 42,
              lastProcessedUid: 6000,
            ),
          );
          expect(
            (await store.loadGmxSyncState(_account))?.lastProcessedUid,
            6000,
          );
        });
      },
    );
  }

  testWidgets('Real startup without saved scans shows the normal dashboard', (
    tester,
  ) async {
    scanDataNotifier.value = null;
    final store = ScanDataStore(
      preferences: _MemoryPreferences(),
      gmxPersistence: _encryptedPersistence(
        _MemoryGmxScanFile(),
        _MemorySecureStorage(),
      ),
      notifier: scanDataNotifier,
    );
    await startYdiApp(dataStore: store, initializeOtherServices: () async {});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your Digital Identity'), findsOneWidget);
    expect(find.text('Erneut laden'), findsNothing);
    expect(store.loadFailed.value, isFalse);
  });

  test(
    'Loading blocks writes and preserves the previous in-memory snapshot on failure',
    () async {
      final file = _MemoryGmxScanFile();
      final keys = _MemorySecureStorage();
      final notifier = ValueNotifier<ScanDataset?>(_dataset());
      final store = ScanDataStore(
        preferences: _MemoryPreferences(),
        gmxPersistence: _encryptedPersistence(file, keys),
        notifier: notifier,
      );
      final previous = notifier.value;
      final barrier = Completer<void>();
      file.readBarrier = barrier;
      file.failReads = true;
      final loading = store.load();
      final failedLoad = expectLater(loading, throwsStateError);
      await expectLater(store.save(_dataset()), throwsStateError);
      await expectLater(store.clear(), throwsStateError);
      barrier.complete();
      await failedLoad;
      expect(notifier.value, same(previous));
      expect(store.loadFailed.value, isTrue);
      expect(file.deleteCount, 0);
      expect(keys.deleteCount, 0);
    },
  );

  for (final failure in ['read', 'missing', 'invalid', 'wrong']) {
    test(
      'Key failure ($failure) preserves snapshot, key and sync state',
      () async {
        final file = _MemoryGmxScanFile();
        final keys = _MemorySecureStorage();
        final store = _encryptedPersistence(file, keys);
        await store.saveWithSyncState(
          _dataset(),
          _account,
          const GmxSyncState(uidValidity: 42, lastProcessedUid: 5000),
        );
        final originalBytes = List<int>.from(file.bytes!);
        final originalKeys = Map<String, String>.from(keys.values);
        switch (failure) {
          case 'read':
            keys.failReads = true;
          case 'missing':
            keys.hideReads = true;
          case 'invalid':
            keys.values.updateAll((_, _) => 'not-base64!');
          case 'wrong':
            keys.values.updateAll((_, _) => base64Encode(List.filled(32, 0)));
        }
        final failingKeys = Map<String, String>.from(keys.values);

        await expectLater(
          store.load(),
          throwsA(
            anyOf(
              isA<StateError>(),
              isA<FormatException>(),
              isA<SecretBoxAuthenticationError>(),
            ),
          ),
        );
        await expectLater(
          store.loadSyncState(_account),
          throwsA(
            anyOf(
              isA<StateError>(),
              isA<FormatException>(),
              isA<SecretBoxAuthenticationError>(),
            ),
          ),
        );
        await expectLater(
          store.save(_dataset()),
          throwsA(
            anyOf(
              isA<StateError>(),
              isA<FormatException>(),
              isA<SecretBoxAuthenticationError>(),
            ),
          ),
        );
        await expectLater(
          store.saveWithSyncState(
            _dataset(),
            _account,
            const GmxSyncState(uidValidity: 42, lastProcessedUid: 6000),
          ),
          throwsA(
            anyOf(
              isA<StateError>(),
              isA<FormatException>(),
              isA<SecretBoxAuthenticationError>(),
            ),
          ),
        );
        await expectLater(
          store.removeAccount(_account),
          throwsA(
            anyOf(
              isA<StateError>(),
              isA<FormatException>(),
              isA<SecretBoxAuthenticationError>(),
            ),
          ),
        );
        expect(file.bytes, originalBytes);
        expect(keys.values, failingKeys);
        expect(file.deleteCount, 0);
        expect(keys.deleteCount, 0);

        keys.failReads = false;
        keys.hideReads = false;
        keys.values
          ..clear()
          ..addAll(originalKeys);
        expect((await store.load())?.accounts, contains(_account));
        expect((await store.loadSyncState(_account))?.lastProcessedUid, 5000);
      },
    );
  }

  for (final failure in ['invalid JSON', 'authentication']) {
    test('$failure failure preserves encrypted data and key', () async {
      final file = _MemoryGmxScanFile();
      final keys = _MemorySecureStorage();
      final store = _encryptedPersistence(file, keys);
      await store.save(_dataset());
      final originalBytes = List<int>.from(file.bytes!);
      final originalKeys = Map<String, String>.from(keys.values);
      if (failure == 'invalid JSON') {
        file.bytes = utf8.encode('{broken');
      } else {
        final envelope =
            jsonDecode(utf8.decode(file.bytes!)) as Map<String, dynamic>;
        final mac = base64Decode(envelope['mac'] as String);
        mac[0] ^= 1;
        envelope['mac'] = base64Encode(mac);
        file.bytes = utf8.encode(jsonEncode(envelope));
      }
      final damagedBytes = List<int>.from(file.bytes!);
      await expectLater(
        store.load(),
        throwsA(
          anyOf(
            isA<StateError>(),
            isA<FormatException>(),
            isA<SecretBoxAuthenticationError>(),
          ),
        ),
      );
      await expectLater(
        store.save(_dataset()),
        throwsA(
          anyOf(
            isA<StateError>(),
            isA<FormatException>(),
            isA<SecretBoxAuthenticationError>(),
          ),
        ),
      );
      expect(file.bytes, damagedBytes);
      expect(keys.values, originalKeys);
      expect(file.deleteCount, 0);
      expect(keys.deleteCount, 0);
      file.bytes = originalBytes;
      expect((await store.load())?.accounts, contains(_account));
    });
  }

  test(
    'Failed snapshot write preserves the previous snapshot and key',
    () async {
      final file = _MemoryGmxScanFile();
      final keys = _MemorySecureStorage();
      final store = _encryptedPersistence(file, keys);
      await store.saveWithSyncState(
        _dataset(),
        _account,
        const GmxSyncState(uidValidity: 42, lastProcessedUid: 5000),
      );
      final previous = List<int>.from(file.bytes!);
      final previousKeys = Map<String, String>.from(keys.values);
      file.failWrites = true;
      await expectLater(
        store.saveWithSyncState(
          _dataset(),
          _account,
          const GmxSyncState(uidValidity: 42, lastProcessedUid: 6000),
        ),
        throwsStateError,
      );
      expect(file.bytes, previous);
      expect(keys.values, previousKeys);
      expect((await store.loadSyncState(_account))?.lastProcessedUid, 5000);
    },
  );

  test(
    'Failed initial key verification does not delete the stored key',
    () async {
      final file = _MemoryGmxScanFile();
      final keys = _MemorySecureStorage()..hideReads = true;
      final store = _encryptedPersistence(file, keys);
      await expectLater(store.save(_dataset()), throwsStateError);
      expect(file.bytes, isNull);
      expect(keys.values, hasLength(1));
      expect(keys.deleteCount, 0);
      expect(file.deleteCount, 0);
      final previousKeys = Map<String, String>.from(keys.values);
      keys.hideReads = false;
      await store.save(_dataset());
      expect(keys.values, previousKeys);
      expect((await store.load())?.accounts, contains(_account));
    },
  );

  test('Failed initial key write does not create a snapshot', () async {
    final file = _MemoryGmxScanFile();
    final keys = _MemorySecureStorage()..failWrites = true;
    await expectLater(
      _encryptedPersistence(file, keys).save(_dataset()),
      throwsStateError,
    );
    expect(file.bytes, isNull);
    expect(keys.values, isEmpty);
    expect(file.deleteCount, 0);
    expect(keys.deleteCount, 0);
  });

  test('Verschlüsselte GMX-Scans überstehen simulierten Neustart', () async {
    final preferences = _MemoryPreferences();
    final secureStorage = _MemorySecureStorage();
    final file = _MemoryGmxScanFile();
    final firstNotifier = ValueNotifier<ScanDataset?>(null);
    final firstStore = ScanDataStore(
      preferences: preferences,
      gmxPersistence: _encryptedPersistence(file, secureStorage),
      notifier: firstNotifier,
    );

    await firstStore.saveGmxDataset(
      _account,
      _dataset(),
      syncState: const GmxSyncState(uidValidity: 42, lastProcessedUid: 5000),
    );

    expect(preferences.values, isEmpty);
    expect(file.bytes, isNotNull);
    final encryptedText = utf8.decode(file.bytes!);
    expect(encryptedText, isNot(contains('private-test@example.com')));
    expect(encryptedText, isNot(contains('private-token')));
    expect(encryptedText, isNot(contains('lastProcessedUid')));

    final restartedNotifier = ValueNotifier<ScanDataset?>(null);
    final restartedStore = ScanDataStore(
      preferences: preferences,
      gmxPersistence: _encryptedPersistence(file, secureStorage),
      notifier: restartedNotifier,
    );
    await restartedStore.load();

    expect(restartedNotifier.value?.accounts, contains(_account));
    expect(
      restartedNotifier.value?.services.single.unsubscribeUrlFor(_account),
      _tokenUrl,
    );
    final restoredState = await restartedStore.loadGmxSyncState(_account);
    expect(restoredState?.uidValidity, 42);
    expect(restoredState?.lastProcessedUid, 5000);
  });

  test('Public Demo liest oder persistiert keine echten GMX-Scans', () async {
    final preferences = _MemoryPreferences();
    final secureStorage = _MemorySecureStorage();
    final file = _MemoryGmxScanFile()..bytes = utf8.encode('private-data');
    final notifier = ValueNotifier<ScanDataset?>(null);
    final store = ScanDataStore(
      preferences: preferences,
      gmxPersistence: _encryptedPersistence(file, secureStorage),
      notifier: notifier,
      publicDemo: true,
    );

    await store.load();
    await expectLater(
      store.saveGmxDataset(_account, _dataset()),
      throwsStateError,
    );
    await expectLater(store.loadGmxSyncState(_account), throwsStateError);

    expect(file.readCount, 0);
    expect(file.bytes, utf8.encode('private-data'));
    expect(secureStorage.values, isEmpty);
    expect(notifier.value, isNull);
  });

  test(
    'Alte ungeschützte SharedPreferences-GMX-Scans werden entfernt',
    () async {
      final preferences = _MemoryPreferences();
      preferences.values['ydi_local_scan_dataset_v1'] = jsonEncode(
        _dataset().toJson(),
      );
      final notifier = ValueNotifier<ScanDataset?>(null);
      final store = ScanDataStore(
        preferences: preferences,
        gmxPersistence: _encryptedPersistence(
          _MemoryGmxScanFile(),
          _MemorySecureStorage(),
        ),
        notifier: notifier,
      );

      await store.load();

      expect(preferences.values, isEmpty);
      expect(notifier.value, isNull);
    },
  );

  test('Legacy-GMX-Scan ohne Quellenmarker wird ebenfalls entfernt', () async {
    final preferences = _MemoryPreferences();
    final legacy = ScanDataset(
      services: _dataset().services,
      sourceFiles: const ['legacy-import.json'],
    );
    preferences.values['ydi_local_scan_dataset_v1'] = jsonEncode(
      legacy.toJson(),
    );
    final notifier = ValueNotifier<ScanDataset?>(null);
    final store = ScanDataStore(
      preferences: preferences,
      gmxPersistence: _encryptedPersistence(
        _MemoryGmxScanFile(),
        _MemorySecureStorage(),
      ),
      notifier: notifier,
    );

    await store.load();

    expect(preferences.values, isEmpty);
    expect(notifier.value, isNull);
  });

  test('Konto-Löschen entfernt Scan-Daten und Credential', () async {
    final scanPreferences = _MemoryPreferences();
    final accountPreferences = _MemoryPreferences();
    final secureStorage = _MemorySecureStorage();
    final file = _MemoryGmxScanFile();
    final scanNotifier = ValueNotifier<ScanDataset?>(null);
    final scanStore = ScanDataStore(
      preferences: scanPreferences,
      gmxPersistence: _encryptedPersistence(file, secureStorage),
      notifier: scanNotifier,
      clearAccountScanTimes: () async {},
      removeAccountScanTime: (_) async {},
    );
    final accountStore = GmxAccountStore(
      preferences: accountPreferences,
      notifier: ValueNotifier<List<GmxAccount>>(const []),
      publicDemo: false,
      now: () => DateTime.utc(2026, 8, 1),
      randomIdPart: () => 42,
    );
    final credentialManager = GmxCredentialManager(
      accountStore: accountStore,
      secureStorage: secureStorage,
      now: () => DateTime.utc(2026, 8, 1),
    );
    var account = await accountStore.ensureAccount('private-test@example.com');
    await credentialManager.saveFor30Days(account, 'synthetic-password');
    account = accountStore.findById(account.accountId)!;
    await scanStore.saveGmxDataset(
      account.scanAccountLabel,
      _dataset(),
      syncState: const GmxSyncState(uidValidity: 42, lastProcessedUid: 5000),
    );

    await scanStore.removeAccount(account.scanAccountLabel);
    await credentialManager.deleteAccount(account);

    expect(file.bytes, isNull);
    expect(scanNotifier.value, isNull);
    expect(await scanStore.loadGmxSyncState(account.scanAccountLabel), isNull);
    expect(secureStorage.values, isEmpty);
    expect(accountStore.accounts, isEmpty);
  });
}
