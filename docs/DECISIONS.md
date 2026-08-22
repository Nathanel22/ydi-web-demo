# YDI Decision Log

Stand: 22. August 2026

## Entwicklungsgeräte

- **D043:** Windows bleibt die primäre Entwicklungsplattform. Das MacBook Pro
  15 Zoll (2016) wird ergänzend für Xcode, iOS-Simulator, Signing und echte
  iOS-Testbuilds verwendet.
- **D044:** EFI, OpenCore, OCLP, Bootloader, Firmware und macOS-Systemkonfiguration
  werden im YDI-Workflow nicht verändert, außer der Nutzer fordert dies
  ausdrücklich an.
- **D045:** Vor der Anbindung echter Provider wird auf dem MacBook zuerst ein
  reiner iOS-Demo-Build mit synthetischen Daten erstellt. Windows-, Web- und
  lokale Scanfunktionen bleiben dabei unverändert.
- **D046:** Der iOS-Bootstrap ist auf dem Branch `ios-bootstrap` mit Commit
  `a1c3967` abgeschlossen. YDI wurde mit `YDI_PUBLIC_DEMO=true` und synthetischen
  Daten erfolgreich im iPhone-16-Plus-Simulator gestartet. Echtes iPhone-Signing
  und native Provider-Anbindungen für iOS bleiben separate spätere Schritte.

## Web-Demo

- **D041:** GitHub Pages wird ausschließlich mit `YDI_PUBLIC_DEMO=true`
  gebaut. Der Build verwendet synthetische Daten und erlaubt keine echten
  Anmeldungen, Dateiimporte oder Postfachscans.
- **D042:** Die erste vorzeigbare Browserfassung heißt
  **YDI Web Prototype 0.2**. Prototype 0.1 bleibt der lokale Funktionsnachweis.
- **Begründung:** Die öffentliche Präsentation darf weder private Browserdaten
  anzeigen noch Zugangsdaten entgegennehmen. Die lokale Windows-Testapp bleibt
  für echte GMX-Scans getrennt erhalten.

## Produkt

- **D001:** Markenname YDI; Langform „Your Digital Identity“.
- **D002:** Fokus auf digitale Ordnung: zuerst verstehen, danach aufräumen.
- **D003:** Free unterstützt ein E-Mail-Konto; Plus soll mehrere Konten und kontoübergreifende Funktionen anbieten.
- **D004:** Keine Werbung und kein Verkauf von Nutzer- oder E-Mail-Daten.
- **D005:** Keine automatische Newsletter-Abmeldung oder Kontolöschung. YDI informiert; der Nutzer entscheidet.
- **D006:** Ein vollständiger kostenloser Erstscan darf nicht künstlich unbrauchbar gemacht oder hinter einer überraschenden Paywall versteckt werden.
- **D007:** Ein späterer Cleanup-Pass ohne automatische Verlängerung bleibt als faire Monetarisierungsoption im Backlog.

## Datenschutz und Sicherheit

- **D008:** Analyse möglichst lokal auf dem Gerät.
- **D009:** Keine Mailtexte oder Anhänge speichern, wenn Header und Metadaten ausreichen.
- **D010:** Offizielle APIs und Provider-Regeln verwenden; keine Schutzmechanismen umgehen.
- **D011:** Unbekannte Domains nicht automatisch hochladen und nicht künstlich bekannten Marken zuordnen.
- **D012:** Webspeicher ist nur für den lokalen Prototyp; die Produktions-App benötigt sichere, verschlüsselte Speicherung.
- **D013:** Eine Datenschutzerklärung allein reicht nicht als Einwilligung. Optionale Datenübertragungen müssen sichtbar, verständlich und freiwillig sein.
- **D014:** Private Kontakte, persönliche Absender, Spam und sensible Plattformen werden nicht in eine gemeinsame Dienst- oder Logo-Datenbank übernommen.
- **D015:** Verbindung trennen widerruft den Providerzugriff. „Konto und lokale Daten entfernen“ löscht zusätzlich die lokalen nutzerbezogenen Ergebnisse dieses Kontos.
- **D016:** Der globale Dienstkatalog enthält nur geprüfte, nicht nutzerbezogene Informationen wie Anbietername, Domain-Alias, Kategorie und freigegebenes Logo.

## Connectoren und Scans

- **D017:** Gmail wird über Google OAuth und die offizielle Gmail API angebunden, nicht über App-Passwörter im normalen Nutzerfluss.
- **D018:** GMX/WEB.DE werden als geführter IMAP-Connector unterstützt, solange keine passende offizielle OAuth-Lösung verfügbar ist.
- **D019:** Gmail ist der einfachste Standard-Einstieg; technische IMAP-Einstellungen dürfen nicht das erste Erlebnis für normale Nutzer sein.
- **D020:** Mehrere verbundene Konten bleiben gleichzeitig in YDI hinterlegt. Beim Scan darf der Nutzer auswählen, welches Konto aktualisiert wird.
- **D021:** Pro Gmail-Konto werden während der aktuellen Testphase maximal 1.000 Metadaten verarbeitet. Später wird schrittweise auf bis zu etwa 7.000–10.000 erhöht, nachdem Performance, API-Limits und Zuverlässigkeit geprüft wurden.
- **D022:** Kleine Postfächer enden bei der tatsächlich vorhandenen Nachrichtenanzahl und werden nicht künstlich bis zum Scanlimit hochgezählt.
- **D023:** Langfristig werden inkrementelle Scans bevorzugt: nur neue oder geänderte Nachrichten seit dem letzten erfolgreichen Scan.
- **D024:** Der CSV-Import ist ein temporäres Entwicklungswerkzeug und wird entfernt, sobald direkte Provider-Connectoren stabil sind.

## Technik und UX

- **D025:** Flutter ist die gemeinsame Codebasis für Android und iOS; Web und Windows dienen zusätzlich als Entwicklungs- und Testplattformen.
- **D026:** Bekannte Dienste erhalten geprüfte Original-Logos; unbekannte Dienste bleiben ohne erfundenes Logo.
- **D027:** Unterstützte Startsprachen: Deutsch, Englisch, Französisch und Spanisch. Chinesisch folgt frühestens später.
- **D028:** Ein Refresh ersetzt die Daten des neu gescannten Kontos und behält andere Konten bei.
- **D029:** Dienste erhalten wenige verständliche Hauptkategorien und optional genauere Unterkategorien.
- **D030:** Nutzer dürfen eine automatisch erkannte Kategorie lokal korrigieren. Die Korrektur wird nicht ungefragt übertragen.
- **D031:** Im allgemeinen Dashboard werden Provider kompakt dargestellt; in Kontoauswahl, Kontoverwaltung und Dienst-Details werden vollständige E-Mail-Adressen angezeigt, wenn sie zur Unterscheidung notwendig sind.
- **D032:** Bei doppelten Registrierungen zeigt die Detailseite alle betroffenen E-Mail-Konten sowie die jeweilige Mailanzahl.
- **D033:** Dienstelisten bieten Filter nach Konto und Kategorie sowie alphabetische Sortierung und Sortierung nach Kategorie.
- **D034:** Sicherheitshinweise werden erst prominent gezeigt, wenn die Erkennung fachlich ausreichend zuverlässig und für Nutzer verständlich erklärt ist.
- **D035:** Native Windows-Unterstützung wird über Visual Studio „Desktopentwicklung mit C++“ eingerichtet; die veraltete Visual-Studio-Workload „Mobileentwicklung mit C++“ wird nicht verwendet.
- **D036:** GMX-Anwendungspasswörter werden nicht dauerhaft gespeichert. Nach Test oder Scan wird das Eingabefeld geleert.
- **D037:** Einzelnes Entfernen eines Kontos löscht nur dessen lokale Scanergebnisse; die globale Löschfunktion wird ausdrücklich als Löschung aller lokalen Scandaten bezeichnet.
- **D038:** Echte Newsletter-Abmelde-URLs dürfen lokal gespeichert werden, verlassen das Gerät nicht und werden ausschließlich auf ausdrückliche Nutzeraktion geöffnet.
- **D039:** Ein bloßer Hinweis auf einen vorhandenen Abmeldelink reicht nicht zum Öffnen. Ohne lokal gespeicherte, gültige HTTP(S)-URL bleibt der Button deaktiviert.
- **D040:** RFC-8058-One-Click-Endpunkte erwarten einen POST-Aufruf. YDI öffnet sie
  nicht als normale GET-Webseite und sendet ohne eine spätere, ausdrücklich
  beschlossene Bestätigungsfunktion keine Abmeldeanfrage.

## Beispielkategorien und Alias-Zuordnungen

- Zasta → Finanzen & Steuern / Steuererklärung
- Volkswagen, Audi, mobile.de, Carly → Mobilität / Fahrzeuge
- SBB → Mobilität / Öffentlicher Verkehr
- CSS, AXA → Versicherungen
- Galaxus, Digitec, Dyson → Shopping
- Active Fitness → Gesundheit / Fitness
- GMX, Proton → E-Mail
- Sparkassen-Absender wie `s-abmil.de` → Finanzen / Bank, nach Prüfung
- Just Eat → Essen bestellen
- Main-Echo, PC-WELT → Nachrichten / Medien
- Meta, Facebook, Instagram, Snapchat → Social Media
- ADticket, myticket → Tickets & Events
