# YDI – Your Digital Identity

YDI hilft Menschen zu verstehen, bei welchen digitalen Diensten sie registriert sind und über welche E-Mail-Konten diese Dienste gefunden wurden.

## Aktueller Prototyp

- Flutter-Web-App mit responsivem Dashboard
- GMX- und Gmail-Ergebnisse aus lokalen CSV-Scans importieren
- mehrere E-Mail-Konten zusammenführen und einzeln filtern
- Dienste, Newsletter, Sicherheitshinweise und Abmeldelinks anzeigen
- doppelte Registrierungen kontoübergreifend erkennen
- Ergebnisse lokal im Browser speichern und bewusst löschen
- Scan-Ergebnisse über den Aktualisieren-Button ersetzen
- Oberfläche auf Deutsch, Englisch, Französisch und Spanisch vorbereitet

Die App lädt keine CSV-Dateien oder E-Mail-Daten zu einem YDI-Server hoch. Im Web-Prototyp werden importierte Zusammenfassungen im lokalen Browserspeicher abgelegt. Die Produktions-App soll sensible Daten verschlüsselt auf dem Gerät speichern.

## Lokal starten

```powershell
cd "C:\Users\RothJ\Documents\Codex\2026-07-11\referenced-chatgpt-conversation-this-is-untrusted\ydi_app"
flutter pub get
flutter run -d chrome --web-port 7357
```

Der feste Port ist notwendig, damit der Browser bei jedem Start denselben lokalen Speicher verwendet.

## Projektstruktur

```text
lib/
  data/           Demo- und lokale Scandaten
  localization/   Sprachen und Texte
  models/         Dienste, Kategorien und Scan-Datensatz
  services/       CSV-Import und Aktualisierungslogik
  main.dart       aktueller UI-Prototyp
test/             automatische Basis- und Importtests
docs/             Projektstatus und Entscheidungen
```

## Nächster technischer Meilenstein

Gmail über Google OAuth verbinden und ausschließlich notwendige Metadaten lokal analysieren. GMX/WEB.DE folgen über einen transparenten IMAP-Connector in der nativen App.
