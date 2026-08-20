import Foundation

/// Detects low-quality generations before they are committed to the visible conversation.
/// This is deliberately model-agnostic: it catches repetition collapse, prompt/role leakage,
/// near-duplicate room answers and obvious copies of the user's message.
enum ResponseQualityGuard {
    struct Assessment: Sendable, Equatable {
        var shouldRepair: Bool
        var score: Int
        var reasons: [String]
    }

    static func assess(
        _ text: String,
        comparedTo recentReplies: [String] = [],
        userText: String = ""
    ) -> Assessment {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return Assessment(shouldRepair: true, score: 0, reasons: ["empty"])
        }

        var score = 100
        var reasons: [String] = []

        if RoleplayGuard.needsRepair(clean) {
            score -= 55
            reasons.append("role/meta leakage")
        }

        let words = normalizedWords(clean)
        if words.count >= 8 {
            let uniqueRatio = Double(Set(words).count) / Double(words.count)
            if uniqueRatio < 0.38 {
                score -= 38
                reasons.append("low lexical diversity")
            } else if uniqueRatio < 0.48 {
                score -= 18
                reasons.append("repetitive vocabulary")
            }

            let frequencies = Dictionary(grouping: words, by: { $0 }).mapValues(\.count)
            if let mostCommon = frequencies.values.max() {
                let dominance = Double(mostCommon) / Double(words.count)
                if dominance >= 0.30 {
                    score -= 45
                    reasons.append("single-token loop")
                } else if dominance >= 0.22 {
                    score -= 22
                    reasons.append("token dominance")
                }
            }

            if repeatedNGram(words, size: 2, threshold: 3) || repeatedNGram(words, size: 3, threshold: 3) {
                score -= 42
                reasons.append("repeated phrase")
            }
        }

        if hasPunctuationOrFragmentLoop(clean) {
            score -= 45
            reasons.append("fragment loop")
        }

        if clean.range(of: #"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]:\s"#, options: .regularExpression) != nil {
            score -= 45
            reasons.append("malformed speaker prefix")
        }

        for previous in recentReplies.suffix(5) where !previous.isEmpty {
            let similarity = jaccardSimilarity(clean, previous)
            if similarity >= 0.82 && normalizedWords(clean).count >= 4 {
                score -= 48
                reasons.append("near-duplicate reply")
                break
            }
        }

        let userWords = normalizedWords(userText)
        if userWords.count >= 5, jaccardSimilarity(clean, userText) >= 0.90 {
            score -= 28
            reasons.append("copies user")
        }

        // Short conversational replies are valid; only fail them when another detector fires.
        let shouldRepair = score < 62 || reasons.contains("single-token loop") || reasons.contains("fragment loop") || reasons.contains("role/meta leakage") || reasons.contains("malformed speaker prefix")
        return Assessment(shouldRepair: shouldRepair, score: max(0, score), reasons: reasons)
    }

    static func needsRepair(
        _ text: String,
        comparedTo recentReplies: [String] = [],
        userText: String = ""
    ) -> Bool {
        assess(text, comparedTo: recentReplies, userText: userText).shouldRepair
    }

    static func canEnterContext(_ text: String) -> Bool {
        !assess(text).shouldRepair
    }

    static func betterCandidate(
        _ first: String,
        _ second: String,
        comparedTo recentReplies: [String] = [],
        userText: String = ""
    ) -> String {
        let a = assess(first, comparedTo: recentReplies, userText: userText)
        let b = assess(second, comparedTo: recentReplies, userText: userText)
        if b.score > a.score { return second }
        return first
    }

    static func repairInstruction(characterName: String) -> String {
        """
        Genera una intervención completamente nueva desde cero como \(characterName). Contesta de forma concreta a lo último que se ha dicho. Usa 1 a 4 frases naturales, variadas y completas. Evita repetir palabras o frases, evita copiar literalmente otra intervención y habla solamente con tu propia voz sin comentar el proceso de respuesta.
        """
    }

    private static func normalizedWords(_ text: String) -> [String] {
        let lowered = text.lowercased().folding(options: [.diacriticInsensitive], locale: .current)
        return lowered
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func repeatedNGram(_ words: [String], size: Int, threshold: Int) -> Bool {
        guard size > 0, words.count >= size * threshold else { return false }
        var counts: [String: Int] = [:]
        for index in 0...(words.count - size) {
            let gram = words[index..<(index + size)].joined(separator: " ")
            counts[gram, default: 0] += 1
            if counts[gram, default: 0] >= threshold { return true }
        }
        return false
    }

    private static func hasPunctuationOrFragmentLoop(_ text: String) -> Bool {
        let compact = text.lowercased().replacingOccurrences(of: "\n", with: " ")
        let fragments = compact
            .components(separatedBy: CharacterSet(charactersIn: ".,;:!?¿¡…"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard fragments.count >= 6 else { return false }
        let short = fragments.map { String($0.prefix(24)) }
        let counts = Dictionary(grouping: short, by: { $0 }).mapValues(\.count)
        if counts.values.contains(where: { $0 >= 4 }) { return true }

        let words = normalizedWords(text)
        guard words.count >= 10 else { return false }
        // Alternating one/two-token fragments are a common Qwen collapse mode (e.g. "¿Lo. ¿Lo...").
        let tinyFragments = fragments.filter { normalizedWords($0).count <= 2 }.count
        return Double(tinyFragments) / Double(fragments.count) >= 0.72
    }

    private static func jaccardSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Set(normalizedWords(lhs))
        let b = Set(normalizedWords(rhs))
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }
}
