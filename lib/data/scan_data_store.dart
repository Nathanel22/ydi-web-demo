import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_dataset.dart';
import 'service_catalog.dart';
import 'account_scan_store.dart';

final scanDataNotifier = ValueNotifier<ScanDataset?>(null);

final scanDataStore = ScanDataStore();

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
  ScanDataStore({ScanPreferences? preferences})
    : _preferences = preferences ?? SharedPreferencesScanPreferences();

  static const _storageKey = 'ydi_local_scan_dataset_v1';
  final ScanPreferences _preferences;
  final Set<String> _memoryOnlyAccounts = {};

  Future<void> load() async {
    final stored = await _preferences.getString(_storageKey);
    if (stored == null) return;

    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      final normalized = ServiceCatalog.normalizeDataset(
        ScanDataset.fromJson(json),
      );
      scanDataNotifier.value = normalized;
      await _preferences.setString(
        _storageKey,
        jsonEncode(normalized.toJson()),
      );
    } on FormatException {
      await clear();
    } on TypeError {
      await clear();
    }
  }

  Future<void> save(ScanDataset dataset) async {
    final normalized = ServiceCatalog.normalizeDataset(dataset);
    final persistent = normalized.withoutAccounts(_memoryOnlyAccounts);
    if (persistent.services.isEmpty && persistent.sourceFiles.isEmpty) {
      await _preferences.remove(_storageKey);
    } else {
      await _preferences.setString(
        _storageKey,
        jsonEncode(persistent.toJson()),
      );
    }
    scanDataNotifier.value = normalized;
  }

  /// Publishes a complete dataset for the current session while marking
  /// [account] as ineligible for every later persistent write.
  ScanDataset setMemoryOnlyDataset(String account, ScanDataset dataset) {
    _memoryOnlyAccounts.add(account);
    final normalized = ServiceCatalog.normalizeDataset(dataset);
    scanDataNotifier.value = normalized;
    return normalized;
  }

  Future<void> clear() async {
    await _preferences.remove(_storageKey);
    _memoryOnlyAccounts.clear();
    scanDataNotifier.value = null;
    await accountScanStore.clear();
  }

  Future<void> removeAccount(String account) async {
    final current = scanDataNotifier.value;
    if (current == null) return;
    final updated = current.withoutAccounts({account});
    if (_memoryOnlyAccounts.remove(account)) {
      scanDataNotifier.value = updated.services.isEmpty ? null : updated;
      return;
    }
    if (updated.services.isEmpty) {
      await clear();
    } else {
      await save(updated);
    }
    await accountScanStore.remove(account);
  }
}
