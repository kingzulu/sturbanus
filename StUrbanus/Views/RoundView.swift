import SwiftData
import SwiftUI

/// Eine Runde: Loch wählen, Schläge erfassen. Score des Lochs = Schläge + Strafschläge.
struct RoundView: View {
    @Environment(\.modelContext) private var context
    /// Das aktuelle Loch liegt in der Runde selbst, damit Siri („nächstes Loch“) und App synchron bleiben.
    @Bindable var round: Round
    /// Löscht die Runde; die Liste kümmert sich um Navigation und Löschen.
    var onDelete: () -> Void = {}
    @State private var showVoice = false
    @State private var confirmDelete = false

    private var currentScore: HoleScore? { round.currentScore }

    var body: some View {
        VStack(spacing: 0) {
            HolePicker(round: round, selectedHole: $round.currentHole)
                .padding(.vertical, 8)

            Divider()

            if let score = currentScore {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HoleHeader(score: score) { gir in
                            RoundService.setGIR(gir, in: round, context: context)
                        }
                        ShotList(score: score, onDelete: deleteShot)
                        if score.isHoled {
                            HoleFinished(score: score,
                                         nextHole: score.holeNumber < round.holeScores.count ? score.holeNumber + 1 : nil) {
                                goTo(score.holeNumber + 1)
                            }
                        } else {
                            ShotEntryPanel(shotNumber: nextShotNumber(score), isGIRShot: isNextShotGIRShot(score)) { type, result, consequence, gir in
                                RoundService.logShot(type, result, consequence, gir: gir, in: round, context: context)
                            }
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Runde löschen", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
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
        .confirmationDialog("Runde löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Runde löschen", role: .destructive, action: onDelete)
        } message: {
            Text("Diese Runde mit allen Schlägen wird gelöscht und zählt nicht mehr in der Statistik. Das lässt sich nicht rückgängig machen.")
        }
        .sheet(isPresented: $showVoice) {
            VoiceShotSheet(recognizer: AppleSpeechRecognizer(), shotNumber: currentScore.map(nextShotNumber), onSave: { type, result, consequence, gir in
                RoundService.logShot(type, result, consequence, gir: gir, in: round, context: context)
            }, onRoundCommand: { command in
                _ = RoundService.apply(command, to: round, in: context)
            })
        }
    }

    private func nextShotNumber(_ score: HoleScore) -> Int { score.nextStrokeNumber }

    /// Der nächste Schlag ist der GIR-Schlag (Par−2), solange GIR noch nicht feststeht.
    private func isNextShotGIRShot(_ score: HoleScore) -> Bool {
        score.gir == nil && nextShotNumber(score) == score.girShotNumber
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
                                HStack(spacing: 1) {
                                    Text(score.shots.isEmpty ? "–" : "\(score.strokes)")
                                    if score.isHoled {
                                        Image(systemName: "checkmark")
                                    }
                                }
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
    let onSetGIR: (Bool?) -> Void

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
            GIRBadge(gir: score.gir, isManual: score.girOverride != nil, onSet: onSetGIR)
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
                        Text("\(score.strokeNumber(of: shot)).")
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

/// GIR-Status des Lochs; per Menü korrigierbar.
private struct GIRBadge: View {
    let gir: Bool?
    let isManual: Bool
    let onSet: (Bool?) -> Void

    var body: some View {
        Menu {
            Button("Grün in Regulation getroffen", systemImage: "checkmark.circle") { onSet(true) }
            Button("Grün in Regulation verfehlt", systemImage: "xmark.circle") { onSet(false) }
            if isManual {
                Button("Automatisch aus den Schlägen", systemImage: "arrow.counterclockwise") { onSet(nil) }
            }
        } label: {
            Label("GIR", systemImage: symbol)
                .font(.subheadline.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15), in: Capsule())
                .foregroundStyle(color)
        }
    }

    private var symbol: String {
        switch gir {
        case true?: "checkmark.circle.fill"
        case false?: "xmark.circle"
        case nil: "questionmark.circle"
        }
    }

    private var color: Color {
        switch gir {
        case true?: .green
        case false?: .orange
        case nil: .secondary
        }
    }
}

/// Loch ist eingelocht: Ergebnis anzeigen statt weiterer Erfassung.
private struct HoleFinished: View {
    let score: HoleScore
    let nextHole: Int?
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Eingelocht mit \(score.strokes) (\(ToPar.format(score.strokes - score.par)))",
                  systemImage: "flag.checkered")
                .font(.title3.bold())
                .foregroundStyle(.green)
            Text("Zum Korrigieren den letzten Schlag oben löschen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let nextHole {
                BigButton(title: "Weiter zu Loch \(nextHole)", systemImage: "chevron.right.circle.fill", tint: .accentColor, action: onNext)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
