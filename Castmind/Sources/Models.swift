import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    var id = UUID()
    var role: Role
    var text: String
    var createdAt = Date()
}

struct CastmindProfile: Codable, Equatable {
    var hasCompletedOnboarding = false
    var name = "Castmind"
    var personality = "Cercana, curiosa, directa y emocionalmente inteligente."
    var memory = "Recuerda preferencias, contexto creativo y detalles que el usuario quiera conservar."
    var emotionalState = "Serena"
    var voiceIdentifier: String?
    var streamBridgeEnabled = false
    var streamBridgePort = 17382
}

struct GenerationSettings: Codable, Equatable {
    var temperature = 0.7
    var topP = 0.9
    var maxTokens = 512
    var speakReplies = true
}

enum ModelLifecycle: String, Codable {
    case notDownloaded = "No descargado"
    case downloading = "Descargando"
    case downloaded = "Descargado"
    case loading = "Cargando"
    case ready = "Listo"
    case generating = "Generando"
    case failed = "Error"
}

struct ModelStatus: Equatable {
    var lifecycle: ModelLifecycle = .notDownloaded
    var progress: Double = 0
    var detail = "Modelo recomendado: mlx-community/Qwen3-1.7B-4bit"
}
