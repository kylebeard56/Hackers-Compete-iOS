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
    
    var bannerColor: Color { buttonColor } // Convenience variable alias for buttonColor
    
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
