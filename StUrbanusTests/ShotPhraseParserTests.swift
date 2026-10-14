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
        Case(phrase: "Eisen 6 rechts", type: .iron6, result: .right, consequence: nil),
        Case(phrase: "Fünfer Eisen zu lang", type: .iron5, result: .long, consequence: nil),
        Case(phrase: "Eisen 8 links ins Wasser", type: .iron8, result: .left, consequence: .water),
        Case(phrase: "Neuner gut", type: .iron9, result: .good, consequence: nil),
        Case(phrase: "Siebener Eisen rechts ins Wasser", type: .iron7, result: .right, consequence: .water),
        Case(phrase: "7er Eisen zu kurz in den Bunker", type: .iron7, result: .short, consequence: .bunker),
        Case(phrase: "Pitching Wedge zu lang", type: .wedge, result: .long, consequence: nil),
        Case(phrase: "Sandwedge links", type: .wedge, result: .left, consequence: nil),
        Case(phrase: "Eisen sechs links", type: .iron6, result: .left, consequence: nil),
        Case(phrase: "Achter Eisen zu kurz", type: .iron8, result: .short, consequence: nil),
        Case(phrase: "5er Hybrid links", type: .woodHybrid, result: .left, consequence: nil),
        Case(phrase: "Drive Fairway", type: .drive, result: .good, consequence: .fairway),
        Case(phrase: "Drive rechts aufs Fairway", type: .drive, result: .right, consequence: .fairway),
        Case(phrase: "Eisen 9 aufs Grün", type: .iron9, result: .good, consequence: .green),
        Case(phrase: "Eisen 7 zu lang, Grün", type: .iron7, result: .long, consequence: .green),
        Case(phrase: "Hybrid rechts First Cut", type: .woodHybrid, result: .right, consequence: .firstCut),
        Case(phrase: "Drive links Semi-Rough", type: .drive, result: .left, consequence: .firstCut),
        Case(phrase: "Drive links im Rough", type: .drive, result: .left, consequence: .rough),
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

    @Test func ironsAreRecognizedIndividually() {
        let phrases = ["Eisen 5", "6er Eisen", "Siebener", "Eisen acht", "Neuner Eisen"]
        #expect(phrases.map { ShotPhraseParser.parse($0).shotType } == [.iron5, .iron6, .iron7, .iron8, .iron9])
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
        #expect(shot == ParsedShot(shotType: .iron7, result: .right, consequence: .water))
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
        #expect(utterance.shot == ParsedShot(shotType: .iron7, result: .right, consequence: .water))
    }

    // MARK: GIR

    @Test func girHitByPhrase() {
        let parsed = ShotPhraseParser.parse("Eisen 8 gut, Grün getroffen")
        #expect(parsed == ParsedShot(shotType: .iron8, result: .good, consequence: .green, gir: true))
    }

    @Test func girMissedIsNotGreen() {
        let parsed = ShotPhraseParser.parse("Wedge rechts, Grün verfehlt")
        #expect(parsed == ParsedShot(shotType: .wedge, result: .right, consequence: nil, gir: false))
    }

    @Test func nichtAufsGruenIsMissed() {
        let parsed = ShotPhraseParser.parse("Eisen 7 zu kurz, nicht aufs Grün")
        #expect(parsed.gir == false)
        #expect(parsed.consequence == nil)
        #expect(parsed.result == .short)
    }

    @Test func standaloneGIRAnswer() {
        #expect(ShotPhraseParser.parse("GIR ja") == ParsedShot(shotType: nil, result: .good, consequence: .green, gir: true))
        #expect(ShotPhraseParser.parse("GIR nein") == ParsedShot(gir: false))
    }
}
