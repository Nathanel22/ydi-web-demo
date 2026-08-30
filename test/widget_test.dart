import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ydi_app/config/public_demo.dart';
import 'package:ydi_app/data/gmx_account_store.dart';
import 'package:ydi_app/localization/app_language.dart';
import 'package:ydi_app/main.dart';
import 'package:ydi_app/data/scan_data_store.dart';
import 'package:ydi_app/models/gmx_account.dart';

void main() {
  setUp(() {
    languageNotifier.value = AppLanguage.german;
    scanDataNotifier.value = null;
    gmxAccountsNotifier.value = const [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const YdiApp());
    await tester.pumpAndSettle();
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    scanDataNotifier.value = publicDemoDataset;
    await pumpApp(tester);
  }

  testWidgets('YDI startet ohne Konto im sicheren Leerzustand', (tester) async {
    await pumpApp(tester);

    expect(find.text('Your Digital Identity'), findsOneWidget);
    expect(find.text('Noch keine E-Mail-Konten verbunden'), findsOneWidget);
    expect(find.text('E-Mail-Konto verbinden'), findsOneWidget);
    expect(find.text('Digitale Dienste'), findsNothing);
    expect(find.text('Netflix'), findsNothing);
  });

  testWidgets('Gespeichertes Konto ohne Scandaten zeigt Sync-Leerzustand', (
    tester,
  ) async {
    gmxAccountsNotifier.value = const [
      GmxAccount(accountId: 'gmx_synthetic', email: 'private-test@example.com'),
    ];
    await pumpApp(tester);

    expect(find.text('GMX verbunden'), findsOneWidget);
    expect(find.textContaining('keine Analyseergebnisse'), findsOneWidget);
    expect(find.text('Jetzt synchronisieren'), findsOneWidget);
    expect(find.text('Noch keine E-Mail-Konten verbunden'), findsNothing);

    await tester.tap(find.text('Jetzt synchronisieren'));
    await tester.pumpAndSettle();

    expect(find.text('Welches Konto aktualisieren?'), findsOneWidget);
  });

  testWidgets('YDI startet mit dem gemeinsamen Dashboard', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Your Digital Identity'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Digitale Dienste'), findsOneWidget);
    expect(find.text('Doppelte Registrierungen'), findsOneWidget);
    expect(find.text('Häufigste Dienste'), findsOneWidget);
  });

  testWidgets('Doppelte Registrierungen lassen sich öffnen', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Doppelte Registrierungen'));
    await tester.pumpAndSettle();

    expect(find.text('Instant Gaming'), findsOneWidget);
    expect(
      find.text('2 Dienste wurden auf mehreren E-Mail-Konten erkannt'),
      findsOneWidget,
    );
  });

  testWidgets('Die Diensteliste lässt sich vom Dashboard öffnen', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Alle anzeigen'));
    await tester.pumpAndSettle();

    expect(find.text('Digitale Dienste'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
  });
}
