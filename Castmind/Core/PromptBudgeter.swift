import Foundation

/// Produces a bounded, stable inference view of very large character descriptions.
/// The complete user-authored text remains stored unchanged in CharacterProfile.
enum PromptBudgeter {
    struct CompiledBehavior: Sendable, Equatable {
        var text: String
        var originalCharacters: Int
        var effectiveCharacters: Int
        var wasReduced: Bool
    }

    static func behaviorBudget(for model: LocalModelChoice) -> Int {
        // Weight memory + KV cache headroom is tighter on the larger model.
        switch model {
        case .fast: return 10_000
        case .balanced: return 8_500
        case .quality: return 6_500
        }
    }

    static func maxSafeInputTokens(for model: LocalModelChoice) -> Int {
        // Conservative iPhone ceilings. The complete saved prompt can be arbitrarily larger;
        // only its per-turn compiled representation is bounded.
        switch model {
        case .fast: return 5_200
        case .balanced: return 4_300
        case .quality: return 3_200
        }
    }

    static func compileBehavior(
        _ raw: String,
        query: String,
        model: LocalModelChoice,
        emergency: Bool = false
    ) -> CompiledBehavior {
        let originalCount = raw.count
        let normalBudget = behaviorBudget(for: model)
        let budget = emergency ? max(2_600, Int(Double(normalBudget) * 0.56)) : normalBudget

        // Never manufacture several copies of a multi-megabyte pasted prompt just before inference.
        let scan = normalize(boundedScan(raw, maxCharacters: emergency ? 80_000 : 140_000))
        guard scan.count > budget else {
            return CompiledBehavior(
                text: scan,
                originalCharacters: originalCount,
                effectiveCharacters: scan.count,
                wasReduced: originalCount > scan.count
            )
        }

        let chunks = chunk(scan)
        guard !chunks.isEmpty else {
            return CompiledBehavior(text: "", originalCharacters: originalCount, effectiveCharacters: 0, wasReduced: true)
        }

        // 80% of the compiled prompt is a stable core selected independently of the current message.
        // This prevents the character's apparent identity from changing from turn to turn.
        let coreBudget = Int(Double(budget) * 0.80)
        let dynamicBudget = budget - coreBudget

        var selected = Set<Int>()
        var used = 0

        func add(_ index: Int, limit: Int) {
            guard chunks.indices.contains(index), !selected.contains(index) else { return }
            let cost = chunks[index].count + 2
            guard used + cost <= limit else { return }
            selected.insert(index)
            used += cost
        }

        // Preserve the opening identity definition and the ending constraints/style whenever possible.
        add(0, limit: coreBudget)
        if chunks.count > 1 { add(1, limit: coreBudget) }
        if chunks.count > 2 { add(chunks.count - 1, limit: coreBudget) }

        let stableRanked = chunks.indices
            .filter { !selected.contains($0) }
            .map { index -> (Int, Int) in
                let density = min(90, chunks[index].count / 28)
                let positional = index < 4 ? (220 - index * 35) : 0
                return (index, ruleScore(chunks[index]) + density + positional)
            }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0 < $1.0
            }

        for candidate in stableRanked {
            add(candidate.0, limit: coreBudget)
            if used >= coreBudget - 180 { break }
        }

        // Use the remaining budget for details that are specifically relevant to the current turn,
        // without displacing the stable core above.
        let terms = significantTerms(query)
        let dynamicRanked = chunks.indices
            .filter { !selected.contains($0) }
            .map { index -> (Int, Int) in
                let lower = chunks[index].lowercased()
                var score = 0
                for term in terms where lower.contains(term) { score += 70 }
                score += min(80, ruleScore(chunks[index]) / 5)
                return (index, score)
            }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0 < $1.0
            }

        let absoluteLimit = min(budget, used + dynamicBudget)
        for candidate in dynamicRanked {
            add(candidate.0, limit: absoluteLimit)
            if used >= absoluteLimit - 120 { break }
        }

        // Fill any unused room with the next strongest stable chunks.
        if used < budget - 200 {
            for candidate in stableRanked where !selected.contains(candidate.0) {
                add(candidate.0, limit: budget)
                if used >= budget - 160 { break }
            }
        }

        if selected.isEmpty {
            let headCount = max(1, budget * 3 / 4)
            let tailCount = max(1, budget - headCount - 2)
            let text = String(scan.prefix(headCount)) + "\n" + String(scan.suffix(tailCount))
            return CompiledBehavior(text: text, originalCharacters: originalCount, effectiveCharacters: text.count, wasReduced: true)
        }

        let output = selected.sorted().map { chunks[$0] }.joined(separator: "\n\n")
        let bounded = output.count > budget ? String(output.prefix(budget)) : output
        return CompiledBehavior(
            text: bounded,
            originalCharacters: originalCount,
            effectiveCharacters: bounded.count,
            wasReduced: true
        )
    }

    static func safeUserInput(_ raw: String, limit: Int = 3_000) -> String {
        let clean = raw
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return String(clean.prefix(limit))
    }

    static func safeContextMessage(_ raw: String, limit: Int = 520) -> String {
        let clean = raw
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return String(clean.prefix(limit)) + "…"
    }

    static func safeMemory(_ raw: String, limit: Int = 360) -> String {
        safeContextMessage(raw, limit: limit)
    }

    static func adjustedGeneration(_ settings: GenerationSettings, compiledBehavior: CompiledBehavior) -> GenerationSettings {
        var result = settings

        // Small local models obey a detailed identity more reliably at lower sampling entropy.
        result.temperature = min(result.temperature, 0.52)
        result.topP = min(result.topP, 0.90)
        result.maxTokens = min(result.maxTokens, 112)
        result.recentContextMessages = min(result.recentContextMessages, 5)

        if compiledBehavior.wasReduced {
            result.temperature = min(result.temperature, 0.46)
            result.topP = min(result.topP, 0.86)
            result.maxTokens = min(result.maxTokens, 96)
            result.recentContextMessages = min(result.recentContextMessages, 3)
        }

        if compiledBehavior.originalCharacters > 40_000 {
            result.temperature = min(result.temperature, 0.42)
            result.maxTokens = min(result.maxTokens, 88)
            result.recentContextMessages = min(result.recentContextMessages, 2)
        }
        return result
    }

    /// Last-resort compaction used after tokenization if a prompt is still above the model-specific
    /// safety ceiling. It preserves the beginning (identity) and end (recent context/output contract).
    static func compactSystemPrompt(_ text: String, targetCharacters: Int) -> String {
        let target = max(1_800, targetCharacters)
        guard text.count > target else { return text }
        let head = Int(Double(target) * 0.72)
        let tail = max(1, target - head)
        return String(text.prefix(head)) + "\n\n" + String(text.suffix(tail))
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
        return String(text.prefix(headCount)) + "\n\n" + String(text.suffix(tailCount))
    }

    private static func chunk(_ text: String) -> [String] {
        var result: [String] = []
        let paragraphs = text.components(separatedBy: "\n\n")
        result.reserveCapacity(paragraphs.count)

        for raw in paragraphs {
            let paragraph = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraph.isEmpty else { continue }
            if paragraph.count <= 900 {
                result.append(paragraph)
                continue
            }

            var remaining = paragraph[...]
            while remaining.count > 900 {
                let end = remaining.index(remaining.startIndex, offsetBy: 820)
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
            "responde", "comportamiento", "mantén", "no cambies", "evita", "recuerda", "historia",
            "personalidad", "carácter", "actitud", "odia", "ama", "cree", "piensa", "quiere"
        ]
        var score = 0
        for keyword in keywords where lower.contains(keyword) { score += 95 }
        return min(score, 900)
    }

    private static func significantTerms(_ text: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let stop: Set<String> = [
            "para", "pero", "como", "porque", "esta", "este", "esto", "unos", "unas", "sobre",
            "desde", "hasta", "cuando", "donde", "quien", "tiene", "tengo", "quiero", "puede",
            "puedo", "hola", "dime", "que", "qué", "con", "por", "del", "las", "los", "una",
            "uno", "muy", "más", "eres", "soy", "ser", "hay", "hacer"
        ]
        var seen = Set<String>()
        var result: [String] = []
        for word in text.lowercased().components(separatedBy: separators) {
            guard word.count >= 4, !stop.contains(word), seen.insert(word).inserted else { continue }
            result.append(word)
            if result.count == 24 { break }
        }
        return result
    }
}
