import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

@MainActor
final class LocalAIEngine {
    private let statusHandler: (ModelStatus) -> Void
    private var session: ChatSession?

    init(statusHandler: @escaping (ModelStatus) -> Void) {
        self.statusHandler = statusHandler
    }

    var isReady: Bool {
        session != nil
    }

    var cachedModelDirectoryExists: Bool {
        candidateCacheDirectories.contains { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }

    func load(profile: CastmindProfile, settings: GenerationSettings) async throws {
        if session != nil { return }

        statusHandler(ModelStatus(lifecycle: .loading, progress: 0, detail: "Preparando Qwen local"))

        let container = try await #huggingFaceLoadModelContainer(
            configuration: LLMRegistry.qwen3_1_7b_4bit
        ) { [statusHandler] progress in
            let fraction = max(0, min(1, progress.fractionCompleted))
            Task { @MainActor in
                statusHandler(
                    ModelStatus(
                        lifecycle: fraction < 1 ? .downloading : .loading,
                        progress: fraction,
                        detail: progress.localizedDescription
                    )
                )
            }
        }

        let instructions = """
        Eres \(profile.name).
        Personalidad: \(profile.personality)
        Estado emocional: \(profile.emotionalState)
        Memoria del usuario: \(profile.memory)
        No uses servicios externos. Responde desde el modelo local.
        """

        session = ChatSession(container, instructions: instructions)
        statusHandler(ModelStatus(lifecycle: .ready, progress: 1, detail: "Qwen local cargado"))
    }

    func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        guard let session else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CastmindAIError.modelNotLoaded)
            }
        }
        return session.streamResponse(to: prompt)
    }

    func unload() {
        session = nil
    }

    func deleteCachedModel() throws {
        for url in candidateCacheDirectories where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private var candidateCacheDirectories: [URL] {
        let fm = FileManager.default
        var roots = fm.urls(for: .cachesDirectory, in: .userDomainMask)
        roots += fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        roots += fm.urls(for: .documentDirectory, in: .userDomainMask)

        return roots.flatMap { root in
            [
                root.appendingPathComponent("huggingface/hub/models--mlx-community--Qwen3-1.7B-4bit"),
                root.appendingPathComponent("models--mlx-community--Qwen3-1.7B-4bit"),
                root.appendingPathComponent("mlx-community/Qwen3-1.7B-4bit")
            ]
        }
    }
}

enum CastmindAIError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "El modelo local todavia no esta cargado."
        }
    }
}
