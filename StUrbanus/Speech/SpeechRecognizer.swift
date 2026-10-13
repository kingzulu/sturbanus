import Foundation

enum SpeechRecognizerError: LocalizedError {
    case notAuthorized
    case unavailable
    case noAudioInput
    case audioSetupFailed(String)
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Mikrofon oder Spracherkennung nicht erlaubt. Bitte in den Einstellungen freigeben."
        case .unavailable: "Spracherkennung (Deutsch) ist auf diesem Gerät gerade nicht verfügbar."
        case .noAudioInput: "Kein Mikrofon-Eingang gefunden."
        case .audioSetupFailed(let detail): "Audio konnte nicht gestartet werden: \(detail)"
        case .recognitionFailed(let detail): "Spracherkennung fehlgeschlagen: \(detail)"
        }
    }
}

/// Abstraktion über die Spracherkennung, damit später z. B. ein HTTP-Recognizer
/// (Audio aufnehmen, an einen Server schicken, Text zurück) eingesteckt werden kann.
@MainActor
protocol SpeechRecognizer: AnyObject {
    /// Fragt Mikrofon- und Spracherkennungs-Berechtigung an.
    func requestAuthorization() async -> Bool

    /// Startet die Aufnahme. `onTranscript` wird mit dem jeweils aktuellen Text aufgerufen
    /// (bei Streaming-Erkennern mehrfach, bei Batch-Erkennern einmal nach `stop()`).
    /// `onError` meldet Fehler, die erst während der Erkennung auftreten.
    func start(onTranscript: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (Error) -> Void) async throws

    /// Beendet die Aufnahme.
    func stop()
}
