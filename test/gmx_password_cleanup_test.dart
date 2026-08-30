import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/main.dart';
import 'package:ydi_app/models/scan_dataset.dart';
import 'package:ydi_app/services/gmx_imap_scanner.dart';

class _FakeGmxScanner extends GmxImapScanner {
  _FakeGmxScanner({required this.shouldFail});

  final bool shouldFail;

  @override
  Future<void> testConnection(String email, String password) async {
    if (shouldFail) throw StateError('Synthetic connection failure.');
  }

  @override
  Future<ScanDataset> scanAndSave(
    String email,
    String password, {
    required void Function(int current, int total) onProgress,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  Future<void> pumpPage(WidgetTester tester, GmxImapScanner scanner) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GmxSetupPage(scanner: scanner, realGmxTestAllowed: true),
      ),
    );
  }

  Future<void> enterCredentialsAndTest(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'private-test@example.com');
    await tester.enterText(fields.at(1), 'synthetic-password');
    await tester.tap(find.text('Verbindung testen'));
    await tester.pumpAndSettle();
  }

  String passwordValue(WidgetTester tester) => tester
      .widget<TextFormField>(find.byType(TextFormField).at(1))
      .controller!
      .text;

  testWidgets('Passwort wird nach erfolgreichem Versuch gelöscht', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: false));
    await enterCredentialsAndTest(tester);

    expect(passwordValue(tester), isEmpty);
    expect(find.textContaining('Verbindung erfolgreich'), findsOneWidget);
  });

  testWidgets('Passwort wird nach fehlgeschlagenem Versuch gelöscht', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: true));
    await enterCredentialsAndTest(tester);

    expect(passwordValue(tester), isEmpty);
    expect(find.textContaining('Verbindung fehlgeschlagen'), findsOneWidget);
  });

  testWidgets('Passwort wird bei Inaktivität aus dem Eingabefeld gelöscht', (
    tester,
  ) async {
    await pumpPage(tester, _FakeGmxScanner(shouldFail: false));
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'synthetic-password',
    );

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.inactive,
    );
    await tester.pump();

    expect(passwordValue(tester), isEmpty);
  });
}
