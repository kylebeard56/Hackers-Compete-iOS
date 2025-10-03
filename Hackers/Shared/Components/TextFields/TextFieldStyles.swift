//
//  TextFieldStyles.swift
//  Hackers
//
//  Created by Kyle Beard on 9/17/25.
//

import Foundation
import SwiftUI

struct HackersTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    
    let theme: PaletteTheme
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let foregroundColor: Color?
    let backgroundColor: Color?
    let fontSize: CGFloat
    let fontWeight: FontModule.Weight
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var foreground: Color { foregroundColor ?? palette.foregroundColor }
    private var background: Color { backgroundColor ?? palette.backgroundColor }
    
    init(
        theme: PaletteTheme = .primary,
        cornerRadius: CGFloat = 12,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 12,
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil,
        fontSize: CGFloat = 17,
        fontWeight: FontModule.Weight = .regular
    ) {
        self.theme = theme
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .fontStyle(.poppins, size: fontSize, weight: fontWeight)
            .foregroundStyle(foreground)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(background)
            .cornerRadius(cornerRadius)
    }
}

