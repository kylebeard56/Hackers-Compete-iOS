//
//  Firebase+Search.swift
//  Hackers
//
//  Created by Kyle Beard on 11/11/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

protocol TokenSearchable {
    var searchKey: String { get }
    var searchKeyReverse: String { get }
    static var forwardSearchField: String { get }
    static var reverseSearchField: String { get }
}

extension String {
    /// Normalize text for Firestore token search:
    /// - lowercase
    /// - diacritic-insensitive
    /// - all whitespace → " "
    /// - remove non-alphanumeric except space
    /// - collapse multi-space → single space
    /// - trim
    var normalizedForSearch: String {
        // 1. Convert all unicode whitespace → " "
        let withAsciiSpaces = unicodeScalars.map {
            CharacterSet.whitespacesAndNewlines.contains($0) ? " " : String($0)
        }.joined()

        // 2. Keep only alphanumeric + space
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filteredScalars = withAsciiSpaces.unicodeScalars.filter { allowed.contains($0) }
        let onlyAlnumSpace = String(String.UnicodeScalarView(filteredScalars))

        // 3. Fold accents + lowercase + collapse spaces
        return onlyAlnumSpace
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// For individual name tokens (given/family etc)
    /// Removes spaces entirely.
    var normalizedForSearchToken: String {
        normalizedForSearch.replacingOccurrences(of: " ", with: "")
    }
}
