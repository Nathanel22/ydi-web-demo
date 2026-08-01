# YDI Web Prototype 0.2 veröffentlichen

Diese Anleitung veröffentlicht ausschließlich die sichere Web-Demo. Der Build
verwendet synthetische Beispieldaten. Echte GMX-/Gmail-Verbindungen, Dateiimport,
Passwörter, Tokens und private Scanergebnisse sind im Demo-Modus deaktiviert.

## 1. Voraussetzungen

- Git und Flutter sind lokal installiert.
- Ein kostenloses GitHub-Konto ist vorhanden.
- Das Projekt wurde lokal mit `flutter build web` geprüft.
- Niemals den Ordner `build/` oder lokale Zwischenspeicher manuell hochladen.

## 2. GitHub-Repository erstellen

1. Auf GitHub rechts oben **New repository** wählen.
2. Als Namen zum Beispiel `ydi-web-demo` eintragen.
3. Sichtbarkeit **Public** auswählen, damit GitHub Pages kostenlos erreichbar ist.
4. README, `.gitignore` und Lizenz auf GitHub nicht zusätzlich erzeugen, weil das
   Flutter-Projekt diese Dateien bereits enthält.
5. **Create repository** wählen.

## 3. Projekt erstmals hochladen

Im Terminal im Ordner `ydi_app` ausführen. `DEIN-NAME` und den Repository-Namen
in der URL ersetzen:

```powershell
git init
git branch -M main
git add .
git commit -m "Prepare YDI Web Prototype 0.2"
git remote add origin https://github.com/DEIN-NAME/ydi-web-demo.git
git push -u origin main
```

Vor `git add .` sicherheitshalber prüfen:

```powershell
git status
```

Die Ordner `.dart_tool`, `build`, `.pub-cache` und lokale Entwicklungsdateien
dürfen nicht als neue Git-Dateien erscheinen.

## 4. GitHub Pages aktivieren

1. Im GitHub-Repository **Settings → Pages** öffnen.
2. Unter **Build and deployment** bei **Source** den Eintrag
   **GitHub Actions** auswählen.
3. Unter **Actions** den Workflow
   **Deploy YDI web demo to GitHub Pages** öffnen.
4. Warten, bis alle Schritte grün abgeschlossen sind.

Der Workflow ermittelt den Repository-Namen automatisch und setzt den für
GitHub Pages erforderlichen `base href`. Er baut immer mit:

```powershell
flutter build web --release --base-href "/REPOSITORY-NAME/" --dart-define=YDI_PUBLIC_DEMO=true
```

## 5. Fertigen Link testen

Der Link hat normalerweise dieses Format:

```text
https://DEIN-NAME.github.io/ydi-web-demo/
```

Folgende Punkte auf Windows und iPhone prüfen:

1. Dashboard erscheint mit Demo-Daten.
2. Dienste, Newsletter, Kategorien und Detailseiten lassen sich öffnen.
3. Sprache lässt sich wechseln.
4. Unter Einstellungen steht **Web Prototype 0.2**.
5. Die GMX-Verbindung lässt sich nur als Demo-Ablauf ansehen.
6. Es gibt keine Möglichkeit, echte Zugangsdaten zu senden oder Dateien zu importieren.
7. Ein Neuladen der Seite funktioniert weiterhin.

Auf dem iPhone mindestens Safari testen. Chrome und Edge verwenden unter iOS
dieselbe Apple-Web-Engine, sollten aber zusätzlich kurz geprüft werden.

## 6. Zukünftige Updates veröffentlichen

Nach einer Änderung zuerst lokal prüfen:

```powershell
flutter analyze
flutter test
flutter build web --dart-define=YDI_PUBLIC_DEMO=true
```

Danach veröffentlichen:

```powershell
git add .
git commit -m "Describe the demo update"
git push
```

GitHub Actions baut und veröffentlicht die neue Demo automatisch. Der Link
bleibt gleich. Falls die Seite noch die alte Version zeigt, Browser-Cache leeren
oder die Seite in einem privaten Tab öffnen.

## 7. Datenschutz-Check vor jedem Upload

- Keine realen E-Mail-Adressen im Quellcode.
- Keine Passwörter, Anwendungspasswörter, OAuth-Tokens oder Client-Secrets.
- Keine CSV-Scans, Screenshots oder exportierten Postfachdaten.
- Keine echten Abmeldelinks; sie können persönliche Einmal-Tokens enthalten.
- Nur `YDI_PUBLIC_DEMO=true` für die veröffentlichte Webseite verwenden.

Die normale lokale Windows-Testapp bleibt getrennt. Sie darf echte GMX-Daten
lokal analysieren, wird aber nicht als GitHub-Pages-Webseite veröffentlicht.

## 8. Bekannte lokale Build-Hinweise

Während der Vorbereitung am 1. August 2026 erreichten mehrere Builds wegen
starker HDD-Auslastung zunächst nur das Zeitlimit. Zusätzlich konnte die
isolierte Codex-Prüfumgebung keine Flutter-Statusdateien unter
`D:\development\flutter\bin\cache` schreiben. Das ist kein Fehler im YDI-Code.

Die Dart-Analyse des Projekts wurde erfolgreich und ohne Codefehler beendet.
Der abschließende Flutter-Web-Build wird deshalb einmal im normalen lokalen
VS-Code-Terminal ausgeführt, das auf das Flutter-SDK schreiben darf:

```powershell
cd "C:\Users\RothJ\Documents\Codex\2026-07-11\referenced-chatgpt-conversation-this-is-untrusted\ydi_app"
flutter build web --release --dart-define=YDI_PUBLIC_DEMO=true
```

Erwartetes Ergebnis:

```text
Built build\web
```

Der Build wurde am 1. August 2026 erfolgreich erstellt. Die anschließend
erzeugten 39 Web-Dateien wurden nochmals auf reale E-Mail-Adressen, Client-IDs,
Tokens, Secrets und private Schlüssel geprüft; es wurden keine gefunden.
