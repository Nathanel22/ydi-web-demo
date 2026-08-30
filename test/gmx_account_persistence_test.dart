import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/gmx_account_store.dart';
import 'package:ydi_app/models/gmx_account.dart';
import 'package:ydi_app/services/gmx_credential_manager.dart';

class _MemoryPreferences implements GmxAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _MemorySecureStorage implements GmxSecureStorage {
  _MemorySecureStorage([Map<String, String>? values])
    : values = values ?? <String, String>{};

  final Map<String, String> values;

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

class _UnreadableSecureStorage extends _MemorySecureStorage {
  @override
  Future<String?> read(String key) => throw StateError('Synthetic read error.');
}

class _NonPersistingSecureStorage extends _MemorySecureStorage {
  @override
  Future<void> write(String key, String value) async {}
}

GmxAccountStore _accountStore(
  _MemoryPreferences preferences, {
  bool publicDemo = false,
}) => GmxAccountStore(
  preferences: preferences,
  notifier: ValueNotifier<List<GmxAccount>>(const []),
  publicDemo: publicDemo,
  now: () => DateTime.utc(2026, 8, 1),
  randomIdPart: () => 42,
);

void main() {
  test('GMX-Konto bleibt nach simuliertem App-Neustart bestehen', () async {
    final preferences = _MemoryPreferences();
    final firstStore = _accountStore(preferences);
    final account = await firstStore.ensureAccount('Private@Test.Example');
    await firstStore.markScanned(account.accountId, DateTime.utc(2026, 8, 2));

    final restartedStore = _accountStore(preferences);
    await restartedStore.load();

    expect(restartedStore.accounts, hasLength(1));
    expect(restartedStore.accounts.single.accountId, account.accountId);
    expect(restartedStore.accounts.single.email, 'private@test.example');
    expect(
      restartedStore.accounts.single.lastSuccessfulScanAt,
      DateTime.utc(2026, 8, 2),
    );
  });

  test('Passwort steht nie im normalen Account-Datensatz', () async {
    final preferences = _MemoryPreferences();
    final secureStorage = _MemorySecureStorage();
    final store = _accountStore(preferences);
    final account = await store.ensureAccount('private@test.example');
    final manager = GmxCredentialManager(
      accountStore: store,
      secureStorage: secureStorage,
      now: () => DateTime.utc(2026, 8, 2),
    );

    await manager.saveFor30Days(account, 'synthetic-password');

    final accountJson = preferences.values[GmxAccountStore.storageKey]!;
    expect(accountJson, isNot(contains('synthetic-password')));
    expect(accountJson, isNot(contains('password')));
    expect(secureStorage.values.values, contains('synthetic-password'));
  });

  test('Unbekannte alte Felder werden beim Laden entfernt', () async {
    final preferences = _MemoryPreferences()
      ..values[GmxAccountStore.storageKey] =
          '[{"accountId":"legacy","provider":"gmx",'
          '"email":"private@test.example",'
          '"credentialAvailable":false,'
          '"password":"legacy-synthetic-value"}]';
    final store = _accountStore(preferences);

    await store.load();

    expect(store.accounts, hasLength(1));
    final rewritten = preferences.values[GmxAccountStore.storageKey]!;
    expect(rewritten, isNot(contains('legacy-synthetic-value')));
    expect(rewritten, isNot(contains('password')));
  });

  test('Gespeichertes Passwort ist vor Ablauf nutzbar', () async {
    var now = DateTime.utc(2026, 8, 1);
    final store = _accountStore(_MemoryPreferences());
    final secureStorage = _MemorySecureStorage();
    final manager = GmxCredentialManager(
      accountStore: store,
      secureStorage: secureStorage,
      now: () => now,
    );
    var account = await store.ensureAccount('private@test.example');
    await manager.saveFor30Days(account, 'synthetic-password');
    account = store.findById(account.accountId)!;

    now = DateTime.utc(2026, 8, 30);

    expect(await manager.readValid(account), 'synthetic-password');
    expect(store.accounts.single.credentialAvailable, isTrue);
  });

  test(
    'Secure-Storage-Credential ist nach simuliertem Neustart lesbar',
    () async {
      final preferences = _MemoryPreferences();
      final keychain = <String, String>{};
      final firstStore = _accountStore(preferences);
      final firstManager = GmxCredentialManager(
        accountStore: firstStore,
        secureStorage: _MemorySecureStorage(keychain),
        now: () => DateTime.utc(2026, 8, 1),
      );
      final account = await firstStore.ensureAccount('private@test.example');
      await firstManager.saveFor30Days(account, 'synthetic-password');

      final restartedStore = _accountStore(preferences);
      await restartedStore.load();
      final restartedManager = GmxCredentialManager(
        accountStore: restartedStore,
        secureStorage: _MemorySecureStorage(keychain),
        now: () => DateTime.utc(2026, 8, 2),
      );

      expect(
        await restartedManager.readValid(restartedStore.accounts.single),
        'synthetic-password',
      );
      expect(restartedStore.accounts.single.credentialAvailable, isTrue);
    },
  );

  test(
    'Fehlendes Credential setzt credentialAvailable nach Neustart zurück',
    () async {
      final preferences = _MemoryPreferences();
      final firstStore = _accountStore(preferences);
      final account = await firstStore.ensureAccount('private@test.example');
      await firstStore.setCredentialAvailable(account.accountId, true);

      final restartedStore = _accountStore(preferences);
      await restartedStore.load();
      final restartedManager = GmxCredentialManager(
        accountStore: restartedStore,
        secureStorage: _MemorySecureStorage(),
        now: () => DateTime.utc(2026, 8, 2),
      );

      expect(
        await restartedManager.readValid(restartedStore.accounts.single),
        isNull,
      );
      expect(restartedStore.accounts, hasLength(1));
      expect(restartedStore.accounts.single.credentialAvailable, isFalse);
    },
  );

  test(
    'Keychain-Lesefehler setzt credentialAvailable fail-closed zurück',
    () async {
      final store = _accountStore(_MemoryPreferences());
      final account = await store.ensureAccount('private@test.example');
      await store.setCredentialAvailable(account.accountId, true);
      final manager = GmxCredentialManager(
        accountStore: store,
        secureStorage: _UnreadableSecureStorage(),
        now: () => DateTime.utc(2026, 8, 2),
      );

      await expectLater(
        manager.readValid(store.accounts.single),
        throwsA(isA<GmxCredentialStorageException>()),
      );
      expect(store.accounts.single.credentialAvailable, isFalse);
    },
  );

  test(
    'Nicht lesbarer Keychain-Write wird nicht als verfügbar markiert',
    () async {
      final store = _accountStore(_MemoryPreferences());
      final account = await store.ensureAccount('private@test.example');
      final manager = GmxCredentialManager(
        accountStore: store,
        secureStorage: _NonPersistingSecureStorage(),
        now: () => DateTime.utc(2026, 8, 2),
      );

      await expectLater(
        manager.saveFor30Days(account, 'synthetic-password'),
        throwsA(isA<GmxCredentialStorageException>()),
      );
      expect(store.accounts.single.credentialAvailable, isFalse);
    },
  );

  test(
    'Passwort wird nach mehr als 30 Tagen verworfen, Konto bleibt',
    () async {
      var now = DateTime.utc(2026, 8, 1);
      final store = _accountStore(_MemoryPreferences());
      final secureStorage = _MemorySecureStorage();
      final manager = GmxCredentialManager(
        accountStore: store,
        secureStorage: secureStorage,
        now: () => now,
      );
      var account = await store.ensureAccount('private@test.example');
      await manager.saveFor30Days(account, 'synthetic-password');
      account = store.findById(account.accountId)!;

      now = DateTime.utc(2026, 9, 1, 0, 0, 1);

      expect(await manager.readValid(account), isNull);
      expect(secureStorage.values, isEmpty);
      expect(store.accounts, hasLength(1));
      expect(store.accounts.single.credentialAvailable, isFalse);
    },
  );

  test('Manuelles Entfernen löscht nur Credential, nicht Konto', () async {
    final store = _accountStore(_MemoryPreferences());
    final secureStorage = _MemorySecureStorage();
    final manager = GmxCredentialManager(
      accountStore: store,
      secureStorage: secureStorage,
      now: () => DateTime.utc(2026, 8, 1),
    );
    var account = await store.ensureAccount('private@test.example');
    await manager.saveFor30Days(account, 'synthetic-password');
    account = store.findById(account.accountId)!;

    await manager.remove(account);

    expect(secureStorage.values, isEmpty);
    expect(store.accounts, hasLength(1));
    expect(store.accounts.single.credentialAvailable, isFalse);
  });

  test('Konto-Löschen entfernt auch Secure-Storage-Credentials', () async {
    final store = _accountStore(_MemoryPreferences());
    final secureStorage = _MemorySecureStorage();
    final manager = GmxCredentialManager(
      accountStore: store,
      secureStorage: secureStorage,
      now: () => DateTime.utc(2026, 8, 1),
    );
    var account = await store.ensureAccount('private@test.example');
    await manager.saveFor30Days(account, 'synthetic-password');
    account = store.findById(account.accountId)!;

    await manager.deleteAccount(account);

    expect(secureStorage.values, isEmpty);
    expect(store.accounts, isEmpty);
  });

  test('Public Demo liest oder schreibt keine echten GMX-Konten', () async {
    final preferences = _MemoryPreferences()
      ..values[GmxAccountStore.storageKey] =
          '[{"accountId":"private","provider":"gmx",'
          '"email":"private@test.example",'
          '"credentialAvailable":false}]';
    final store = _accountStore(preferences, publicDemo: true);
    final secureStorage = _MemorySecureStorage();
    final manager = GmxCredentialManager(
      accountStore: store,
      secureStorage: secureStorage,
    );

    await store.load();

    expect(store.accounts, isEmpty);
    await expectLater(
      store.ensureAccount('other@test.example'),
      throwsStateError,
    );
    await expectLater(
      manager.readValid(
        const GmxAccount(
          accountId: 'private',
          email: 'private@test.example',
          credentialAvailable: true,
        ),
      ),
      throwsStateError,
    );
    expect(secureStorage.values, isEmpty);
  });
}
