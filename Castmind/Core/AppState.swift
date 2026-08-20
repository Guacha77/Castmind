import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    enum RootTab: Hashable { case characters, chat, rooms, settings }

    @Published var library: CastmindLibrary
    @Published var settings: AppSettings
    @Published var composerText = ""
    @Published var selectedTab: RootTab = .characters
    @Published var errorMessage: String?
    @Published var shareURL: URL?
    @Published var insightLoadingIDs: Set<UUID> = []
    @Published var isBootstrapped = false
    @Published var roomComposerText = ""

    let ai = AIEngine()
    let recognizer = SpeechRecognizerService()
    let speaker = SpeechSynthesizerService()
    let bridge = StreamBridgeService()
    let bridgeDiscovery = BridgeDiscoveryService()
    let performance = PerformanceManager()

    let store = PersistenceStore()
    private var generationTask: Task<Void, Never>?
    private var roomGenerationTask: Task<Void, Never>?
    private var activeGenerationContext: (conversationID: UUID, responseID: UUID)?

    private enum VoiceDestination: Equatable {
        case chat
        case room(UUID)
    }
    private var voiceDestination: VoiceDestination?

    init() {
        library = store.loadLibrary()
        settings = store.loadSettings()
        repairLibraryIfNeeded()
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // iOS may terminate a memory-heavy local-LLM app without warning. Release transient
                // generation state immediately; if idle, unload the model and transparently reload on demand.
                self.speaker.stop()
                if self.generationTask != nil { self.cancelCurrentResponse() }
                if self.roomGenerationTask != nil { self.cancelRoomGeneration() }
                await self.ai.unload()
            }
        }
    }

    // MARK: - Active objects

    var activeCharacter: CharacterProfile {
        library.characters.first(where: { $0.id == library.activeCharacterID }) ?? library.characters[0]
    }

    var activeConversation: ConversationThread {
        if let found = library.conversations.first(where: { $0.id == library.activeConversationID }) { return found }
        return library.conversations.first(where: { $0.characterID == activeCharacter.id }) ?? ConversationThread.fresh(for: activeCharacter)
    }

    var activeMessages: [ChatMessage] { activeConversation.messages }
    var activeMemories: [MemoryItem] { library.memories.filter { $0.characterID == activeCharacter.id } }
    var activeModelChoice: LocalModelChoice { settings.modelChoice }

    var selectedScenario: WorldScenario {
        settings.scenarios.first(where: { $0.id == settings.selectedScenarioID }) ?? settings.scenarios.first ?? WorldScenario.defaults[0]
    }

    var modelStatusText: String {
        switch ai.phase {
        case .idle: return "Sin cargar"
        case .downloading(let p): return "Descargando · \(Int(p * 100))%"
        case .loading: return "Preparando"
        case .warming: return "Calentando"
        case .ready: return "Local · listo"
        case .generating: return "Generando"
        case .failed: return "Error"
        }
    }

    var modelProgress: Double? {
        if case .downloading(let p) = ai.phase { return p }
        return nil
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        library.stats.launches += 1
        MemoryEngine.maintenance(&library.memories, enabled: true)
        persistLibrary()

        if settings.streamBridge.enabled && settings.streamBridge.autoDiscover {
            bridgeDiscovery.start()
        }

        guard settings.hasCompletedOnboarding, settings.autoLoadModel else { return }
        await preloadModel()
        if ai.isReady, settings.benchmark == nil {
            Task { await runBenchmarkIfNeeded() }
        }
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        persistSettings()
    }

    func preloadModel() async {
        do {
            try await ai.ensureReady(model: activeModelChoice, warmup: settings.warmupModel)
            settings.lastModelID = activeModelChoice.modelID
            persistSettings()
        } catch {
            errorMessage = "No pude cargar el modelo: \(error.localizedDescription)"
        }
    }

    func switchGlobalModel(to choice: LocalModelChoice) async {
        guard settings.modelChoice != choice else { return }
        settings.modelChoice = choice
        persistSettings()
        do {
            try await ai.ensureReady(model: activeModelChoice, warmup: settings.warmupModel)
            settings.lastModelID = activeModelChoice.modelID
            persistSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unloadModel() async { await ai.unload() }

    func deleteModel(_ choice: LocalModelChoice) async {
        do { try await ai.deleteCachedModel(choice) }
        catch { errorMessage = "No se pudo borrar el modelo: \(error.localizedDescription)" }
    }

    func runBenchmarkIfNeeded(force: Bool = false) async {
        if settings.benchmark != nil && !force { return }
        guard !ai.isGenerating else { return }
        do {
            settings.benchmark = try await ai.benchmark(model: activeModelChoice, warmup: settings.warmupModel)
            persistSettings()
        } catch {
            if force { errorMessage = "Benchmark: \(error.localizedDescription)" }
        }
    }

    // MARK: - Character library

    func selectCharacter(_ id: UUID, openChat: Bool = true) {
        guard library.characters.contains(where: { $0.id == id }) else { return }
        library.activeCharacterID = id
        if let latest = library.conversations
            .filter({ $0.characterID == id })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            library.activeConversationID = latest.id
        } else if let character = library.characters.first(where: { $0.id == id }) {
            let thread = ConversationThread.fresh(for: character)
            library.conversations.append(thread)
            library.activeConversationID = thread.id
        }
        persistLibrary()
        if openChat { selectedTab = .chat }
        if settings.autoLoadModel, ai.activeModelID != activeModelChoice.modelID {
            Task { await preloadModel() }
        }
    }

    @discardableResult
    func createCharacter(preset: CharacterPreset? = nil) -> UUID {
        var character = CharacterProfile.blank()
        if let preset {
            character.subtitle = preset.title
            character.behaviorPrompt = preset.prompt
        }
        library.characters.append(character)
        let thread = ConversationThread.fresh(for: character)
        library.conversations.append(thread)
        library.activeCharacterID = character.id
        library.activeConversationID = thread.id
        persistLibrary()
        return character.id
    }

    @discardableResult
    func duplicateCharacter(_ id: UUID) -> UUID? {
        guard var character = library.characters.first(where: { $0.id == id }) else { return nil }
        character.id = UUID()
        character.name += " copia"
        character.createdAt = Date()
        if let data = store.avatarData(filename: character.avatarFilename), let filename = try? store.saveAvatar(data, for: character.id) {
            character.avatarFilename = filename
        } else {
            character.avatarFilename = nil
        }
        library.characters.append(character)
        for memory in library.memories.filter({ $0.characterID == id }) {
            var copy = memory
            copy.id = UUID()
            copy.characterID = character.id
            library.memories.append(copy)
        }
        let thread = ConversationThread.fresh(for: character)
        library.conversations.append(thread)
        persistLibrary()
        return character.id
    }

    func updateCharacter(_ updated: CharacterProfile) {
        guard let index = library.characters.firstIndex(where: { $0.id == updated.id }) else { return }
        library.characters[index] = updated
        persistLibrary()
    }

    func deleteCharacter(_ id: UUID) {
        guard library.characters.count > 1,
              let character = library.characters.first(where: { $0.id == id }) else { return }
        store.removeAvatar(filename: character.avatarFilename)
        library.characters.removeAll { $0.id == id }
        library.memories.removeAll { $0.characterID == id }
        library.conversations.removeAll { $0.characterID == id }
        library.rooms = library.rooms.compactMap { room in
            var room = room
            room.participantIDs.removeAll { $0 == id }
            return room.participantIDs.isEmpty ? nil : room
        }
        if library.activeCharacterID == id, let next = library.characters.first {
            library.activeCharacterID = next.id
            ensureConversation(for: next.id)
        }
        persistLibrary()
    }

    func setAvatar(data: Data, for characterID: UUID) {
        guard let index = library.characters.firstIndex(where: { $0.id == characterID }) else { return }
        do {
            if let old = library.characters[index].avatarFilename { store.removeAvatar(filename: old) }
            library.characters[index].avatarFilename = try store.saveAvatar(data, for: characterID)
            persistLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyPreset(_ preset: CharacterPreset, to id: UUID) {
        guard let index = library.characters.firstIndex(where: { $0.id == id }) else { return }
        library.characters[index].subtitle = preset.title
        library.characters[index].behaviorPrompt = preset.prompt
        persistLibrary()
    }

    // MARK: - Conversations

    func newConversation(for characterID: UUID? = nil) {
        let id = characterID ?? library.activeCharacterID
        guard let character = library.characters.first(where: { $0.id == id }) else { return }
        let thread = ConversationThread.fresh(for: character)
        library.conversations.append(thread)
        library.activeCharacterID = id
        library.activeConversationID = thread.id
        persistLibrary()
        selectedTab = .chat
    }

    func selectConversation(_ id: UUID) {
        guard let thread = library.conversations.first(where: { $0.id == id }) else { return }
        library.activeConversationID = id
        library.activeCharacterID = thread.characterID
        persistLibrary()
        selectedTab = .chat
    }

    func togglePinnedConversation(_ id: UUID) {
        guard let index = library.conversations.firstIndex(where: { $0.id == id }) else { return }
        library.conversations[index].isPinned.toggle()
        persistLibrary()
    }

    func deleteMessage(_ id: UUID) {
        guard let cIndex = activeConversationIndex else { return }
        library.conversations[cIndex].messages.removeAll { $0.id == id }
        library.conversations[cIndex].updatedAt = Date()
        persistLibrary()
    }

    func regenerateAssistantMessage(_ id: UUID) {
        guard generationTask == nil,
              let cIndex = activeConversationIndex,
              let mIndex = library.conversations[cIndex].messages.firstIndex(where: { $0.id == id }),
              library.conversations[cIndex].messages[mIndex].role == .assistant,
              let userIndex = library.conversations[cIndex].messages[..<mIndex].lastIndex(where: { $0.role == .user }) else { return }
        let text = library.conversations[cIndex].messages[userIndex].text
        // Remove the original user turn too; send() will append it exactly once.
        library.conversations[cIndex].messages.removeSubrange(userIndex...)
        persistLibrary()
        startSending(text)
    }

    func deleteConversation(_ id: UUID) {
        guard library.conversations.count > 1 else {
            newConversation()
            return
        }
        let deleted = library.conversations.first(where: { $0.id == id })
        library.conversations.removeAll { $0.id == id }
        if library.activeConversationID == id {
            if let replacement = library.conversations.first(where: { $0.characterID == deleted?.characterID }) ?? library.conversations.first {
                library.activeConversationID = replacement.id
                library.activeCharacterID = replacement.characterID
            }
        }
        persistLibrary()
    }

    func clearActiveConversation() async {
        guard let index = activeConversationIndex else { return }
        library.conversations[index] = ConversationThread.fresh(for: activeCharacter)
        library.activeConversationID = library.conversations[index].id
        persistLibrary()
        await ai.cancelGeneration()
    }

    // MARK: - Chat

    func sendComposer() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composerText = ""
        startSending(text)
    }

    func startSending(_ text: String) {
        guard generationTask == nil else { return }
        generationTask = Task { [weak self] in
            guard let self else { return }
            await self.send(text)
            self.generationTask = nil
        }
    }

    func cancelCurrentResponse() {
        generationTask?.cancel()
        generationTask = nil
        speaker.stop()
        Task { await ai.cancelGeneration() }
        if let context = activeGenerationContext,
           let index = library.conversations.firstIndex(where: { $0.id == context.conversationID }),
           let messageIndex = library.conversations[index].messages.firstIndex(where: { $0.id == context.responseID }) {
            library.conversations[index].messages[messageIndex].isStreaming = false
            let current = library.conversations[index].messages[messageIndex].text
            if current.isEmpty { library.conversations[index].messages.remove(at: messageIndex) }
            library.conversations[index].updatedAt = Date()
            persistLibrary()
        }
        activeGenerationContext = nil
    }

    private func send(_ rawText: String) async {
        var text = PromptBudgeter.safeUserInput(rawText)
        guard !text.isEmpty, !ai.isGenerating else { return }

        if settings.wakeWordsEnabled, let routed = routeWakeWord(in: text) {
            if routed.characterID != library.activeCharacterID { selectCharacter(routed.characterID, openChat: false) }
            text = routed.text
        }

        guard let threadIndex = activeConversationIndex else { return }
        let conversationID = library.conversations[threadIndex].id
        var character = activeCharacter
        speaker.stop()

        let userMessage = ChatMessage.user(text)
        library.conversations[threadIndex].messages.append(userMessage)
        library.conversations[threadIndex].updatedAt = Date()
        if library.conversations[threadIndex].title == "Nueva conversación" {
            library.conversations[threadIndex].title = smartTitle(text)
        }
        library.stats.totalUserMessages += 1
        library.stats.perCharacterMessages[character.id, default: 0] += 1

        if character.memory.enabled && character.memory.autoCapture {
            addAutoMemories(MemoryEngine.capture(from: text, characterID: character.id))
        }
        StateAnalyzer.apply(userText: text, to: &character)
        if let charIndex = library.characters.firstIndex(where: { $0.id == character.id }) {
            library.characters[charIndex] = character
        }
        persistLibrary()

        let relevant: [MemoryItem] = character.memory.enabled ? MemoryEngine.selectRelevant(
            from: library.memories.filter { $0.characterID == character.id },
            query: text,
            limit: character.memory.maxPromptMemories,
            allowDecay: character.memory.allowDecay
        ) : []
        touchMemories(relevant.map(\.id))

        let compiledBehavior = PromptBudgeter.compileBehavior(
            character.effectiveBehavior,
            query: text,
            model: settings.modelChoice
        )
        let baseGeneration = performance.adjusted(character.generation, mode: settings.performanceMode)
        let effectiveGeneration = PromptBudgeter.adjustedGeneration(baseGeneration, compiledBehavior: compiledBehavior)
        let prompt = makeSystemPrompt(
            character: character,
            compiledBehavior: compiledBehavior,
            relevantMemories: relevant
        )
        let history = directHistory(
            conversationID: conversationID,
            excluding: userMessage.id,
            limit: effectiveGeneration.recentContextMessages
        )
        let recentAssistantReplies = (library.conversations[threadIndex].messages)
            .filter { $0.role == .assistant && !$0.isStreaming && ResponseQualityGuard.canEnterContext($0.text) }
            .suffix(4)
            .map(\.text)

        let responseID = UUID()
        library.conversations[threadIndex].messages.append(.assistant("", characterID: character.id, streaming: true))
        library.conversations[threadIndex].messages[library.conversations[threadIndex].messages.count - 1].id = responseID
        activeGenerationContext = (conversationID, responseID)
        persistLibrary()

        do {
            // Do not stream unvalidated small-model output into the visible chat. DougDoug's setup
            // gets a complete model answer before presenting/speaking it; V3.3 follows that pattern
            // so repetition collapse never pollutes history or TTS.
            var rawDraft = ""
            let metrics = try await ai.streamReply(
                to: text,
                model: settings.modelChoice,
                generation: effectiveGeneration,
                systemPrompt: prompt,
                history: history,
                warmup: settings.warmupModel
            ) { chunk in rawDraft += chunk }

            guard let cIndex = library.conversations.firstIndex(where: { $0.id == conversationID }),
                  let mIndex = library.conversations[cIndex].messages.firstIndex(where: { $0.id == responseID }) else { return }

            var finalText = ReplySanitizer.direct(rawDraft, characterName: character.name)
            let firstAssessment = ResponseQualityGuard.assess(finalText, comparedTo: recentAssistantReplies, userText: text)

            if firstAssessment.shouldRepair {
                ai.releaseTransientMemory()
                var repairGeneration = effectiveGeneration
                repairGeneration.temperature = max(0.70, min(repairGeneration.temperature + 0.04, 0.78))
                repairGeneration.topP = min(0.82, max(0.78, repairGeneration.topP))
                repairGeneration.maxTokens = min(repairGeneration.maxTokens, 96)
                var repairedRaw = ""
                do {
                    _ = try await ai.streamReply(
                        to: text,
                        model: settings.modelChoice,
                        generation: repairGeneration,
                        systemPrompt: prompt + "\n\n" + ResponseQualityGuard.repairInstruction(characterName: character.name),
                        history: history,
                        warmup: false
                    ) { chunk in repairedRaw += chunk }
                    let repaired = ReplySanitizer.direct(repairedRaw, characterName: character.name)
                    finalText = ResponseQualityGuard.betterCandidate(
                        finalText,
                        repaired,
                        comparedTo: recentAssistantReplies,
                        userText: text
                    )
                } catch {
                    // The first draft remains available for scoring below.
                }
            }

            let finalAssessment = ResponseQualityGuard.assess(finalText, comparedTo: recentAssistantReplies, userText: text)
            if finalText.isEmpty || finalAssessment.shouldRepair {
                // Never commit an obvious token loop to future context. A coherent neutral turn is
                // much less damaging than teaching the next generation the broken pattern.
                finalText = "No tengo una respuesta clara para eso ahora mismo. Dímelo de otra forma."
            }

            library.conversations[cIndex].messages[mIndex].text = finalText
            library.conversations[cIndex].messages[mIndex].isStreaming = false
            library.conversations[cIndex].messages[mIndex].latencyMS = metrics.firstTokenMS
            library.conversations[cIndex].updatedAt = Date()

            if character.voice.autoSpeak {
                speaker.speak(finalText, settings: character.voice, locale: settings.speechLocale)
            }

            library.stats.totalAssistantMessages += 1
            library.stats.totalGeneratedCharacters += finalText.count
            library.stats.recordFirstToken(metrics.firstTokenMS)
            library.stats.perCharacterMessages[character.id, default: 0] += 1
            persistLibrary()
            activeGenerationContext = nil

            if settings.streamBridge.enabled {
                try? await bridge.sendReply(text: finalText, character: character, settings: settings.streamBridge, cue: cue(for: character))
            }
            haptic(.light)
        } catch is CancellationError {
            speaker.stop()
            activeGenerationContext = nil
        } catch {
            activeGenerationContext = nil
            speaker.stop()
            removeMessage(responseID)
            // If Metal/MLX entered a bad allocation state, discard the container rather than
            // carrying that state into every later turn. The next message reloads automatically.
            await ai.unload()
            errorMessage = "La IA local se ha reiniciado de forma segura: \(error.localizedDescription)"
        }
    }

    func loadInsight(for messageID: UUID) async {
        guard !insightLoadingIDs.contains(messageID),
              let cIndex = activeConversationIndex,
              let mIndex = library.conversations[cIndex].messages.firstIndex(where: { $0.id == messageID }),
              library.conversations[cIndex].messages[mIndex].role == .assistant else { return }
        if library.conversations[cIndex].messages[mIndex].insight != nil { return }
        insightLoadingIDs.insert(messageID)
        defer { insightLoadingIDs.remove(messageID) }

        // Capture the exact conversation/character before the await so switching chats while
        // the explanation is generated can never attach it to the wrong thread.
        let conversationID = library.conversations[cIndex].id
        let characterID = library.conversations[cIndex].characterID
        guard let character = library.characters.first(where: { $0.id == characterID }) else { return }
        let reply = library.conversations[cIndex].messages[mIndex].text
        let precedingUser = library.conversations[cIndex].messages[..<mIndex].last(where: { $0.role == .user })?.text ?? ""
        let memories = library.memories.filter { $0.characterID == characterID }
        let relevant = MemoryEngine.selectRelevant(from: memories, query: precedingUser, limit: 5, allowDecay: character.memory.allowDecay)
        do {
            let insight = try await ai.explainReply(
                userText: precedingUser,
                reply: reply,
                character: character,
                memories: relevant,
                model: settings.modelChoice,
                warmup: settings.warmupModel
            )
            if let targetC = library.conversations.firstIndex(where: { $0.id == conversationID }),
               let targetM = library.conversations[targetC].messages.firstIndex(where: { $0.id == messageID }) {
                library.conversations[targetC].messages[targetM].insight = insight
                persistLibrary()
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "No pude crear la explicación: \(error.localizedDescription)"
        }
    }

    // MARK: - Voice

    var isChatListening: Bool {
        recognizer.isListening && voiceDestination == .chat
    }

    func isRoomListening(_ roomID: UUID) -> Bool {
        recognizer.isListening && voiceDestination == .room(roomID)
    }

    func toggleMicrophone() async {
        await toggleVoice(destination: .chat)
    }

    func toggleRoomMicrophone(roomID: UUID) async {
        await toggleVoice(destination: .room(roomID))
    }

    private func toggleVoice(destination: VoiceDestination) async {
        if recognizer.isListening {
            let target = voiceDestination ?? destination
            let captured = recognizer.stop()
            voiceDestination = nil
            await settleSpeechResources()
            routeVoice(captured, to: target)
            return
        }

        if generationTask != nil { cancelCurrentResponse() }
        if roomGenerationTask != nil { cancelRoomGeneration() }
        speaker.stop()
        voiceDestination = destination

        do {
            switch settings.voiceMode {
            case .pushToTalk:
                try await recognizer.start(locale: settings.speechLocale)
            case .handsFree:
                try await recognizer.start(locale: settings.speechLocale, autoStopAfter: 1.05) { [weak self] text in
                    Task { @MainActor in
                        guard let self else { return }
                        let target = self.voiceDestination ?? destination
                        self.voiceDestination = nil
                        await self.settleSpeechResources()
                        self.routeVoice(text, to: target)
                    }
                }
            }
            haptic(.medium)
        } catch {
            voiceDestination = nil
            errorMessage = error.localizedDescription
        }
    }

    private func settleSpeechResources() async {
        // Speech.framework and AVAudioEngine can briefly retain decoder/audio buffers after stop().
        // Clear MLX's recyclable pool and give iOS a slightly longer drain window before prefill.
        ai.releaseTransientMemory()
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    private func routeVoice(_ raw: String, to destination: VoiceDestination) {
        let text = PromptBudgeter.safeUserInput(raw)
        guard !text.isEmpty else { return }
        switch destination {
        case .chat:
            startSending(text)
        case .room(let roomID):
            sendToRoom(text, roomID: roomID)
        }
    }

    private func routeWakeWord(in text: String) -> (characterID: UUID, text: String)? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for character in library.characters {
            let candidates = [character.wakeWord, character.name].filter { !$0.isEmpty }
            for candidate in candidates {
                if normalized.lowercased().hasPrefix(candidate.lowercased()) {
                    var remainder = String(normalized.dropFirst(candidate.count))
                    remainder = remainder.trimmingCharacters(in: CharacterSet(charactersIn: " ,.:;!?-\n\t"))
                    return (character.id, remainder.isEmpty ? normalized : remainder)
                }
            }
        }
        return nil
    }

    // MARK: - Memories

    func addMemory(_ text: String, characterID: UUID? = nil, category: MemoryCategory = .event, pinned: Bool = false) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let ownerID = characterID ?? activeCharacter.id
        let item = MemoryItem(characterID: ownerID, text: clean, category: category, importance: pinned ? 1 : 0.72, isPinned: pinned, source: "manual")
        library.memories.insert(item, at: 0)
        persistLibrary()
    }

    func updateMemory(_ memory: MemoryItem) {
        guard let index = library.memories.firstIndex(where: { $0.id == memory.id }) else { return }
        library.memories[index] = memory
        persistLibrary()
    }

    func deleteMemory(_ id: UUID) {
        library.memories.removeAll { $0.id == id }
        persistLibrary()
    }

    func clearMemories(for characterID: UUID? = nil) {
        let id = characterID ?? activeCharacter.id
        library.memories.removeAll { $0.characterID == id }
        persistLibrary()
    }

    private func addAutoMemories(_ candidates: [MemoryItem]) {
        for item in candidates {
            let duplicate = library.memories.contains {
                $0.characterID == item.characterID && $0.text.caseInsensitiveCompare(item.text) == .orderedSame
            }
            if !duplicate { library.memories.insert(item, at: 0) }
        }
    }

    private func touchMemories(_ ids: [UUID]) {
        let set = Set(ids)
        for index in library.memories.indices where set.contains(library.memories[index].id) {
            library.memories[index].lastAccessedAt = Date()
        }
    }

    // MARK: - Rooms

    @discardableResult
    func createRoom(title: String = "Nueva sala", participants: [UUID]? = nil) -> UUID {
        let ids = participants ?? Array(library.characters.prefix(2).map(\.id))
        let room = CharacterRoom(title: title, participantIDs: ids)
        library.rooms.append(room)
        persistLibrary()
        return room.id
    }

    func updateRoom(_ room: CharacterRoom) {
        guard let index = library.rooms.firstIndex(where: { $0.id == room.id }) else { return }
        library.rooms[index] = room
        persistLibrary()
    }

    func deleteRoom(_ id: UUID) {
        library.rooms.removeAll { $0.id == id }
        persistLibrary()
    }

    func sendToRoom(_ text: String, roomID: UUID) {
        let safeText = PromptBudgeter.safeUserInput(text)
        guard !safeText.isEmpty, roomGenerationTask == nil else { return }
        roomGenerationTask = Task { [weak self] in
            guard let self else { return }
            await self.runRoomRound(text: safeText, roomID: roomID)
            self.roomGenerationTask = nil
        }
    }

    func cancelRoomGeneration() {
        roomGenerationTask?.cancel()
        roomGenerationTask = nil
        speaker.stop()
        Task { await ai.cancelGeneration() }
    }

    private func runRoomRound(text: String, roomID: UUID) async {
        guard let roomIndex = library.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        library.rooms[roomIndex].messages.append(RoomMessage(characterID: nil, text: text))
        library.rooms[roomIndex].messages = Array(library.rooms[roomIndex].messages.suffix(80))
        persistLibrary()

        let participantIDs = library.rooms[roomIndex].participantIDs.prefix(4)
        let participants = participantIDs.compactMap { id in library.characters.first(where: { $0.id == id }) }
        guard !participants.isEmpty else { return }

        // Each character gets its own perspective of the shared conversation, matching DougDoug's
        // multi-agent design: its own previous lines are assistant messages; everybody else's lines
        // are user messages tagged with the speaker name. One character is generated at a time.
        for character in participants {
            if Task.isCancelled { break }
            guard let currentRoomIndex = library.rooms.firstIndex(where: { $0.id == roomID }) else { break }

            let memories: [MemoryItem] = character.memory.enabled ? MemoryEngine.selectRelevant(
                from: library.memories.filter { $0.characterID == character.id },
                query: text,
                limit: min(3, character.memory.maxPromptMemories),
                allowDecay: character.memory.allowDecay
            ) : []
            let memoryBlock = memories.map { "- \(PromptBudgeter.safeMemory($0.text))" }.joined(separator: "\n")
            let compiledBehavior = PromptBudgeter.compileBehavior(
                character.effectiveBehavior,
                query: text,
                model: settings.modelChoice
            )
            let otherNames = participants.filter { $0.id != character.id }.map(\.name)
            let system = """
            Te llamas \(character.name).

            ASÍ ERES
            \(compiledBehavior.text)

            RECUERDOS ÚTILES
            \(memoryBlock.isEmpty ? "Ninguno relevante ahora." : memoryBlock)

            Estás conversando con el usuario y con \(otherNames.joined(separator: ", ")). Los mensajes ajenos llevan el nombre de quien habló. Responde únicamente con lo que diría \(character.name), sin escribir las intervenciones de nadie más. Mantén la forma de ser descrita arriba con naturalidad. Normalmente responde en 1 a 4 frases completas y concretas.
            """

            let history = roomHistory(
                roomID: roomID,
                for: character,
                participants: participants,
                limit: 8
            )
            let recentRoomReplies = library.rooms[currentRoomIndex].messages
                .compactMap { message -> String? in
                    guard message.characterID != nil, ResponseQualityGuard.canEnterContext(message.text) else { return nil }
                    return message.text
                }
                .suffix(5)

            var roomGeneration = performance.adjusted(character.generation, mode: settings.performanceMode)
            roomGeneration = PromptBudgeter.adjustedGeneration(roomGeneration, compiledBehavior: compiledBehavior)
            roomGeneration.temperature = max(0.68, min(roomGeneration.temperature, 0.78))
            roomGeneration.topP = max(0.78, min(roomGeneration.topP, 0.84))
            roomGeneration.maxTokens = min(roomGeneration.maxTokens, 96)
            roomGeneration.recentContextMessages = min(roomGeneration.recentContextMessages, 6)

            do {
                var raw = ""
                _ = try await ai.streamReply(
                    to: "Tu turno. Responde de forma natural a lo último que se ha dicho. 1 a 4 frases.",
                    model: settings.modelChoice,
                    generation: roomGeneration,
                    systemPrompt: system,
                    history: history,
                    warmup: settings.warmupModel
                ) { chunk in raw += chunk }

                var clean = ReplySanitizer.room(raw, currentName: character.name, participantNames: participants.map(\.name))
                let firstAssessment = ResponseQualityGuard.assess(clean, comparedTo: Array(recentRoomReplies), userText: text)

                if firstAssessment.shouldRepair {
                    ai.releaseTransientMemory()
                    var repair = roomGeneration
                    repair.temperature = max(0.72, min(repair.temperature + 0.04, 0.80))
                    repair.topP = max(0.78, min(repair.topP, 0.82))
                    repair.maxTokens = min(repair.maxTokens, 84)
                    var repairedRaw = ""
                    _ = try await ai.streamReply(
                        to: "Tu turno. Da una respuesta nueva y concreta a lo último que se ha dicho.",
                        model: settings.modelChoice,
                        generation: repair,
                        systemPrompt: system + "\n\n" + ResponseQualityGuard.repairInstruction(characterName: character.name),
                        history: history,
                        warmup: false
                    ) { chunk in repairedRaw += chunk }
                    let repaired = ReplySanitizer.room(repairedRaw, currentName: character.name, participantNames: participants.map(\.name))
                    clean = ResponseQualityGuard.betterCandidate(
                        clean,
                        repaired,
                        comparedTo: Array(recentRoomReplies),
                        userText: text
                    )
                }

                let finalAssessment = ResponseQualityGuard.assess(clean, comparedTo: Array(recentRoomReplies), userText: text)
                guard !clean.isEmpty, !finalAssessment.shouldRepair,
                      let latestRoom = library.rooms.firstIndex(where: { $0.id == roomID }) else {
                    // Do not teach the other agents a broken loop or duplicated answer.
                    ai.releaseTransientMemory()
                    continue
                }

                library.rooms[latestRoom].messages.append(RoomMessage(characterID: character.id, text: clean))
                library.rooms[latestRoom].messages = Array(library.rooms[latestRoom].messages.suffix(80))
                persistLibrary()

                if character.voice.autoSpeak {
                    speaker.enqueueSpeech(clean, settings: character.voice, locale: settings.speechLocale)
                }

                ai.releaseTransientMemory()
                await Task.yield()
            } catch is CancellationError {
                break
            } catch {
                errorMessage = "Sala: el modelo se ha reiniciado de forma segura: \(error.localizedDescription)"
                await ai.unload()
                break
            }
        }
    }

    // MARK: - Import / export

    func exportActiveCharacter() {
        do {
            shareURL = try store.exportCharacter(activeCharacter, memories: activeMemories)
        } catch { errorMessage = error.localizedDescription }
    }

    func importCharacter(from url: URL) {
        do {
            var bundle = try store.importCharacter(from: url)
            let oldID = bundle.character.id
            bundle.character.id = UUID()
            bundle.character.createdAt = Date()
            if let avatar = bundle.avatarData {
                bundle.character.avatarFilename = try store.saveAvatar(avatar, for: bundle.character.id)
            } else {
                bundle.character.avatarFilename = nil
            }
            library.characters.append(bundle.character)
            for var memory in bundle.memories {
                memory.id = UUID()
                memory.characterID = bundle.character.id
                library.memories.append(memory)
            }
            let thread = ConversationThread.fresh(for: bundle.character)
            library.conversations.append(thread)
            library.activeCharacterID = bundle.character.id
            library.activeConversationID = thread.id
            persistLibrary()
            _ = oldID
        } catch { errorMessage = "No pude importar el personaje: \(error.localizedDescription)" }
    }

    func exportBackup() {
        do { shareURL = try store.exportBackup(library: library, settings: settings) }
        catch { errorMessage = error.localizedDescription }
    }

    func importBackup(from url: URL) {
        do {
            let backup = try store.importBackup(from: url)
            library = backup.library
            settings = backup.settings
            repairLibraryIfNeeded()
            persistAll()
        } catch { errorMessage = "No pude restaurar el backup: \(error.localizedDescription)" }
    }

    // MARK: - Settings / Bridge

    func saveSettings() { persistSettings() }

    func useDiscoveredBridge(_ item: DiscoveredBridge) {
        settings.streamBridge.host = item.host
        settings.streamBridge.port = item.port
        settings.streamBridge.enabled = true
        persistSettings()
        Task { await bridge.connect(host: item.host, port: item.port) }
    }

    func testBridge() async {
        do { try await bridge.test(settings: settings.streamBridge) }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Helpers

    private var activeConversationIndex: Int? {
        library.conversations.firstIndex(where: { $0.id == library.activeConversationID })
    }

    private func ensureConversation(for characterID: UUID) {
        if let thread = library.conversations.first(where: { $0.characterID == characterID }) {
            library.activeConversationID = thread.id
        } else if let character = library.characters.first(where: { $0.id == characterID }) {
            let thread = ConversationThread.fresh(for: character)
            library.conversations.append(thread)
            library.activeConversationID = thread.id
        }
    }

    private func repairLibraryIfNeeded() {
        var libraryChanged = false
        if library.characters.isEmpty { library = .fresh; libraryChanged = true }
        if !library.characters.contains(where: { $0.id == library.activeCharacterID }), let first = library.characters.first {
            library.activeCharacterID = first.id
            libraryChanged = true
        }
        ensureConversation(for: library.activeCharacterID)

        // Migrate V3.2's exact low-entropy defaults. Qwen warns that near-deterministic decoding can
        // collapse into endless repetition, so existing characters should not remain stuck at 0.50.
        for index in library.characters.indices {
            let g = library.characters[index].generation
            if abs(g.temperature - 0.50) < 0.001 && abs(g.topP - 0.86) < 0.001 {
                library.characters[index].generation.temperature = 0.70
                library.characters[index].generation.topP = 0.80
                library.characters[index].generation.recentContextMessages = max(6, g.recentContextMessages)
                libraryChanged = true
            }
            // V3.3 validates a complete answer before TTS, so stale streaming-TTS preferences are disabled.
            if library.characters[index].voice.speakWhileGenerating {
                library.characters[index].voice.speakWhileGenerating = false
                libraryChanged = true
            }
        }

        if settings.scenarios.isEmpty { settings.scenarios = WorldScenario.defaults }
        if settings.selectedScenarioID == nil { settings.selectedScenarioID = settings.scenarios.first?.id }
        if libraryChanged { store.saveLibrary(library) }
    }

    private func directHistory(
        conversationID: UUID,
        excluding messageID: UUID?,
        limit: Int
    ) -> [LLMHistoryMessage] {
        let thread = library.conversations.first(where: { $0.id == conversationID })
        return (thread?.messages ?? [])
            .filter { message in
                guard message.id != messageID, !message.isStreaming, !message.text.isEmpty else { return false }
                if message.role == .assistant { return ResponseQualityGuard.canEnterContext(message.text) }
                return message.role == .user
            }
            .suffix(max(2, limit))
            .compactMap { message in
                let safe = PromptBudgeter.safeContextMessage(message.text, limit: 700)
                switch message.role {
                case .user: return .user(safe)
                case .assistant: return .assistant(safe)
                case .system: return nil
                }
            }
    }

    private func roomHistory(
        roomID: UUID,
        for character: CharacterProfile,
        participants: [CharacterProfile],
        limit: Int
    ) -> [LLMHistoryMessage] {
        guard let room = library.rooms.first(where: { $0.id == roomID }) else { return [] }
        let names = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0.name) })
        return room.messages
            .filter { message in
                guard !message.text.isEmpty else { return false }
                if message.characterID != nil { return ResponseQualityGuard.canEnterContext(message.text) }
                return true
            }
            .suffix(max(3, limit))
            .map { message in
                let safe = PromptBudgeter.safeContextMessage(message.text, limit: 600)
                guard let speakerID = message.characterID else {
                    return .user("[USUARIO] \(safe)")
                }
                if speakerID == character.id {
                    return .assistant(safe)
                }
                let speakerName = names[speakerID] ?? "OTRA PERSONA"
                return .user("[\(speakerName)] \(safe)")
            }
    }

    private func makeSystemPrompt(
        character: CharacterProfile,
        compiledBehavior: PromptBudgeter.CompiledBehavior,
        relevantMemories: [MemoryItem]
    ) -> String {
        let memoryBlock = relevantMemories.prefix(5).map {
            "- \(PromptBudgeter.safeMemory($0.text))"
        }.joined(separator: "\n")

        // Keep the persona stable and compact. Conversation turns are supplied separately with real
        // user/assistant roles, exactly as chat-tuned models expect them.
        return """
        Te llamas \(character.name).

        ASÍ ERES
        \(compiledBehavior.text)

        RECUERDOS ÚTILES
        \(memoryBlock.isEmpty ? "Ninguno relevante ahora." : memoryBlock)

        Conversa con naturalidad desde la forma de ser descrita arriba. Responde directamente a la persona con la que hablas y conserva continuidad con la conversación. Normalmente usa 1 a 4 frases completas. Habla solamente con tu propia voz: no escribas líneas del usuario ni de otras personas y no añadas tu nombre como prefijo.
        """
    }

    private func removeMessage(_ id: UUID) {
        for index in library.conversations.indices {
            library.conversations[index].messages.removeAll { $0.id == id }
        }
        persistLibrary()
    }

    private func smartTitle(_ text: String) -> String {
        let clean = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return String(clean.prefix(38)) + (clean.count > 38 ? "…" : "")
    }

    private func cue(for character: CharacterProfile) -> String {
        let e = character.emotion
        if e.anger > 70 { return "angry" }
        if e.excitement > 70 { return "excited" }
        if e.mood > 75 { return "happy" }
        if e.stress > 70 { return "stressed" }
        return "normal"
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard settings.haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func persistLibrary() { store.saveLibrary(library) }
    private func persistSettings() { store.saveSettings(settings) }
    private func persistAll() { persistLibrary(); persistSettings() }
}
