import Foundation
import UIKit

final class PersistenceStore {
    let root: URL
    let avatarsFolder: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        root = base.appendingPathComponent("CastmindV2", isDirectory: true)
        avatarsFolder = root.appendingPathComponent("Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: avatarsFolder, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadLibrary() -> CastmindLibrary {
        let current = root.appendingPathComponent("library-v2.json")
        if let data = try? Data(contentsOf: current), let value = try? decoder.decode(CastmindLibrary.self, from: data) {
            return value
        }
        if let migrated = migrateV1Library() {
            saveLibrary(migrated)
            return migrated
        }
        return .fresh
    }

    func saveLibrary(_ library: CastmindLibrary) {
        save(library, name: "library-v2.json")
    }

    func loadSettings() -> AppSettings {
        let current = root.appendingPathComponent("settings-v2.json")
        if let data = try? Data(contentsOf: current), let value = try? decoder.decode(AppSettings.self, from: data) {
            return value
        }
        if let migrated = migrateV1Settings() {
            saveSettings(migrated)
            return migrated
        }
        return .default
    }

    func saveSettings(_ settings: AppSettings) {
        save(settings, name: "settings-v2.json")
    }

    func load<T: Decodable>(_ type: T.Type, name: String, fallback: T) -> T {
        let url = root.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), let value = try? decoder.decode(T.self, from: data) else {
            return fallback
        }
        return value
    }

    func save<T: Encodable>(_ value: T, name: String) {
        let url = root.appendingPathComponent(name)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    @discardableResult
    func saveAvatar(_ data: Data, for characterID: UUID) throws -> String {
        let filename = "avatar-\(characterID.uuidString)-\(UUID().uuidString.prefix(8)).jpg"
        let url = avatarsFolder.appendingPathComponent(filename)
        guard let image = UIImage(data: data) else { throw StoreError.invalidImage }
        let maxSide: CGFloat = 1024
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let target = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { throw StoreError.invalidImage }
        try jpeg.write(to: url, options: [.atomic])
        return filename
    }

    func avatarURL(filename: String?) -> URL? {
        guard let filename else { return nil }
        let url = avatarsFolder.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func avatarData(filename: String?) -> Data? {
        guard let url = avatarURL(filename: filename) else { return nil }
        return try? Data(contentsOf: url)
    }

    func removeAvatar(filename: String?) {
        guard let url = avatarURL(filename: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func exportCharacter(_ character: CharacterProfile, memories: [MemoryItem]) throws -> URL {
        let bundle = CharacterBundle(character: character, memories: memories, avatarData: avatarData(filename: character.avatarFilename))
        let data = try encoder.encode(bundle)
        let safeName = character.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).castmind-character.json")
        try data.write(to: url, options: [.atomic])
        return url
    }

    func importCharacter(from url: URL) throws -> CharacterBundle {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try decoder.decode(CharacterBundle.self, from: data)
    }

    func exportBackup(library: CastmindLibrary, settings: AppSettings) throws -> URL {
        var avatars: [String: Data] = [:]
        for character in library.characters {
            if let filename = character.avatarFilename, let data = avatarData(filename: filename) {
                avatars[filename] = data
            }
        }
        let backup = CastmindBackup(library: library, settings: settings, avatars: avatars)
        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Castmind-V3-Backup-\(formatter.string(from: Date())).json")
        try data.write(to: url, options: [.atomic])
        return url
    }

    func importBackup(from url: URL) throws -> CastmindBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let backup = try decoder.decode(CastmindBackup.self, from: data)
        for (filename, avatar) in backup.avatars {
            let target = avatarsFolder.appendingPathComponent(filename)
            try avatar.write(to: target, options: [.atomic])
        }
        return backup
    }

    // MARK: - V1 migration

    /// Castmind V1 (the version built from the public Guacha77/Castmind repo) stored
    /// its JSON files directly in Documents using JSONEncoder's default Date format.
    private var legacyDocumentsRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var legacyDecoder: JSONDecoder {
        // Intentionally keep the default dateDecodingStrategy. V1 used a plain
        // JSONEncoder, whose Date representation is seconds since the reference date.
        JSONDecoder()
    }

    private func legacyDecode<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        let url = legacyDocumentsRoot.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? legacyDecoder.decode(type, from: data)
    }

    private func migrateV1Library() -> CastmindLibrary? {
        let oldProfile = legacyDecode(LegacyProfile.self, filename: "castmind-profile.json")
        let oldMessages = legacyDecode([LegacyMessage].self, filename: "castmind-messages.json")
        let oldGeneration = legacyDecode(LegacyGenerationSettings.self, filename: "castmind-generation.json")

        // Do not invent a migration if V1 never wrote any of its files.
        guard oldProfile != nil || oldMessages != nil || oldGeneration != nil else { return nil }

        let profile = oldProfile ?? LegacyProfile()
        let generation = oldGeneration ?? LegacyGenerationSettings()
        var character = CharacterProfile.gregorio
        character.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Gregorio" : profile.name
        character.subtitle = "Importado de Castmind V1"
        character.personality = profile.personality
        character.behaviorPrompt = profile.personality
        character.wakeWord = character.name
        character.voice.voiceIdentifier = profile.voiceIdentifier
        character.voice.autoSpeak = generation.speakReplies
        character.generation.temperature = generation.temperature
        character.generation.topP = generation.topP
        character.generation.maxTokens = min(max(generation.maxTokens, 32), 1024)

        var thread = ConversationThread(characterID: character.id, title: "Conversación importada de V1")
        thread.messages = (oldMessages ?? []).compactMap { item in
            switch item.role {
            case .user:
                return ChatMessage(id: item.id, role: .user, characterID: nil, text: item.text, createdAt: item.createdAt, isStreaming: false)
            case .assistant:
                return ChatMessage(id: item.id, role: .assistant, characterID: character.id, text: item.text, createdAt: item.createdAt, isStreaming: false)
            case .system:
                // V2 no exposes system messages as chat bubbles. Preserve useful text as lore below instead.
                return nil
            }
        }
        if thread.messages.isEmpty {
            thread = ConversationThread.fresh(for: character)
        } else {
            thread.updatedAt = thread.messages.last?.createdAt ?? Date()
        }

        var memories: [MemoryItem] = []
        let legacyMemory = profile.memory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !legacyMemory.isEmpty {
            memories.append(MemoryItem(
                characterID: character.id,
                text: legacyMemory,
                category: .characterLore,
                importance: 0.92,
                isPinned: true,
                source: "v1-profile"
            ))
        }
        let oldEmotionalState = profile.emotionalState.trimmingCharacters(in: .whitespacesAndNewlines)
        if !oldEmotionalState.isEmpty && oldEmotionalState.lowercased() != "serena" {
            memories.append(MemoryItem(
                characterID: character.id,
                text: "Estado descrito en V1: \(oldEmotionalState)",
                category: .characterLore,
                importance: 0.55,
                source: "v1-profile"
            ))
        }

        return CastmindLibrary(
            characters: [character],
            conversations: [thread],
            memories: memories,
            rooms: [],
            activeCharacterID: character.id,
            activeConversationID: thread.id,
            stats: UsageStats()
        )
    }

    private func migrateV1Settings() -> AppSettings? {
        guard let profile = legacyDecode(LegacyProfile.self, filename: "castmind-profile.json") else { return nil }
        var settings = AppSettings.default
        settings.hasCompletedOnboarding = profile.hasCompletedOnboarding
        settings.streamBridge.enabled = profile.streamBridgeEnabled
        settings.streamBridge.port = profile.streamBridgePort
        return settings
    }

    private struct LegacyProfile: Codable {
        var hasCompletedOnboarding: Bool = false
        var name: String = "Castmind"
        var personality: String = "Cercana, curiosa, directa y emocionalmente inteligente."
        var memory: String = ""
        var emotionalState: String = "Serena"
        var voiceIdentifier: String? = nil
        var streamBridgeEnabled: Bool = false
        var streamBridgePort: Int = 17382
    }

    private struct LegacyMessage: Codable {
        enum Role: String, Codable { case user, assistant, system }
        var id: UUID
        var role: Role
        var text: String
        var createdAt: Date
    }

    private struct LegacyGenerationSettings: Codable {
        var temperature: Double = 0.7
        var topP: Double = 0.9
        var maxTokens: Int = 512
        var speakReplies: Bool = true
    }

    enum StoreError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "La imagen seleccionada no se pudo preparar." }
    }
}
