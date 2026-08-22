# YDI Projektstatus

Stand: 22. August 2026

## Dual-System-Entwicklung (10.08.2026)

- Windows-PC bleibt der Hauptentwicklungsrechner für Flutter, Git, Web/Windows
  sowie lokale GMX-/IMAP-Tests.
- Ein MacBook Pro 15 Zoll (2016, Intel, 16 GB RAM, macOS Sequoia 15.7.9
  über OpenCore Legacy Patcher 2.4.1) steht für Xcode, iOS-Simulator und
  echte iOS-Testbuilds zur Verfügung.
- Änderungen an EFI, OpenCore, OCLP, Bootloader, Firmware oder der
  macOS-Systemkonfiguration sind ohne ausdrücklichen Auftrag ausgeschlossen.
- Touch Bar/T1 und Apple-Account-Anmeldung werden separat behandelt und dürfen
  die plattformunabhängige Flutter-Entwicklung nicht blockieren.
- Der erste iOS-Meilenstein ist ein Demo-Daten-Build ohne echte Gmail- oder
  GMX-Verbindung. So werden Toolchain, Plugins, Signing und UI getrennt geprüft.
- Der Flutter-Plattformordner `ios/` wurde kontrolliert auf dem MacBook ergänzt.
- Der iOS-Bootstrap ist abgeschlossen; `macos/` wurde dabei nicht ergänzt.

## iOS-Bootstrap (22.08.2026)

- Branch: `ios-bootstrap`
- Commit: `a1c3967 Bootstrap iOS simulator support`
- YDI wurde erfolgreich im iPhone-16-Plus-Simulator gestartet.
- Der Simulatorstart erfolgte mit `YDI_PUBLIC_DEMO=true` und ausschließlich
  synthetischen Demodaten.
- Der manuelle iOS-Demo-Smoke-Test wurde reproduzierbar auf einem iPhone 16 Plus
  mit iOS 18.6 bestätigt: Das Dashboard öffnete korrekt, ausschließlich
  synthetische Demodaten waren sichtbar und es erschienen keine echten lokalen
  Konten oder Scandaten. Beim Start traten keine offensichtlichen Exceptions
  oder Abstürze auf.
- Letzter Teststand: `flutter test` vollständig bestanden (10/10 Tests).
- Letzter Analysestand: `flutter analyze` ohne Fehler oder Warnungen; lediglich
  zwei bereits bestehende Info-Hinweise.
- Verwendete Mac-Toolchain:
  - macOS Sequoia 15.7.9
  - Flutter 3.44.9
  - Xcode 16.4 / Build 16F6
  - iOS 18.6 Simulator Runtime
  - CocoaPods 1.17.0
- Echtes iPhone-Signing und Gmail OAuth für iOS wurden noch nicht begonnen.
- EFI, OpenCore, OCLP, Bootloader, Firmware und macOS-Systemkonfiguration wurden
  nicht verändert.

## Web Prototype 0.2 – GitHub-Pages-Vorbereitung (01.08.2026)

- eigener compile-time Demo-Modus `YDI_PUBLIC_DEMO=true`
- ausschließlich synthetische Anbieter- und Statistikdaten
- echte Kontoverbindungen und Dateiimport im Demo-Modus gesperrt
- sicherer, nicht ausführbarer GMX-Verbindungsablauf für Vorführungen
- Web-Metadaten für mobile Browser angepasst
- GitHub-Pages-Workflow und `DEPLOYMENT.md` erstellt
- Datenschutzscan ohne echte Adressen, Tokens oder Secrets
- Dart-Analyse ohne Fehler abgeschlossen
- Flutter-Release-Build erfolgreich: `build/web` (01.08.2026)

## Produktkern

YDI („Your Digital Identity“) hilft Nutzern zu verstehen, bei welchen digitalen Diensten sie registriert sind, welche E-Mail-Konten verwendet werden und wo Newsletter, Sicherheitsaktivitäten oder doppelte Registrierungen vorkommen.

Leitprinzip: **YDI analysiert und informiert; der Nutzer entscheidet und handelt selbst.**

## Erreicht

- Flutter-Prototyp mit Dashboard, Navigation, Diensteliste und Detailseiten
- responsive Web-Oberfläche als schneller Entwicklungs- und Testweg
- echte Gmail-Anmeldung über Google OAuth im Google-Cloud-Testprojekt `ydi-development`
- Gmail-Metadatenscan über die offizielle Gmail API
- bis zu 1.000 Nachrichten pro Gmail-Konto werden schrittweise ausgewertet
- mehrere Google-Konten können verbunden und getrennt ausgewertet werden
- kleinere Postfächer werden korrekt beendet, sobald alle verfügbaren Nachrichten verarbeitet sind
- vollständige E-Mail-Adressen werden dort angezeigt, wo Konten eindeutig unterscheidbar sein müssen
- kontoübergreifendes Zusammenführen von Diensten und Erkennung doppelter Registrierungen
- Anzeige der verwendeten Konten und Mailanzahl je Dienst
- Filter nach E-Mail-Konto und Kategorie
- alphabetische Sortierung und Sortierung nach Kategorie
- wachsende lokale Service-Datenbank mit geprüften Namen und Kategorien
- Newsletter-, Abmeldelink- und Sicherheitshinweise werden aus Metadaten abgeleitet
- lokale Speicherung, Aktualisierung und Löschung von Scanergebnissen
- CSV-Import bleibt vorübergehend als Entwicklungs- und Rückfallwerkzeug vorhanden
- vier Startsprachen vorbereitet: Deutsch, Englisch, Französisch und Spanisch
- automatisierte Flutter-Tests für zentrale Abläufe vorhanden
- native Windows-App erfolgreich eingerichtet und gestartet
- zwei GMX-Konten über verschlüsseltes IMAP mit Anwendungspasswort getestet
- bis zu 1.000 GMX-Metadaten pro Konto werden lokal ausgewertet
- GMX-Passwörter werden nach Verbindung bzw. Scan verworfen und nicht gespeichert
- einzelne GMX-Konten bleiben nach App-Neustart mit ihren lokalen Ergebnissen erhalten
- einzelne Konten können samt ausschließlich ihrer lokalen Ergebnisse entfernt werden
- letzter erfolgreicher GMX-Scan wird künftig pro Konto lokal protokolliert
- Newsletter-Zeilen öffnen die zugehörige Dienst-Detailseite
- echte HTTP(S)-Abmeldelinks werden beim GMX-Scan lokal aus `List-Unsubscribe` übernommen
- Abmeldeseiten werden nur auf Nutzeraktion extern geöffnet; YDI meldet nicht automatisch ab
- RFC-8058-One-Click-Endpunkte mit `List-Unsubscribe-Post` werden von normalen
  Browserlinks unterschieden und nicht fälschlich per GET geöffnet

## Datenschutz und Sicherheit

- keine Werbung und kein Verkauf von Nutzer- oder E-Mail-Daten
- keine automatische Newsletter-Abmeldung, Kontolöschung oder Kontaktaufnahme mit Anbietern
- keine Mailtexte oder Anhänge speichern, solange Metadaten ausreichen
- unbekannte Domains werden nicht automatisch an YDI übertragen
- keine privaten Kontakte, persönlichen Absender oder sensiblen/erwachsenen Inhalte in die gemeinsame Service-Datenbank übernehmen
- Dienstkatalog und Nutzer-Scanergebnisse werden getrennt behandelt
- Verbindung trennen und lokale Nutzerdaten löschen müssen als getrennte, verständliche Aktionen verfügbar bleiben
- OAuth und offizielle Provider-Schnittstellen werden gegenüber Passwortzugriff bevorzugt

## Aktuelle Grenzen

- die Webversion ist ein Entwicklungsprototyp und keine fertige Produktions-App
- Google OAuth im Testmodus ist nur für hinterlegte Testkonten verfügbar
- Gmail-Sicherheitshinweise sind heuristische Hinweise und noch keine belastbare Sicherheitsbewertung
- Gmail OAuth funktioniert derzeit im Web-Prototyp, aber noch nicht in der nativen Windows-App
- WEB.DE ist noch nicht direkt angebunden
- direkter IMAP-Zugriff bleibt im Browser technisch nicht möglich
- lokale Produktionsspeicherung muss später auf Mobilgeräten sicher und verschlüsselt umgesetzt werden
- Logos dürfen nur aus einer geprüften, rechtlich sauberen YDI-Datenbank stammen
- Monetarisierung und Vollversionsprüfung sind als Produktregeln definiert, aber noch nicht technisch umgesetzt

## In Arbeit

- GMX-Kontoverwaltung und Scanstatus in der Windows-App testen
- inkrementelle GMX-Scans konzipieren, ohne Zugangsdaten dauerhaft zu speichern
- native Gmail-OAuth-Strategie für Windows und Mobile festlegen

## Nächste Meilensteine

1. GMX-Kontoverwaltung, einzelnes Löschen und Scanzeiten praktisch prüfen
2. Newsletter-Detailseiten und echte Abmeldelinks mit einem neuen GMX-Scan prüfen
3. Gmail nativ über OAuth anbinden
4. Gmail- und GMX-Ergebnisse durch dieselbe YDI-Engine verarbeiten
5. inkrementelle Scans statt wiederholter Vollscans einführen
6. Sicherheitsaktivitäten fachlich sauberer klassifizieren und erklären
7. Dienstkatalog, Kategorien und Alias-Domains kontrolliert erweitern
8. CSV-Import entfernen, sobald Gmail und GMX stabil direkt funktionieren
9. Android-Toolchain einrichten und ersten mobilen Build testen
10. erste iOS-spezifische Funktionen nach dem erfolgreich bestätigten
    Demo-Smoke-Test kontrolliert beginnen

## Nächster Startpunkt

Der iOS-Demo-Smoke-Test ist reproduzierbar bestätigt. Vor der nächsten
plattformübergreifenden Änderung den Stand von Windows und Mac kontrolliert
abgleichen und anschließend die erste iOS-spezifische Funktion planen.
