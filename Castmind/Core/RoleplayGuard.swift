import Foundation

/// Lightweight guardrail for small local models. It never changes the saved character prompt;
/// it only detects responses that expose the scaffolding of the roleplay or collapse into loops.
enum RoleplayGuard {
    private static let metaFragments = [
        "sigo un papel", "seguir un papel", "salirme del papel", "salir del papel", "lo que sea un papel",
        "estoy interpretando", "interpreto un personaje", "soy un personaje", "como personaje",
        "mi prompt", "el prompt", "mis instrucciones", "estas instrucciones", "instrucciones internas",
        "mis reglas", "reglas que sigo", "me han programado", "fui programad", "estoy programad",
        "soy una ia", "como ia", "como inteligencia artificial", "modelo de lenguaje",
        "system prompt", "mensaje de sistema", "no puedo romper el personaje", "no romperé el personaje",
        "nunca me saldré del papel", "no me saldré del papel", "mantenerme en personaje",
        "me obligan a", "me han dicho que responda", "debo seguir el rol", "seguir el rol"
    ]

    static func needsRepair(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return true }
        let lower = clean.lowercased()
        if metaFragments.contains(where: { lower.contains($0) }) { return true }
        if hasRunawayRepetition(clean) { return true }
        return false
    }

    static func canEnterContext(_ text: String) -> Bool {
        !needsRepair(text)
    }

    static func repairInstruction(characterName: String) -> String {
        """
        Responde otra vez de forma natural y directa como \(characterName). Habla desde tu identidad sin comentar cómo se produce la respuesta, sin describir directrices externas y sin explicar tu propia interpretación. Mantén los hechos, tono y personalidad definidos arriba. Da solamente la respuesta que dirías en la conversación.
        """
    }

    private static func hasRunawayRepetition(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard normalized.count >= 18 else { return false }

        // Detect the same 4-word sequence repeated 3+ times. This catches common small-model loops
        // without rejecting ordinary rhetorical repetition.
        var counts: [String: Int] = [:]
        for index in 0...(normalized.count - 4) {
            let gram = normalized[index..<(index + 4)].joined(separator: " ")
            counts[gram, default: 0] += 1
            if counts[gram, default: 0] >= 3 { return true }
        }
        return false
    }
}
