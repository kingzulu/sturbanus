import AppIntents
import SwiftData
import SwiftUI

@main
struct StUrbanusApp: App {
    init() {
        // Siri-Sätze nach Updates sofort neu registrieren.
        UrbanusShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppModel.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("Runden", systemImage: "figure.golf") {
                RoundsView()
            }
            Tab("Statistik", systemImage: "chart.bar") {
                StatsView()
            }
            Tab("Plätze", systemImage: "map") {
                CoursesView()
            }
        }
        .task {
            SeedData.seedIfNeeded(context)
        }
    }
}
