//
//  Font.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

/// Below is an example of how to integrate a custom font

enum CustomFontWeight: String {
    case regular = "DM Sans Regular"
    case medium = "DM Sans Medium"
    case bold = "DM Sans Bold"
}

extension Font {
    static func dmSans(size: CGFloat, weight: CustomFontWeight = .regular, italics: Bool = false) -> Font {
        let customFont: String = "\(weight.rawValue)\(italics ? "Italic" : "")"
        return Font.custom(customFont, size: size)
    }
}

extension UIFont {
    static func dmSans(size: CGFloat, weight: CustomFontWeight = .regular, italics: Bool = false) -> UIFont {
        let customFont: String = "\(weight.rawValue)\(italics ? "Italic" : "")"
        return UIFont(name: customFont, size: size) ?? UIFont.systemFont(ofSize: size)
    }
}
