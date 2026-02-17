//
//  SecondaryButton.swift
//  Hackers
//
//  Created by Kyle Beard on 9/30/25.
//

import SwiftUI

struct SecondaryButton: View {
    @Environment(\.colorScheme) var colorScheme
    
    var text: String
    var icon: String?
    var weight: FontModule.Weight?
    var labelColor: Color?
    var buttonColor: Color?
    var theme: PaletteTheme = .primary
    var height: CGFloat = 36
    var fillWidth: Bool = true
    var iconSize: CGFloat = 15
    var fontSize: CGFloat = 15
    var radius: CGFloat = 10
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool
    
    var onTap: Callback?
    
    private func buttonTapped() {
        Haptics.fire(.light)
        onTap?()
    }
    
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    private var foreground: Color { isDisabled ? .neutral : labelColor ?? palette.foregroundColor }
    private var background: Color { isDisabled ? .neutral6 : buttonColor ?? palette.backgroundColor }
    
    var body: some View {
        Button(action: buttonTapped) {
            button
        }
        .buttonStyle(
            HackersSecondaryButtonStyle(background: background, radius: radius)
        )
        .disabled(isDisabled)
    }
    
    private var button: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if fillWidth {
                    Spacer(minLength: 0)
                }
                
                if let icon, let weight {
                    Icon(name: icon, size: iconSize, maxSize: iconSize, weight: weight)
                        .foregroundColor(foreground)
                }
                
                Text(text)
                    .fontStyle(kFontName, size: fontSize , weight: .semibold)
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
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
        .frame(height: height)
    }
}

import Flow

#Preview {
    ZStack {
        Color.backgroundPrimary
        
        VStack(spacing: 16) {
            HFlow(spacing: 8) {
                Chip(text: "Today")
                Chip(text: "Tomorrow", style: .outline)
                Chip(text: "Thursday", style: .outline)
                Chip(text: "Friday", style: .outline)
                Chip(text: "Saturday", style: .outline)
            }
            .alignLeading()
            
            SecondaryButton(
                text: "See more options",
                isDisabled: .false,
                isLoading: .false,
                onTap: { }
            )
        }
        .padding(16)
        .alignTop()
    }
}
