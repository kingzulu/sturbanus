import SwiftData
import SwiftUI

struct RoundsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var path: [Round] = []
    @State private var roundToDelete: Round?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        startRound()
                    } label: {
                        Label("Neue Runde starten", systemImage: "plus.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .disabled(courses.isEmpty)
                }

                if !rounds.isEmpty {
                    Section("Bisherige Runden") {
                        ForEach(rounds) { round in
                            NavigationLink(value: round) {
                                RoundRow(round: round)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    roundToDelete = round
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Runden")
            .navigationDestination(for: Round.self) { round in
                RoundView(round: round) {
                    // Erst zurück zur Liste, dann löschen, damit keine Ansicht mehr auf die Runde zeigt.
                    path.removeAll()
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        RoundService.deleteRound(round, in: context)
                    }
                }
            }
            .confirmationDialog("Runde löschen?", isPresented: Binding(
                get: { roundToDelete != nil },
                set: { if !$0 { roundToDelete = nil } }
            ), titleVisibility: .visible, presenting: roundToDelete) { round in
                Button("Runde löschen", role: .destructive) {
                    RoundService.deleteRound(round, in: context)
                    roundToDelete = nil
                }
            } message: { round in
                Text("Die Runde vom \(round.date.formatted(date: .abbreviated, time: .shortened)) mit allen Schlägen wird gelöscht und zählt nicht mehr in der Statistik. Das lässt sich nicht rückgängig machen.")
            }
        }
    }

    private func startRound() {
        guard let course = courses.first else { return }
        path.append(RoundService.startRound(on: course, in: context))
    }

}

private struct RoundRow: View {
    let round: Round

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(round.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Text(round.isFinished
                     ? "\(round.playedScores.count) von \(round.holeScores.count) Löchern"
                     : "Läuft · Loch \(round.currentHole)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if round.totalStrokes > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(round.totalStrokes)")
                        .font(.title2.bold())
                    Text(ToPar.format(round.toPar))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

enum ToPar {
    static func format(_ value: Int) -> String {
        value == 0 ? "E" : (value > 0 ? "+\(value)" : "\(value)")
    }
}
