import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/data/service_catalog.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/models/service_category.dart';
import 'package:ydi_app/models/service_item.dart';
import 'package:ydi_app/models/unsubscribe_option.dart';
import 'package:ydi_app/services/unsubscribe_header_parser.dart';

const _account = 'GMX · synthetic@example.com';
const _other = 'Gmail · synthetic@example.net';
const _parser = UnsubscribeHeaderParser();

List<UnsubscribeOption> _parse(
  List<String> headers, {
  List<String> post = const [],
}) => _parser.parse(
  account: _account,
  listUnsubscribe: headers,
  listUnsubscribePost: post,
);

ServiceItem _service(String account, List<UnsubscribeOption> options) =>
    ServiceItem(
      id: 'synthetic',
      name: 'Synthetic',
      categoryId: ServiceCategory.unknown,
      mailCounts: {account: 1},
      color: Colors.blue,
      monogram: 'S',
      domains: const ['synthetic.example'],
      unsubscribeOptions: options,
    );

void main() {
  test('Preserves comma URLs and multiple methods in repeated headers', () {
    final result = _parse([
      '<https://example.com/a,b?token=x,y>, <mailto:leave@example.com?subject=a,b>',
      '<http://example.net/leave>, <https://example.com/a,b?token=x,y>',
    ]);
    expect(result.map((option) => option.uri.toString()), [
      'https://example.com/a,b?token=x,y',
      'mailto:leave@example.com?subject=a,b',
      'http://example.net/leave',
    ]);
    expect(result.map((option) => option.method), [
      UnsubscribeMethod.httpGet,
      UnsubscribeMethod.mailto,
      UnsubscribeMethod.httpGet,
    ]);
    expect(result.every((option) => option.account == _account), isTrue);
    expect(() => result.clear(), throwsUnsupportedError);
  });

  test('Preserves a mailto recipient list and encoded query values', () {
    final result = _parse([
      '<mailto:a@example.com,b@example.net?subject=Leave%20list&body=a%2Cb>',
    ]);
    expect(
      result.single.uri.toString(),
      'mailto:a@example.com,b@example.net?subject=Leave%20list&body=a%2Cb',
    );
    expect(result.single.method, UnsubscribeMethod.mailto);
  });

  test(
    'Unfolds repeated header entries and recognizes case-insensitive schemes',
    () {
      final result = _parse([
        '<HTTPS://example.com/a>,\r\n\t<MAILTO:leave@example.com>',
      ]);
      expect(result, hasLength(2));
      expect(result.first.uri.scheme, 'https');
      expect(result.last.method, UnsubscribeMethod.mailto);
    },
  );

  test('One-Click metadata marks HTTPS POST without changing mailto', () {
    final result = _parse(
      ['<https://example.com/leave>, <mailto:leave@example.com>'],
      post: [' List-Unsubscribe = One-Click ', 'list-unsubscribe=one-click'],
    );
    expect(result.map((option) => option.method), [
      UnsubscribeMethod.oneClickPost,
      UnsubscribeMethod.mailto,
    ]);
  });

  test('One-Click never authorizes POST over plain HTTP', () {
    final result = _parse(
      ['<http://example.com/leave>'],
      post: ['List-Unsubscribe=One-Click'],
    );
    expect(result.single.method, UnsubscribeMethod.unknown);
  });

  for (final post in [
    [''],
    ['not-list-unsubscribe=one-click'],
    ['List-Unsubscribe=One-Click-extra'],
    ['List-Unsubscribe=One-Click', 'unknown'],
  ]) {
    test('Ambiguous POST metadata remains unknown: $post', () {
      expect(
        _parse(['<https://example.com/leave>'], post: post).single.method,
        UnsubscribeMethod.unknown,
      );
    });
  }

  for (final uri in [
    '',
    'javascript:alert(1)',
    'data:text/plain,hello',
    'ftp://example.com/a',
    '/relative',
    'https:///missing-host',
    'https://user:pass@example.com/a',
    'https://example.com:70000/a',
    'https://example.com:bad/a',
    'https://bad host/a',
    'https://example.com/%zz',
    'https://example.com/a\\b',
    'https://example.com/a%0D%0Ab',
    'mailto:',
    'mailto:not-an-address',
    'mailto://leave@example.com',
    'mailto:leave@example.com?subject=a%0Ab',
  ]) {
    test('Rejects malformed or unsupported URI: $uri', () {
      expect(_parse(['<$uri>']), isEmpty);
    });
  }

  test('Rejects injected, nested and unterminated header values', () {
    expect(_parse(['<https://example.com/a>\r\nX-Injected: yes']), isEmpty);
    expect(_parse(['<<https://example.com/a>>']), isEmpty);
    expect(_parse(['<https://example.com/a']), isEmpty);
  });

  test('Skips invalid entries while retaining independent valid options', () {
    expect(
      _parse([
        '<javascript:bad>, <https://example.com/a,b>',
      ]).single.uri.toString(),
      'https://example.com/a,b',
    );
  });

  test('Tolerates one bare URI without splitting its commas', () {
    expect(_parse(['https://example.com/a,b']).single.uri.path, '/a,b');
  });

  test('POST header alone does not fabricate an unsubscribe URL', () {
    expect(_parse([], post: ['List-Unsubscribe=One-Click']), isEmpty);
  });

  test('Account contexts remain distinct for identical URLs', () {
    final first = _parse(['<https://example.com/leave>']).single;
    final second = _parser
        .parse(
          account: _other,
          listUnsubscribe: ['<https://example.com/leave>'],
        )
        .single;
    expect({first, second}, hasLength(2));
  });

  test(
    'Optional structured metadata round-trips without a storage migration',
    () {
      final options = _parse(
        ['<https://example.com/a,b>, <mailto:leave@example.com>'],
        post: ['List-Unsubscribe=One-Click'],
      );
      final original = _service(_account, options);
      final restored = ServiceItem.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.unsubscribeOptions, options);
      final legacy = original.toJson()..remove('unsubscribeOptions');
      expect(ServiceItem.fromJson(legacy).unsubscribeOptions, isEmpty);
    },
  );

  test(
    'Invalid persisted options are skipped and unknown methods stay blocked',
    () {
      final json = _service(_account, []).toJson();
      json['unsubscribeOptions'] = [
        {'account': _account, 'url': 'javascript:bad', 'method': 'httpGet'},
        {
          'account': _account,
          'url': 'https://example.com/leave',
          'method': 'futureMethod',
        },
        {
          'account': _account,
          'url': 'mailto:leave@example.com',
          'method': 'httpGet',
        },
      ];
      final options = ServiceItem.fromJson(json).unsubscribeOptions;
      expect(options, hasLength(2));
      expect(
        options.every((option) => option.method == UnsubscribeMethod.unknown),
        isTrue,
      );
    },
  );

  test(
    'Merge, normalization, removal and replacement preserve account context',
    () {
      final first = _service(_account, _parse(['<https://example.com/a>']));
      final second = _service(
        _other,
        _parser.parse(
          account: _other,
          listUnsubscribe: ['<mailto:leave@example.net>'],
        ),
      );
      final dataset = ScanDataset(services: [first], sourceFiles: const []);
      final incoming = ScanDataset(services: [second], sourceFiles: const []);
      final merged = ServiceCatalog.normalizeDataset(
        dataset.mergedWith(incoming),
      );
      expect(merged.services.single.unsubscribeOptions, [
        ...first.unsubscribeOptions,
        ...second.unsubscribeOptions,
      ]);
      expect(
        merged.withoutAccounts({_account}).services.single.unsubscribeOptions,
        second.unsubscribeOptions,
      );
      final refreshed = _service(
        _account,
        _parse(['<https://example.com/new>']),
      );
      final replacement = merged.replacingAccountsWith(
        ScanDataset(services: [refreshed], sourceFiles: const []),
      );
      expect(
        replacement.services.single.unsubscribeOptions.map(
          (option) => option.uri.toString(),
        ),
        containsAll(['https://example.com/new', 'mailto:leave@example.net']),
      );
      expect(
        replacement.services.single.unsubscribeOptions,
        isNot(contains(first.unsubscribeOptions.single)),
      );
    },
  );
}
