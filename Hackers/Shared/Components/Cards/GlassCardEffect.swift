//
//  GlassCardEffect.swift
//  Hackers
//
//  Created by Kyle Beard on 1/31/26.
//

import SwiftUI

extension View {
    /// Apple Sports-style glass surface for cards/tiles.
    ///
    /// - iOS 26+: uses `.glassEffect`
    /// - iOS 18-25: material fallback with tint + specular highlight
    func glassCardEffect(
        cornerRadius: CGFloat = 24,
        material: Material = .ultraThinMaterial,
        tint: Color? = nil,
        strokeOpacity: CGFloat = 0.22,
        shadowOpacity: CGFloat = 0.10
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        return Group {
            if #available(iOS 26, *) {
                self
                    .glassEffect(.regular.interactive(), in: shape)
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
                            .blendMode(.overlay)
                    }
                    .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 10)
            }
        }
    }
}

