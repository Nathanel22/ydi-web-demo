import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ydi_app/localization/app_language.dart';
import 'package:ydi_app/main.dart';
import 'package:ydi_app/data/scan_data_store.dart';

void main() {
  setUp(() {
    languageNotifier.value = AppLanguage.german;
    scanDataNotifier.value = null;
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const YdiApp());
    await tester.pumpAndSettle();
  }

  testWidgets('YDI startet mit dem gemeinsamen Dashboard', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Your Digital Identity'), findsOneWidget);
    expect(find.text('102'), findsOneWidget);
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
      find.text('1 Dienst wurde auf mehreren E-Mail-Konten erkannt'),
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
