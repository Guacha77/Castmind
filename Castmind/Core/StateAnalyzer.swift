import Foundation

struct StateAnalyzer {
    static func apply(userText: String, to character: inout CharacterProfile) {
        let lower = userText.lowercased()
        var e = character.emotion

        let hostile = ["idiota", "inútil", "inutil", "cállate", "callate", "odio", "pringado", "imbécil", "imbecil", "estúpido", "estupido"]
        let friendly = ["gracias", "bien hecho", "me caes bien", "te quiero", "crack", "grande", "jaj", "haha", "me gusta"]
        let exciting = ["vamos", "increíble", "increible", "ganamos", "victoria", "brutal", "hostia", "wow"]
        let worrying = ["miedo", "problema", "mal", "perdimos", "fracaso", "peligro"]

        if hostile.contains(where: lower.contains) {
            e.anger += 8; e.trust -= 4; e.stress += 4; e.affection -= 2
        }
        if friendly.contains(where: lower.contains) {
            e.mood += 5; e.trust += 4; e.anger -= 3; e.affection += 4
        }
        if exciting.contains(where: lower.contains) {
            e.excitement += 8; e.energy += 4; e.mood += 3
        }
        if worrying.contains(where: lower.contains) {
            e.stress += 6; e.mood -= 3
        }
        if userText.contains("!") { e.excitement += 1.5 }
        if userText.count > 220 { e.energy -= 1 }

        // Gentle regression so a single interaction does not permanently max values.
        e.anger += (18 - e.anger) * 0.015
        e.stress += (18 - e.stress) * 0.012
        e.excitement += (45 - e.excitement) * 0.010
        e.clamp()
        character.emotion = e
    }
}
