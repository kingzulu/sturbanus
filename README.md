# St. Urbanus – Golf-Caddy (iOS)

SwiftUI-App für iPhone (iOS 26). Jeder Schlag wird mit seinem Fehlermuster erfasst, damit sichtbar wird, wo Schläge verloren gehen. Alle Daten bleiben lokal (SwiftData).

## Aufbau

- `project.yml`: XcodeGen-Spezifikation (Quelle der Wahrheit). `StUrbanus.xcodeproj` wird daraus erzeugt.
- `StUrbanus/Models`: SwiftData-Modelle (Course, Hole, Round, HoleScore, Shot), Enums, Seed-Daten (V-Golf St. Urbanus Köln, 18 Löcher, Par laut Scorecard, gesamt 72; in der Runde und im Tab „Platz“ änderbar).
- `StUrbanus/Views`: Runden, Schlag-Erfassung (Schlagart → Ergebnis → Folge), Statistik, Platz (Par editierbar).
- `StUrbanus/Speech`: Protokoll `SpeechRecognizer`, `AppleSpeechRecognizer` (Speech-Framework, de-DE, auf dem Gerät), `ShotPhraseParser` (deutsche Ansage → Felder).
- `StUrbanusTests`: Tests für den Parser.

Score eines Lochs = erfasste Schläge + Strafschläge (Aus, Wasser und Strafschlag zählen je +1).

## Projekt neu erzeugen

```bash
brew install xcodegen
xcodegen generate
```

## Bauen und testen

```bash
xcodebuild -scheme StUrbanus -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Auf dem eigenen iPhone (kostenlose Apple-ID)

1. `StUrbanus.xcodeproj` in Xcode öffnen.
2. Xcode > Settings > Accounts: Apple-ID hinzufügen.
3. Target StUrbanus > Signing & Capabilities: Team = „(Dein Name) (Personal Team)“. Falls die Bundle-ID schon vergeben ist, das Suffix ändern.
4. iPhone per Kabel verbinden, entsperren, „Diesem Computer vertrauen“ bestätigen. Auf dem iPhone unter Einstellungen > Datenschutz & Sicherheit den Entwicklermodus aktivieren (das iPhone startet dabei neu).
5. Oben in Xcode das iPhone als Ziel wählen und ▶︎ drücken.
6. Beim ersten Start auf dem iPhone: Einstellungen > Allgemein > VPN & Geräteverwaltung > Entwickler-App vertrauen.

Mit einer kostenlosen Apple-ID läuft die Signatur nach 7 Tagen ab. Danach die App einfach erneut aus Xcode starten; die Daten bleiben erhalten.
