//
//  InvisibleInkModifier.swift
//  Hackers
//
//  Created by Kyle Beard on 3/26/26.
//

import SwiftUI

/// iMessage-style invisible ink effect that obscures content with animated noise particles.
struct InvisibleInkModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .hidden()
                .overlay {
                    InvisibleInkCanvas()
                        .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}

private struct InvisibleInkCanvas: View {
    private static let particleCount = 50
    private let particles: [Particle] = (0..<particleCount).map { _ in
        Particle(
            baseX: CGFloat.random(in: 0...1),
            baseY: CGFloat.random(in: 0...1),
            radius: CGFloat.random(in: 1.5...3.5),
            driftX: CGFloat.random(in: -0.03...0.03),
            driftY: CGFloat.random(in: -0.03...0.03),
            speed: Double.random(in: 0.6...1.4)
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let phase = t * p.speed
                    let x = (p.baseX + p.driftX * CGFloat(sin(phase * 2.5))) * size.width
                    let y = (p.baseY + p.driftY * CGFloat(cos(phase * 3.1))) * size.height

                    let rect = CGRect(
                        x: x - p.radius,
                        y: y - p.radius,
                        width: p.radius * 2,
                        height: p.radius * 2
                    )
                    let opacity = 0.35 + 0.35 * sin(phase * 1.8 + Double(p.baseX * 10))
                    context.opacity = opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.neutral3)
                    )
                }
            }
        }
    }

    private struct Particle {
        let baseX: CGFloat
        let baseY: CGFloat
        let radius: CGFloat
        let driftX: CGFloat
        let driftY: CGFloat
        let speed: Double
    }
}

extension View {
    func invisibleInk(active: Bool) -> some View {
        modifier(InvisibleInkModifier(isActive: active))
    }
}
