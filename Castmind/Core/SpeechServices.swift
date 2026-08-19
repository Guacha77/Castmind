import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognizerService: ObservableObject {
    @Published private(set) var isListening = false
    @Published var transcript = ""
    @Published private(set) var audioLevel: Double = 0

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastSpeechUpdate = Date()
    private var lastTranscript = ""
    private var onSilence: ((String) -> Void)?
    private var tapInstalled = false

    func start(locale: String, autoStopAfter silenceSeconds: Double? = nil, onSilence: ((String) -> Void)? = nil) async throws {
        stopSilently()
        let authorized = await requestPermissions()
        guard authorized else { throw SpeechError.permissionDenied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else {
            throw SpeechError.unavailable
        }
        guard recognizer.supportsOnDeviceRecognition else { throw SpeechError.onDeviceUnavailable }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        transcript = ""
        lastTranscript = ""
        audioLevel = 0
        self.onSilence = onSilence
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            let level = Self.normalizedLevel(buffer)
            Task { @MainActor in self?.audioLevel = level }
        }
        tapInstalled = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let newText = result.bestTranscription.formattedString
                    if newText != self.transcript {
                        self.transcript = newText
                        self.lastSpeechUpdate = Date()
                    }
                }
                if error != nil { self.stopSilently() }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        lastSpeechUpdate = Date()

        if let silenceSeconds {
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isListening else { return }
                    let hasText = !self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let idle = Date().timeIntervalSince(self.lastSpeechUpdate)
                    if hasText, idle >= silenceSeconds {
                        let text = self.stop()
                        self.onSilence?(text)
                        self.onSilence = nil
                    }
                }
            }
        }
    }

    @discardableResult
    func stop() -> String {
        guard isListening else { return transcript.trimmingCharacters(in: .whitespacesAndNewlines) }
        let captured = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopSilently()
        return captured
    }

    private func stopSilently() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        // Cancel instead of finish so Speech.framework releases its decoder immediately before
        // the local LLM starts its memory-heavy prefill. We already captured the latest partial
        // transcript above, so waiting for another final callback is unnecessary.
        task?.cancel()
        request = nil
        task = nil
        audioEngine.reset()
        isListening = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    nonisolated private static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<frames {
            let value = channel[index]
            sum += value * value
        }
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(max(rms, 0.000_001))
        return min(1, max(0, Double((db + 50) / 50)))
    }

    enum SpeechError: LocalizedError {
        case permissionDenied, unavailable, onDeviceUnavailable
        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Necesito permisos de micrófono y reconocimiento de voz."
            case .unavailable: return "El reconocimiento de voz no está disponible ahora mismo."
            case .onDeviceUnavailable: return "Este idioma no tiene reconocimiento local disponible en el dispositivo."
            }
        }
    }
}

@MainActor
final class SpeechSynthesizerService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published private(set) var speechPulse: Double = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var streamingBuffer = ""
    private var pulseTimer: Timer?
    private var queuedUtterances = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var spanishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("es") }
            .sorted { ($0.name, $0.language) < ($1.name, $1.language) }
    }

    func beginStreaming() {
        streamingBuffer = ""
        stop(clearBuffer: false)
    }

    func consumeStreamingText(_ delta: String, settings: VoiceSettings, locale: String) {
        streamingBuffer += delta
        while let boundary = sentenceBoundary(in: streamingBuffer) {
            let sentence = String(streamingBuffer[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            streamingBuffer = String(streamingBuffer[boundary...])
            if sentence.count >= 2 { enqueue(sentence, settings: settings, locale: locale) }
        }
    }

    func finishStreaming(settings: VoiceSettings, locale: String) {
        let tail = streamingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        streamingBuffer = ""
        if !tail.isEmpty { enqueue(tail, settings: settings, locale: locale) }
    }

    func speak(_ text: String, settings: VoiceSettings, locale: String) {
        stop()
        enqueue(text, settings: settings, locale: locale)
    }

    /// Queue speech without interrupting an utterance already playing. Used by rooms so every
    /// character can speak its own turn in sequence instead of the next turn cutting the previous one.
    func enqueueSpeech(_ text: String, settings: VoiceSettings, locale: String) {
        enqueue(text, settings: settings, locale: locale)
    }

    func preview(settings: VoiceSettings, locale: String, characterName: String) {
        speak("Hola. Soy \(characterName). Esta es mi voz en Castmind.", settings: settings, locale: locale)
    }

    func stop(clearBuffer: Bool = true) {
        synthesizer.stopSpeaking(at: .immediate)
        queuedUtterances = 0
        if clearBuffer { streamingBuffer = "" }
        isSpeaking = false
        speechPulse = 0
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    private func enqueue(_ text: String, settings: VoiceSettings, locale: String) {
        guard !text.isEmpty else { return }
        activatePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        if let identifier = settings.voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: locale)
        }
        utterance.rate = Float(settings.rate.clamped(to: 0.30...0.65))
        utterance.pitchMultiplier = Float(settings.pitch.clamped(to: 0.6...1.4))
        utterance.volume = Float(settings.volume.clamped(to: 0...1))
        utterance.preUtteranceDelay = 0.01
        utterance.postUtteranceDelay = 0.01
        queuedUtterances += 1
        synthesizer.speak(utterance)
    }

    private func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func sentenceBoundary(in text: String) -> String.Index? {
        guard text.count >= 14 else { return nil }
        for index in text.indices {
            let c = text[index]
            if c == "." || c == "!" || c == "?" || c == "\n" {
                let next = text.index(after: index)
                if text.distance(from: text.startIndex, to: next) >= 14 { return next }
            }
        }
        if text.count > 150 {
            let rough = text.index(text.startIndex, offsetBy: 120)
            if let space = text[rough...].firstIndex(of: " ") { return text.index(after: space) }
        }
        return nil
    }

    private func startPulse() {
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSpeaking else { return }
                let t = Date().timeIntervalSinceReferenceDate
                self.speechPulse = 0.48 + sin(t * 11.0) * 0.22 + sin(t * 19.0) * 0.12
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
        startPulse()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        queuedUtterances = max(0, queuedUtterances - 1)
        if queuedUtterances == 0 && !synthesizer.isSpeaking {
            isSpeaking = false
            speechPulse = 0
            pulseTimer?.invalidate()
            pulseTimer = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        queuedUtterances = 0
        isSpeaking = false
        speechPulse = 0
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}
