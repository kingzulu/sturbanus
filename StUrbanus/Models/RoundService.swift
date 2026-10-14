import Foundation
import SwiftData

/// Rundenlogik, die App und Siri gemeinsam nutzen. Jede Aktion liefert einen kurzen Satz,
/// den Siri vorliest (oder die App anzeigt).
@MainActor
enum RoundService {
    static let noActiveRound = "Keine laufende Runde. Starte zuerst eine Runde in der App."

    /// Die zuletzt begonnene, nicht beendete Runde.
    static func activeRound(in context: ModelContext) -> Round? {
        var descriptor = FetchDescriptor<Round>(
            predicate: #Predicate { !$0.isFinished },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Startet eine neue Runde; noch offene Runden gelten damit als beendet.
    static func startRound(on course: Course, in context: ModelContext) -> Round {
        let open = (try? context.fetch(FetchDescriptor<Round>(predicate: #Predicate { !$0.isFinished }))) ?? []
        for round in open { round.isFinished = true }

        let round = Round(course: course)
        context.insert(round)
        for hole in course.sortedHoles {
            round.holeScores.append(HoleScore(holeNumber: hole.number, par: hole.par))
        }
        try? context.save()
        return round
    }

    /// Löscht eine Runde samt Löchern und Schlägen; sie taucht danach auch in der Statistik nicht mehr auf.
    /// War es die laufende Runde, hat Siri danach keine aktive Runde mehr.
    static func deleteRound(_ round: Round, in context: ModelContext) {
        for score in round.holeScores {
            for shot in score.shots { context.delete(shot) }
            context.delete(score)
        }
        context.delete(round)
        try? context.save()
    }

    /// Wertet eine gesprochene Ansage aus („Drive rechts ins Aus“, „Putt drin, nächstes Loch“, „Loch 7“).
    static func handleVoice(_ phrase: String, in context: ModelContext) -> String {
        guard let round = activeRound(in: context) else { return noActiveRound }
        let utterance = ShotPhraseParser.parseRoundUtterance(phrase)
        if utterance.command == .cancel { return "Verworfen." }

        var replies: [String] = []
        // „Loch 7, Drive rechts“: erst wechseln, dann den Schlag dort erfassen.
        if case .goToHole(let hole)? = utterance.roundCommand {
            replies.append(move(round, to: hole, in: context))
        }

        let shot = utterance.shot
        if let type = shot.shotType, let result = shot.result {
            replies.append(logShot(type, result, shot.consequence, gir: shot.gir, in: round, context: context))
        } else if let gir = shot.gir, shot.shotType == nil {
            // Nur „GIR ja“ / „Grün verfehlt“: gilt für das aktuelle Loch.
            replies.append(setGIR(gir, in: round, context: context))
        } else if shot != ParsedShot() {
            replies.append("Nicht gespeichert, \(missingFields(shot)) fehlt.")
        }

        switch utterance.roundCommand {
        case .goToHole?: break
        case let command?: replies.append(apply(command, to: round, in: context))
        case nil:
            if shot == ParsedShot() {
                replies.append("Das habe ich nicht verstanden. Sag zum Beispiel: Drive rechts.")
            }
        }
        return replies.joined(separator: " ")
    }

    static func apply(_ command: RoundCommand, to round: Round, in context: ModelContext) -> String {
        switch command {
        case .nextHole:
            guard round.currentHole < round.holeScores.count else {
                return "Das war das letzte Loch. \(scoreSummary(round)) Sag Runde beenden, um abzuschließen."
            }
            return move(round, to: round.currentHole + 1, in: context)
        case .previousHole:
            guard round.currentHole > 1 else { return "Du bist schon auf Loch 1." }
            return move(round, to: round.currentHole - 1, in: context)
        case .goToHole(let hole):
            return move(round, to: hole, in: context)
        case .undoLastShot:
            return undoLastShot(in: round, context: context)
        case .score:
            return scoreSummary(round)
        case .endRound:
            round.isFinished = true
            try? context.save()
            return "Runde beendet. \(scoreSummary(round))"
        }
    }

    @discardableResult
    static func logShot(_ type: ShotType, _ result: ShotResult, _ consequence: ShotConsequence?,
                        gir: Bool? = nil, in round: Round, context: ModelContext) -> String {
        guard let score = round.currentScore else { return "Loch \(round.currentHole) gibt es in dieser Runde nicht." }
        let girBefore = score.gir
        let stroke = score.nextStrokeNumber
        let index = (score.shots.map(\.index).max() ?? 0) + 1
        score.shots.append(Shot(index: index, type: type, result: result, consequence: consequence))
        if let gir { score.girOverride = gir }
        try? context.save()

        let parts = [type.spokenLabel, result.label, consequence?.label].compactMap { $0 }
        var reply = "\(parts.joined(separator: ", ")). Schlag \(stroke) auf Loch \(score.holeNumber)."
        if consequence == .holed {
            let relative = score.strokes - score.par
            let word = switch relative {
            case 0: "Par"
            case -1: "Birdie"
            case -2: "Eagle"
            case 1: "Bogey"
            case 2: "Doppel-Bogey"
            default: relative > 0 ? "\(relative) über Par" : "\(-relative) unter Par"
            }
            reply += " Loch \(score.holeNumber) beendet mit \(score.strokes), \(word)."
        }
        if girBefore == nil, let girNow = score.gir {
            reply += girNow ? " Grün in Regulation." : " Grün in Regulation verfehlt."
        } else if score.gir == nil, stroke == score.girShotNumber {
            reply += " War das Grün getroffen? Sag GIR ja oder GIR nein."
        }
        return reply
    }

    /// Setzt GIR für das aktuelle Loch ausdrücklich (`nil` = wieder aus den Schlägen ableiten).
    @discardableResult
    static func setGIR(_ gir: Bool?, in round: Round, context: ModelContext) -> String {
        guard let score = round.currentScore else { return "Loch \(round.currentHole) gibt es in dieser Runde nicht." }
        score.girOverride = gir
        try? context.save()
        switch score.gir {
        case true?: return "Loch \(score.holeNumber): Grün in Regulation."
        case false?: return "Loch \(score.holeNumber): Grün in Regulation verfehlt."
        case nil: return "Loch \(score.holeNumber): GIR noch offen."
        }
    }

    static func move(_ round: Round, to hole: Int, in context: ModelContext) -> String {
        guard let score = round.holeScores.first(where: { $0.holeNumber == hole }) else {
            return "Loch \(hole) gibt es nicht."
        }
        round.currentHole = hole
        try? context.save()

        var text = "Loch \(hole), Par \(score.par)."
        if !round.playedScores.isEmpty {
            text += " Bisher \(round.totalStrokes) Schläge, \(toParWords(round.toPar))."
        }
        return text
    }

    static func undoLastShot(in round: Round, context: ModelContext) -> String {
        guard let score = round.currentScore, let last = score.sortedShots.last else {
            return "Auf Loch \(round.currentHole) gibt es keinen Schlag zum Löschen."
        }
        let label = last.shotType.spokenLabel
        score.shots.removeAll { $0 === last }
        context.delete(last)
        try? context.save()
        return "Letzter Schlag gelöscht: \(label). Loch \(score.holeNumber) steht bei \(score.strokes)."
    }

    static func scoreSummary(_ round: Round) -> String {
        let played = round.playedScores.count
        guard played > 0 else { return "Noch keine Schläge erfasst." }
        let holes = played == 1 ? "einem Loch" : "\(played) Löchern"
        return "Nach \(holes) \(round.totalStrokes) Schläge, \(toParWords(round.toPar))."
    }

    static func toParWords(_ value: Int) -> String {
        switch value {
        case 0: "genau Par"
        case 1: "eins über Par"
        case -1: "eins unter Par"
        case let v where v > 0: "\(v) über Par"
        default: "\(-value) unter Par"
        }
    }

    private static func missingFields(_ shot: ParsedShot) -> String {
        switch (shot.shotType, shot.result) {
        case (nil, nil): "Schlagart und Ergebnis"
        case (nil, _): "die Schlagart"
        default: "das Ergebnis"
        }
    }
}

extension ShotType {
    /// Für die Sprachausgabe, ohne Schrägstrich.
    var spokenLabel: String { label.replacingOccurrences(of: "/", with: " oder ") }
}
