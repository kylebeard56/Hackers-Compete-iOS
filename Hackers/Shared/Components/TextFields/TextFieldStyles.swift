//
//  TextFieldStyles.swift
//  Hackers
//
//  Created by Kyle Beard on 9/17/25.
//

import Foundation
import SwiftUI

//struct HackersTextFieldStyle: TextFieldStyle {
//    @Environment(\.colorScheme) var colorScheme
//    
//    let theme: PaletteTheme
//    let cornerRadius: CGFloat
//    let horizontalPadding: CGFloat
//    let verticalPadding: CGFloat
//    let foregroundColor: Color?
//    let backgroundColor: Color?
//    let fontSize: CGFloat
//    let fontWeight: FontModule.Weight
//    
//    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
//    private var foreground: Color { foregroundColor ?? palette.foregroundColor }
//    private var background: Color { backgroundColor ?? palette.backgroundColor }
//    
//    init(
//        theme: PaletteTheme = .primary,
//        cornerRadius: CGFloat = 12,
//        horizontalPadding: CGFloat = 16,
//        verticalPadding: CGFloat = 12,
//        foregroundColor: Color? = nil,
//        backgroundColor: Color? = nil,
//        fontSize: CGFloat = 17,
//        fontWeight: FontModule.Weight = .regular
//    ) {
//        self.theme = theme
//        self.cornerRadius = cornerRadius
//        self.horizontalPadding = horizontalPadding
//        self.verticalPadding = verticalPadding
//        self.foregroundColor = foregroundColor
//        self.backgroundColor = backgroundColor
//        self.fontSize = fontSize
//        self.fontWeight = fontWeight
//    }
//    
//    func _body(configuration: TextField<Self._Label>) -> some View {
//        configuration
//            .fontStyle(kFontName, size: fontSize, weight: fontWeight)
//            .foregroundStyle(foreground)
//            .padding(.vertical, verticalPadding)
//            .padding(.horizontal, horizontalPadding)
//            .background(background)
//            .cornerRadius(cornerRadius)
//    }
//}

struct BorderedContentModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var isActive: Bool
    var isDisabled: Bool
    var theme: PaletteTheme
    var color: Color?
    /// When set (e.g. `cardEmbeddedRowBackground`), replaces `palette.textField` for fields on card surfaces.
    var fill: Color?
    var error: String
    
    private let radius: CGFloat = 10
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    private var backgroundColor: Color {
        if isDisabled { return palette.disabledTextField }
        if let fill { return fill }
        return palette.textField
    }
    private var borderColor: Color {
        if !error.isEmpty {
            return .systemError
        } else if isActive {
            return color ?? palette.foregroundColor
        } else {
            return palette.borderColor
        }
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            if !error.isEmpty {
                Text(error)
                    .fontStyle(size: 12)
                    .foregroundColor(Color.systemError)
                    .alignLeading()
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .border(borderColor, width: isActive ? 4 : 2, cornerRadius: radius)
        .cornerRadius(radius)
        .disabled(isDisabled)
    }
}

struct UnderlinedContentModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var isActive: Binding<Bool>
    var isDisabled: Bool
    var theme: PaletteTheme
    var success: String
    var error: String
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    
    var lineColor: Color {
        if isDisabled {
            return Color.neutral
        } else if isActive.wrappedValue {
            if success.isPopulated {
                return Color.systemGreen
            } else if error.isPopulated {
                return Color.systemError
            } else {
                return palette.foregroundColor
            }
        } else {
            return palette.borderColor
        }
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            
            RoundedRectangle(cornerRadius: 2, style: .circular)
                .fill(lineColor)
                .frame(height: isActive.wrappedValue || !error.isEmpty ? 3 : 2)

            if !success.isEmpty {
                Text(success)
                    .fontStyle(size: 14, weight: .medium)
                    .foregroundColor(Color.accentGreen)
                    .alignLeading()
                    .padding(.top, 4)
            }
            
            if !error.isEmpty {
                Text(error)
                    .fontStyle(size: 14, weight: .medium)
                    .foregroundColor(Color.systemError)
                    .alignLeading()
                    .padding(.top, 4)
            }
        }
        .disabled(isDisabled)
    }
}

extension View {
    func borderedContentStyle(
        isActive: Bool = false,
        isDisabled: Bool = false,
        theme: PaletteTheme = .primary,
        color: Color? = nil,
        fill: Color? = nil,
        error: String = "",
    ) -> some View {
        return modifier(
            BorderedContentModifier(
                isActive: isActive,
                isDisabled: isDisabled,
                theme: theme,
                color: color,
                fill: fill,
                error: error
            )
        )
    }
    
    func underlinedContentStyle(
        isActive: Binding<Bool> = .false,
        isDisabled: Bool = false,
        theme: PaletteTheme = .primary,
        success: String = "",
        error: String = "",
    ) -> some View {
        return modifier(
            UnderlinedContentModifier(
                isActive: isActive,
                isDisabled: isDisabled,
                theme: theme,
                success: success,
                error: error
            )
        )
    }
}

#Preview {
    VStack {}
}
