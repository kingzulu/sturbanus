import Foundation
import SwiftData

enum SeedData {
    static let stUrbanusName = "V-Golf St. Urbanus Köln"

    /// Par pro Loch laut Scorecard (Out 37, In 35, gesamt 72).
    static let stUrbanusPars = [5, 4, 3, 4, 3, 5, 4, 5, 4,
                                4, 4, 3, 5, 4, 3, 5, 3, 4]

    /// Legt den Heimatplatz an, falls noch kein Platz existiert, und korrigiert
    /// ältere Installationen, die noch die Platzhalter-Pars (überall 4) haben.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []

        guard !courses.isEmpty else {
            let course = Course(name: stUrbanusName)
            context.insert(course)
            for (offset, par) in stUrbanusPars.enumerated() {
                course.holes.append(Hole(number: offset + 1, par: par))
            }
            try? context.save()
            return
        }

        if let course = courses.first(where: { $0.name == stUrbanusName }) {
            applyScorecardParsIfPlaceholder(course, context: context)
        }
    }

    /// Nur wenn alle Pars noch auf dem Platzhalter 4 stehen (also nichts von Hand geändert wurde).
    @MainActor
    private static func applyScorecardParsIfPlaceholder(_ course: Course, context: ModelContext) {
        guard course.holes.count == stUrbanusPars.count,
              course.holes.allSatisfy({ $0.par == 4 }) else { return }

        for hole in course.holes {
            hole.par = stUrbanusPars[hole.number - 1]
        }
        let rounds = (try? context.fetch(FetchDescriptor<Round>())) ?? []
        for round in rounds where round.course === course && round.holeScores.allSatisfy({ $0.par == 4 }) {
            for score in round.holeScores where (1...stUrbanusPars.count).contains(score.holeNumber) {
                score.par = stUrbanusPars[score.holeNumber - 1]
            }
        }
        try? context.save()
    }
}
