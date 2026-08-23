//
//  ColorScheme.swift
//  Hackers
//
//  Created by Kyle Beard on 7/14/25.
//

import SwiftUI

/// This is used to shorthand map a color
enum ColorSchemeGrayShade {
    case white
    case gray
    case gray2
    case gray3
    case gray4
    case gray5
    case gray6
//    case gray7
    
    var color: Color {
        switch self {
        case .white:    return .white
        case .gray:     return .neutral
        case .gray2:    return .neutral2
        case .gray3:    return .neutral3
        case .gray4:    return .neutral4
        case .gray5:    return .neutral5
        case .gray6:    return .neutral6
//        case .gray7:    return .neutral7
        }
    }
}

extension ColorScheme {
    var isLight: Bool { self == .light }
    var isDark: Bool { self == .dark }
    
    var opposite: ColorScheme {
        isLight ? .dark : .light
    }
    
    var blurStyle: UIBlurEffect.Style {
        self.isLight ? .light : .dark
    }
    
    var translucent: CGFloat {
        self.isLight ? 0.1 : 0.25
    }
    
    var ultraTranslucent: CGFloat {
        translucent / 2.5
    }
    
    func translucent(_ light: CGFloat, _ dark: CGFloat) -> CGFloat {
        self.isLight ? light : dark
    }
    
    func set(_ light: ColorSchemeGrayShade, _ dark: ColorSchemeGrayShade) -> Color {
        self.isLight ? light.color : dark.color
    }
    
    func accentGreenBackgroundGradient() -> LinearGradient {
        switch self {
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 31/255, green: 77/255, blue: 42/255), // #1F4D2A
                    Color(red: 46/255, green: 106/255, blue: 60/255) // #2E6A3C
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        default: // .light
            return LinearGradient(
                colors: [
                    Color(red: 230/255, green: 241/255, blue: 234/255), // #E6F1EA
                    Color(red: 211/255, green: 230/255, blue: 218/255)  // #D3E6DA
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension Color {
    func opacity(_ colorScheme: ColorScheme, _ light: CGFloat, _ dark: CGFloat) -> Color {
        self.opacity(colorScheme.translucent(light, dark))
    }
}
