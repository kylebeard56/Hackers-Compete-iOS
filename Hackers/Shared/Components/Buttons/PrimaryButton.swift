//
//  HackersGrayStyle.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

//enum HackersGrayStyle {
//    /// Gray3 on Gray7
//    case ultralight
//    
//    /// Gray2 on Gray6
//    case light
//    
//    /// Gray on Gray5
//    case normal
//    
//    /// Charcoal on Gray4
//    case dark
//    
//    var text: Color {
//        switch self {
//        case .ultralight:   return .hackersGray3
//        case .light:        return .hackersGray2
//        case .normal:       return .hackersGray
//        case .dark:         return .hackersCharcoal
//        }
//    }
//    
//    var tint: Color {
//        switch self {
//        case .ultralight:   return .hackersGray7
//        case .light:        return .hackersGray6
//        case .normal:       return .hackersGray5
//        case .dark:         return .hackersGray4
//        }
//    }
//}

//enum HackersButtonAppearance {
//    case outline, fill
//    
//    func disabledText(for theme: PaletteTheme) -> Color {
//        return .neutral
//    }
//    
//    var disabledTint: Color {
//        switch self {
//        case .outline:  return HackersGrayStyle.light.tint
//        case .fill:     return HackersGrayStyle.normal.tint
//        }
//    }
//}

enum HackersButtonAppearance { case outline, fill }

struct PrimaryButton: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var appearance: HackersButtonAppearance = .fill
    var title: String?
    var callToActionText: String?
    var image: Image?
    var icon: String?
    var callToActionIcon: String?
    var iconWeight: FontModule.Weight?
    var fontName: FontModule.Name = kFontName
    var fontWeight: FontModule.Weight = .semibold
    var labelColor: Color?
    var buttonColor: Color?
    var borderColor: Color?
    var theme: PaletteTheme = .primary
    var height: CGFloat = 48
    var fillWidth: Bool = true
    var iconSize: CGFloat = 17
    var fontSize: CGFloat = 17
    var borderSize: CGFloat = 4
    var radius: CGFloat?
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: Callback?
    
    private func buttonTapped() {
        Haptics.fire(.light)
        onTap?()
    }
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    private var foreground: Color { isDisabled ? .neutral : labelColor ?? palette.foregroundColor }
    private var border: Color { borderColor ?? palette.foregroundColor }
    private var background: Color {
        switch appearance {
        case .outline:      return isDisabled ? palette.disabledButtonColor : .systemClear
        case .fill:         return isDisabled ? palette.disabledButtonColor : buttonColor ?? palette.backgroundColor
        }
    }
    
    var body: some View {
        Group {
            if appearance == .fill {
                Button(action: buttonTapped) {
                    button
                }
            }
            if appearance == .outline {
                Button(action: buttonTapped) {
                    button
                        .overlay(
                            Capsule()
                                .stroke(isDisabled ? Color.neutral5 : border, lineWidth: borderSize)
                        )
                }
            }
        }
        .buttonStyle(
            HackersButtonStyle(background: background, radius: radius)
        )
        .disabled(isDisabled)
    }
    
    private var button: some View {
        VStack(spacing: 0) {
            if callToActionText != nil || callToActionIcon != nil {
                HStack(spacing: 12) {
                    if let icon, let iconWeight {
                        Icon(name: icon, size: iconSize, maxSize: iconSize, weight: iconWeight)
                            .foregroundColor(foreground)
                    }
                    
                    if let title {
                        Text(title)
                            .fontStyle(fontName, size: fontSize, weight: fontWeight)
                            .foregroundColor(foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    
                    if fillWidth {
                        Spacer(minLength: 0)
                    }

                    if isLoading && !isDisabled {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: foreground.opacity(0.6)))
                    } else {
                        if let callToActionText {
                            Text(callToActionText)
                                .fontStyle(fontName, size: fontSize, weight: fontWeight)
                                .foregroundColor(foreground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        
                        if let callToActionIcon, let iconWeight {
                            Icon(name: callToActionIcon, size: iconSize, maxSize: iconSize, weight: iconWeight)
                                .foregroundColor(foreground)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                HStack(spacing: 12) {
                    if fillWidth {
                        Spacer(minLength: 0)
                    }
                    
                    if let image {
                        image
                            .interpolation(.high)
                            .resizable()
                            .scaledToFit()
                            .frame(height: iconSize)
                    }
                    
                    if let icon, let iconWeight {
                        Icon(name: icon, size: iconSize, maxSize: iconSize, weight: iconWeight)
                            .foregroundColor(foreground)
                    }
                    
                    if let title {
                        Text(title)
                            .fontStyle(fontName, size: fontSize, weight: fontWeight)
                            .foregroundColor(foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    
                    if isLoading && !isDisabled {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: foreground.opacity(0.6)))
                    }
                    
                    if fillWidth {
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
            }

        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(
            appearance: .fill,
            title: "Sign in with Apple",
            icon: "f179",
            iconWeight: .brand,
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            iconSize: 24,
            isDisabled: .false,
            isLoading: .false,
            onTap: { }
        )
        
        PrimaryButton(
            appearance: .fill,
            title: "Sign in with Apple",
            icon: "f179",
            iconWeight: .brand,
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            iconSize: 24,
            isDisabled: .true,
            isLoading: .false,
            onTap: { }
        )
        
        PrimaryButton(
            appearance: .outline,
            title: "Sign in with Google",
            image: Image("Google"),
            labelColor: .foregroundPrimary,
            buttonColor: .foregroundPrimary,
            iconSize: 22,
            isDisabled: .false,
            isLoading: .false,
            onTap: { }
        )
        
        PrimaryButton(
            appearance: .outline,
            title: "Sign in with Google",
            image: Image("Google"),
            labelColor: .backgroundPrimary,
            borderColor: .foregroundPrimary,
            iconSize: 22,
            isDisabled: .true,
            isLoading: .false,
            onTap: { }
        )
        
        PrimaryButton(
            appearance: .fill,
            title: "Continue with free trial",
            icon: nil,
            iconWeight: nil,
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            fillWidth: true,
            isDisabled: .false,
            isLoading: .false,
            onTap: {}
        )
        
        PrimaryButton(
            appearance: .fill,
            title: "Download",
            icon: nil,
            iconWeight: nil,
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            fillWidth: false,
            isDisabled: .false,
            isLoading: .false,
            onTap: {}
        )
        
        PrimaryButton(
            appearance: .fill,
            title: "The Preserve at Verdae",
            callToActionIcon: "f178",
            iconWeight: .solid,
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            fillWidth: true,
            isDisabled: .false,
            isLoading: .false,
            onTap: {}
        )
        
        PrimaryButton(
            appearance: .fill,
            title: "The Preserve at Verdae",
            callToActionText: "Edit",
            iconWeight: nil,
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            fillWidth: true,
            isDisabled: .false,
            isLoading: .false,
            onTap: {}
        )
    }
    .alignMiddle()
    .padding(16)
    .background(Color.backgroundPrimary)
}
