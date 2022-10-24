//
//  ColorPalette.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import SwiftUI

/// Note: The term 'system' refers to it being dynamically swapping for light + dark mode schemes.
/// https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/color/

/// Conversion from UIColors
extension Color {
    /// Conversion of dynamic UIColor to Color
    static let systemRed = Color(.systemRed)
    static let systemOrange = Color(.systemOrange)
    static let systemYellow = Color(.systemYellow)
    static let systemGreen = Color(.systemGreen)
    static let systemBlue = Color(.systemBlue)
    static let systemPurple = Color(.systemPurple)
    static let systemGray = Color(.systemGray)
    static let systemGray2 = Color(.systemGray2)
    static let systemGray3 = Color(.systemGray3)
    static let systemGray4 = Color(.systemGray4)
    static let systemGray5 = Color(.systemGray5)
    static let systemGray6 = Color(.systemGray6)
    static let systemBackground = Color(.systemBackground)
    static let placeholderText = Color(.placeholderText)

    /// Custom colors from `Colors.xcassets`
    static let systemBlack = Color(.systemBlack)
    static let systemCard = Color(.systemCard)
//    static let systemDarkGray = Color(.systemDarkGray)
//    static let systemSearchBar = Color(.systemSearchBar)
    static let systemWhite = Color(.systemWhite)
//    static let systemOffWhite = Color(.systemOffWhite)
//    static let midnight = Color(.midnight)
    
    /// This should be used instead of .clear because it renders shape and allows tap gesture recognition.
    static let systemClear = Color.white.opacity(0.001)
}

extension UIColor {
    /// Light: black, Dark: white
    static let systemBlack = UIColor(named: "SystemBlack")!

    /// Light: white, Dark: systemGray5
    static let systemCard = UIColor(named: "SystemCard")!

//    /// Inverse of systemGray5
//    static let systemDarkGray = UIColor(named: "SystemDarkGray")!
//
//    /// Light: systemGray6, Dark: systemGray5
//    static let systemSearchBar = UIColor(named: "SystemSearchBar")!
//
    /// Light: white, Dark: black
    static let systemWhite = UIColor(named: "SystemWhite")!

//    /// Light: near white, Dark: systemBackground
//    static let systemOffWhite = UIColor(named: "SystemOffWhite")!
//
//    /// Non-system color that is near black
//    static let midnight = UIColor(named: "Midnight")!
}
