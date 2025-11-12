//
//  String.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import PhoneNumberKit
import UIKit

// MARK: - Dates

extension String {
    var fromISO8601: Date? {
        ISO8601DateFormatter().date(from: self)
    }
}

// MARK: - Validation / Regex

extension String {
//    static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    
//    var isValidEmail: Bool {
//        return NSPredicate(format:"SELF MATCHES %@", String.emailRegex).evaluate(with: self)
//    }
    
    var isValidUsernameRegex: Bool {
        return NSPredicate(format:"SELF MATCHES %@", "^[a-zA-Z0-9_-]+$").evaluate(with: self)
    }
    
    var isValidUsernameLength: Bool {
        return self.count >= 3 && self.count <= 30
    }
    
    @MainActor
    var isValidPhoneNumber: Bool {
        let field = PhoneNumberTextField()
        field.text = self
        return field.isValidNumber
    }
}

// MARK: - Unicode / Icons

extension String {
    var unicode: String? {
        guard let c = UInt32(self, radix: 16), let u = UnicodeScalar(c) else { return nil }
        return String(u)
    }
    
    /// Used to print the unicode value
    var unicodeEscaped: String? {
        return self.flatMap(\.unicodeScalars).compactMap({ $0.escaped(asASCII: true) }).first
    }
}

// MARK: - Manipulation / Concatenation

extension String {
    var possessive: String {
        "\(self)\(self.suffix(1) == "s" ? "'" : "'s")"
    }
    
    var alphanumericLowercased: String {
        self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
    
    var removeWhitespace: String {
        self.removeLeadingWhitespace.removeTrailingWhitespace
    }
    
    var removeLeadingWhitespace: String {
        var str: String = self
        if let index = str.firstIndex(where: { char in !char.isWhitespace }) {
            str = String(str[index...])
        }
        return str
    }
    
    var removeTrailingWhitespace: String {
        var str: String = self
        if let index = str.lastIndex(where: { char in !char.isWhitespace }) {
            str = String(str[...index])
        }
        return str
    }
    
    func middleSpaced() -> String {
        guard count % 2 == 0 else { return self }
        let midIndex = index(startIndex, offsetBy: count / 2)
        return String(prefix(upTo: midIndex)) + " " + String(suffix(from: midIndex))
    }
    
    func slashZeros() -> String {
        self.replacingOccurrences(of: "0", with: "Ø")
    }
    
    /// Not used yet
    func toFullPhoneNumber() -> String {
        // Remove any non-numeric characters
        let numbers = self.filter { $0.isNumber }
        
        // Check if we have enough digits for a phone number
        guard numbers.count == 10 else { return self }
        
        // Split the string into array for easier formatting
        let chars = Array(numbers)
        
        // Format as (XXX) XXX-XXXX
        let areaCode = String(chars[0...2])
        let prefix = String(chars[3...5])
        let lineNumber = String(chars[6...9])
        
        return "(\(areaCode)) \(prefix)-\(lineNumber)"
    }
    
    func toPartialPhoneFormat() -> String {
        // Remove any non-numeric characters
        let numbers = self.filter { $0.isNumber }
        let chars = Array(numbers)
        
        switch chars.count {
        case 0...2:
            return numbers
        case 3:
            return "(\(numbers))"
        case 4...5:
            return "(\(String(chars[0...2]))) \(String(chars[3...]))"
        case 6:
            return "(\(String(chars[0...2]))) \(String(chars[3...5]))"
        case 7...9:
            return "(\(String(chars[0...2]))) \(String(chars[3...5]))-\(String(chars[6...]))"
        case 10:
            return "(\(String(chars[0...2]))) \(String(chars[3...5]))-\(String(chars[6...9]))"
        default:
            return String(chars[0...9])
        }
    }
}

// MARK: - Sizing / Measurement
    
extension String {
    /// Returns the point width of a string for a given font
    func size(for font: UIFont) -> CGSize {
        return self.size(withAttributes: [NSAttributedString.Key.font: font])
    }
    
    func width(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
    
    func height(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.height
    }
}

// MARK: - Version logic

extension String {
    static func versionSort(lhs: String, rhs: String) -> Bool {
        let lhsComponents = lhs.versionComponents()
        let rhsComponents = rhs.versionComponents()
        
        // Ensure we have valid version numbers with 3 components
        guard lhsComponents.count == 3, rhsComponents.count == 3 else {
            return false
        }
        
        // Compare major version
        if lhsComponents[0] != rhsComponents[0] {
            return lhsComponents[0] < rhsComponents[0]
        }
        
        // Compare minor version
        if lhsComponents[1] != rhsComponents[1] {
            return lhsComponents[1] < rhsComponents[1]
        }
        
        // Compare patch version
        return lhsComponents[2] < rhsComponents[2]
    }
    
    private func versionComponents() -> [Int] {
        self.split(separator: ".").compactMap { Int($0) }
    }
    
    /// https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
    func versionCompare(_ v: String) -> ComparisonResult {
        return self.compare(v, options: .numeric)
    }
    
    func isGreaterThanOrEqualTo(version: String) -> Bool {
        // compare() returns .orderedAscending if self < version
        // returns .orderedSame if self == version
        // returns .orderedDescending if self > version
        
        //"2.0.0".isVersionGreaterThanOrEqualTo("1.9.9")  // true
        //"1.9.9".isVersionGreaterThanOrEqualTo("2.0.0")  // false
        //"2.0.0".isVersionGreaterThanOrEqualTo("2.0.0")  // true
        //"2.0.1".isVersionGreaterThanOrEqualTo("2.0.0")  // true
        //"2.0.0".isVersionGreaterThanOrEqualTo("2.0.1")  // false
        let comparison = self.compare(version, options: .numeric)
        return comparison == .orderedDescending || comparison == .orderedSame
    }
}

// MARK: - Golf Course Name

extension String {
    func prettifiedCourseTitle() -> String {
        // Step 1: Move "The", "A", or "An" to the front if needed
        let leadingArticles = ["The", "A", "An"]
        var trimmed = self
        for article in leadingArticles {
            let suffix = ", \(article)"
            if self.hasSuffix(suffix) {
                trimmed = "\(article) \(self.dropLast(suffix.count))"
                break
            }
        }

        // Step 2: Title case it with smart lowercasing of common words
        let lowercaseWords = ["a", "an", "the", "and", "but", "or", "nor", "for", "so", "yet", "at", "by", "in", "of", "on", "to", "up", "with", "as"]

        let words = trimmed.lowercased().split(separator: " ")
        let titledWords = words.enumerated().map { index, word -> String in
            if index == 0 || !lowercaseWords.contains(String(word)) {
                return word.capitalized
            } else {
                return String(word)
            }
        }

        return titledWords.joined(separator: " ")
    }
}

