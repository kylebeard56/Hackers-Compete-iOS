//
//  ColorPalette.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

/// Note: The term 'system' refers to it being dynamically swapping for light + dark mode schemes.
/// https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/color/
/// https://sarunw.com/posts/dark-color-cheat-sheet/

/// Conversion from UIColors
extension Color {
    /// Conversion of dynamic UIColor to Color
    static let systemRed = Color(.systemRed)
    static let systemOrange = Color(.systemOrange)
    static let systemYellow = Color(.systemYellow)
    static let systemGreen = Color(.systemGreen)
    static let systemBlue = Color(.systemBlue)
    static let systemPurple = Color(.systemPurple)
    static let systemIndigo = Color(.systemIndigo)
    static let systemCyan = Color(.systemCyan)
    static let systemPink = Color(.systemPink)
    static let systemTeal = Color(.systemTeal)
    static let systemMint = Color(.systemMint)
    static let systemBrown = Color(.systemBrown)
    
    static let systemGray = Color(.systemGray)
    static let systemGray2 = Color(.systemGray2)
    static let systemGray3 = Color(.systemGray3)
    static let systemGray4 = Color(.systemGray4)
    static let systemGray5 = Color(.systemGray5)
    static let systemGray6 = Color(.systemGray6)
    static let systemBackground = Color(.systemBackground)
    static let secondarySystemBackground = Color(.secondarySystemBackground)
    static let tertiarySystemBackground = Color(.tertiarySystemBackground)
    static let placeholderText = Color(.placeholderText)
    
    /// This should be used instead of .clear because it renders shape and allows tap gesture recognition.
    static let systemClear = Color.white.opacity(0.001)
    static let systemError = Color.systemPink.opacity(0.8)
}
