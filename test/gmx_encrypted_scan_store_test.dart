import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/encrypted_gmx_scan_store.dart';
import 'package:ydi_app/data/gmx_account_store.dart';
import 'package:ydi_app/data/scan_data_store.dart';
import 'package:ydi_app/models/gmx_account.dart';
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

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _MemoryGmxScanFile implements GmxScanFile {
  List<int>? bytes;
  var readCount = 0;

  @override
  Future<List<int>?> read() async {
    readCount++;
    return bytes == null ? null : List<int>.from(bytes!);
  }

  @override
  Future<void> write(List<int> value) async {
    bytes = List<int>.from(value);
  }

  @override
  Future<void> delete() async {
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

    await firstStore.saveGmxDataset(_account, _dataset());

    expect(preferences.values, isEmpty);
    expect(file.bytes, isNotNull);
    final encryptedText = utf8.decode(file.bytes!);
    expect(encryptedText, isNot(contains('private-test@example.com')));
    expect(encryptedText, isNot(contains('private-token')));

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
    await scanStore.saveGmxDataset(account.scanAccountLabel, _dataset());

    await scanStore.removeAccount(account.scanAccountLabel);
    await credentialManager.deleteAccount(account);

    expect(file.bytes, isNull);
    expect(scanNotifier.value, isNull);
    expect(secureStorage.values, isEmpty);
    expect(accountStore.accounts, isEmpty);
  });
}
