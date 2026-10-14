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

    // MARK: GIR (Loch 1 Par 5, Loch 2 Par 4, Loch 3 Par 3)

    @Test func girHitOnPar4SecondShot() {
        round.currentHole = 2
        let first = RoundService.handleVoice("Drive Fairway", in: context)
        #expect(!first.contains("Regulation"))
        let second = RoundService.handleVoice("Eisen 8 aufs Grün", in: context)
        #expect(second.hasSuffix("Grün in Regulation."))
        #expect(round.currentScore?.gir == true)
    }

    @Test func girMissedOnPar3() {
        round.currentHole = 3
        let reply = RoundService.handleVoice("Eisen 7 rechts ins Rough", in: context)
        #expect(reply.hasSuffix("Grün in Regulation verfehlt."))
        #expect(round.currentScore?.gir == false)
    }

    @Test func openGIRShotIsResolvedByPutt() {
        _ = RoundService.handleVoice("Drive gut", in: context)
        _ = RoundService.handleVoice("Hybrid gut", in: context)
        let gir = RoundService.handleVoice("Wedge gut", in: context)
        #expect(gir.hasSuffix("Sag GIR ja oder GIR nein."))
        #expect(round.currentScore?.gir == nil)
        _ = RoundService.handleVoice("Putt drin", in: context)
        #expect(round.currentScore?.gir == true)
    }

    @Test func chipAfterGIRShotMeansMissed() {
        round.currentHole = 2
        _ = RoundService.handleVoice("Drive gut", in: context)
        _ = RoundService.handleVoice("Eisen 7 zu kurz", in: context)
        _ = RoundService.handleVoice("Chip gut", in: context)
        #expect(round.currentScore?.gir == false)
    }

    @Test func standaloneGIRAnswerOverrides() {
        round.currentHole = 3
        _ = RoundService.handleVoice("Eisen 7 gut", in: context)
        let reply = RoundService.handleVoice("GIR nein", in: context)
        #expect(reply == "Loch 3: Grün in Regulation verfehlt.")
        #expect(round.currentScore?.shots.count == 1)
        #expect(round.currentScore?.gir == false)
    }

    @Test func undoResetsDerivedGIR() {
        round.currentHole = 3
        _ = RoundService.handleVoice("Eisen 9 aufs Grün", in: context)
        #expect(round.currentScore?.gir == true)
        _ = RoundService.handleVoice("letzten Schlag löschen", in: context)
        #expect(round.currentScore?.gir == nil)
    }

    @Test func standaloneGIRYes() {
        round.currentHole = 2
        _ = RoundService.handleVoice("Drive gut", in: context)
        _ = RoundService.handleVoice("Eisen 8 gut", in: context)
        let reply = RoundService.handleVoice("GIR ja", in: context)
        #expect(reply == "Loch 2: Grün in Regulation.")
        #expect(round.currentScore?.shots.count == 2)
        #expect(round.currentScore?.gir == true)
    }

    // MARK: Eingelocht

    @Test func holingOutFinishesHoleAndAnnouncesScore() {
        round.currentHole = 3 // Par 3
        _ = RoundService.handleVoice("Eisen 7 aufs Grün", in: context)
        let reply = RoundService.handleVoice("Putt drin", in: context)
        #expect(reply == "Putt, Gut, Eingelocht. Schlag 2 auf Loch 3. Loch 3 beendet mit 2, Birdie.")
        #expect(round.currentScore?.isHoled == true)
        #expect(round.currentHole == 3) // kein automatischer Lochwechsel
    }

    @Test func chipInAfterMissedGreenIsNoGIR() {
        round.currentHole = 2 // Par 4
        _ = RoundService.handleVoice("Drive Fairway", in: context)
        _ = RoundService.handleVoice("Eisen 8 rechts ins Rough", in: context)
        let reply = RoundService.handleVoice("Chip eingelocht", in: context)
        #expect(reply.hasSuffix("Loch 2 beendet mit 3, Birdie."))
        #expect(round.currentScore?.gir == false)
        #expect(round.currentScore?.strokes == 3)
    }

    @Test func holeOutOnGIRShotCountsAsGIR() {
        round.currentHole = 2 // Par 4
        _ = RoundService.handleVoice("Drive gut", in: context)
        _ = RoundService.handleVoice("Wedge eingelocht", in: context)
        #expect(round.currentScore?.gir == true)
        #expect(round.currentScore?.isHoled == true)
    }
}
