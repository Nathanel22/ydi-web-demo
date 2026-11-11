import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ydi_app/data/scan_data_store.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/models/unsubscribe_option.dart';
import 'package:ydi_app/services/gmail_metadata_scanner.dart';

class _Account extends Fake implements GoogleSignInAccount {
  @override
  String get email => 'synthetic@example.com';
}

class _Preferences implements ScanPreferences {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  for (final oneClick in [true, false]) {
    test(
      'Gmail retains repeated headers and One-Click=$oneClick using mocked metadata only',
      () async {
        final preferences = _Preferences();
        final store = ScanDataStore(
          preferences: preferences,
          notifier: ValueNotifier<ScanDataset?>(null),
        );
        final scanner = GmailMetadataScanner(
          dataStore: store,
          authorizeMetadata: (_) async => {},
        );
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          expect(request.url.host, 'gmail.googleapis.com');
          if (request.url.path.endsWith('/messages')) {
            return http.Response(
              jsonEncode({
                'messages': [
                  {'id': 'synthetic-message'},
                ],
              }),
              200,
            );
          }
          expect(
            request.url.queryParametersAll['metadataHeaders'],
            contains('List-Unsubscribe-Post'),
          );
          return http.Response(
            jsonEncode({
              'payload': {
                'headers': [
                  {'name': 'From', 'value': 'Synthetic <sender@example.net>'},
                  {'name': 'Subject', 'value': 'Synthetic Newsletter'},
                  {
                    'name': 'List-Unsubscribe',
                    'value': '<https://example.net/a,b?token=x,y>',
                  },
                  {
                    'name': 'list-unsubscribe',
                    'value': '<mailto:leave@example.net>',
                  },
                  if (oneClick)
                    {
                      'name': 'List-Unsubscribe-Post',
                      'value': 'List-Unsubscribe=One-Click',
                    },
                ],
              },
            }),
            200,
          );
        });
        final result = await http.runWithClient(
          () => scanner.scanAndSave(_Account(), onProgress: (_, _) {}),
          () => client,
        );
        expect(requests, 2);
        final service = result.services.single;
        final account = scanner.accountLabelFor('synthetic@example.com');
        expect(
          service.unsubscribeOptions.every(
            (option) => option.account == account,
          ),
          isTrue,
        );
        expect(service.unsubscribeOptions.map((option) => option.method), [
          oneClick ? UnsubscribeMethod.oneClickPost : UnsubscribeMethod.httpGet,
          UnsubscribeMethod.mailto,
        ]);
        expect(
          service.unsubscribeUrlFor(account),
          'https://example.net/a,b?token=x,y',
        );
        expect(service.unsubscribeRequiresPostFor(account), oneClick);
        expect(service.newsletterCountFor(account), 1);
        // Structured metadata survives the actual preferences serialization path.
        await store.load();
        expect(
          store.notifier.value?.services.single.unsubscribeOptions,
          service.unsubscribeOptions,
        );
        client.close();
      },
    );
  }
}
