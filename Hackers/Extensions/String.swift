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
