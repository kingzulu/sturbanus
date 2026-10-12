import SwiftData
import SwiftUI

/// Eine Runde: Loch wählen, Schläge erfassen. Score des Lochs = Schläge + Strafschläge.
struct RoundView: View {
    @Environment(\.modelContext) private var context
    let round: Round
    @State private var selectedHole = 1
    @State private var showVoice = false

    private var currentScore: HoleScore? {
        round.holeScores.first { $0.holeNumber == selectedHole }
    }

    var body: some View {
        VStack(spacing: 0) {
            HolePicker(round: round, selectedHole: $selectedHole)
                .padding(.vertical, 8)

            Divider()

            if let score = currentScore {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HoleHeader(score: score)
                        ShotList(score: score, onDelete: deleteShot)
                        ShotEntryPanel { type, result, consequence in
                            addShot(to: score, type: type, result: result, consequence: consequence)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Loch \(selectedHole)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showVoice = true
                } label: {
                    Label("Sprechen", systemImage: "mic.fill")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button("Vorheriges", systemImage: "chevron.left") { selectedHole = max(1, selectedHole - 1) }
                        .disabled(selectedHole <= 1)
                    Spacer()
                    Text("Gesamt \(round.totalStrokes) (\(ToPar.format(round.toPar)))")
                        .font(.subheadline.monospacedDigit())
                    Spacer()
                    Button("Nächstes", systemImage: "chevron.right") { selectedHole = min(round.holeScores.count, selectedHole + 1) }
                        .disabled(selectedHole >= round.holeScores.count)
                }
            }
        }
        .sheet(isPresented: $showVoice) {
            VoiceShotSheet(recognizer: AppleSpeechRecognizer()) { type, result, consequence in
                if let score = currentScore {
                    addShot(to: score, type: type, result: result, consequence: consequence)
                }
            }
        }
    }

    private func addShot(to score: HoleScore, type: ShotType, result: ShotResult, consequence: ShotConsequence?) {
        let nextIndex = (score.shots.map(\.index).max() ?? 0) + 1
        score.shots.append(Shot(index: nextIndex, type: type, result: result, consequence: consequence))
        try? context.save()
    }

    private func deleteShot(_ shot: Shot) {
        context.delete(shot)
        try? context.save()
    }
}

private struct HolePicker: View {
    let round: Round
    @Binding var selectedHole: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(round.sortedScores) { score in
                        Button {
                            selectedHole = score.holeNumber
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(score.holeNumber)").font(.headline)
                                Text(score.shots.isEmpty ? "–" : "\(score.strokes)")
                                    .font(.caption.monospacedDigit())
                            }
                            .frame(width: 44, height: 48)
                            .background(score.holeNumber == selectedHole ? Color.accentColor : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(score.holeNumber == selectedHole ? Color.white : Color.primary)
                        }
                        .id(score.holeNumber)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selectedHole) { _, hole in
                withAnimation { proxy.scrollTo(hole, anchor: .center) }
            }
        }
    }
}

private struct HoleHeader: View {
    let score: HoleScore

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Par \(score.par)")
                .font(.title2.bold())
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(score.strokes)")
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                if score.penaltyStrokes > 0 {
                    Text("davon \(score.penaltyStrokes) Strafschlag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ShotList: View {
    let score: HoleScore
    let onDelete: (Shot) -> Void

    var body: some View {
        if score.shots.isEmpty {
            Text("Noch keine Schläge auf diesem Loch.")
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 6) {
                ForEach(score.sortedShots) { shot in
                    HStack {
                        Text("\(shot.index).")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        Text(shot.shotType.label).bold()
                        Text(shot.result.label)
                            .foregroundStyle(shot.result == .good ? Color.green : Color.orange)
                        if let consequence = shot.consequence {
                            Text(consequence.label)
                                .font(.caption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                        Button(role: .destructive) {
                            onDelete(shot)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
