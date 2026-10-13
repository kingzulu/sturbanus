import SwiftData
import SwiftUI

/// Eine Runde: Loch wählen, Schläge erfassen. Score des Lochs = Schläge + Strafschläge.
struct RoundView: View {
    @Environment(\.modelContext) private var context
    /// Das aktuelle Loch liegt in der Runde selbst, damit Siri („nächstes Loch“) und App synchron bleiben.
    @Bindable var round: Round
    @State private var showVoice = false

    private var currentScore: HoleScore? { round.currentScore }

    var body: some View {
        VStack(spacing: 0) {
            HolePicker(round: round, selectedHole: $round.currentHole)
                .padding(.vertical, 8)

            Divider()

            if let score = currentScore {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HoleHeader(score: score)
                        ShotList(score: score, onDelete: deleteShot)
                        ShotEntryPanel { type, result, consequence in
                            RoundService.logShot(type, result, consequence, in: round, context: context)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Loch \(round.currentHole)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showVoice = true
                } label: {
                    Label("Sprechen", systemImage: "mic.fill")
                }
            }
        }
        // Eigene Leiste statt Toolbar-.bottomBar, die von der TabBar verdeckt wird.
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Vorheriges", systemImage: "chevron.left") { goTo(round.currentHole - 1) }
                    .disabled(round.currentHole <= 1)
                Spacer()
                Text("Gesamt \(round.totalStrokes) (\(ToPar.format(round.toPar)))")
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Button("Nächstes", systemImage: "chevron.right") { goTo(round.currentHole + 1) }
                    .disabled(round.currentHole >= round.holeScores.count)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .sheet(isPresented: $showVoice) {
            VoiceShotSheet(recognizer: AppleSpeechRecognizer(), onSave: { type, result, consequence in
                RoundService.logShot(type, result, consequence, in: round, context: context)
            }, onRoundCommand: { command in
                _ = RoundService.apply(command, to: round, in: context)
            })
        }
    }

    private func goTo(_ hole: Int) {
        guard (1...round.holeScores.count).contains(hole) else { return }
        round.currentHole = hole
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
            // Par direkt in der Runde korrigierbar; gilt auch für künftige Runden.
            Menu {
                Picker("Par", selection: Binding(
                    get: { score.par },
                    set: { newPar in
                        score.par = newPar
                        score.round?.course?.holes.first { $0.number == score.holeNumber }?.par = newPar
                    }
                )) {
                    ForEach(3...6, id: \.self) { Text("Par \($0)").tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Par \(score.par)")
                    Image(systemName: "chevron.up.chevron.down").font(.footnote)
                }
                .font(.title2.bold())
            }
            .tint(.primary)
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
