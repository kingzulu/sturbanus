import Foundation

enum SpeechRecognizerError: LocalizedError {
    case notAuthorized
    case unavailable
    case audioSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Mikrofon oder Spracherkennung nicht erlaubt. Bitte in den Einstellungen freigeben."
        case .unavailable: "Spracherkennung (Deutsch) ist auf diesem Gerät gerade nicht verfügbar."
        case .audioSetupFailed(let detail): "Audio konnte nicht gestartet werden: \(detail)"
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
    func start(onTranscript: @escaping @MainActor (String) -> Void) throws

    /// Beendet die Aufnahme.
    func stop()
}
