//
//  LiveStatusView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/24/26.
//


import SwiftUI

struct LiveStatusView: View {
    var color: Color
    
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                // Ripple
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 10, height: 10)
                    .scaleEffect(animate ? 2.6 : 1)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        reduceMotion ? .default :
                        .easeOut(duration: 3)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )

                // Core dot
                Circle()
                    .fill(color)
                    .frame(width: 7.5, height: 7.5)
            }

            Text("LIVE")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(color)
        }
        .onAppear { animate = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live")
    }
}

#Preview  {
    VStack {
        LiveStatusView(color: .accentPurple)
            .scaleEffect(4)
    }
}
