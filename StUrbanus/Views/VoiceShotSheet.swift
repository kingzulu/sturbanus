import SwiftUI

/// Sprach-Erfassung: aufnehmen → erkannte Felder anzeigen → bestätigen oder korrigieren → speichern.
struct VoiceShotSheet: View {
    let recognizer: any SpeechRecognizer
    let onSave: (ShotType, ShotResult, ShotConsequence?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var transcript = ""
    @State private var isListening = false
    @State private var errorMessage: String?
    @State private var parsed = ParsedShot()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Beispiel: „Siebener Eisen rechts ins Wasser“")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(transcript.isEmpty ? (isListening ? "Ich höre zu …" : "Tippe auf das Mikrofon und sag deinen Schlag.") : "„\(transcript)“")
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }

                    Button {
                        isListening ? stopListening() : startListening()
                    } label: {
                        Label(isListening ? "Fertig" : "Sprechen", systemImage: isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isListening ? .red : .accentColor)

                    Divider()

                    Text("Schlagart").font(.headline)
                    BigButtonGrid(items: ShotType.allCases, label: \.label, selected: parsed.shotType, tint: .gray) {
                        parsed.shotType = $0
                    }
                    Text("Ergebnis").font(.headline)
                    BigButtonGrid(items: ShotResult.allCases, label: \.label, selected: parsed.result, tint: .gray) {
                        parsed.result = $0
                    }
                    Text("Folge (optional)").font(.headline)
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
                    Button("Abbrechen") {
                        recognizer.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        guard let type = parsed.shotType, let result = parsed.result else { return }
                        recognizer.stop()
                        onSave(type, result, parsed.consequence)
                        dismiss()
                    }
                    .disabled(!parsed.isComplete)
                }
            }
        }
        .onDisappear { recognizer.stop() }
    }

    private func startListening() {
        errorMessage = nil
        Task {
            guard await recognizer.requestAuthorization() else {
                errorMessage = SpeechRecognizerError.notAuthorized.localizedDescription
                return
            }
            do {
                transcript = ""
                try recognizer.start { text in
                    transcript = text
                    parsed = ShotPhraseParser.parse(text)
                }
                isListening = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopListening() {
        recognizer.stop()
        isListening = false
    }
}
