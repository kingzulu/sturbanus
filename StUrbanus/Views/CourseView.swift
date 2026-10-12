import SwiftData
import SwiftUI

/// Platzdaten: Par pro Loch anpassen (Standard Par 4, bis die echten Werte eingetragen sind).
struct CourseView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.createdAt) private var courses: [Course]

    var body: some View {
        NavigationStack {
            List {
                if let course = courses.first {
                    Section {
                        LabeledContent("Löcher", value: "\(course.holes.count)")
                        LabeledContent("Par gesamt", value: "\(course.totalPar)")
                    } header: {
                        Text(course.name)
                    } footer: {
                        Text("Par-Änderungen gelten für neue Runden.")
                    }

                    Section("Par pro Loch") {
                        ForEach(course.sortedHoles) { hole in
                            HoleParRow(hole: hole)
                        }
                    }
                }
            }
            .navigationTitle("Platz")
            .onDisappear { try? context.save() }
        }
    }
}

private struct HoleParRow: View {
    @Bindable var hole: Hole

    var body: some View {
        Stepper(value: $hole.par, in: 3...6) {
            HStack {
                Text("Loch \(hole.number)")
                Spacer()
                Text("Par \(hole.par)").monospacedDigit().bold()
            }
        }
    }
}
