//
//  String.swift
//  Hackers
//
//  Created by Kyle Beard on 11/14/22.
//

import Foundation
import UIKit

extension String {
    static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    
    var isValidEmail: Bool {
        return NSPredicate(format:"SELF MATCHES %@", String.emailRegex).evaluate(with: self)
      }
    
    var unicode: String? {
        if let c = UInt32(self, radix: 16), let u = UnicodeScalar(c) {
            return String(u)
        }
        return nil
    }
    
    var unicodeEscaped: String? {
        return self.flatMap(\.unicodeScalars).compactMap({ $0.escaped(asASCII: true) }).first
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
    
    var dateFromISO8601: Date {
        if let secDate = self.dateFromISO8601Seconds {
            return secDate
        }
        if let milliDate = self.dateFromISO8601Milliseconds {
            return milliDate
        }
        return Date()
    }
    
    private var dateFromISO8601Seconds: Date? {
        return ISO8601DateFormatter().date(from: self)
    }
    
    private var dateFromISO8601Milliseconds: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            ISO8601DateFormatter.Options.withFractionalSeconds,
            ISO8601DateFormatter.Options.withInternetDateTime
        ]
        return formatter.date(from: self)
    }
    
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
    
    /// https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
    func versionCompare(_ v: String) -> ComparisonResult {
        return self.compare(v, options: .numeric)
    }
}
