import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/models/service_category.dart';
import 'package:ydi_app/models/service_item.dart';

void main() {
  const gmxOne = 'GMX · first@example.com';
  const gmxTwo = 'GMX · second@example.com';

  ServiceItem service({
    required String id,
    required Map<String, int> mailCounts,
    Map<String, String> unsubscribeUrls = const {},
  }) => ServiceItem(
    id: id,
    name: id,
    categoryId: ServiceCategory.shopping,
    mailCounts: mailCounts,
    color: Colors.blue,
    monogram: id.substring(0, 1).toUpperCase(),
    domains: ['$id.example'],
    newsletterCounts: {for (final entry in mailCounts.entries) entry.key: 1},
    unsubscribeByAccount: {
      for (final entry in mailCounts.entries) entry.key: true,
    },
    unsubscribeUrlsByAccount: unsubscribeUrls,
    unsubscribeRequiresPostByAccount: {
      for (final account in unsubscribeUrls.keys) account: true,
    },
  );

  test('Entfernen eines Kontos behält andere Kontodaten bei', () {
    final dataset = ScanDataset(
      services: [
        service(id: 'shared', mailCounts: {gmxOne: 5, gmxTwo: 3}),
        service(id: 'only_first', mailCounts: {gmxOne: 2}),
        service(id: 'only_second', mailCounts: {gmxTwo: 4}),
      ],
      sourceFiles: ['gmx-imap:$gmxOne', 'gmx-imap:$gmxTwo'],
    );

    final result = dataset.withoutAccounts({gmxOne});

    expect(result.accounts, [gmxTwo]);
    expect(
      result.services.map((item) => item.id),
      isNot(contains('only_first')),
    );
    expect(
      result.services.map((item) => item.id),
      containsAll(['shared', 'only_second']),
    );
    expect(
      result.services.firstWhere((item) => item.id == 'shared').mailCounts,
      {gmxTwo: 3},
    );
    expect(result.sourceFiles, ['gmx-imap:$gmxTwo']);
  });

  test('Abmeldelinks bleiben lokal serialisierbar', () {
    final original = service(
      id: 'newsletter',
      mailCounts: {gmxOne: 1},
      unsubscribeUrls: {gmxOne: 'https://example.com/unsubscribe/token'},
    );

    final restored = ServiceItem.fromJson(original.toJson());

    expect(
      restored.unsubscribeUrlFor('Alle E-Mail-Konten'),
      'https://example.com/unsubscribe/token',
    );
    expect(restored.unsubscribeUrlFor(gmxOne), contains('/unsubscribe/'));
    expect(restored.unsubscribeRequiresPostFor(gmxOne), isTrue);
  });

  test('Alte Scandaten ohne gespeicherte URL bleiben kompatibel', () {
    final json = service(id: 'legacy', mailCounts: {gmxOne: 1}).toJson()
      ..remove('unsubscribeUrlsByAccount');

    final restored = ServiceItem.fromJson(json);

    expect(restored.hasUnsubscribeLinkFor(gmxOne), isTrue);
    expect(restored.unsubscribeUrlFor(gmxOne), isNull);
  });

  test('Alte URLs ohne bekannten Aufruftyp werden vorsichtig blockiert', () {
    final json = service(
      id: 'legacy_url',
      mailCounts: {gmxOne: 1},
      unsubscribeUrls: {gmxOne: 'https://example.com/u/token'},
    ).toJson()..remove('unsubscribeRequiresPostByAccount');

    final restored = ServiceItem.fromJson(json);

    expect(restored.unsubscribeRequiresPostFor(gmxOne), isTrue);
  });
}
