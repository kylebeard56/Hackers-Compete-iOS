//
//  ColorPalette.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
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

    /// Custom colors from `Colors.xcassets`
    static let systemBlack = Color(.systemBlack)
    static let systemCard = Color(.systemCard)
    static let systemGrayDark = Color(.systemGrayDark)
    static let systemMarquee = Color(.systemMarquee)
    static let systemWhite = Color(.systemWhite)
    static let systemViewBackground = Color(.systemViewBackground)
    static let systemGold = Color(.systemGold)
    static let systemBlackButton = Color(.systemBlackButton)
    
    /// This should be used instead of .clear because it renders shape and allows tap gesture recognition.
    static let systemClear = Color.white.opacity(0.001)
}

extension UIColor {
    /// Light: black, Dark: white
    static let systemBlack = UIColor(named: "SystemBlack")!

    /// Light: white, Dark: systemGray5
    static let systemCard = UIColor(named: "SystemCard")!

    /// Subtle dark gray
    static let systemGrayDark = UIColor(named: "SystemGrayDark")!
    
    /// System brown with 5% opacity
    static let systemMarquee = UIColor(named: "SystemMarquee")!
    
    /// Light: white, Dark: black
    static let systemWhite = UIColor(named: "SystemWhite")!
    
    static let systemViewBackground = UIColor(named: "SystemViewBackground")!
    
    static let systemPageIndicator = UIColor(named: "SystemPageIndicator")!
    
    static let systemGold = UIColor(named: "SystemGold")!
    
    static let systemBlackButton = UIColor(named: "SystemBlackButton")!
}
