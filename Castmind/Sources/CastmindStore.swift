import AVFoundation
import Foundation
import Network
import Speech
import SwiftUI

@MainActor
final class CastmindStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft = ""
    @Published var profile = CastmindProfile()
    @Published var settings = GenerationSettings()
    @Published var modelStatus = ModelStatus()
    @Published var isListening = false
    @Published var lastError: String?

    private let persistence = PersistenceController()
    private let speech = SpeechInputController()
    private let voice = VoiceOutputController()
    private let bridge = StreamBridgeController()
    private lazy var ai = LocalAIEngine { [weak self] status in
        Task { @MainActor in self?.modelStatus = status }
    }
    private var generationTask: Task<Void, Never>?

    func bootstrap() async {
        profile = persistence.loadProfile()
        settings = persistence.loadSettings()
        messages = persistence.loadMessages()
        modelStatus.lifecycle = ai.cachedModelDirectoryExists ? .downloaded : .notDownloaded
        configureBridge()
    }

    func saveProfile() {
        persistence.saveProfile(profile)
        configureBridge()
    }

    func saveSettings() {
        persistence.saveSettings(settings)
    }

    func saveMessages() {
        persistence.saveMessages(messages)
    }

    func sendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, generationTask == nil else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, text: trimmed))
        messages.append(ChatMessage(role: .assistant, text: ""))
        saveMessages()

        generationTask = Task { [weak self] in
            guard let self else { return }
            await self.generateReply(for: trimmed)
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        modelStatus.lifecycle = ai.isReady ? .ready : modelStatus.lifecycle
    }

    func downloadModel() {
        guard generationTask == nil else { return }
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.ai.load(profile: self.profile, settings: self.settings)
                self.modelStatus.lifecycle = .ready
            } catch {
                self.lastError = error.localizedDescription
                self.modelStatus = ModelStatus(lifecycle: .failed, detail: error.localizedDescription)
            }
            self.generationTask = nil
        }
    }

    func unloadModel() {
        ai.unload()
        modelStatus.lifecycle = ai.cachedModelDirectoryExists ? .downloaded : .notDownloaded
    }

    func deleteDownloadedModel() {
        unloadModel()
        do {
            try ai.deleteCachedModel()
            modelStatus = ModelStatus(lifecycle: .notDownloaded)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleDictation() {
        if isListening {
            speech.stop()
            isListening = false
            return
        }

        Task {
            do {
                isListening = true
                try await speech.start { [weak self] text in
                    Task { @MainActor in self?.draft = text }
                }
            } catch {
                isListening = false
                lastError = error.localizedDescription
            }
        }
    }

    func speak(_ text: String) {
        voice.speak(text, voiceIdentifier: profile.voiceIdentifier)
    }

    func stopSpeaking() {
        voice.stop()
    }

    func clearChat() {
        cancelGeneration()
        messages.removeAll()
        saveMessages()
    }

    var exportText: String {
        messages.map { message in
            let role = message.role.rawValue.uppercased()
            return "[\(role)] \(message.text)"
        }.joined(separator: "\n\n")
    }

    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(Locale.current.language.languageCode?.identifier ?? "en") || $0.language.hasPrefix("es") || $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    private func generateReply(for prompt: String) async {
        do {
            if !ai.isReady {
                try await ai.load(profile: profile, settings: settings)
            }

            modelStatus.lifecycle = .generating
            guard let assistantIndex = messages.indices.last else { return }
            var complete = ""

            let contextPrompt = buildPrompt(userPrompt: prompt)
            for try await chunk in ai.stream(prompt: contextPrompt) {
                if Task.isCancelled { break }
                complete += chunk
                messages[assistantIndex].text = complete
            }

            if Task.isCancelled {
                messages[assistantIndex].text += "\n\n[Generacion cancelada]"
            } else if settings.speakReplies {
                speak(complete)
            }

            modelStatus.lifecycle = ai.isReady ? .ready : .downloaded
            bridge.publish(exportText)
            saveMessages()
        } catch {
            if let assistantIndex = messages.indices.last {
                messages[assistantIndex].text = "No he podido generar la respuesta: \(error.localizedDescription)"
            }
            lastError = error.localizedDescription
            modelStatus = ModelStatus(lifecycle: .failed, detail: error.localizedDescription)
        }

        generationTask = nil
    }

    private func buildPrompt(userPrompt: String) -> String {
        """
        Eres \(profile.name).
        Personalidad: \(profile.personality)
        Estado emocional actual: \(profile.emotionalState)
        Memoria persistente: \(profile.memory)

        Responde de forma util, natural y coherente con el personaje.

        Usuario: \(userPrompt)
        """
    }

    private func configureBridge() {
        if profile.streamBridgeEnabled {
            bridge.start(port: UInt16(profile.streamBridgePort), initialText: exportText)
        } else {
            bridge.stop()
        }
    }
}
