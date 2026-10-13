import Testing
@testable import StUrbanus

struct ShotPhraseParserTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let phrase: String
        let type: ShotType?
        let result: ShotResult?
        let consequence: ShotConsequence?
        var testDescription: String { phrase }
    }

    static let cases: [Case] = [
        Case(phrase: "Drive gut", type: .drive, result: .good, consequence: nil),
        Case(phrase: "Driver rechts ins Aus", type: .drive, result: .right, consequence: .outOfBounds),
        Case(phrase: "Drive rechts Aus", type: .drive, result: .right, consequence: .outOfBounds),
        Case(phrase: "Abschlag links ins Rough", type: .drive, result: .left, consequence: .rough),
        Case(phrase: "Hybrid zu kurz", type: .woodHybrid, result: .short, consequence: nil),
        Case(phrase: "Fairwayholz gerade", type: .woodHybrid, result: .good, consequence: nil),
        Case(phrase: "Dreier Holz links", type: .woodHybrid, result: .left, consequence: nil),
        Case(phrase: "Langes Eisen rechts", type: .longIron, result: .right, consequence: nil),
        Case(phrase: "Fünfer Eisen zu lang", type: .longIron, result: .long, consequence: nil),
        Case(phrase: "Eisen 4 links ins Wasser", type: .longIron, result: .left, consequence: .water),
        Case(phrase: "Kurzes Eisen gut", type: .shortIronWedge, result: .good, consequence: nil),
        Case(phrase: "Siebener Eisen rechts ins Wasser", type: .shortIronWedge, result: .right, consequence: .water),
        Case(phrase: "7er Eisen zu kurz in den Bunker", type: .shortIronWedge, result: .short, consequence: .bunker),
        Case(phrase: "Pitching Wedge zu lang", type: .shortIronWedge, result: .long, consequence: nil),
        Case(phrase: "Sandwedge links", type: .shortIronWedge, result: .left, consequence: nil),
        Case(phrase: "Pitch zu kurz", type: .pitch, result: .short, consequence: nil),
        Case(phrase: "Chip gut", type: .chip, result: .good, consequence: nil),
        Case(phrase: "Chip zu weit", type: .chip, result: .long, consequence: nil),
        Case(phrase: "Bunker gut", type: .bunker, result: .good, consequence: nil),
        Case(phrase: "Aus dem Bunker zu kurz", type: .bunker, result: .short, consequence: nil),
        Case(phrase: "Bunkerschlag zu lang", type: .bunker, result: .long, consequence: nil),
        Case(phrase: "Putt zu kurz", type: .putt, result: .short, consequence: nil),
        Case(phrase: "Putt drin", type: .putt, result: .good, consequence: nil),
        Case(phrase: "Drive gut Strafschlag", type: .drive, result: .good, consequence: .penalty),
        Case(phrase: "Hybrid links, Teich", type: .woodHybrid, result: .left, consequence: .water),
        Case(phrase: "DRIVE RECHTS!", type: .drive, result: .right, consequence: nil),
        Case(phrase: "Chip aus dem Rough gut", type: .chip, result: .good, consequence: nil),
    ]

    @Test(arguments: cases)
    func parsesPhrase(_ c: Case) {
        let parsed = ShotPhraseParser.parse(c.phrase)
        #expect(parsed.shotType == c.type)
        #expect(parsed.result == c.result)
        #expect(parsed.consequence == c.consequence)
    }

    @Test func siehtGutAusIsNotOutOfBounds() {
        let parsed = ShotPhraseParser.parse("Drive sieht gut aus")
        #expect(parsed == ParsedShot(shotType: .drive, result: .good, consequence: nil))
    }

    @Test func kurzesEisenDoesNotBecomeShort() {
        let parsed = ShotPhraseParser.parse("kurzes Eisen rechts")
        #expect(parsed.result == .right)
    }

    @Test func incompletePhraseLeavesFieldsEmpty() {
        let parsed = ShotPhraseParser.parse("links")
        #expect(parsed.shotType == nil)
        #expect(parsed.result == .left)
        #expect(!parsed.isComplete)
    }

    @Test func emptyPhrase() {
        #expect(ShotPhraseParser.parse("") == ParsedShot())
    }

    @Test func normalizeFoldsUmlautsAndPunctuation() {
        #expect(ShotPhraseParser.normalize("Fünfer-Eisen, drüber!") == "funfer eisen druber")
        #expect(ShotPhraseParser.normalize("Straße") == "strasse")
    }

    @Test func trailingFertigSavesAndIsStripped() {
        let (shot, command) = ShotPhraseParser.parseUtterance("Drive rechts ins Aus fertig")
        #expect(command == .save)
        #expect(shot == ParsedShot(shotType: .drive, result: .right, consequence: .outOfBounds))
    }

    @Test func trailingSpeichernSaves() {
        let (shot, command) = ShotPhraseParser.parseUtterance("Putt zu kurz, speichern.")
        #expect(command == .save)
        #expect(shot == ParsedShot(shotType: .putt, result: .short, consequence: nil))
    }

    @Test func trailingAbbrechenCancels() {
        let (_, command) = ShotPhraseParser.parseUtterance("Chip links abbrechen")
        #expect(command == .cancel)
    }

    @Test func commandOnlyCountsAtTheEnd() {
        let (shot, command) = ShotPhraseParser.parseUtterance("fertig Drive gut")
        #expect(command == nil)
        #expect(shot.shotType == .drive)
        #expect(shot.result == .good)
    }

    @Test func noCommandWithoutCommandWord() {
        let (shot, command) = ShotPhraseParser.parseUtterance("Siebener Eisen rechts ins Wasser")
        #expect(command == nil)
        #expect(shot == ParsedShot(shotType: .shortIronWedge, result: .right, consequence: .water))
    }

    @Test func commandAloneGivesEmptyShot() {
        let (shot, command) = ShotPhraseParser.parseUtterance("Fertig")
        #expect(command == .save)
        #expect(shot == ParsedShot())
    }

    // MARK: Rundenbefehle

    @Test(arguments: [
        ("nächstes Loch", RoundCommand.nextHole),
        ("Das nächste Loch", .nextHole),
        ("vorheriges Loch", .previousHole),
        ("letztes Loch", .previousHole),
        ("Loch 7", .goToHole(7)),
        ("Loch sieben", .goToHole(7)),
        ("Loch Nummer 12", .goToHole(12)),
        ("letzten Schlag löschen", .undoLastShot),
        ("rückgängig", .undoLastShot),
        ("Wie steht's?", .score),
        ("Spielstand", .score),
        ("Runde beenden", .endRound),
        ("Runde fertig", .endRound),
    ])
    func roundCommand(_ phrase: String, _ expected: RoundCommand) {
        let utterance = ShotPhraseParser.parseRoundUtterance(phrase)
        #expect(utterance.roundCommand == expected)
        #expect(utterance.shot == ParsedShot())
        #expect(utterance.command == nil)
    }

    @Test func shotThenNextHole() {
        let utterance = ShotPhraseParser.parseRoundUtterance("Putt drin, nächstes Loch")
        #expect(utterance.roundCommand == .nextHole)
        #expect(utterance.shot == ParsedShot(shotType: .putt, result: .good, consequence: nil))
    }

    @Test func holeThenShot() {
        let utterance = ShotPhraseParser.parseRoundUtterance("Loch 3, Drive links fertig")
        #expect(utterance.roundCommand == .goToHole(3))
        #expect(utterance.command == .save)
        #expect(utterance.shot == ParsedShot(shotType: .drive, result: .left, consequence: nil))
    }

    @Test func invalidHoleNumberIsIgnored() {
        #expect(ShotPhraseParser.parseRoundUtterance("Loch 19").roundCommand == nil)
    }

    @Test func plainShotHasNoRoundCommand() {
        let utterance = ShotPhraseParser.parseRoundUtterance("Siebener Eisen rechts ins Wasser")
        #expect(utterance.roundCommand == nil)
        #expect(utterance.shot == ParsedShot(shotType: .shortIronWedge, result: .right, consequence: .water))
    }
}
