import SwiftData
import SwiftUI

@main
struct StUrbanusApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Course.self, Hole.self, Round.self, HoleScore.self, Shot.self])
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
            Tab("Platz", systemImage: "map") {
                CourseView()
            }
        }
        .task {
            SeedData.seedIfNeeded(context)
        }
    }
}
