import Foundation
import SwiftData

enum SeedData {
    static let stUrbanusName = "V-Golf St. Urbanus Köln"

    /// Legt den Heimatplatz an, falls noch kein Platz existiert.
    /// Par pro Loch ist noch unbekannt: Standard Par 4, im Tab „Platz“ editierbar.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Course>())) ?? 0
        guard count == 0 else { return }

        let course = Course(name: stUrbanusName)
        context.insert(course)
        for number in 1...18 {
            course.holes.append(Hole(number: number, par: 4))
        }
        try? context.save()
    }
}
