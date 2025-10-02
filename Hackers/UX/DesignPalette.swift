//
//  DesignPalette.swift
//  Hackers
//
//  Created by Kyle Beard on 10/2/25.
//

import SwiftUI

enum PaletteTheme {
    case primary, secondary
    
    // TODO: Setup folders for primary and secondary colors
    var backgroundColor: Color {
        switch self {
        case .primary: return .hackersBackground
        case .secondary: return .boxFoxBackground
        }
    }
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
    
    var buttonColor: Color {
        switch (theme, scheme) {
        case (.primary, .light):        return .hackersGray6
        case (.primary, .dark):         return .hackersGray4
        case (.secondary, .light):      return .hackersGray5
        case (.secondary, .dark):       return .hackersGray5
        default:                        return .systemError
        }
    }
}
