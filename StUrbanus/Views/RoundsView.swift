import SwiftData
import SwiftUI

struct RoundsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var path: [Round] = []

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
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Runden")
            .navigationDestination(for: Round.self) { round in
                RoundView(round: round)
            }
        }
    }

    private func startRound() {
        guard let course = courses.first else { return }
        let round = Round(course: course)
        context.insert(round)
        for hole in course.sortedHoles {
            round.holeScores.append(HoleScore(holeNumber: hole.number, par: hole.par))
        }
        try? context.save()
        path.append(round)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(rounds[index])
        }
        try? context.save()
    }
}

private struct RoundRow: View {
    let round: Round

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(round.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Text("\(round.playedScores.count) von \(round.holeScores.count) Löchern")
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
