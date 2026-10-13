import SwiftData
import Testing
@testable import StUrbanus

@MainActor
struct RoundServiceTests {
    let context: ModelContext
    let round: Round

    init() throws {
        let container = try ModelContainer(
            for: Course.self, Hole.self, Round.self, HoleScore.self, Shot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        let course = Course(name: SeedData.stUrbanusName)
        context.insert(course)
        for (offset, par) in SeedData.stUrbanusPars.enumerated() {
            course.holes.append(Hole(number: offset + 1, par: par))
        }
        round = RoundService.startRound(on: course, in: context)
    }

    @Test func logsShotOnCurrentHole() {
        let reply = RoundService.handleVoice("Drive rechts ins Aus", in: context)
        #expect(reply == "Drive, Rechts, Aus. Schlag 1 auf Loch 1.")
        #expect(round.currentScore?.shots.count == 1)
        #expect(round.currentScore?.strokes == 2) // Aus = Strafschlag
    }

    @Test func shotThenNextHole() {
        let reply = RoundService.handleVoice("Putt drin, nächstes Loch", in: context)
        #expect(round.currentHole == 2)
        #expect(round.holeScores.first { $0.holeNumber == 1 }?.shots.first?.shotType == .putt)
        #expect(reply.hasSuffix("Loch 2, Par 4. Bisher 1 Schläge, 4 unter Par."))
    }

    @Test func goToHoleThenShotLandsOnNewHole() {
        _ = RoundService.handleVoice("Loch 7, Drive links", in: context)
        #expect(round.currentHole == 7)
        #expect(round.holeScores.first { $0.holeNumber == 7 }?.shots.count == 1)
        #expect(round.holeScores.first { $0.holeNumber == 1 }?.shots.isEmpty == true)
    }

    @Test func incompleteShotIsNotSaved() {
        let reply = RoundService.handleVoice("rechts ins Wasser", in: context)
        #expect(reply == "Nicht gespeichert, die Schlagart fehlt.")
        #expect(round.currentScore?.shots.isEmpty == true)
    }

    @Test func undoRemovesLastShot() {
        _ = RoundService.handleVoice("Drive gut", in: context)
        _ = RoundService.handleVoice("Chip zu kurz", in: context)
        let reply = RoundService.handleVoice("letzten Schlag löschen", in: context)
        #expect(reply == "Letzter Schlag gelöscht: Chip. Loch 1 steht bei 1.")
        #expect(round.currentScore?.sortedShots.map(\.shotType) == [.drive])
    }

    @Test func nextHoleStopsAtLastHole() {
        round.currentHole = 18
        let reply = RoundService.apply(.nextHole, to: round, in: context)
        #expect(round.currentHole == 18)
        #expect(reply.hasPrefix("Das war das letzte Loch."))
    }

    @Test func endRoundFinishesAndDeactivates() {
        _ = RoundService.handleVoice("Drive gut", in: context)
        let reply = RoundService.handleVoice("Runde beenden", in: context)
        #expect(round.isFinished)
        #expect(reply == "Runde beendet. Nach einem Loch 1 Schläge, 4 unter Par.")
        #expect(RoundService.activeRound(in: context) == nil)
        #expect(RoundService.handleVoice("Drive gut", in: context) == RoundService.noActiveRound)
    }

    @Test func gibberishIsExplained() {
        let reply = RoundService.handleVoice("Schönes Wetter heute", in: context)
        #expect(reply.hasPrefix("Das habe ich nicht verstanden."))
    }
}
