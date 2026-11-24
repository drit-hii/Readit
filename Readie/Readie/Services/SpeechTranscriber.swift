// SpeechTranscriber.swift
// Live speech-to-text using Apple's Speech framework (on-device when supported).
import Foundation
import Speech
import AVFoundation
import Observation

@Observable @MainActor
final class SpeechTranscriber {
    enum Status { case idle, requesting, recording, denied, unavailable }

    var status: Status = .idle
    var transcript = ""
    private(set) var startedAt: Date?

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        guard let recognizer, recognizer.isAvailable else { status = .unavailable; return }
        status = .requesting

        let speechOK = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard speechOK, micOK else { status = .denied; return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request = req

            let input = engine.inputNode
            guard input.outputFormat(forBus: 0).sampleRate > 0 else { status = .unavailable; return }
            input.removeTap(onBus: 0)
            Self.installTap(on: input, request: req)
            engine.prepare()
            try engine.start()

            transcript = ""
            task = Self.startTask(recognizer: recognizer, request: req) { [weak self] text in
                Task { @MainActor in
                    if let text { self?.transcript = text }
                }
            }
            startedAt = .now
            status = .recording
        } catch {
            status = .unavailable
        }
    }

    /// Stops recording and returns the final text and how long it ran.
    func stop() -> (text: String, duration: TimeInterval) {
        let duration = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        startedAt = nil
        status = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (transcript, duration)
    }

    // These are nonisolated so the audio / recognition callbacks don't run main-actor isolated code
    // on background threads.
    private nonisolated static func installTap(on input: AVAudioInputNode,
                                               request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func startTask(recognizer: SFSpeechRecognizer,
                                              request: SFSpeechAudioBufferRecognitionRequest,
                                              handler: @escaping @Sendable (String?) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, _ in
            handler(result?.bestTranscription.formattedString)
        }
    }
}
