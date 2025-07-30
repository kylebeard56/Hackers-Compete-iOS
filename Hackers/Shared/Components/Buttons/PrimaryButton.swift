//
//  HackersGrayStyle.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

enum HackersGrayStyle {
    /// Gray3 on Gray7
    case ultralight
    
    /// Gray2 on Gray6
    case light
    
    /// Gray on Gray5
    case normal
    
    /// Charcoal on Gray4
    case dark
    
    var text: Color {
        switch self {
        case .ultralight:   return .hackersGray3
        case .light:        return .hackersGray2
        case .normal:       return .hackersGray
        case .dark:         return .hackersCharcoal
        }
    }
    
    var tint: Color {
        switch self {
        case .ultralight:   return .hackersGray7
        case .light:        return .hackersGray6
        case .normal:       return .hackersGray5
        case .dark:         return .hackersGray4
        }
    }
}

enum HackersButtonAppearance {
    case outline, fill
    
    var disabledText: Color {
        return HackersGrayStyle.normal.text
    }
    
    var disabledTint: Color {
        switch self {
        case .outline:  return HackersGrayStyle.light.tint
        case .fill:     return HackersGrayStyle.normal.tint
        }
    }
}

struct PrimaryButton: View {
    var appearance: HackersButtonAppearance = .fill
    var title: String?
    var image: Image?
    var icon: String?
    var iconWeight: FontModule.Weight?
    var fontName: FontModule.Name = kFontName
    var fontWeight: FontModule.Weight = .semibold
    var labelColor: Color = .hackersBackground
    var buttonColor: Color = .hackersForeground
    var borderColor: Color = .hackersGray5
    var height: CGFloat = 48
    var fillWidth: Bool = true
    var iconSize: CGFloat = 17
    var fontSize: CGFloat = 17
    var borderSize: CGFloat = 4
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: () -> Void
    
    private var radius: CGFloat {
        height / 2
    }
    
    private func buttonTapped() {
        Haptics.fire(.light)
        onTap()
    }
    
    private var foreground: Color {
        return isDisabled ? appearance.disabledText : labelColor
    }
    
    private var background: Color {
        switch appearance {
        case .outline:  return isDisabled ? appearance.disabledTint : .systemClear
        case .fill:    return isDisabled ? appearance.disabledTint : buttonColor
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
                                .stroke(isDisabled ? Color.hackersGray5 : borderColor, lineWidth: borderSize)
                        )
                }
            }
        }
        .buttonStyle(
            HackersButtonStyle(background: background)
        )
        .disabled(isDisabled)
    }
    
    private var button: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
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
                        .progressViewStyle(CircularProgressViewStyle(tint: labelColor.opacity(0.6)))
                }
                
                if fillWidth {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, radius)
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
            labelColor: .hackersBackground,
            buttonColor: .hackersForeground,
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
            labelColor: .hackersBackground,
            buttonColor: .hackersForeground,
            iconSize: 24,
            isDisabled: .true,
            isLoading: .false,
            onTap: { }
        )
        
        PrimaryButton(
            appearance: .outline,
            title: "Sign in with Google",
            image: Image("Google"),
            labelColor: .hackersForeground,
            buttonColor: .hackersBackground,
            iconSize: 22,
            isDisabled: .false,
            isLoading: .false,
            onTap: { }
        )
        
        PrimaryButton(
            appearance: .outline,
            title: "Sign in with Google",
            image: Image("Google"),
            labelColor: .hackersForeground,
            buttonColor: .hackersBackground,
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
            labelColor: .hackersBackground,
            buttonColor: .hackersForeground,
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
            labelColor: .hackersBackground,
            buttonColor: .hackersForeground,
            fillWidth: false,
            isDisabled: .false,
            isLoading: .false,
            onTap: {}
        )
    }
    .alignMiddle()
    .padding(16)
    .background(Color.hackersBackground)
}
