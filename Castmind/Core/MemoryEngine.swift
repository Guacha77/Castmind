import Foundation

struct MemoryEngine {
    static func capture(from text: String, characterID: UUID) -> [MemoryItem] {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 5 else { return [] }
        let lower = clean.lowercased()
        var items: [MemoryItem] = []

        func append(_ category: MemoryCategory, _ importance: Double) {
            items.append(MemoryItem(characterID: characterID, text: clean, category: category, importance: importance))
        }

        if lower.contains("recuerda") || lower.contains("acuérdate") || lower.contains("acuerdate") {
            append(.event, 0.95)
        } else if lower.contains("me llamo ") || lower.contains("mi nombre es ") || lower.contains("soy de ") || lower.contains("tengo ") {
            append(.userFact, 0.86)
        } else if lower.contains("me gusta ") || lower.contains("me encanta ") || lower.contains("odio ") || lower.contains("prefiero ") || lower.contains("mi favorito") || lower.contains("mi favorita") {
            append(.preference, 0.82)
        } else if lower.contains("prometo ") || lower.contains("te prometo ") || lower.contains("quedamos en ") || lower.contains("te debo ") {
            append(.promise, 0.90)
        } else if lower.contains("mi amigo") || lower.contains("mi amiga") || lower.contains("mi hermano") || lower.contains("mi hermana") || lower.contains("mi novia") || lower.contains("mi novio") {
            append(.relationship, 0.78)
        }

        return items
    }

    static func selectRelevant(
        from memories: [MemoryItem],
        query: String,
        limit: Int,
        allowDecay: Bool
    ) -> [MemoryItem] {
        let queryTokens = tokens(query)
        let now = Date()
        return memories
            .map { memory -> (MemoryItem, Double) in
                let overlap = lexicalOverlap(queryTokens, tokens(memory.text))
                let ageDays = max(0, now.timeIntervalSince(memory.createdAt) / 86_400)
                let decay = allowDecay && !memory.isPinned ? max(0.42, 1 - ageDays / 300.0) : 1.0
                let pinBoost = memory.isPinned ? 1.1 : 0
                let recencyBoost = max(0, 0.22 - ageDays / 365.0)
                let score = memory.importance * 0.56 + overlap * 0.70 + pinBoost + recencyBoost
                return (memory, score * decay)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(max(0, limit))
            .map(\.0)
    }

    static func maintenance(_ memories: inout [MemoryItem], enabled: Bool) {
        guard enabled else { return }
        let cutoff = Date().addingTimeInterval(-180 * 86_400)
        memories.removeAll { memory in
            !memory.isPinned && memory.importance < 0.25 && memory.createdAt < cutoff
        }
    }

    private static func tokens(_ text: String) -> Set<String> {
        let ignored: Set<String> = ["que", "como", "para", "pero", "porque", "esta", "este", "esto", "una", "uno", "con", "por", "del", "las", "los", "muy", "soy", "eres", "tengo", "tiene", "me", "te", "mi", "tu", "de", "la", "el", "y", "a", "en"]
        return Set(
            text.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !ignored.contains($0) }
        )
    }

    private static func lexicalOverlap(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let intersection = a.intersection(b).count
        return Double(intersection) / Double(max(1, min(a.count, b.count)))
    }
}
