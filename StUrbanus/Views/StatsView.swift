import SwiftData
import SwiftUI

/// Wo gehen Schläge verloren? Fehlermuster pro Schlagart über alle Runden.
struct StatsView: View {
    @Query private var shots: [Shot]
    @Query private var rounds: [Round]

    var body: some View {
        NavigationStack {
            List {
                if shots.isEmpty {
                    ContentUnavailableView("Noch keine Daten",
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
        }
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
