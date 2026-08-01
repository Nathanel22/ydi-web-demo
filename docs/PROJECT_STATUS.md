# YDI Projektstatus

Stand: 19. Juli 2026

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
10. später iOS-Build auf aktueller Apple-Hardware vorbereiten

## Nächster Startpunkt

Die native Windows-App starten, ein GMX-Konto neu scannen und anschließend einen
Newsletter-Dienst öffnen. Bei vorhandenem HTTP(S)-Abmeldelink muss der Button die
offizielle externe Seite öffnen; ohne gespeicherte URL bleibt er deaktiviert.
