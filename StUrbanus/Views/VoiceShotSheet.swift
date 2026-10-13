import SwiftUI

/// Sprach-Erfassung: aufnehmen → erkannte Felder anzeigen → bestätigen oder korrigieren → speichern.
/// Freihändig: „… fertig“ / „… speichern“ oder 2 s Stille speichern, „… abbrechen“ verwirft.
/// Fehlt Schlagart oder Ergebnis, bleibt die Ansicht offen und markiert das fehlende Feld.
struct VoiceShotSheet: View {
    let recognizer: any SpeechRecognizer
    let onSave: (ShotType, ShotResult, ShotConsequence?) -> Void
    /// Rundenbefehle aus der Ansage („nächstes Loch“, „Loch 7“, …).
    var onRoundCommand: (RoundCommand) -> Void = { _ in }

    /// Stille nach erkanntem Text, nach der automatisch beendet und gespeichert wird.
    private static let silenceTimeout: Duration = .seconds(2)

    @Environment(\.dismiss) private var dismiss
    @State private var transcript = ""
    @State private var isListening = false
    @State private var errorMessage: String?
    @State private var parsed = ParsedShot()
    @State private var showMissing = false
    @State private var pendingRoundCommand: RoundCommand?
    @State private var silenceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Beispiel: „Siebener Eisen rechts ins Wasser, fertig“ oder „Putt drin, nächstes Loch“")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(transcript.isEmpty ? (isListening ? "Ich höre zu …" : "Tippe auf das Mikrofon und sag deinen Schlag.") : "„\(transcript)“")
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }

                    Button {
                        isListening ? finishListening() : startListening()
                    } label: {
                        Label(isListening ? "Fertig" : "Sprechen", systemImage: isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isListening ? .red : .accentColor)

                    Divider()

                    fieldHeader("Schlagart", missing: showMissing && parsed.shotType == nil)
                    BigButtonGrid(items: ShotType.allCases, label: \.label, selected: parsed.shotType, tint: .gray) {
                        parsed.shotType = $0
                    }
                    fieldHeader("Ergebnis", missing: showMissing && parsed.result == nil)
                    BigButtonGrid(items: ShotResult.allCases, label: \.label, selected: parsed.result, tint: .gray) {
                        parsed.result = $0
                    }
                    fieldHeader("Folge (optional)", missing: false)
                    BigButtonGrid(items: ShotConsequence.allCases, label: \.label, selected: parsed.consequence, tint: .gray) {
                        parsed.consequence = (parsed.consequence == $0) ? nil : $0
                    }
                }
                .padding()
            }
            .navigationTitle("Schlag ansagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { trySave() }
                        .disabled(!parsed.isComplete)
                }
            }
        }
        .onDisappear {
            silenceTask?.cancel()
            recognizer.stop()
        }
    }

    @ViewBuilder
    private func fieldHeader(_ title: String, missing: Bool) -> some View {
        HStack {
            Text(title).font(.headline)
            if missing {
                Label("fehlt – bitte antippen", systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Ablauf

    private func startListening() {
        errorMessage = nil
        showMissing = false
        Task {
            guard await recognizer.requestAuthorization() else {
                errorMessage = SpeechRecognizerError.notAuthorized.localizedDescription
                return
            }
            do {
                transcript = ""
                try await recognizer.start(onTranscript: handleTranscript, onError: { error in
                    errorMessage = error.localizedDescription
                    stopListening()
                })
                isListening = true
                warnIfSilent()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleTranscript(_ text: String) {
        guard isListening else { return }
        transcript = text
        let utterance = ShotPhraseParser.parseRoundUtterance(text)
        parsed = utterance.shot
        pendingRoundCommand = utterance.roundCommand

        switch utterance.command {
        case .cancel:
            cancel()
        case .save:
            finishListening()
        case nil:
            restartSilenceTimer()
        }
    }

    /// Nach erkanntem Text: bei 2 s ohne neue Wörter automatisch beenden und speichern.
    private func restartSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task {
            try? await Task.sleep(for: Self.silenceTimeout)
            guard !Task.isCancelled, isListening, !transcript.isEmpty else { return }
            finishListening()
        }
    }

    /// Hinweis, falls nach einigen Sekunden noch nichts erkannt wurde, statt stumm zu bleiben.
    private func warnIfSilent() {
        Task {
            try? await Task.sleep(for: .seconds(6))
            if isListening, transcript.isEmpty, errorMessage == nil {
                errorMessage = "Noch nichts verstanden. Sprich etwas lauter oder prüfe den Mikrofon-Eingang."
            }
        }
    }

    /// Aufnahme beenden und speichern, sofern Schlagart und Ergebnis erkannt sind.
    private func finishListening() {
        stopListening()
        if let command = pendingRoundCommand {
            complete(with: command)
        } else {
            trySave()
        }
    }

    /// Mit Rundenbefehl: Schlag nur speichern, wenn vollständig, dann Befehl ausführen und schließen.
    /// Bei „Loch 7, Drive rechts“ erst wechseln, damit der Schlag auf Loch 7 landet.
    private func complete(with command: RoundCommand) {
        if case .goToHole = command {
            onRoundCommand(command)
            saveIfComplete()
        } else {
            saveIfComplete()
            onRoundCommand(command)
        }
        dismiss()
    }

    private func saveIfComplete() {
        guard let type = parsed.shotType, let result = parsed.result else { return }
        onSave(type, result, parsed.consequence)
    }

    private func trySave() {
        guard let type = parsed.shotType, let result = parsed.result else {
            showMissing = true
            return
        }
        stopListening()
        onSave(type, result, parsed.consequence)
        dismiss()
    }

    private func cancel() {
        stopListening()
        dismiss()
    }

    private func stopListening() {
        silenceTask?.cancel()
        silenceTask = nil
        recognizer.stop()
        isListening = false
    }
}
