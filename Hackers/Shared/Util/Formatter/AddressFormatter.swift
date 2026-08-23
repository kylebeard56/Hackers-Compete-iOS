//
//  AddressFormatter.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import Foundation
struct AddressFormatter {

    /// Removes trailing US ZIP and country from a comma-separated address.
    /// "201 Gold Bridge Rd, Marietta, SC, 29661, USA" → "201 Gold Bridge Rd, Marietta, SC"
    /// "123 Main St, Portland, ME 04101, United States" → "123 Main St, Portland, ME"
    static func trimmedUSAddress(_ address: String?) -> String {
        guard let address, !address.isEmpty else { return "" }
        var parts = address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        func normalize(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter }
        }
        func isUSZip(_ s: String) -> Bool {
            s.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
        }
        let usTokens: Set<String> = [
            "us", "usa", "unitedstates", "unitedstatesofamerica", "usminoroutlyingislands"
        ]

        var changed = true
        while changed, let last = parts.last {
            changed = false
            let norm = normalize(last)
            if usTokens.contains(norm) { parts.removeLast(); changed = true; continue }
            if isUSZip(last) { parts.removeLast(); changed = true; continue }
        }

        if var tail = parts.last {
            if let range = tail.range(of: #"\s*\d{5}(-\d{4})?$"#, options: .regularExpression) {
                tail.removeSubrange(range)
                tail = tail.trimmingCharacters(in: .whitespacesAndNewlines)
                if tail.isEmpty {
                    parts.removeLast()
                } else {
                    parts[parts.count - 1] = tail
                }
            }
        }
        return parts.joined(separator: ", ")
    }
}
