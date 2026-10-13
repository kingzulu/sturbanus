import AVFoundation
import Foundation
import os
import Speech

/// Spracherkennung über Apples Speech-Framework, Deutsch, bevorzugt komplett auf dem Gerät.
/// Fehlt das Sprachmodell auf dem Gerät (z. B. im Simulator), wird einmal auf Apples
/// Online-Erkennung ausgewichen.
@MainActor
final class AppleSpeechRecognizer: SpeechRecognizer {
    private static let log = Logger(subsystem: "com.zuluindustries.StUrbanus", category: "Speech")

    /// AVAudioSession-Aufrufe blockieren per IPC; deshalb seriell abseits des Main Threads.
    private nonisolated static let audioQueue = DispatchQueue(label: "com.zuluindustries.StUrbanus.audiosession")

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var receivedText = false
    var onAudioLevel: (@MainActor (Float) -> Void)?

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start(onTranscript: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (Error) -> Void) async throws {
        stop()

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.unavailable
        }

        try await Self.activateAudioSession()
        let route = AVAudioSession.sharedInstance().currentRoute.inputs.map(\.portName).joined(separator: ", ")
        Self.log.info("Audio session active, input: \(route, privacy: .public), on-device supported: \(recognizer.supportsOnDeviceRecognition)")
        try beginRecognition(with: recognizer,
                             onDevice: recognizer.supportsOnDeviceRecognition,
                             onTranscript: onTranscript,
                             onError: onError)
    }

    func stop() {
        let wasRunning = request != nil
        teardownRecognition()
        if wasRunning {
            Self.audioQueue.async {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    // MARK: - Intern

    private nonisolated static func activateAudioSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            audioQueue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    // playAndRecord + allowBluetoothHFP: Bluetooth-Headsets (z. B. AirPods) als Mikrofon nutzen.
                    try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: SpeechRecognizerError.audioSetupFailed(error.localizedDescription))
                }
            }
        }
    }

    private func beginRecognition(with recognizer: SFSpeechRecognizer,
                                  onDevice: Bool,
                                  onTranscript: @escaping @MainActor (String) -> Void,
                                  onError: @escaping @MainActor (Error) -> Void) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = onDevice
        // Golf-Begriffe als Hinweis für die Erkennung.
        request.contextualStrings = [
            "Drive", "Hybrid", "Holz", "Eisen", "Wedge", "Pitch", "Chip", "Bunker", "Putt",
            "links", "rechts", "zu kurz", "zu lang", "Aus", "Wasser", "Rough", "Strafschlag",
        ]
        self.request = request
        receivedText = false

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        Self.log.info("Starting recognition (onDevice: \(onDevice)), format: \(format.sampleRate) Hz, \(format.channelCount) ch")
        guard format.sampleRate > 0, format.channelCount > 0 else {
            teardownRecognition()
            throw SpeechRecognizerError.noAudioInput
        }
        let levelHandler = onAudioLevel
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            guard let levelHandler, let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
            let rms = (sum / Float(buffer.frameLength)).squareRoot()
            // Grob auf 0…1 abbilden (Sprache liegt etwa bei -40…-10 dBFS).
            let level = max(0, min(1, (20 * log10(max(rms, 0.000_01)) + 50) / 40))
            Task { @MainActor in levelHandler(level) }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            teardownRecognition()
            throw SpeechRecognizerError.audioSetupFailed(error.localizedDescription)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let failure = (result == nil) ? error : nil
            Task { @MainActor [weak self] in
                // Rückmeldungen einer bereits beendeten Erkennung ignorieren.
                guard let self, self.request === request else { return }
                if let text, !text.isEmpty {
                    if !self.receivedText { Self.log.info("First transcript received") }
                    self.receivedText = true
                    onTranscript(text)
                }
                guard let failure else { return }
                Self.log.error("Recognition failed (onDevice: \(onDevice)): \(failure.localizedDescription, privacy: .public)")
                if onDevice && !self.receivedText {
                    // Sprachmodell auf dem Gerät fehlt oder ist defekt: einmal online versuchen.
                    self.teardownRecognition()
                    do {
                        try self.beginRecognition(with: recognizer, onDevice: false,
                                                  onTranscript: onTranscript, onError: onError)
                    } catch {
                        onError(error)
                    }
                } else {
                    onError(SpeechRecognizerError.recognitionFailed(failure.localizedDescription))
                }
            }
        }
    }

    private func teardownRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }
}
