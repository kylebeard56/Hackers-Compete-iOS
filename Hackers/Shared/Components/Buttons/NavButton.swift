//
//  NavButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

enum NavigationButtonStyle { case fill, glass }

/// Used mostly for navigation or headers
struct NavButton: View {
    @Environment(\.colorScheme) var colorScheme
    
    var style: NavigationButtonStyle = .fill
    var icon = "f00d"
    var text: String? = ""
    var size: CGFloat = 20
    var weight: FontModule.Weight = .solid
    var color = Color.charcoal
    var background: Color? = nil
    var theme: PaletteTheme = .primary
    var mirror: Bool = false
    var onTap: Callback? = nil
    
    private var designPalette: DesignPalette { DesignPalette(theme: theme, scheme: colorScheme) }
    
    var body: some View {
        Group {
            if #available(iOS 26, *), style == .glass {
                button
                    .glassEffect(.regular.interactive(), in: .circle)
            } else {
                button
            }
        }
    }
    
    private var button: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap?()
        }) {
            iconView
                .frame(width: size * 2, height: size * 2)
                .background(style == .glass ? .clear : background ?? designPalette.buttonColor)
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
    .background(Color.backgroundPrimary)
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
    .background(Color.backgroundPrimary)
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
    .background(Color.backgroundSecondary)
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
    .background(Color.backgroundSecondary)
    .colorScheme(.dark)
}

#Preview("Tile Light") {
    HackersCard(
        icon: "e1d8",
        title: "Notes",
        headerStyle: .prominent,
        callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
        content: { EmptyView() }
    )
    .alignTop()
    .padding(20)
    .background(Color.cardPrimary)
    .colorScheme(.light)
}

#Preview("Tile Dark") {
    HackersCard(
        icon: "e1d8",
        title: "Notes",
        headerStyle: .prominent,
        callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
        content: { EmptyView() }
    )
    .alignTop()
    .padding(20)
    .background(Color.cardPrimary)
    .colorScheme(.dark)
}
