import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_dataset.dart';
import 'service_catalog.dart';
import 'account_scan_store.dart';

final scanDataNotifier = ValueNotifier<ScanDataset?>(null);

final scanDataStore = ScanDataStore();

class ScanDataStore {
  static const _storageKey = 'ydi_local_scan_dataset_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

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
    await _preferences.setString(_storageKey, jsonEncode(normalized.toJson()));
    scanDataNotifier.value = normalized;
  }

  Future<void> clear() async {
    await _preferences.remove(_storageKey);
    scanDataNotifier.value = null;
    await accountScanStore.clear();
  }

  Future<void> removeAccount(String account) async {
    final current = scanDataNotifier.value;
    if (current == null) return;
    final updated = current.withoutAccounts({account});
    if (updated.services.isEmpty) {
      await clear();
    } else {
      await save(updated);
    }
    await accountScanStore.remove(account);
  }
}
