//
//  DesignPalette.swift
//  Hackers
//
//  Created by Kyle Beard on 10/2/25.
//

import SwiftUI

enum PaletteTheme {
    case glass, primary, secondary
    
    var backgroundColor: Color {
        switch self {
        case .primary, .glass:      return .backgroundPrimary
        case .secondary:            return .backgroundSecondary
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .glass:      return .foregroundPrimary
        case .secondary:            return .foregroundSecondary
        }
    }
    
    var cardColor: Color {
        switch self {
        case .primary, .glass:      return .cardPrimary
        case .secondary:            return .cardSecondary
        }
    }
    
    var borderColor: Color {
        switch self {
        case .primary, .glass:      return .neutral5
        case .secondary:            return .neutral4
        }
    }

    func palette(for colorScheme: ColorScheme) -> DesignPalette { .init(theme: self, scheme: colorScheme) }
}

struct DesignPalette {
    let theme: PaletteTheme
    let scheme: ColorScheme
    
    init(theme: PaletteTheme, scheme: ColorScheme) {
        self.theme = theme
        self.scheme = scheme
    }
}

extension DesignPalette {
    var backgroundColor: Color { theme.backgroundColor }
    var foregroundColor: Color { theme.foregroundColor }
    var cardColor: Color { theme.cardColor }
    var borderColor: Color { theme.borderColor }
    
    var buttonColor: Color {
        switch (theme, scheme) {
        case (.glass, .light):          return .neutral6
        case (.glass, .dark):           return .neutral4
        case (.primary, .light):        return .neutral6
        case (.primary, .dark):         return .neutral4
        case (.secondary, .light):      return .neutral5
        case (.secondary, .dark):       return .neutral5
        default:                        return .systemError
        }
    }
    
    /// Glass effect tint for buttons/chips: 0% opacity in light mode, 37.5% in dark mode.
    var glassButtonColor: Color {
//        buttonColor.opacity(scheme, 0, 0.375)
        scheme.isLight ? Color.neutral6 : Color.neutral.opacity(0.375)
    }
    
    var bannerColor: Color { buttonColor } // Convenience variable alias for buttonColor
    
    var whiteGlassButtonColor: Color {
        scheme.isLight ? Color.white.opacity(0.8) : Color.neutral.opacity(0.375)
    }
    
    var shadowColor: Color {
        scheme.isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06)
    }
    
    var disabledButtonColor: Color {
        switch (theme, scheme) {
        case (.glass, .light):          return .neutral6
        case (.glass, .dark):           return .neutral5
        case (.primary, .light):        return .neutral6
        case (.primary, .dark):         return .neutral5
        case (.secondary, .light):      return .neutral5
        case (.secondary, .dark):       return .neutral4
        default:                        return .systemError
        }
    }
    
    var skeletonColor: Color {
        switch (theme, scheme) {
        case (.glass, .light):          return .neutral3
        case (.glass, .dark):           return .neutral2
        case (.primary, .light):        return .neutral5
        case (.primary, .dark):         return .neutral4
        case (.secondary, .light):      return .neutral4
        case (.secondary, .dark):       return .neutral3
        default:                        return .systemError
        }
    }
    
    var skeletonBackground: Color {
        switch (theme, scheme) {
        case (.glass, .light):          return .neutral5
        case (.glass, .dark):           return .neutral4
        case (.primary, .light):        return .neutral4
        case (.primary, .dark):         return .neutral3
        case (.secondary, .light):      return .neutral5
        case (.secondary, .dark):       return .neutral4
        default:                        return .systemError
        }
    }
    
    var textField: Color {
        Color.systemClear
    }
    
    var disabledTextField: Color {
        switch (theme, scheme) {
        case (.glass, .light):          return .neutral6
        case (.glass, .dark):           return .neutral5 // try 4 if weird
        case (.primary, .light):        return .neutral6
        case (.primary, .dark):         return .neutral5 // try 4 if weird
        case (.secondary, .light):      return .neutral5
        case (.secondary, .dark):       return .neutral4
        default:                        return .systemError
        }
    }
    
    var searchBar: Color {
        switch (theme, scheme) {
        case (.glass, .light):          return .neutral6
        case (.glass, .dark):           return .neutral6
        case (.primary, .light):        return .neutral6
        case (.primary, .dark):         return .neutral6
        case (.secondary, .light):      return .neutral5
        case (.secondary, .dark):       return .neutral5
        default:                        return .systemError
        }
    }
}
