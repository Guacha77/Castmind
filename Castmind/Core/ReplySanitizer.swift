import Foundation

enum ReplySanitizer {
    static func direct(_ raw: String, characterName: String) -> String {
        let normalized = unwrap(raw)
        var kept: [String] = []
        let forbidden = ["usuario:", "user:", "streamer:", "[usuario]:", "[user]:", "[streamer]:"]

        for original in normalized.components(separatedBy: .newlines) {
            var line = original.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            line = stripOwnPrefix(line, name: characterName)
            if forbidden.contains(where: { line.lowercased().hasPrefix($0) }) { break }
            if let cut = firstForbiddenInlineIndex(in: line, prefixes: forbidden), cut > line.startIndex {
                line = String(line[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty { kept.append(line) }
                break
            }
            if !line.isEmpty { kept.append(line) }
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func room(_ raw: String, currentName: String, participantNames: [String]) -> String {
        let normalized = unwrap(raw)
        let otherNames = participantNames.filter { $0.caseInsensitiveCompare(currentName) != .orderedSame }
        let otherPrefixes = otherNames.flatMap { name in
            ["\(name):", "[\(name)]:", "**\(name):**", "\(name) —", "\(name) -"]
        }
        var kept: [String] = []

        for original in normalized.components(separatedBy: .newlines) {
            var line = original.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            line = stripOwnPrefix(line, name: currentName)
            if otherPrefixes.contains(where: { line.lowercased().hasPrefix($0.lowercased()) }) { break }
            if let cut = firstForbiddenInlineIndex(in: line, prefixes: otherPrefixes), cut > line.startIndex {
                line = String(line[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty { kept.append(line) }
                break
            }
            if !line.isEmpty { kept.append(line) }
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unwrap(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "<reply>", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "</reply>", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripOwnPrefix(_ value: String, name: String) -> String {
        var line = value
        let prefixes = ["\(name):", "[\(name)]:", "**\(name):**", "\(name) —", "\(name) -"]
        if let prefix = prefixes.first(where: { line.lowercased().hasPrefix($0.lowercased()) }) {
            line = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private static func firstForbiddenInlineIndex(in line: String, prefixes: [String]) -> String.Index? {
        let lower = line.lowercased()
        var earliest: String.Index?
        for prefix in prefixes {
            let needle = prefix.lowercased()
            // Require whitespace/punctuation before a speaker marker to avoid cutting ordinary words.
            for marker in [" \(needle)", "\t\(needle)", " — \(needle)"] {
                if let range = lower.range(of: marker) {
                    let idx = range.lowerBound
                    if earliest == nil || idx < earliest! { earliest = idx }
                }
            }
        }
        return earliest
    }
}
