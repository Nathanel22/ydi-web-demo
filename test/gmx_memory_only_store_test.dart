import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/scan_data_store.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/models/service_category.dart';
import 'package:ydi_app/models/service_item.dart';

class _MemoryPreferences implements ScanPreferences {
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

void main() {
  tearDown(() => scanDataNotifier.value = null);

  test('Memory-only-GMX-Daten gelangen nicht in die Persistenz', () async {
    const account = 'GMX · private-test@example.com';
    const tokenUrl = 'https://example.com/unsubscribe/private-token';
    final preferences = _MemoryPreferences();
    final store = ScanDataStore(preferences: preferences);
    final dataset = ScanDataset(
      services: const [
        ServiceItem(
          id: 'synthetic_service',
          name: 'Synthetic Service',
          categoryId: ServiceCategory.shopping,
          mailCounts: {account: 2},
          color: Colors.blue,
          monogram: 'SS',
          domains: ['example.com'],
          unsubscribeByAccount: {account: true},
          unsubscribeUrlsByAccount: {account: tokenUrl},
        ),
      ],
      sourceFiles: const ['gmx-imap:$account'],
    );

    store.setMemoryOnlyDataset(account, dataset);
    await store.save(scanDataNotifier.value!);

    final persistedText = preferences.values.values.join();
    expect(persistedText, isNot(contains('private-test@example.com')));
    expect(persistedText, isNot(contains('private-token')));
    expect(scanDataNotifier.value?.accounts, contains(account));
  });
}
