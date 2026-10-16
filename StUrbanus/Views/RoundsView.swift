import SwiftData
import SwiftUI

struct RoundsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var path: [Round] = []
    @State private var roundToDelete: Round?
    @State private var choosingCourse = false
    @State private var showAbout = false

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
                    .tint(.zuluGold)
                    .foregroundStyle(Color.zuluNavy)
                    .listRowInsets(EdgeInsets())
                    // Kein weißer Zeilenhintergrund um den Knopf.
                    .listRowBackground(Color.clear)
                    .disabled(courses.isEmpty)
                } footer: {
                    if courses.isEmpty {
                        Text("Lege zuerst unter „Plätze“ einen Platz an.")
                    }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Zulu-Golf-Logo; führt zu „Über Caddy“.
                    Button {
                        showAbout = true
                    } label: {
                        ZGBadge(height: 22)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Über Caddy")
                }
                // Ohne den hellen Glas-Rahmen der Symbolleiste; das Logo hat seinen eigenen Hintergrund.
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
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
            .confirmationDialog("Auf welchem Platz spielst du?", isPresented: $choosingCourse, titleVisibility: .visible) {
                let options = CourseService.coursesForSelection(in: context)
                ForEach(Array(options.enumerated()), id: \.element.id) { offset, course in
                    Button(offset == 0 && course.lastUsedAt != nil ? "\(course.name) (zuletzt)" : course.name) {
                        start(on: course)
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

    /// Ein Platz: sofort starten. Mehrere: fragen, zuletzt gespielter Platz steht oben.
    private func startRound() {
        let options = CourseService.coursesForSelection(in: context)
        if options.count == 1 {
            start(on: options[0])
        } else if options.count > 1 {
            choosingCourse = true
        }
    }

    private func start(on course: Course) {
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
                Text(round.course?.name ?? round.courseName)
                    .font(.subheadline)
                    .lineLimit(1)
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
