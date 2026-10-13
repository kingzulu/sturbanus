import Foundation
import SwiftData

@Model
final class Course {
    var name: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Hole.course)
    var holes: [Hole] = []

    init(name: String) {
        self.name = name
    }

    var sortedHoles: [Hole] { holes.sorted { $0.number < $1.number } }
    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
}

@Model
final class Hole {
    var number: Int = 0
    var par: Int = 4
    var course: Course?

    init(number: Int, par: Int = 4) {
        self.number = number
        self.par = par
    }
}

@Model
final class Round {
    var date: Date = Date()
    var courseName: String = ""
    /// Loch, auf dem gerade gespielt wird; geteilt zwischen App und Siri.
    var currentHole: Int = 1
    /// Beendete Runden sind nicht mehr „aktiv“ für Siri.
    var isFinished: Bool = false
    var course: Course?
    @Relationship(deleteRule: .cascade, inverse: \HoleScore.round)
    var holeScores: [HoleScore] = []

    init(course: Course, date: Date = Date()) {
        self.date = date
        self.course = course
        self.courseName = course.name
    }

    var sortedScores: [HoleScore] { holeScores.sorted { $0.holeNumber < $1.holeNumber } }
    var currentScore: HoleScore? { holeScores.first { $0.holeNumber == currentHole } }
    var playedScores: [HoleScore] { holeScores.filter { !$0.shots.isEmpty } }
    var totalStrokes: Int { playedScores.reduce(0) { $0 + $1.strokes } }
    var parOfPlayedHoles: Int { playedScores.reduce(0) { $0 + $1.par } }
    var toPar: Int { totalStrokes - parOfPlayedHoles }
}

@Model
final class HoleScore {
    var holeNumber: Int = 0
    var par: Int = 4
    var round: Round?
    @Relationship(deleteRule: .cascade, inverse: \Shot.holeScore)
    var shots: [Shot] = []

    init(holeNumber: Int, par: Int) {
        self.holeNumber = holeNumber
        self.par = par
    }

    var sortedShots: [Shot] { shots.sorted { $0.index < $1.index } }
    var penaltyStrokes: Int { shots.reduce(0) { $0 + ($1.consequence?.penaltyStrokes ?? 0) } }
    /// Score = erfasste Schläge + Strafschläge.
    var strokes: Int { shots.count + penaltyStrokes }
}

@Model
final class Shot {
    var index: Int = 0
    var timestamp: Date = Date()
    var shotTypeRaw: String = ShotType.drive.rawValue
    var resultRaw: String = ShotResult.good.rawValue
    var consequenceRaw: String?
    var holeScore: HoleScore?

    init(index: Int, type: ShotType, result: ShotResult, consequence: ShotConsequence?) {
        self.index = index
        self.shotTypeRaw = type.rawValue
        self.resultRaw = result.rawValue
        self.consequenceRaw = consequence?.rawValue
    }

    var shotType: ShotType {
        get { ShotType(rawValue: shotTypeRaw) ?? .drive }
        set { shotTypeRaw = newValue.rawValue }
    }

    var result: ShotResult {
        get { ShotResult(rawValue: resultRaw) ?? .good }
        set { resultRaw = newValue.rawValue }
    }

    var consequence: ShotConsequence? {
        get { consequenceRaw.flatMap(ShotConsequence.init(rawValue:)) }
        set { consequenceRaw = newValue?.rawValue }
    }
}
