import Foundation

final class PersistenceController {
    private let messagesURL: URL
    private let profileURL: URL
    private let settingsURL: URL

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        messagesURL = base.appendingPathComponent("castmind-messages.json")
        profileURL = base.appendingPathComponent("castmind-profile.json")
        settingsURL = base.appendingPathComponent("castmind-generation.json")
    }

    func loadMessages() -> [ChatMessage] {
        load([ChatMessage].self, from: messagesURL) ?? [
            ChatMessage(role: .assistant, text: "Estoy lista. Descarga el modelo local cuando quieras y empezamos.")
        ]
    }

    func saveMessages(_ messages: [ChatMessage]) {
        save(messages, to: messagesURL)
    }

    func loadProfile() -> CastmindProfile {
        load(CastmindProfile.self, from: profileURL) ?? CastmindProfile()
    }

    func saveProfile(_ profile: CastmindProfile) {
        save(profile, to: profileURL)
    }

    func loadSettings() -> GenerationSettings {
        load(GenerationSettings.self, from: settingsURL) ?? GenerationSettings()
    }

    func saveSettings(_ settings: GenerationSettings) {
        save(settings, to: settingsURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder.pretty.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
