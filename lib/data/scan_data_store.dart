import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/public_demo.dart';
import '../models/scan_dataset.dart';
import '../services/gmx_credential_manager.dart';
import 'service_catalog.dart';
import 'account_scan_store.dart';
import 'encrypted_gmx_scan_store.dart';
import 'gmx_scan_file_factory.dart';

final scanDataNotifier = ValueNotifier<ScanDataset?>(null);

final scanDataStore = ScanDataStore(
  gmxPersistence: EncryptedGmxScanPersistence(
    createGmxScanFile(),
    FlutterGmxSecureStorage(),
  ),
  publicDemo: isPublicDemo,
);

abstract interface class ScanPreferences {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesScanPreferences implements ScanPreferences {
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

class ScanDataStore {
  ScanDataStore({
    ScanPreferences? preferences,
    GmxScanPersistence? gmxPersistence,
    ValueNotifier<ScanDataset?>? notifier,
    Future<void> Function()? clearAccountScanTimes,
    Future<void> Function(String account)? removeAccountScanTime,
    this.publicDemo = false,
  }) : _preferences = preferences ?? SharedPreferencesScanPreferences(),
       _gmxPersistence = gmxPersistence ?? const NoopGmxScanPersistence(),
       notifier = notifier ?? scanDataNotifier,
       _clearAccountScanTimes =
           clearAccountScanTimes ?? (() => accountScanStore.clear()),
       _removeAccountScanTime =
           removeAccountScanTime ??
           ((account) => accountScanStore.remove(account));

  static const _storageKey = 'ydi_local_scan_dataset_v1';
  final ScanPreferences _preferences;
  final GmxScanPersistence _gmxPersistence;
  final ValueNotifier<ScanDataset?> notifier;
  final Future<void> Function() _clearAccountScanTimes;
  final Future<void> Function(String account) _removeAccountScanTime;
  final bool publicDemo;

  Future<void> load() async {
    if (publicDemo) return;
    ScanDataset? persistent;
    final stored = await _preferences.getString(_storageKey);
    if (stored != null) {
      try {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        final normalized = ServiceCatalog.normalizeDataset(
          ScanDataset.fromJson(json),
        );
        persistent = _withoutDirectGmx(normalized);
        if (_isEmpty(persistent)) {
          persistent = null;
          await _preferences.remove(_storageKey);
        } else {
          await _preferences.setString(
            _storageKey,
            jsonEncode(persistent.toJson()),
          );
        }
      } on FormatException {
        await _preferences.remove(_storageKey);
      } on TypeError {
        await _preferences.remove(_storageKey);
      }
    }

    final encryptedGmx = await _gmxPersistence.load();
    final complete = persistent == null
        ? encryptedGmx
        : encryptedGmx == null
        ? persistent
        : persistent.mergedWith(encryptedGmx);
    notifier.value = complete == null
        ? null
        : ServiceCatalog.normalizeDataset(complete);
  }

  Future<void> save(ScanDataset dataset) async {
    _ensureRealPersistenceAllowed();
    final normalized = ServiceCatalog.normalizeDataset(dataset);
    await _savePersistentParts(normalized);
    notifier.value = normalized;
  }

  Future<ScanDataset> saveGmxDataset(
    String account,
    ScanDataset dataset,
  ) async {
    _ensureRealPersistenceAllowed();
    final normalized = ServiceCatalog.normalizeDataset(dataset);
    if (!_directGmxAccounts(normalized).contains(account)) {
      throw ArgumentError('GMX scan source does not match the account.');
    }
    await _savePersistentParts(normalized);
    notifier.value = normalized;
    return normalized;
  }

  Future<void> _savePersistentParts(ScanDataset normalized) async {
    final persistent = _withoutDirectGmx(normalized);
    final encryptedGmx = _onlyDirectGmx(normalized);
    if (_isEmpty(persistent)) {
      await _preferences.remove(_storageKey);
    } else {
      await _preferences.setString(
        _storageKey,
        jsonEncode(persistent.toJson()),
      );
    }
    await _gmxPersistence.save(_isEmpty(encryptedGmx) ? null : encryptedGmx);
  }

  Future<void> clear() async {
    _ensureRealPersistenceAllowed();
    await _preferences.remove(_storageKey);
    await _gmxPersistence.clear();
    notifier.value = null;
    await _clearAccountScanTimes();
  }

  Future<void> removeAccount(String account) async {
    _ensureRealPersistenceAllowed();
    final current = notifier.value;
    if (current == null) {
      await _gmxPersistence.removeAccount(account);
      await _removeAccountScanTime(account);
      return;
    }
    final updated = current.withoutAccounts({account});
    if (_isEmpty(updated)) {
      await clear();
      return;
    } else {
      await save(updated);
    }
    await _removeAccountScanTime(account);
  }

  Set<String> _directGmxAccounts(ScanDataset dataset) => {
    ...dataset.sourceFiles
        .where((source) => source.toLowerCase().startsWith('gmx-imap:'))
        .map((source) => source.substring('gmx-imap:'.length))
        .where((account) => account.isNotEmpty),
    ...dataset.accounts.where(
      (account) => account.toLowerCase().startsWith('gmx · '),
    ),
  };

  ScanDataset _withoutDirectGmx(ScanDataset dataset) {
    final gmxAccounts = _directGmxAccounts(dataset);
    final filtered = dataset.withoutAccounts(gmxAccounts);
    return ScanDataset(
      services: filtered.services,
      sourceFiles: filtered.services.isEmpty && gmxAccounts.isNotEmpty
          ? const []
          : filtered.sourceFiles
                .where(
                  (source) => !source.toLowerCase().startsWith('gmx-imap:'),
                )
                .toList(growable: false),
    );
  }

  ScanDataset _onlyDirectGmx(ScanDataset dataset) {
    final gmxAccounts = _directGmxAccounts(dataset);
    final filtered = dataset.withoutAccounts(
      dataset.accounts.toSet().difference(gmxAccounts),
    );
    return ScanDataset(
      services: filtered.services,
      sourceFiles: dataset.sourceFiles
          .where((source) => source.toLowerCase().startsWith('gmx-imap:'))
          .toList(growable: false),
    );
  }

  bool _isEmpty(ScanDataset dataset) =>
      dataset.services.isEmpty && dataset.sourceFiles.isEmpty;

  void _ensureRealPersistenceAllowed() {
    if (publicDemo) {
      throw StateError('Real scan persistence is disabled in demos.');
    }
  }
}
