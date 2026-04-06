//
//  HackersGrayStyle.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

// MARK: - Enums

enum HackersButtonAppearance {
    case outline
    case fill
    case liquid
}

enum HackersOutlineStyle {
    case solid
    case dotted
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Appearance
    var appearance: HackersButtonAppearance = .fill
    var outlineStyle: HackersOutlineStyle = .solid

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

    // MARK: Colors
    var buttonColor: Color?
    var borderColor: Color?

    // MARK: Liquid
    var liquidMaterial: Material = .ultraThinMaterial
    var liquidTint: Color? = nil

    // MARK: Theme / Layout
    var theme: PaletteTheme = .primary
    var height: CGFloat = 48
    var fillWidth: Bool = true
    var iconSize: CGFloat = 17
    var fontSize: CGFloat = 17
    var borderSize: CGFloat = 4
    var radius: CGFloat?

    // MARK: State
    @Binding var isDisabled: Bool
    @Binding var isLoading: Bool

    // MARK: Action
    var onTap: Callback?
    var onTapAsync: AsyncCallback?

    // MARK: Derived

    private var palette: DesignPalette {
        theme.palette(for: colorScheme)
    }

    private var resolvedRadius: CGFloat {
        radius ?? height / 2
    }

    private var foreground: Color {
        if isDisabled { return .neutral }
        return labelColor ?? palette.foregroundColor
    }

    private var backgroundColor: Color {
        switch appearance {
        case .outline:
            return isDisabled ? palette.disabledButtonColor : .systemClear
        case .fill:
            return isDisabled
                ? palette.disabledButtonColor
                : buttonColor ?? palette.backgroundColor
        case .liquid:
            return .clear
        }
    }

    private var border: Color {
        borderColor ?? palette.foregroundColor
    }

    // MARK: Actions

    private func buttonTapped() {
        guard !isDisabled, !isLoading else { return }
        Haptics.fire(.light)
        onTap?()
        Task { await onTapAsync?() }
    }

    // MARK: Body

    var body: some View {
        Button(action: buttonTapped) {
            buttonContent
                .background { liquidBackground }
        }
        .buttonStyle(
            HackersButtonStyle(
                background: backgroundColor,
                radius: resolvedRadius
            )
        )
        .overlay {
            if appearance == .outline {
                outlineOverlay
            }
        }
        .disabled(isDisabled)
    }

    // MARK: Button Content

    private var buttonContent: some View {
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

            if isLoading {
                ProgressView()
                    .progressViewStyle(
                        CircularProgressViewStyle(
                            tint: foreground.opacity(0.6)
                        )
                    )
            }

            if fillWidth { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Subcomponents

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
        if isLoading {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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

    // MARK: Liquid Background

    @ViewBuilder
    private var liquidBackground: some View {
        if appearance == .liquid {

            if #available(iOS 26, *) {
                // iOS 26+ TRUE Liquid Glass
                Capsule()
                    .fill(.clear)
                    .glassEffect(
                        .regular.interactive(),
                        in: .capsule
                    )

            } else {
                // iOS ≤25 Fallback (Material-based glass)
                Capsule()
                    .fill(liquidMaterial)
                    .overlay {
                        // Specular lift (makes it feel lighter than ultraThin)
                        Capsule()
                            .fill(
                                Color.white.opacity(
                                    colorScheme == .dark ? 0.12 : 0.30
                                )
                            )
                    }
                    .overlay {
                        // Optional brand tint
                        if let liquidTint {
                            Capsule()
                                .fill(
                                    liquidTint.opacity(
                                        colorScheme == .dark ? 0.20 : 0.14
                                    )
                                )
                        }
                    }
                    .overlay {
                        // Inner highlight
                        Capsule()
                            .inset(by: 1)
                            .stroke(
                                Color.white.opacity(
                                    colorScheme == .dark ? 0.30 : 0.45
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.overlay)
                    }
                    .shadow(
                        color: .black.opacity(0.06),
                        radius: 12,
                        y: 8
                    )
            }
        }
    }

    // MARK: Outline

    private var outlineOverlay: some View {
        Capsule()
            .stroke(
                isDisabled ? Color.neutral5 : border,
                style: strokeStyle
            )
    }

    private var strokeStyle: StrokeStyle {
        switch outlineStyle {
        case .solid:
            return StrokeStyle(lineWidth: borderSize)
        case .dotted:
            return StrokeStyle(
                lineWidth: borderSize,
                lineCap: .round,
                dash: [0, borderSize * 2]
            )
        }
    }
}

#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @State private var disabled = false
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Fill

                PrimaryButton(
                    appearance: .fill,
                    title: "Primary Action",
                    icon: "f178",
                    iconWeight: .solid,
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    isDisabled: $disabled,
                    isLoading: $loading,
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .fill,
                    title: "Loading State",
                    icon: "f178",
                    iconWeight: .solid,
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    isDisabled: .constant(false),
                    isLoading: .constant(true),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .fill,
                    title: "Disabled Fill",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    isDisabled: .constant(true),
                    isLoading: .constant(false),
                    onTap: {}
                )

                Divider().padding(.vertical, 8)

                // MARK: - Outline

                PrimaryButton(
                    appearance: .outline,
                    title: "Outline Button",
                    image: Image("Google"),
                    labelColor: .foregroundPrimary,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .outline,
                    outlineStyle: .dotted,
                    title: "Dotted Outline",
                    labelColor: .foregroundPrimary,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .outline,
                    title: "Disabled Outline",
                    labelColor: .foregroundPrimary,
                    borderColor: .foregroundPrimary,
                    isDisabled: .constant(true),
                    isLoading: .constant(false),
                    onTap: {}
                )

                Divider().padding(.vertical, 8)

                // MARK: - Liquid (Glass)

                PrimaryButton(
                    appearance: .liquid,
                    title: "Glass Primary",
                    icon: "f178",
                    iconWeight: .solid,
                    labelColor: .foregroundPrimary,
                    liquidMaterial: .ultraThinMaterial,
                    liquidTint: .accentGreen,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .liquid,
                    title: "Subtle Glass",
                    labelColor: .foregroundPrimary,
                    liquidMaterial: .thinMaterial,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .liquid,
                    title: "Disabled Glass",
                    labelColor: .foregroundPrimary,
                    isDisabled: .constant(true),
                    isLoading: .constant(false),
                    onTap: {}
                )

                Divider().padding(.vertical, 8)

                // MARK: - CTA Variants

                PrimaryButton(
                    appearance: .fill,
                    title: "The Preserve at Verdae",
                    callToActionIcon: "f178",
                    iconWeight: .solid,
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .fill,
                    title: "The Preserve at Verdae",
                    callToActionText: "Edit",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                Divider().padding(.vertical, 8)

                // MARK: - Width Variants

                PrimaryButton(
                    appearance: .fill,
                    title: "Full Width",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: true,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

                PrimaryButton(
                    appearance: .fill,
                    title: "Hug Content",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: false,
                    isDisabled: .constant(false),
                    isLoading: .constant(false),
                    onTap: {}
                )

            }
            .alignMiddle()
            .padding(16)
        }
        .background(Color.backgroundPrimary)
    }
}
