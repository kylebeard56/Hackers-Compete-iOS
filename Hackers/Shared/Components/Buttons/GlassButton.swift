//
//  GlassButton.swift
//  Hackers
//
//  Created by Kyle Beard on 12/30/25.
//

import SwiftUI

struct GlassButton: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Content
    var title: String?
    var callToActionText: String?
    var image: Image?
    var icon: String?
    var callToActionIcon: String?
    var iconWeight: FontModule.Weight?

    // MARK: Typography
    var fontName: FontModule.Name = kFontName
    var fontWeight: FontModule.Weight = .semibold
    var labelColor: Color?
    var tintColor: Color?
    var loaderColor: Color = .neutral

    // MARK: Fallback Glass (iOS < 26)
    var material: Material = .ultraThinMaterial

    // MARK: Layout
    var height: CGFloat = 48
    var fillWidth: Bool = true
    var iconSize: CGFloat = 17
    var fontSize: CGFloat = 17

    // MARK: State
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool

    // MARK: Action
    var onTap: Callback?

    // MARK: Derived

    private var foreground: Color {
        if isDisabled { return .neutral }
        return labelColor ?? .primary
    }

    // MARK: Actions

    private func buttonTapped() {
        guard !isDisabled else { return }
        Haptics.fire(.light)
        onTap?()
    }

    // MARK: Body

    var body: some View {
        button
            .glassCardEffect(
                shape: .capsule,
                interactive: true,
                tint: tintColor
            )
    }
    
    private var button: some View {
        Button(action: buttonTapped) {
            content
        }
        .disabled(isDisabled)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            if callToActionText != nil || callToActionIcon != nil {
                actionRow
            } else {
                standardRow
            }
        }
        .frame(height: height)
        .contentShape(Capsule())
    }

    private var standardRow: some View {
        HStack(spacing: 12) {
            if fillWidth { Spacer(minLength: 0) }

            leadingContent

            if let title {
                Text(title)
                    .fontStyle(fontName, size: fontSize, weight: fontWeight)
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if isLoading && !isDisabled {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: loaderColor))
            }

            if fillWidth { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 16)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            leadingContent

            if let title {
                Text(title)
                    .fontStyle(fontName, size: fontSize, weight: fontWeight)
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if fillWidth { Spacer(minLength: 0) }

            trailingAction
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var leadingContent: some View {
        if let image {
            image
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(height: iconSize)
        }

        if let icon, let iconWeight {
            Icon(
                name: icon,
                size: iconSize,
                maxSize: iconSize,
                weight: iconWeight
            )
            .foregroundColor(foreground)
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        if isLoading && !isDisabled {
            ProgressView()
                .progressViewStyle(
                    CircularProgressViewStyle(
                        tint: foreground.opacity(0.6)
                    )
                )
        } else {
            if let callToActionText {
                Text(callToActionText)
                    .fontStyle(fontName, size: fontSize, weight: fontWeight)
                    .foregroundColor(foreground)
            }

            if let callToActionIcon, let iconWeight {
                Icon(
                    name: callToActionIcon,
                    size: iconSize,
                    maxSize: iconSize,
                    weight: iconWeight
                )
                .foregroundColor(foreground)
            }
        }
    }
}

#Preview {
    GlassButtonPreview()
}

private struct GlassButtonPreview: View {
    @State private var disabled = false
    @State private var loading = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            GlassButton(
                title: "Join with code",
                labelColor: .primary,
                isDisabled: $disabled,
                isLoading: $loading,
                onTap: {}
            )

            GlassButton(
                title: "Prominent Glass",
                labelColor: .primary,
                tintColor: .accentGreen.opacity(0.6),
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTap: {}
            )

            GlassButton(
                title: "Loading",
                labelColor: .primary,
                isDisabled: .constant(false),
                isLoading: .constant(true),
                onTap: {}
            )

            GlassButton(
                title: "Disabled",
                labelColor: .primary,
                isDisabled: .constant(true),
                isLoading: .constant(false),
                onTap: {}
            )
            
            GlassButton(
                title: "See more",
                labelColor: .primary,
                fillWidth: false,
                isDisabled: $disabled,
                isLoading: $loading,
                onTap: {}
            )
            
            Spacer()
        }
        .padding(20)
        .background(GolfTopology())
    }
}
