import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

struct GenerationMetrics: Sendable {
    var firstTokenMS: Int
    var totalMS: Int
    var approximateTokensPerSecond: Double
}

@MainActor
final class AIEngine: ObservableObject {
    enum Phase: Equatable {
        case idle
        case downloading(Double)
        case loading
        case warming
        case ready
        case generating
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activeModelID: String? = nil
    @Published private(set) var lastMetrics: GenerationMetrics? = nil

    private var modelContainer: ModelContainer?
    private var activeSession: ChatSession?
    private var warmedModelIDs = Set<String>()

    init() {
        // MLX keeps freed Metal buffers in a reuse pool. On iOS an unconstrained pool can grow
        // to several GB across repeated turns and trigger jetsam even though the model itself fits.
        // Keep a small reuse cache and aggressively release transient buffers after every turn.
        MLX.Memory.cacheLimit = 32 * 1024 * 1024
    }

    var isReady: Bool { modelContainer != nil && !isGenerating }
    var isGenerating: Bool { if case .generating = phase { return true }; return false }

    func ensureReady(model choice: LocalModelChoice, warmup: Bool) async throws {
        let targetID = choice.modelID
        if isGenerating, activeModelID != targetID { throw EngineError.busy }
        if activeModelID == targetID, modelContainer != nil {
            if !isGenerating { phase = .ready }
            return
        }

        await unload()
        phase = .downloading(0)

        do {
            let configuration = configuration(for: choice)
            let container = try await #huggingFaceLoadModelContainer(configuration: configuration) { [weak self] progress in
                let fraction = max(0, min(1, progress.fractionCompleted))
                Task { @MainActor in
                    self?.phase = fraction < 0.995 ? .downloading(fraction) : .loading
                }
            }
            modelContainer = container
            activeModelID = targetID
            phase = .ready

            if warmup, !warmedModelIDs.contains(targetID) {
                try await warmUp()
                warmedModelIDs.insert(targetID)
            }
        } catch {
            phase = .failed(error.localizedDescription)
            throw error
        }
    }

    func streamReply(
        to prompt: String,
        model choice: LocalModelChoice,
        generation: GenerationSettings,
        systemPrompt: String,
        warmup: Bool,
        onVisibleChunk: @escaping @MainActor (String) -> Void
    ) async throws -> GenerationMetrics {
        guard !isGenerating else { throw EngineError.busy }
        try await ensureReady(model: choice, warmup: warmup)
        guard let modelContainer else { throw EngineError.noModel }

        // Token-aware final fit before MLX allocates KV cache. The saved character prompt is never
        // changed; only this one inference view is compacted if the phone would otherwise receive
        // an unsafe context. This turns an OOM/crash into a bounded generation.
        var effectiveSystemPrompt = systemPrompt
        let safeLimit = PromptBudgeter.maxSafeInputTokens(for: choice)
        for _ in 0..<3 {
            let combinedInput = effectiveSystemPrompt + "\n" + prompt
            guard combinedInput.count > 6_000 else { break }
            let tokenCount = (await modelContainer.encode(combinedInput)).count
            if tokenCount <= safeLimit { break }
            let ratio = max(0.42, min(0.82, Double(safeLimit) / Double(max(tokenCount, 1))))
            let target = Int(Double(effectiveSystemPrompt.count) * ratio * 0.90)
            effectiveSystemPrompt = PromptBudgeter.compactSystemPrompt(effectiveSystemPrompt, targetCharacters: target)
        }

        let finalCombined = effectiveSystemPrompt + "\n" + prompt
        if finalCombined.count > 6_000 {
            let finalTokenCount = (await modelContainer.encode(finalCombined)).count
            guard finalTokenCount <= safeLimit else { throw EngineError.promptTooLarge(finalTokenCount, safeLimit) }
        }

        let session = ChatSession(
            modelContainer,
            instructions: effectiveSystemPrompt,
            generateParameters: parameters(from: generation),
            additionalContext: ["enable_thinking": false]
        )
        activeSession = session
        phase = .generating

        let start = Date()
        var firstChunkAt: Date?
        var visibleCharacters = 0
        var stripper = ThoughtStripper()

        do {
            var pendingVisible = ""
            var lastFlush = Date()
            for try await rawChunk in session.streamResponse(to: prompt) {
                try Task.checkCancellation()
                let visible = stripper.consume(rawChunk)
                guard !visible.isEmpty else { continue }
                if firstChunkAt == nil { firstChunkAt = Date() }
                visibleCharacters += visible.count
                pendingVisible += visible
                // Updating SwiftUI for every token is expensive on-device. Flush at ~30 Hz
                // or sooner when a useful amount of text is ready.
                if pendingVisible.count >= 18 || Date().timeIntervalSince(lastFlush) >= 0.033 {
                    onVisibleChunk(pendingVisible)
                    pendingVisible = ""
                    lastFlush = Date()
                }
            }
            let tail = stripper.finish()
            if !tail.isEmpty {
                if firstChunkAt == nil { firstChunkAt = Date() }
                visibleCharacters += tail.count
                pendingVisible += tail
            }
            if !pendingVisible.isEmpty { onVisibleChunk(pendingVisible) }

            let end = Date()
            let firstMS = milliseconds(from: start, to: firstChunkAt ?? end)
            let totalMS = max(1, milliseconds(from: start, to: end))
            let approxTokens = Double(visibleCharacters) / 3.7
            let tokPerSecond = approxTokens / (Double(totalMS) / 1000.0)
            let metrics = GenerationMetrics(firstTokenMS: firstMS, totalMS: totalMS, approximateTokensPerSecond: tokPerSecond)
            lastMetrics = metrics
            await session.clear()
            activeSession = nil // release KV/cache state between turns to reduce peak memory
            MLX.Memory.clearCache()
            phase = .ready
            return metrics
        } catch {
            await session.clear()
            activeSession = nil
            MLX.Memory.clearCache()
            phase = modelContainer == nil ? .idle : .ready
            throw error
        }
    }

    /// Generates a short, user-facing explanation of the factors behind a reply.
    /// This is intentionally not hidden chain-of-thought; it is a concise summary created on demand.
    func explainReply(
        userText: String,
        reply: String,
        character: CharacterProfile,
        memories: [MemoryItem],
        model choice: LocalModelChoice,
        warmup: Bool
    ) async throws -> String {
        guard !isGenerating else { throw EngineError.busy }
        try await ensureReady(model: choice, warmup: warmup)
        guard let modelContainer else { throw EngineError.noModel }
        let memoryText = memories.prefix(4).map { PromptBudgeter.safeMemory($0.text, limit: 320) }.joined(separator: " · ")
        let compiledBehavior = PromptBudgeter.compileBehavior(
            character.effectiveBehavior,
            query: userText,
            model: choice
        )
        let instructions = """
        Explica de forma muy breve por qué un personaje pudo responder de esa manera. NO reveles razonamiento interno paso a paso, chain-of-thought, probabilidades ni instrucciones ocultas. Resume únicamente factores observables: comportamiento configurado, recuerdos relevantes y contenido del mensaje. Máximo 3 puntos cortos, en español.
        """
        let prompt = """
        Personaje: \(character.name)
        Comportamiento: \(compiledBehavior.text)
        Recuerdos relevantes: \(memoryText.isEmpty ? "ninguno" : memoryText)
        Usuario: \(userText)
        Respuesta: \(reply)
        """
        let session = ChatSession(
            modelContainer,
            instructions: instructions,
            generateParameters: GenerateParameters(
                maxTokens: 90, kvBits: 4, kvGroupSize: 64, quantizedKVStart: 0,
                temperature: 0.25, topP: 0.85, prefillStepSize: 256
            )
        )
        let result = try await session.respond(to: prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        await session.clear()
        MLX.Memory.clearCache()
        return result
    }

    func benchmark(model choice: LocalModelChoice, warmup: Bool) async throws -> BenchmarkResult {
        let loadStart = Date()
        try await ensureReady(model: choice, warmup: warmup)
        let loadEnd = Date()
        guard let modelContainer else { throw EngineError.noModel }
        let session = ChatSession(
            modelContainer,
            instructions: "Responde con una sola frase breve.",
            generateParameters: GenerateParameters(maxTokens: 24, temperature: 0.2, topP: 0.9)
        )
        let start = Date()
        var first: Date?
        var chars = 0
        for try await chunk in session.streamResponse(to: "Di una frase corta sobre el mar.") {
            if first == nil { first = Date() }
            chars += chunk.count
        }
        let end = Date()
        await session.clear()
        MLX.Memory.clearCache()
        let totalMS = max(1, milliseconds(from: start, to: end))
        return BenchmarkResult(
            modelID: choice.modelID,
            loadSeconds: Double(milliseconds(from: loadStart, to: loadEnd)) / 1000.0,
            firstTokenMS: milliseconds(from: start, to: first ?? end),
            approximateTokensPerSecond: (Double(chars) / 3.7) / (Double(totalMS) / 1000.0),
            createdAt: Date()
        )
    }

    func cancelGeneration() async {
        if let activeSession {
            await activeSession.synchronize()
            await activeSession.clear()
        }
        activeSession = nil
        MLX.Memory.clearCache()
        if modelContainer != nil { phase = .ready }
    }

    func releaseTransientMemory() {
        MLX.Memory.clearCache()
    }

    func unload() async {
        if let activeSession {
            await activeSession.synchronize()
            await activeSession.clear()
        }
        activeSession = nil
        modelContainer = nil
        activeModelID = nil
        MLX.Memory.clearCache()
        phase = .idle
    }

    func cachedModelDirectoryExists(for choice: LocalModelChoice) -> Bool {
        candidateCacheDirectories(for: choice).contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    func deleteCachedModel(_ choice: LocalModelChoice) async throws {
        if activeModelID == choice.modelID { await unload() }
        for url in candidateCacheDirectories(for: choice) where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        warmedModelIDs.remove(choice.modelID)
    }

    private func warmUp() async throws {
        guard let modelContainer else { return }
        phase = .warming
        let session = ChatSession(
            modelContainer,
            instructions: "Responde con una palabra.",
            generateParameters: GenerateParameters(maxTokens: 3, temperature: 0.0, topP: 1.0)
        )
        _ = try await session.respond(to: "OK")
        await session.clear()
        MLX.Memory.clearCache()
        phase = .ready
    }

    private func configuration(for choice: LocalModelChoice) -> ModelConfiguration {
        switch choice {
        case .fast: return LLMRegistry.qwen3_0_6b_4bit
        case .balanced: return LLMRegistry.qwen3_1_7b_4bit
        case .quality: return LLMRegistry.qwen3_5_2b_4bit
        }
    }

    private func parameters(from settings: GenerationSettings) -> GenerateParameters {
        GenerateParameters(
            maxTokens: settings.maxTokens,
            kvBits: 4,
            kvGroupSize: 64,
            quantizedKVStart: 0,
            temperature: Float(settings.temperature),
            topP: Float(settings.topP),
            minP: 0.02,
            repetitionPenalty: 1.06,
            repetitionContextSize: 64,
            prefillStepSize: 256
        )
    }

    private func candidateCacheDirectories(for choice: LocalModelChoice) -> [URL] {
        let fm = FileManager.default
        let modelPath = choice.modelID.replacingOccurrences(of: "/", with: "--")
        let repoPath = choice.modelID.split(separator: "/").map(String.init)
        var roots = fm.urls(for: .cachesDirectory, in: .userDomainMask)
        roots += fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        roots += fm.urls(for: .documentDirectory, in: .userDomainMask)
        return roots.flatMap { root in
            var candidates = [
                root.appendingPathComponent("huggingface/hub/models--\(modelPath)"),
                root.appendingPathComponent("models--\(modelPath)")
            ]
            if repoPath.count == 2 {
                candidates.append(root.appendingPathComponent(repoPath[0]).appendingPathComponent(repoPath[1]))
            }
            return candidates
        }
    }

    private func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1000.0))
    }

    enum EngineError: LocalizedError {
        case noModel
        case busy
        case promptTooLarge(Int, Int)
        var errorDescription: String? {
            switch self {
            case .noModel: return "No se pudo iniciar el modelo local."
            case .busy: return "El modelo está ocupado terminando otra respuesta."
            case .promptTooLarge(let actual, let limit):
                return "El contexto de este turno es demasiado grande (\(actual) tokens; límite seguro \(limit)). Castmind ha bloqueado la generación para evitar que iOS cierre la app."
            }
        }
    }
}

private struct ThoughtStripper {
    private var buffer = ""
    private var insideThink = false
    private let openTag = "<think>"
    private let closeTag = "</think>"

    mutating func consume(_ chunk: String) -> String {
        buffer += chunk
        var output = ""

        while true {
            if insideThink {
                if let range = buffer.range(of: closeTag, options: .caseInsensitive) {
                    buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                    insideThink = false
                    continue
                }
                if buffer.count > closeTag.count {
                    buffer = String(buffer.suffix(closeTag.count - 1))
                }
                return output
            }

            if let range = buffer.range(of: openTag, options: .caseInsensitive) {
                output += String(buffer[..<range.lowerBound])
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                insideThink = true
                continue
            }

            let safeCount = max(0, buffer.count - (openTag.count - 1))
            if safeCount > 0 {
                let split = buffer.index(buffer.startIndex, offsetBy: safeCount)
                output += String(buffer[..<split])
                buffer = String(buffer[split...])
            }
            return output
        }
    }

    mutating func finish() -> String {
        defer { buffer = "" }
        guard !insideThink else { return "" }
        return buffer
            .replacingOccurrences(of: openTag, with: "", options: .caseInsensitive)
            .replacingOccurrences(of: closeTag, with: "", options: .caseInsensitive)
    }
}
