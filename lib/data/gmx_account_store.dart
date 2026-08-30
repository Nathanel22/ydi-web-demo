import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/public_demo.dart';
import '../models/gmx_account.dart';

final gmxAccountsNotifier = ValueNotifier<List<GmxAccount>>(
  const <GmxAccount>[],
);
final gmxAccountStore = GmxAccountStore();

abstract interface class GmxAccountPreferences {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesGmxAccountPreferences implements GmxAccountPreferences {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}

class GmxAccountStore {
  GmxAccountStore({
    GmxAccountPreferences? preferences,
    ValueNotifier<List<GmxAccount>>? notifier,
    this.publicDemo = isPublicDemo,
    DateTime Function()? now,
    int Function()? randomIdPart,
  }) : _preferences = preferences ?? SharedPreferencesGmxAccountPreferences(),
       notifier = notifier ?? gmxAccountsNotifier,
       _now = now ?? DateTime.now,
       _randomIdPart = randomIdPart ?? (() => Random.secure().nextInt(1 << 32));

  static const storageKey = 'ydi_gmx_accounts_v1';

  final GmxAccountPreferences _preferences;
  final ValueNotifier<List<GmxAccount>> notifier;
  final bool publicDemo;
  final DateTime Function() _now;
  final int Function() _randomIdPart;

  List<GmxAccount> get accounts => notifier.value;

  Future<void> load() async {
    if (publicDemo) {
      notifier.value = const <GmxAccount>[];
      return;
    }
    final stored = await _preferences.getString(storageKey);
    if (stored == null) return;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) throw const FormatException();
      final accounts = decoded
          .map(GmxAccount.tryFromJson)
          .whereType<GmxAccount>()
          .toList(growable: false);
      notifier.value = accounts;
      // Rewrites valid records through the allow-listed model. Unknown legacy
      // fields (including any accidentally introduced secret) are discarded.
      await _save(accounts);
    } on FormatException {
      await _clearInvalidData();
    } on TypeError {
      await _clearInvalidData();
    }
  }

  GmxAccount? findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email == normalized) return account;
    }
    return null;
  }

  GmxAccount? findById(String accountId) {
    for (final account in accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }

  Future<GmxAccount> ensureAccount(String email) async {
    _ensurePersistenceAllowed();
    final normalized = email.trim().toLowerCase();
    final existing = findByEmail(normalized);
    if (existing != null) return existing;
    final now = _now().toUtc();
    final account = GmxAccount(
      accountId:
          'gmx_${now.microsecondsSinceEpoch}_${_randomIdPart().toRadixString(16)}',
      email: normalized,
    );
    await _save([...accounts, account]);
    return account;
  }

  Future<GmxAccount> markScanned(String accountId, DateTime scannedAt) async {
    _ensurePersistenceAllowed();
    final account = findById(accountId);
    if (account == null) throw StateError('GMX account is not registered.');
    final updated = account.withLastSuccessfulScanAt(scannedAt.toUtc());
    await _replace(updated);
    return updated;
  }

  Future<GmxAccount> setCredentialAvailable(
    String accountId,
    bool available,
  ) async {
    _ensurePersistenceAllowed();
    final account = findById(accountId);
    if (account == null) throw StateError('GMX account is not registered.');
    final updated = account.withCredentialAvailable(available);
    await _replace(updated);
    return updated;
  }

  Future<void> remove(String accountId) async {
    _ensurePersistenceAllowed();
    await _save(
      accounts.where((account) => account.accountId != accountId).toList(),
    );
  }

  Future<void> clear() async {
    _ensurePersistenceAllowed();
    await _preferences.remove(storageKey);
    notifier.value = const <GmxAccount>[];
  }

  Future<void> _replace(GmxAccount updated) async {
    await _save([
      for (final account in accounts)
        if (account.accountId == updated.accountId) updated else account,
    ]);
  }

  Future<void> _clearInvalidData() async {
    await _preferences.remove(storageKey);
    notifier.value = const <GmxAccount>[];
  }

  Future<void> _save(List<GmxAccount> accounts) async {
    if (accounts.isEmpty) {
      await _preferences.remove(storageKey);
    } else {
      await _preferences.setString(
        storageKey,
        jsonEncode(accounts.map((account) => account.toJson()).toList()),
      );
    }
    notifier.value = List.unmodifiable(accounts);
  }

  void _ensurePersistenceAllowed() {
    if (publicDemo) {
      throw StateError('Real GMX account persistence is disabled in demos.');
    }
  }
}
