import SwiftData

/// Ein gemeinsamer Datenspeicher für App und Siri-Kurzbefehle (laufen im selben Prozess).
@MainActor
enum AppModel {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Course.self, Hole.self, Round.self, HoleScore.self, Shot.self)
        } catch {
            fatalError("SwiftData-Speicher konnte nicht geöffnet werden: \(error)")
        }
    }()
}
