import Foundation

/// Ergebnis der Auswertung einer gesprochenen Ansage. Fehlende Felder bleiben `nil`
/// und werden im Bestätigungsschritt per Tipp ergänzt.
struct ParsedShot: Equatable, Sendable {
    var shotType: ShotType?
    var result: ShotResult?
    var consequence: ShotConsequence?

    var isComplete: Bool { shotType != nil && result != nil }
}

/// Bildet deutsche Ansagen wie „Siebener Eisen rechts ins Wasser“ auf Schlagart,
/// Ergebnis und Folge ab. Rein schlüsselwortbasiert, ohne Netz.
enum ShotPhraseParser {
    static func parse(_ phrase: String) -> ParsedShot {
        var scanner = PhraseScanner(normalize(phrase))
        var parsed = ParsedShot()

        // Füllphrasen, die sonst als „Aus“ gelesen würden („sieht gut aus“).
        scanner.blank(#"\baus\s*$"#, onlyIf: { $0.contains("sieht") })
        scanner.blank(#"\bsieht\b"#)

        // „in den Bunker“ ist eine Folge, kein Bunkerschlag.
        let bunkerConsequence = scanner.firstMatch(of: [#"\b(in den|im|ins|in) bunker\b"#])

        parsed.shotType = scanner.take(shotTypeRules)
        if parsed.shotType == nil, scanner.firstMatch(of: [#"\bbunker\b"#]) != nil {
            parsed.shotType = .bunker
        }

        // Lage-Angaben („aus dem Rough“) sind keine „Aus“-Folge.
        scanner.blank(#"\baus (dem|der|den)( \w+)?\b"#)

        parsed.result = scanner.take(resultRules)

        let consequence = scanner.takeWithLocation(consequenceRules)
        switch (bunkerConsequence, consequence) {
        case let (bunker?, other?):
            parsed.consequence = bunker < other.location ? .bunker : other.value
        case (_?, nil):
            parsed.consequence = .bunker
        case let (nil, other?):
            parsed.consequence = other.value
        case (nil, nil):
            parsed.consequence = nil
        }
        return parsed
    }

    // MARK: - Vokabular (normalisiert: klein, ohne Umlaute/Akzente, ß → ss)

    private static let longIronNumbers = "(?:[345]|drei|vier|funf)"
    private static let shortIronNumbers = "(?:[6789]|sechs|sieben|acht|neun)"

    static let shotTypeRules: [(ShotType, [String])] = [
        (.bunker, [#"\baus dem bunker\b"#, #"\bbunker ?(schlag|schuss)\b"#, #"\bsand ?schlag\b"#, #"\bexplosions ?schlag\b"#]),
        (.putt, [#"\bputt(s|en)?\b"#, #"\bgeputtet\b"#, #"\bputter\b"#]),
        (.chip, [#"\bchip(s|pen)?\b"#, #"\bgechippt\b"#]),
        (.shortIronWedge, [
            #"\bkurze[snm]? eisen\b"#,
            #"\b\#(shortIronNumbers)(er)? ?eisen\b"#,
            #"\beisen ?\#(shortIronNumbers)\b"#,
            #"\b(pitching|sand|gap|lob)? ?wedge\b"#,
            #"\bpw\b"#, #"\bsw\b"#,
        ]),
        (.pitch, [#"\bpitch(es|en)?\b"#, #"\bgepitcht\b"#]),
        (.longIron, [
            #"\blange[snm]? eisen\b"#,
            #"\b\#(longIronNumbers)(er)? ?eisen\b"#,
            #"\beisen ?\#(longIronNumbers)\b"#,
        ]),
        (.woodHybrid, [#"\b\w*holz\b"#, #"\bhybrid\b"#, #"\brescue\b"#, #"\bwood\b"#]),
        (.drive, [#"\bdrive\b"#, #"\bdriver\b"#, #"\babschlag\b"#]),
    ]

    static let resultRules: [(ShotResult, [String])] = [
        (.short, [#"\bzu kurz\b"#, #"\bkurz\b"#]),
        (.long, [#"\bzu lang\b"#, #"\bzu weit\b"#, #"\blang\b"#, #"\bdruber\b"#]),
        (.left, [#"\b(nach )?links\b"#, #"\bhook\b"#, #"\bpull\b"#]),
        (.right, [#"\b(nach )?rechts\b"#, #"\bslice\b"#, #"\bpush\b"#]),
        (.good, [#"\bgut\b"#, #"\bgerade\b"#, #"\bperfekt\b"#, #"\bsuper\b"#, #"\bsauber\b"#, #"\bok(ay)?\b"#,
                 #"\bfairway\b"#, #"\b(aufs |auf dem )?grun\b"#, #"\beingelocht\b"#, #"\bdrin\b"#]),
    ]

    static let consequenceRules: [(ShotConsequence, [String])] = [
        (.penalty, [#"\bstraf ?schlag\b"#, #"\bstrafe\b"#, #"\bpenalty\b"#]),
        (.outOfBounds, [#"\b(ins|im) aus\b"#, #"\bout( of bounds)?\b"#, #"\bausgrenze\b"#, #"\baus\s*$"#, #"\baus\b"#]),
        (.water, [#"\bwasser\w*\b"#, #"\bteich\b"#, #"\bsee\b"#, #"\bbach\b"#]),
        (.rough, [#"\brough\b"#, #"\bsemi\b"#]),
        (.bunker, [#"\bbunker\b"#]),
    ]

    // MARK: - Normalisierung

    static func normalize(_ text: String) -> String {
        let folded = text
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
        let cleaned = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    // MARK: - Scanner

    /// Sucht Muster im Text und „verbraucht“ Treffer, damit z. B. „kurzes Eisen“
    /// später nicht noch einmal als Ergebnis „zu kurz“ gelesen wird.
    private struct PhraseScanner {
        private(set) var text: String

        init(_ text: String) { self.text = text }

        private static func regex(_ pattern: String) -> NSRegularExpression {
            // Muster sind statisch und getestet.
            try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }

        private func matches(_ pattern: String) -> [NSRange] {
            let ns = text as NSString
            return Self.regex(pattern)
                .matches(in: text, range: NSRange(location: 0, length: ns.length))
                .map(\.range)
        }

        private mutating func blank(ranges: [NSRange]) {
            let ns = NSMutableString(string: text)
            for range in ranges.sorted(by: { $0.location > $1.location }) {
                ns.replaceCharacters(in: range, with: String(repeating: " ", count: range.length))
            }
            text = ns as String
        }

        mutating func blank(_ pattern: String, onlyIf condition: (String) -> Bool = { _ in true }) {
            guard condition(text) else { return }
            blank(ranges: matches(pattern))
        }

        /// Position des frühesten Treffers über alle Muster; Treffer werden verbraucht.
        mutating func firstMatch(of patterns: [String]) -> Int? {
            let found = patterns.flatMap { matches($0) }
            guard !found.isEmpty else { return nil }
            blank(ranges: found)
            return found.map(\.location).min()
        }

        /// Wählt den Wert, dessen Schlüsselwort zuerst im Satz vorkommt; verbraucht alle Treffer des Felds.
        mutating func takeWithLocation<Value>(_ rules: [(Value, [String])]) -> (value: Value, location: Int)? {
            var best: (value: Value, location: Int)?
            var consumed: [NSRange] = []
            for (value, patterns) in rules {
                for pattern in patterns {
                    // Treffer an bereits verbrauchten Stellen ignorieren.
                    for range in matches(pattern) where !consumed.contains(where: { NSIntersectionRange($0, range).length > 0 }) {
                        consumed.append(range)
                        if best == nil || range.location < best!.location {
                            best = (value, range.location)
                        }
                    }
                }
            }
            blank(ranges: consumed)
            return best
        }

        mutating func take<Value>(_ rules: [(Value, [String])]) -> Value? {
            takeWithLocation(rules)?.value
        }
    }
}
