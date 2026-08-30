import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/gmx_account_store.dart';
import '../models/gmx_account.dart';

final gmxCredentialManager = GmxCredentialManager(
  accountStore: gmxAccountStore,
  secureStorage: FlutterGmxSecureStorage(),
);

abstract interface class GmxSecureStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class GmxCredentialStorageException implements Exception {
  const GmxCredentialStorageException();
}

class FlutterGmxSecureStorage implements GmxSecureStorage {
  FlutterGmxSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accountName: 'com.nathanel22.ydi.gmx',
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class GmxCredentialManager {
  GmxCredentialManager({
    required GmxAccountStore accountStore,
    required GmxSecureStorage secureStorage,
    DateTime Function()? now,
  }) : _accountStore = accountStore,
       _secureStorage = secureStorage,
       _now = now ?? DateTime.now;

  static const maximumAge = Duration(days: 30);
  static const _passwordKeyPrefix = 'ydi_gmx_password_v1_';
  static const _storedAtKeyPrefix = 'ydi_gmx_password_stored_at_v1_';

  final GmxAccountStore _accountStore;
  final GmxSecureStorage _secureStorage;
  final DateTime Function() _now;

  Future<void> saveFor30Days(GmxAccount account, String password) async {
    _ensureAllowed();
    if (password.isEmpty) throw ArgumentError('Password must not be empty.');
    final passwordKey = _passwordKey(account.accountId);
    final storedAtKey = _storedAtKey(account.accountId);
    try {
      await _secureStorage.write(passwordKey, password);
      final storedAtValue = _now().toUtc().toIso8601String();
      await _secureStorage.write(storedAtKey, storedAtValue);
      final verifiedPassword = await _secureStorage.read(passwordKey);
      final verifiedStoredAt = await _secureStorage.read(storedAtKey);
      if (verifiedPassword != password || verifiedStoredAt != storedAtValue) {
        throw const GmxCredentialStorageException();
      }
      await _accountStore.setCredentialAvailable(account.accountId, true);
    } catch (_) {
      await _invalidate(account, deleteSecureValues: true);
      throw const GmxCredentialStorageException();
    }
  }

  Future<String?> readValid(GmxAccount account) async {
    _ensureAllowed();
    if (!account.credentialAvailable) return null;
    late final String? password;
    late final String? storedAtValue;
    try {
      password = await _secureStorage.read(_passwordKey(account.accountId));
      storedAtValue = await _secureStorage.read(
        _storedAtKey(account.accountId),
      );
    } catch (_) {
      await _invalidate(account, deleteSecureValues: false);
      throw const GmxCredentialStorageException();
    }
    final storedAt = storedAtValue == null
        ? null
        : DateTime.tryParse(storedAtValue)?.toUtc();
    final now = _now().toUtc();
    final invalid =
        password == null ||
        password.isEmpty ||
        storedAt == null ||
        storedAt.isAfter(now) ||
        now.difference(storedAt) > maximumAge;
    if (invalid) {
      await _invalidate(account, deleteSecureValues: true);
      return null;
    }
    return password;
  }

  Future<void> remove(GmxAccount account) async {
    _ensureAllowed();
    await _deleteKeys(account.accountId);
    if (_accountStore.findById(account.accountId) != null) {
      await _accountStore.setCredentialAvailable(account.accountId, false);
    }
  }

  Future<void> deleteAccount(GmxAccount account) async {
    _ensureAllowed();
    await _deleteKeys(account.accountId);
    await _accountStore.remove(account.accountId);
  }

  Future<void> discardExpiredCredentials() async {
    _ensureAllowed();
    for (final account in List<GmxAccount>.from(_accountStore.accounts)) {
      if (!account.credentialAvailable) continue;
      try {
        await readValid(account);
      } on GmxCredentialStorageException {
        // readValid already made the persisted availability status fail-closed.
      }
    }
  }

  Future<void> _deleteKeys(String accountId) async {
    await Future.wait([
      _secureStorage.delete(_passwordKey(accountId)),
      _secureStorage.delete(_storedAtKey(accountId)),
    ]);
  }

  Future<void> _invalidate(
    GmxAccount account, {
    required bool deleteSecureValues,
  }) async {
    var deletionFailed = false;
    if (deleteSecureValues) {
      try {
        await _deleteKeys(account.accountId);
      } catch (_) {
        deletionFailed = true;
      }
    }
    if (_accountStore.findById(account.accountId) != null) {
      await _accountStore.setCredentialAvailable(account.accountId, false);
    }
    if (deletionFailed) throw const GmxCredentialStorageException();
  }

  void _ensureAllowed() {
    if (_accountStore.publicDemo) {
      throw StateError('Real GMX credentials are disabled in demos.');
    }
  }

  String _passwordKey(String accountId) => '$_passwordKeyPrefix$accountId';

  String _storedAtKey(String accountId) => '$_storedAtKeyPrefix$accountId';
}
