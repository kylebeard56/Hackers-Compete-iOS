//
//  NavButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

enum ButtonPalette {
    case primary // gray 6 & 4
    case secondary // gray 5
}

/// Used mostly for navigation or headers
struct NavButton: View {
    @Environment(\.colorScheme) var colorScheme
    
    var icon = "f00d"
    var text: String? = ""
    var size: CGFloat = 20
    var weight: FontModule.Weight = .solid
    var color = Color.hackersCharcoal
    var background: Color? = nil
    var theme: PaletteTheme = .primary
    var mirror: Bool = false
    var onTap: Callback? = nil
    
    private var designPalette: DesignPalette { DesignPalette(theme: theme, scheme: colorScheme) }
    
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
                .background(background ?? designPalette.buttonColor)
                .clipShape(Circle())
        }
        .scaleEffect(x: mirror ? -1 : 1, y: 1)
    }
    
    private var iconView: some View {
        Icon(name: icon, size: size, maxSize: size, weight: weight)
            .foregroundStyle(color)
    }
}

#Preview("Primary Light") {
    HStack {
        NavButton(icon: "f00d")
        NavButton(icon: "f053")
        Spacer()
        NavButton(icon: "f00c")
    }
    .alignTop()
    .padding(20)
    .background(Color.hackersBackground)
    .colorScheme(.light)
}

#Preview("Primary Dark") {
    HStack {
        NavButton(icon: "f00d")
        NavButton(icon: "f053")
        Spacer()
        NavButton(icon: "f00c")
    }
    .alignTop()
    .padding(20)
    .background(Color.hackersBackground)
    .colorScheme(.dark)
}

#Preview("Secondary Light") {
    HStack {
        NavButton(icon: "f00d", theme: .secondary)
        NavButton(icon: "f053", theme: .secondary)
        Spacer()
        NavButton(icon: "f00c", theme: .secondary)
    }
    .alignTop()
    .padding(20)
    .background(Color.boxFoxBackground)
    .colorScheme(.light)
}

#Preview("Secondary Dark") {
    HStack {
        NavButton(icon: "f00d", theme: .secondary)
        NavButton(icon: "f053", theme: .secondary)
        Spacer()
        NavButton(icon: "f00c", theme: .secondary)
    }
    .alignTop()
    .padding(20)
    .background(Color.boxFoxBackground)
    .colorScheme(.dark)
}

#Preview("Tile Light") {
    HackersCard(
        icon: "e1d8",
        title: "Notes",
        headerStyle: .primary,
        callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
        content: { EmptyView() }
    )
    .alignTop()
    .padding(20)
    .background(Color.boxFoxBackground)
    .colorScheme(.light)
}

#Preview("Tile Dark") {
    HackersCard(
        icon: "e1d8",
        title: "Notes",
        headerStyle: .primary,
        callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
        content: { EmptyView() }
    )
    .alignTop()
    .padding(20)
    .background(Color.boxFoxBackground)
    .colorScheme(.dark)
}
