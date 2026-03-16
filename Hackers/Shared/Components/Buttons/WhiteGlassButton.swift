//
//  WhiteGlassButton.swift
//  Hackers
//
//  Created by Kyle Beard on 3/16/26.
//

import SwiftUI

struct WhiteGlassButtonEffect: ViewModifier {
    var palette: DesignPalette
    var padding: (horizontal: CGFloat, vertical: CGFloat)
    var tint: Color
    var fontSize: CGFloat
    
    func body(content: Content) -> some View {
        content
            .fontStyle(kFontName, size: fontSize, weight: .semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, padding.horizontal)
            .padding(.vertical, padding.vertical)
            .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
            .shadow(color: palette.shadowColor, radius: 10, x: 0, y: 0)
    }
}

extension View {
    func whiteGlassButton(
        palette: DesignPalette,
        padding: (horizontal: CGFloat, vertical: CGFloat) = (16, 8),
        tint: Color = Color.accentGreen,
        fontSize: CGFloat = 15,
    ) -> some View {
        return modifier(
            WhiteGlassButtonEffect(palette: palette, padding: padding, tint: tint, fontSize: fontSize)
        )
    }
}
