import Foundation

/// Builds a bounded inference prompt while keeping the full user-authored behaviour prompt on disk.
/// The goal is to avoid unbounded KV-cache growth / memory pressure on iPhone when a character has
/// a very large prompt. Nothing is deleted from the character profile; only the per-turn inference
/// view is compacted when necessary.
enum PromptBudgeter {
    struct CompiledBehavior: Sendable, Equatable {
        var text: String
        var originalCharacters: Int
        var effectiveCharacters: Int
        var wasReduced: Bool
    }

    static func behaviorBudget(for model: LocalModelChoice) -> Int {
        // Larger weights leave less headroom for prompt/KV cache on the same phone.
        switch model {
        case .fast: return 14_000
        case .balanced: return 12_000
        case .quality: return 9_000
        }
    }

    static func maxSafeInputTokens(for model: LocalModelChoice) -> Int {
        switch model {
        case .fast: return 6_000
        case .balanced: return 7_000
        case .quality: return 5_000
        }
    }

    static func compileBehavior(_ raw: String, query: String, model: LocalModelChoice) -> CompiledBehavior {
        let originalCount = raw.count
        let budget = behaviorBudget(for: model)
        // Bound before normalization so even an accidental multi-megabyte paste never creates
        // multiple full-size temporary strings immediately before inference.
        let scan = normalize(boundedScan(raw, maxCharacters: 220_000))
        guard originalCount > budget else {
            return CompiledBehavior(text: scan, originalCharacters: originalCount, effectiveCharacters: scan.count, wasReduced: false)
        }

        // Rank a bounded working set while the full source prompt remains untouched in storage.
        let chunks = chunk(scan)
        let queryTerms = significantTerms(query)

        var scored: [(index: Int, text: String, score: Int)] = []
        scored.reserveCapacity(chunks.count)
        for (index, value) in chunks.enumerated() {
            var score = 0
            if index < 2 { score += 1_000 - index * 50 }
            if index >= max(0, chunks.count - 2) { score += 650 }
            score += ruleScore(value)
            let lower = value.lowercased()
            for term in queryTerms where lower.contains(term) { score += 45 }
            // Prefer information-dense chunks over tiny fragments when scores tie.
            score += min(80, value.count / 35)
            scored.append((index, value, score))
        }

        // Choose the highest-value chunks under the strict budget, then restore original order.
        let ranked = scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.index < $1.index
        }
        var selected: [(index: Int, text: String)] = []
        var used = 0
        for candidate in ranked {
            let cost = candidate.text.count + 2
            guard cost <= budget else { continue }
            if used + cost > budget { continue }
            selected.append((candidate.index, candidate.text))
            used += cost
            if used >= budget - 180 { break }
        }

        // A single huge unstructured paragraph can otherwise leave us with no chunk. Keep head+tail.
        if selected.isEmpty {
            let headCount = max(1, budget * 2 / 3)
            let tailCount = max(1, budget - headCount - 16)
            let text = String(scan.prefix(headCount)) + "\n[…]\n" + String(scan.suffix(tailCount))
            return CompiledBehavior(text: text, originalCharacters: originalCount, effectiveCharacters: text.count, wasReduced: true)
        }

        selected.sort { $0.index < $1.index }
        var output = ""
        var previousIndex: Int?
        for item in selected {
            if let previousIndex, item.index > previousIndex + 1 { output += "\n[…]\n" }
            if !output.isEmpty, !output.hasSuffix("\n") { output += "\n\n" }
            output += item.text
            previousIndex = item.index
        }
        if output.count > budget { output = String(output.prefix(budget)) }

        return CompiledBehavior(text: output, originalCharacters: originalCount, effectiveCharacters: output.count, wasReduced: true)
    }

    static func safeUserInput(_ raw: String, limit: Int = 4_000) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return String(clean.prefix(limit))
    }

    static func safeContextMessage(_ raw: String, limit: Int = 700) -> String {
        let clean = raw.replacingOccurrences(of: "\u{0000}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return String(clean.prefix(limit)) + "…"
    }

    static func safeMemory(_ raw: String, limit: Int = 500) -> String {
        safeContextMessage(raw, limit: limit)
    }

    static func adjustedGeneration(_ settings: GenerationSettings, compiledBehavior: CompiledBehavior) -> GenerationSettings {
        guard compiledBehavior.wasReduced else { return settings }
        var result = settings
        // Large source prompts usually imply rich character definitions. Keep replies useful while
        // reserving extra memory headroom for prefill/KV allocation.
        result.maxTokens = min(result.maxTokens, 112)
        result.recentContextMessages = min(result.recentContextMessages, 4)
        return result
    }

    private static func normalize(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boundedScan(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else { return text }
        let headCount = maxCharacters * 3 / 4
        let tailCount = maxCharacters - headCount
        return String(text.prefix(headCount)) + "\n\n[…]\n\n" + String(text.suffix(tailCount))
    }

    private static func chunk(_ text: String) -> [String] {
        let rawParagraphs = text.components(separatedBy: "\n\n")
        var result: [String] = []
        result.reserveCapacity(rawParagraphs.count)
        for raw in rawParagraphs {
            let paragraph = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraph.isEmpty else { continue }
            if paragraph.count <= 1_100 {
                result.append(paragraph)
                continue
            }
            var remaining = paragraph[...]
            while remaining.count > 1_100 {
                let end = remaining.index(remaining.startIndex, offsetBy: 1_000)
                let slice = remaining[..<end]
                result.append(String(slice).trimmingCharacters(in: .whitespacesAndNewlines))
                remaining = remaining[end...]
            }
            let tail = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { result.append(tail) }
        }
        return result
    }

    private static func ruleScore(_ value: String) -> Int {
        let lower = value.lowercased()
        let keywords = [
            "siempre", "nunca", "debes", "debe ", "no debes", "prohibido", "regla", "reglas",
            "importante", "prioridad", "identidad", "eres ", "tu nombre", "objetivo", "objetivos",
            "forma de hablar", "habla ", "tono", "vocabulario", "relación", "cuando ", "si ",
            "responde", "comportamiento", "mantén", "no cambies", "evita"
        ]
        var score = 0
        for keyword in keywords where lower.contains(keyword) { score += 90 }
        return min(score, 720)
    }

    private static func significantTerms(_ text: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let stop: Set<String> = ["para", "pero", "como", "porque", "esta", "este", "esto", "unos", "unas", "sobre", "desde", "hasta", "cuando", "donde", "quien", "tiene", "tengo", "quiero", "puede", "puedo", "hola", "dime", "que", "qué", "con", "por", "del", "las", "los", "una", "uno", "muy", "más"]
        return Array(Set(text.lowercased().components(separatedBy: separators).filter { $0.count >= 4 && !stop.contains($0) })).prefix(24).map { $0 }
    }
}
