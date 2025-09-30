//
//  NavButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

/// Used mostly for navigation or headers
struct NavButton: View {
    @Environment(\.colorScheme) var colorScheme
    
    var icon = "f00d"
    var text: String? = ""
    var size: CGFloat = 20
    var weight: FontModule.Weight = .solid
    var color = Color.hackersCharcoal
    var background: Color? = nil
    var mirror: Bool = false
    var onTap: Callback? = nil
    
    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap?()
        }) {
//            if let text {
//                HStack(spacing: 12) {
//                    iconView
//                    Text(text)
//                        .fontStyle(.poppins, size: size, weight: .medium)
//                        .foregroundStyle(color)
//                }
//                .padding(.horizontal, size)
//                .frame(height: size * 2)
//                .background(background ?? colorScheme.set(.gray6, .gray6))
//                .clipShape(Capsule())
//            } else {
//
//            }
            iconView
                .frame(width: size * 2, height: size * 2)
                .background(background ?? colorScheme.set(.gray6, .gray6))
                .clipShape(Circle())
        }
        .scaleEffect(x: mirror ? -1 : 1, y: 1)
    }
    
    private var iconView: some View {
        Icon(name: icon, size: size, maxSize: size, weight: weight)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack {
        HStack {
            NavButton(icon: "f00d")
            NavButton(icon: "f053")
            Spacer()
            NavButton(icon: "f00c")
        }
        NavButton(
            icon: "e3fd",
            text: "10 Credits",
            color: .accentPurple,
            background: .accentPurple.opacity(0.125)
        )
        Spacer()
    }
    .padding(20)
    .background(Color.hackersBackground)
}
