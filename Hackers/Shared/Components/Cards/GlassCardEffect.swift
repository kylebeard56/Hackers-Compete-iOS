//
//  GlassCardEffect.swift
//  Hackers
//
//  Created by Kyle Beard on 1/31/26.
//

import SwiftUI
import UIKit

// MARK: - Liquid glass material style (iOS < 26 / forced material fallback)

/// Tunable layered look on top of system `Material`: base veil, cool tint, directional highlight, optional legacy tint.
struct LiquidGlassMaterialStyle: Sendable {
    // MARK: Base veil (mostly white / dark; photo still reads through material + veil)

    var lightBaseVeil: Color = .white
    var lightBaseVeilOpacity: CGFloat = 0.18
    var darkBaseVeil: Color = Color(white: 0.08)
    var darkBaseVeilOpacity: CGFloat = 0.42

    // MARK: Cool bias (hint of blue)

    var lightCoolTint: Color = Color(red: 0.92, green: 0.95, blue: 1.0)
    var lightCoolTintOpacity: CGFloat = 0.08
    var darkCoolTint: Color = Color(red: 0.14, green: 0.16, blue: 0.22)
    var darkCoolTintOpacity: CGFloat = 0.10

    // MARK: Directional highlight (uneven “thickness”, not shimmer)

    var gradientStart: UnitPoint = .topLeading
    var gradientEnd: UnitPoint = .bottomTrailing
    var lightGradientHighlightOpacity: CGFloat = 0.12
    var darkGradientHighlightOpacity: CGFloat = 0.08
    var gradientBlendMode: BlendMode = .overlay

    // MARK: Call-site `tint:` overlay (e.g. `whiteGlassButtonColor`)

    var legacyTintOpacity: CGFloat = 0.14

    // MARK: Reduce Transparency

    /// Adaptive system grouped background when translucency is disabled.
    var reduceTransparencyFill: Color = Color(uiColor: .secondarySystemGroupedBackground)
    var reduceTransparencyLegacyTintOpacity: CGFloat = 0.22

    static let standard = LiquidGlassMaterialStyle()

    /// Lighter veils for dense UI (chips, small tiles).
    static var reduced: LiquidGlassMaterialStyle {
        var s = LiquidGlassMaterialStyle()
        s.lightBaseVeilOpacity = 0.12
        s.darkBaseVeilOpacity = 0.32
        s.lightCoolTintOpacity = 0.05
        s.darkCoolTintOpacity = 0.07
        s.lightGradientHighlightOpacity = 0.08
        s.darkGradientHighlightOpacity = 0.05
        return s
    }

    func baseVeil(for scheme: ColorScheme) -> (Color, CGFloat) {
        switch scheme {
        case .light: return (lightBaseVeil, lightBaseVeilOpacity)
        case .dark: return (darkBaseVeil, darkBaseVeilOpacity)
        @unknown default: return (lightBaseVeil, lightBaseVeilOpacity)
        }
    }

    func coolTint(for scheme: ColorScheme) -> (Color, CGFloat) {
        switch scheme {
        case .light: return (lightCoolTint, lightCoolTintOpacity)
        case .dark: return (darkCoolTint, darkCoolTintOpacity)
        @unknown default: return (lightCoolTint, lightCoolTintOpacity)
        }
    }

    func gradientHighlightOpacity(for scheme: ColorScheme) -> CGFloat {
        switch scheme {
        case .light: return lightGradientHighlightOpacity
        case .dark: return darkGradientHighlightOpacity
        @unknown default: return lightGradientHighlightOpacity
        }
    }

    @ViewBuilder
    func reduceTransparencyBackground<S: InsettableShape>(
        shape: S,
        legacyTint: Color?
    ) -> some View {
        ZStack {
            shape.fill(reduceTransparencyFill)
            if let legacyTint {
                shape.fill(legacyTint.opacity(reduceTransparencyLegacyTintOpacity))
            }
        }
    }
}

// MARK: - Material fallback modifier

private struct GlassMaterialFallbackModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let material: Material
    let tint: Color?
    let strokeOpacity: CGFloat
    let shadowOpacity: CGFloat
    let liquidGlassStyle: LiquidGlassMaterialStyle

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content
                    .background {
                        liquidGlassStyle.reduceTransparencyBackground(shape: shape, legacyTint: tint)
                    }
                    .clipShape(shape)
            } else {
                let (baseColor, baseOp) = liquidGlassStyle.baseVeil(for: colorScheme)
                let (coolColor, coolOp) = liquidGlassStyle.coolTint(for: colorScheme)
                let gradOp = liquidGlassStyle.gradientHighlightOpacity(for: colorScheme)

                content
                    .background {
                        ZStack {
                            shape.fill(material)
                            shape.fill(baseColor.opacity(baseOp))
                            shape.fill(coolColor.opacity(coolOp))
                            shape.fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(gradOp),
                                        Color.clear,
                                    ],
                                    startPoint: liquidGlassStyle.gradientStart,
                                    endPoint: liquidGlassStyle.gradientEnd
                                )
                            )
                            .blendMode(liquidGlassStyle.gradientBlendMode)
                            if let tint {
                                shape.fill(tint.opacity(liquidGlassStyle.legacyTintOpacity))
                            }
                        }
                    }
                    .clipShape(shape)
            }
        }
        .overlay {
            shape
                .inset(by: 1)
                .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
        }
        .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 10)
    }
}

extension View {

    // MARK: - Shape-agnostic base

    /// Apple Sports–style glass surface for cards/tiles.
    ///
    /// - iOS 26+: uses `.glassEffect`.
    /// - Otherwise: layered `Material` with scheme-aware veil, cool tint, directional highlight, optional `tint`, edge stroke, and shadow (`LiquidGlassMaterialStyle`).
    func glassCardEffect<S: InsettableShape>(
        shape: S,
        material: Material = .ultraThinMaterial,
        interactive: Bool = true,
        forceMaterial: Bool = false,
        tint: Color? = nil,
        strokeOpacity: CGFloat = 0.22,
        shadowOpacity: CGFloat = 0.10,
        liquidGlassStyle: LiquidGlassMaterialStyle = .standard
    ) -> some View {
        Group {
            if #available(iOS 26.0, *), !forceMaterial, GlassEffectCapability.useGlassEffect {
                self
                    .background(tint ?? Color.clear)
                    .clipShape(shape)
                    .glassEffect(.regular.interactive(interactive), in: shape)
                    // post-glass tint layer
//                    .overlay {
//                        if let tint {
//                            shape
//                                .fill(tint.opacity(0.6))
//                                .blendMode(.plusDarker)
//                        }
//                    }
//
//                    // specular edge
//                    .overlay {
//                        shape.stroke(.white.opacity(0.12))
//                    }
            } else {
                self.modifier(
                    GlassMaterialFallbackModifier(
                        shape: shape,
                        material: material,
                        tint: tint,
                        strokeOpacity: strokeOpacity,
                        shadowOpacity: shadowOpacity,
                        liquidGlassStyle: liquidGlassStyle
                    )
                )
            }
        }
    }

    // MARK: - Default RoundedRectangle convenience

    /// Apple Sports–style glass surface for cards/tiles (rounded rectangle default).
    ///
    /// - iOS 26+: uses `.glassEffect`.
    /// - Otherwise: layered `Material` fallback (`LiquidGlassMaterialStyle`).
    func glassCardEffect(
        cornerRadius: CGFloat = 24,
        material: Material = .ultraThinMaterial,
        interactive: Bool = true,
        forceMaterial: Bool = false,
        tint: Color? = nil,
        strokeOpacity: CGFloat = 0.22,
        shadowOpacity: CGFloat = 0.10,
        liquidGlassStyle: LiquidGlassMaterialStyle = .standard
    ) -> some View {
        glassCardEffect(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            material: material,
            interactive: interactive,
            forceMaterial: forceMaterial,
            tint: tint,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity,
            liquidGlassStyle: liquidGlassStyle
        )
    }
}

// MARK: - Previews

private struct LiquidGlassMaterialFallbackPreviewCard: View {
    var forceMaterial: Bool = true
    var style: LiquidGlassMaterialStyle = .standard

    var body: some View {
        Text("Liquid glass fallback")
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(24)
            .frame(maxWidth: 320)
            .glassCardEffect(forceMaterial: forceMaterial, liquidGlassStyle: style)
    }
}

#Preview("Liquid glass — light") {
    ZStack {
        Image(systemName: "photo")
            .font(.system(size: 120))
            .foregroundStyle(.quaternary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.5), .blue.opacity(0.45), .purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        LiquidGlassMaterialFallbackPreviewCard()
    }
    .preferredColorScheme(.light)
}

#Preview("Liquid glass — dark") {
    ZStack {
        Image(systemName: "photo")
            .font(.system(size: 120))
            .foregroundStyle(.quaternary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.4), .blue.opacity(0.35), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        LiquidGlassMaterialFallbackPreviewCard()
    }
    .preferredColorScheme(.dark)
}

#Preview("Liquid glass — reduced style") {
    ZStack {
        Color.green.opacity(0.3)
            .ignoresSafeArea()
        LiquidGlassMaterialFallbackPreviewCard(style: .reduced)
    }
}
