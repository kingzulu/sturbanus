import SwiftData
import SwiftUI

/// Wo gehen Schläge verloren? Fehlermuster pro Schlagart über alle Runden.
struct StatsView: View {
    @Query private var allShots: [Shot]
    @Query private var allRounds: [Round]
    @Query private var allHoleScores: [HoleScore]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    /// `nil` = alle Plätze.
    @State private var courseFilter: PersistentIdentifier?

    private var shots: [Shot] { allShots.filter { StatsFilter.matches($0.holeScore?.round, courseFilter) } }
    private var rounds: [Round] { allRounds.filter { StatsFilter.matches($0, courseFilter) } }
    private var holeScores: [HoleScore] { allHoleScores.filter { StatsFilter.matches($0.round, courseFilter) } }

    var body: some View {
        NavigationStack {
            List {
                if shots.isEmpty {
                    ContentUnavailableView(courseFilter == nil ? "Noch keine Daten" : "Keine Daten für diesen Platz",
                                           systemImage: "chart.bar",
                                           description: Text("Erfasse Schläge in einer Runde, dann siehst du hier deine Fehlermuster."))
                } else {
                    Section("Überblick") {
                        LabeledContent("Runden", value: "\(rounds.count)")
                        LabeledContent("Erfasste Schläge", value: "\(shots.count)")
                        LabeledContent("Strafschläge", value: "\(shots.reduce(0) { $0 + ($1.consequence?.penaltyStrokes ?? 0) })")
                        LabeledContent("Gute Schläge", value: percent(shots.filter { $0.result == .good }.count, of: shots.count))
                    }

                    Section {
                        GIRRow(title: "Gesamt", scores: holeScores)
                        ForEach([3, 4, 5], id: \.self) { par in
                            GIRRow(title: "Par \(par)", scores: holeScores.filter { $0.par == par })
                        }
                    } header: {
                        Text("Green in Regulation")
                    } footer: {
                        Text("Grün spätestens mit Schlag Par−2 erreicht (Par 3: 1., Par 4: 2., Par 5: 3. Schlag).")
                    }

                    Section {
                        ForEach(ShotType.allCases) { type in
                            let typed = shots.filter { $0.shotType == type }
                            if !typed.isEmpty {
                                ShotTypeStatsRow(type: type, shots: typed)
                            }
                        }
                    } header: {
                        Text("Fehlermuster pro Schlagart")
                    } footer: {
                        Legend()
                    }
                }
            }
            .navigationTitle("Statistik")
            .toolbar {
                if courses.count > 1 {
                    Menu {
                        Picker("Platz", selection: $courseFilter) {
                            Text("Alle Plätze").tag(PersistentIdentifier?.none)
                            ForEach(courses) { course in
                                Text(course.name).tag(PersistentIdentifier?.some(course.persistentModelID))
                            }
                        }
                    } label: {
                        Label(courseFilterName, systemImage: "line.3.horizontal.decrease.circle")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }

    private var courseFilterName: String {
        courses.first { $0.persistentModelID == courseFilter }?.name ?? "Alle Plätze"
    }
}

/// Filtert Statistikdaten nach Platz.
enum StatsFilter {
    static func matches(_ round: Round?, _ course: PersistentIdentifier?) -> Bool {
        guard let course else { return true }
        return round?.course?.persistentModelID == course
    }
}

private func percent(_ part: Int, of total: Int) -> String {
    guard total > 0 else { return "–" }
    return "\(Int((Double(part) / Double(total) * 100).rounded())) %"
}

extension ShotResult {
    var color: Color {
        switch self {
        case .good: .green
        case .left: .blue
        case .right: .purple
        case .short: .orange
        case .long: .pink
        }
    }
}

private struct ShotTypeStatsRow: View {
    let type: ShotType
    let shots: [Shot]

    private var resultCounts: [(ShotResult, Int)] {
        ShotResult.allCases.map { result in (result, shots.filter { $0.result == result }.count) }
    }

    private var consequenceCounts: [(ShotConsequence, Int)] {
        ShotConsequence.allCases
            .map { c in (c, shots.filter { $0.consequence == c }.count) }
            .filter { $0.1 > 0 }
    }

    private var worstMiss: (ShotResult, Int)? {
        resultCounts.filter { $0.0 != .good && $0.1 > 0 }.max { $0.1 < $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(type.label).font(.headline)
                Spacer()
                Text("\(shots.count) Schläge").font(.subheadline).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(resultCounts.filter { $0.1 > 0 }, id: \.0) { result, count in
                        Rectangle()
                            .fill(result.color)
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(shots.count))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 16)

            HStack(spacing: 10) {
                ForEach(resultCounts.filter { $0.1 > 0 }, id: \.0) { result, count in
                    Text("\(result.label) \(percent(count, of: shots.count))")
                        .font(.caption)
                        .foregroundStyle(result.color)
                }
            }

            if let worstMiss {
                Text("Häufigster Fehler: \(worstMiss.0.label)")
                    .font(.subheadline.bold())
            }

            if !consequenceCounts.isEmpty {
                Text(consequenceCounts.map { "\($0.0.label) ×\($0.1)" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(ShotResult.allCases) { result in
                HStack(spacing: 4) {
                    Circle().fill(result.color).frame(width: 8, height: 8)
                    Text(result.label)
                }
            }
        }
        .font(.caption2)
    }
}

/// GIR-Quote über alle Löcher, bei denen GIR schon feststeht.
private struct GIRRow: View {
    let title: String
    let scores: [HoleScore]

    var body: some View {
        let decided = scores.compactMap(\.gir)
        let hits = decided.filter { $0 }.count
        LabeledContent(title) {
            if decided.isEmpty {
                Text("–")
            } else {
                Text("\(percent(hits, of: decided.count))  (\(hits) von \(decided.count))")
                    .monospacedDigit()
            }
        }
    }
}
