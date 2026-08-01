import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final accountScanTimesNotifier = ValueNotifier<Map<String, DateTime>>({});
final accountScanStore = AccountScanStore();

class AccountScanStore {
  static const _storageKey = 'ydi_account_scan_times_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<void> load() async {
    final stored = await _preferences.getString(_storageKey);
    if (stored == null) return;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(stored) as Map);
      accountScanTimesNotifier.value = {
        for (final entry in decoded.entries)
          if (DateTime.tryParse(entry.value as String) case final time?)
            entry.key: time,
      };
    } catch (_) {
      await _preferences.remove(_storageKey);
      accountScanTimesNotifier.value = {};
    }
  }

  Future<void> markScanned(String account) async {
    final updated = Map<String, DateTime>.from(accountScanTimesNotifier.value)
      ..[account] = DateTime.now();
    await _save(updated);
  }

  Future<void> remove(String account) async {
    final updated = Map<String, DateTime>.from(accountScanTimesNotifier.value)
      ..remove(account);
    await _save(updated);
  }

  Future<void> clear() async {
    await _preferences.remove(_storageKey);
    accountScanTimesNotifier.value = {};
  }

  Future<void> _save(Map<String, DateTime> values) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode(
        values.map((key, value) => MapEntry(key, value.toIso8601String())),
      ),
    );
    accountScanTimesNotifier.value = values;
  }
}
