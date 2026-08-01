import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/services/scan_csv_importer.dart';

void main() {
  test('GMX und Gmail werden lokal zusammengeführt', () {
    const header =
        'Dienst;Domain;Kategorie;Mails gesamt;Newsletter;Sicherheit;Transaktion;Account;Unbekannt;Abmeldelink gefunden;Abmeldelink Anzahl;Prüfhinweis\n';
    final dataset = const ScanCsvImporter().parseContents({
      'idy_gmx_scan_result.csv':
          '${header}Instant Gaming;instant-gaming.com;Gaming;23;12;0;4;1;6;Nein;0;',
      'idy_gmail_scan_result.csv':
          '${header}Instant Gaming;instant-gaming.com;Gaming;35;14;0;5;1;15;Ja;1;',
    });

    expect(dataset.accounts, ['GMX', 'Gmail']);
    expect(dataset.services.length, 1);
    expect(dataset.services.single.totalMailCount, 58);
    expect(dataset.services.single.isDuplicateRegistration, true);
    expect(dataset.services.single.newsletterCountFor('Gmail'), 14);
  });

  test('Ein erneuter Scan ersetzt nur das betroffene Konto', () {
    const header =
        'Dienst;Domain;Kategorie;Mails gesamt;Newsletter;Sicherheit;Transaktion;Account;Unbekannt;Abmeldelink gefunden;Abmeldelink Anzahl;Prüfhinweis\n';
    final importer = const ScanCsvImporter();
    final firstScan = importer.parseContents({
      'idy_gmx_scan_result.csv':
          '${header}Netflix;netflix.com;Streaming;69;68;1;0;0;0;Ja;1;',
      'idy_gmail_scan_result.csv':
          '${header}Google;google.com;Technologie;62;0;26;0;0;36;Nein;0;',
    });
    final refreshedGmx = importer.parseContents({
      'idy_gmx_scan_result.csv':
          '${header}Netflix;netflix.com;Streaming;12;11;0;0;0;1;Ja;1;',
    });

    final result = firstScan.replacingAccountsWith(refreshedGmx);

    expect(result.accounts, ['GMX', 'Gmail']);
    expect(result.services.length, 2);
    expect(
      result.services
          .firstWhere((service) => service.name == 'Netflix')
          .totalMailCount,
      12,
    );
    expect(
      result.services
          .firstWhere((service) => service.name == 'Google')
          .totalMailCount,
      62,
    );
  });
}
