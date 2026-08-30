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
      await _secureStorage.write(storedAtKey, _now().toUtc().toIso8601String());
      await _accountStore.setCredentialAvailable(account.accountId, true);
    } catch (_) {
      await _deleteKeys(account.accountId);
      rethrow;
    }
  }

  Future<String?> readValid(GmxAccount account) async {
    _ensureAllowed();
    if (!account.credentialAvailable) return null;
    final password = await _secureStorage.read(_passwordKey(account.accountId));
    final storedAtValue = await _secureStorage.read(
      _storedAtKey(account.accountId),
    );
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
      await remove(account);
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
      } catch (_) {
        // A temporarily unavailable platform key store must not prevent the
        // app from starting. Credential use still remains fail-closed.
      }
    }
  }

  Future<void> _deleteKeys(String accountId) async {
    await Future.wait([
      _secureStorage.delete(_passwordKey(accountId)),
      _secureStorage.delete(_storedAtKey(accountId)),
    ]);
  }

  void _ensureAllowed() {
    if (_accountStore.publicDemo) {
      throw StateError('Real GMX credentials are disabled in demos.');
    }
  }

  String _passwordKey(String accountId) => '$_passwordKeyPrefix$accountId';

  String _storedAtKey(String accountId) => '$_storedAtKeyPrefix$accountId';
}
