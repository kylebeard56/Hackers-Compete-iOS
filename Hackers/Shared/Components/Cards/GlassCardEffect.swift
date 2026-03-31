//
//  GlassCardEffect.swift
//  Hackers
//
//  Created by Kyle Beard on 1/31/26.
//

import SwiftUI

extension View {

    // MARK: - Shape-agnostic base

    /// Apple Sports-style glass surface for cards/tiles.
    ///
    /// - iOS 26+: uses `.glassEffect`
    /// - iOS 18–25: material fallback with tint + specular highlight
    func glassCardEffect<S: InsettableShape>(
        shape: S,
        material: Material = .ultraThinMaterial,
        interactive: Bool = true,
        forceMaterial: Bool = false,
        tint: Color? = nil,
        strokeOpacity: CGFloat = 0.22,
        shadowOpacity: CGFloat = 0.10
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
                self
                    .background(material)
                    .clipShape(shape)
                    .overlay {
                        if let tint {
                            shape
                                .fill(tint.opacity(0.14))
                        }
                    }
                    .overlay {
                        // Inner highlight (specular)
                        shape
                            .inset(by: 1)
                            .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
//                            .blendMode(.overlay)
                    }
                    .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 10)
            }
        }
    }

    // MARK: - Default RoundedRectangle convenience

    /// Apple Sports-style glass surface for cards/tiles (rounded rectangle default).
    ///
    /// - iOS 26+: uses `.glassEffect`
    /// - iOS 18–25: material fallback with tint + specular highlight
    func glassCardEffect(
        cornerRadius: CGFloat = 24,
        material: Material = .ultraThinMaterial,
        interactive: Bool = true,
        forceMaterial: Bool = false,
        tint: Color? = nil,
        strokeOpacity: CGFloat = 0.22,
        shadowOpacity: CGFloat = 0.10
    ) -> some View {
        glassCardEffect(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            material: material,
            interactive: interactive,
            forceMaterial: forceMaterial,
            tint: tint,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity
        )
    }

}
