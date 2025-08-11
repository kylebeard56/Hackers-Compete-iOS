//
//  CourseNameNormalizer.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/25.
//

import Foundation

struct CourseNameNormalizer {
    // phrases to drop entirely (order matters: longer first)
    private static let stopPhrases: [String] = [
        "golf & grill", "golf and grill",
        "golf & country club", "golf and country club",
        "country club", "golf course", "golf club", "recreation club",
        "resort & spa", "resort and spa", "resort", "links"
    ]

    // single words to drop
    private static let stopWords: Set<String> = [
        "golf","course","club","country","championship","signature",
        "executive","municipal","driving","range","practice","mini",
        "park","the","at","of","and","&"
    ]

    // quick expansions + cleanups
    private static let replacements: [(pattern: String, replace: String)] = [
        ("\\bcc\\b", " country club "),
        ("\\bgc\\b", " golf club "),
        ("&", " and "),
        ("’", "'"),
        ("\\bpar\\s*[- ]?\\s*3\\b", " "),          // "par 3"
        ("[^a-z0-9' ]+", " ")                      // kill punctuation
    ]

    static func normalize(_ raw: String) -> String {
        var t = raw.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "’", with: "'")

        // standardize/strip patterns
        for r in replacements {
            t = t.replacingOccurrences(of: r.pattern, with: r.replace, options: .regularExpression)
        }

        // remove known phrases
        for phrase in stopPhrases {
            let p = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            t = t.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }

        // collapse whitespace
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)

        // drop stopwords but keep digits and names (also normalize "3's" -> "3s")
        let tokens = t
            .replacingOccurrences(of: "\\b(\\d+)'s\\b", with: "$1s", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { !stopWords.contains($0) }

        return tokens.joined(separator: " ")
    }

    /// Generate a few search candidates from a Maps name.
    static func variants(from mapsName: String) -> [String] {
        var out: [String] = []
        func push(_ s: String) { if !s.isEmpty && !out.contains(s) { out.append(s) } }

        let original = mapsName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalize(original)

        push(original)                 // 1) as-is
        push(normalized)               // 2) cleaned ("cross winds", "chanticleer", etc.)

        // 3) handle "the ___ at ___" → keep both orders
        let lower = original.lowercased()
        if lower.contains(" at ") {
            let parts = lower.components(separatedBy: " at ")
            if parts.count == 2 {
                let a = normalize(parts[0])
                let b = normalize(parts[1])
                push("\(a) \(b)")      // "preserve verdae"
                push("\(a) at \(b)")   // "preserve at verdae"
            }
        }

        // 4) also try removing terminal descriptors once (e.g., “… country club”)
        let clipped = original.replacingOccurrences(
            of: "\\s+(golf (course|club)|country club|recreation club)\\s*$",
            with: "",
            options: .regularExpression
        )
        let clippedNorm = normalize(clipped)
        push(clipped)
        push(clippedNorm)

        return out
    }
}
