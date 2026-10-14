# Caddy – Golf-Caddy für iPhone (Projekt StUrbanus)

SwiftUI-App für iPhone (iOS 26). Jeder Schlag wird mit seinem Fehlermuster erfasst, damit sichtbar wird, wo Schläge verloren gehen. Alle Daten bleiben lokal (SwiftData).

## Aufbau

- `project.yml`: XcodeGen-Spezifikation (Quelle der Wahrheit). `StUrbanus.xcodeproj` wird daraus erzeugt.
- `StUrbanus/Models`: SwiftData-Modelle (Course, Hole, Round, HoleScore, Shot), Enums, Rundenlogik (`RoundService`), Plätze (`CourseService`), Seed-Daten (V-Golf St. Urbanus Köln, 18 Löcher, Par laut Scorecard, gesamt 72).
- `StUrbanus/Views`: Runden, Schlag-Erfassung (Schlag → Ergebnis → Folge), Statistik (Filter nach Platz), Plätze.
- `StUrbanus/Speech`: Protokoll `SpeechRecognizer`, `AppleSpeechRecognizer` (Speech-Framework, de-DE, auf dem Gerät), `ShotPhraseParser` (deutsche Ansage → Felder).
- `StUrbanusTests`: Tests für Parser und Rundenlogik.

Sprach-Erfassung: Ansage mit „fertig“ oder „speichern“ beenden (oder 2 s schweigen), dann wird gespeichert, sofern Schlagart und Ergebnis erkannt sind. „abbrechen“ verwirft. Fehlt etwas, bleibt die Ansicht offen und markiert das Feld.

## Plätze

Im Tab „Plätze“ lassen sich beliebige Plätze anlegen, umbenennen und löschen: Name, 9 oder 18 Löcher, Par je Loch. St. Urbanus ist vorinstalliert. Beim Rundenstart wählt man den Platz (zuletzt gespielter oben). Gespielte Runden behalten ihre Pars; ein Platz mit Runden lässt sich erst löschen, wenn seine Runden gelöscht sind.

## Freihändig mit Siri (iPhone kann im Bag bleiben)

Runde in der App starten, danach per „Hey Siri“ (auch über AirPods, auch bei gesperrtem iPhone):

- „Caddy Schlag“ → Siri fragt „Welcher Schlag?“ → „Drive rechts ins Aus“ (oder „Putt drin, nächstes Loch“)
- „Caddy nächstes Loch“ / „Caddy vorheriges Loch“
- „Caddy letzten Schlag löschen“
- „Caddy Spielstand“
- „Caddy Runde beenden“

Statt „Caddy“ versteht Siri auch „Urbanus“, „Golf Caddy“ und „Mein Caddy“.

Siri antwortet gesprochen, z. B. „Drive, Rechts, Aus. Schlag 1 auf Loch 1.“ Das aktuelle Loch wird in der Runde gespeichert, App und Siri bleiben synchron.

## Schläger, Folge und GIR

- Schlagart: Drive, Holz/Hybrid, Eisen 5–9 einzeln, Wedge, Pitch, Chip, Bunker, Putt (per Sprache z. B. „Eisen 7“, „7er Eisen“, „Siebener“).
- Eingelocht: eigener Knopf im Schritt „Folge:“ (per Sprache „eingelocht“, „versenkt“, „drin“). Das Loch ist damit beendet und zeigt sein Ergebnis; zum nächsten Loch geht es per Knopf oder „nächstes Loch“.
- Folge (wo der Ball liegt): Fairway, First Cut, Grün, Rough, Bunker, Wasser, Aus, Strafschlag. „Drive Fairway“ oder „Eisen 9 aufs Grün“ zählen ohne Richtungsangabe als gut.
- Green in Regulation: Der GIR-Schlag ist Schlag Par−2 (Par 3: 1., Par 4: 2., Par 5: 3.). Dort fragt die App ausdrücklich „Grün getroffen?“. GIR ergibt sich sonst aus den Schlägen (Folge „Grün“ spätestens beim GIR-Schlag oder direkt danach geputtet) und lässt sich per „GIR ja/nein“, „Grün getroffen/verfehlt“ oder über das GIR-Feld am Loch korrigieren. Die Statistik zeigt die GIR-Quote gesamt und je Par 3/4/5.

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
