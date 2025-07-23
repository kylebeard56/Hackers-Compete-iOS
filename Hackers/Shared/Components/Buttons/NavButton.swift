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
    var size: CGFloat = 17
    var weight: FontModule.Weight = .solid
    var color = Color.hackersCharcoal
    var background: Color?
    var onTap: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap()
        }) {
            Icon(name: icon, size: size, maxSize: size, weight: weight)
                .foregroundStyle(color)
                .frame(width: size * 2, height: size * 2)
                .background(background ?? colorScheme.set(.gray5, .gray6))
                .clipShape(Circle())
        }
    }
}

#Preview {
    VStack {
        HStack {
            NavButton(icon: "f00d", onTap: { })
            NavButton(icon: "f053", onTap: { })
            Spacer()
            NavButton(icon: "f00c", onTap: { })
        }
        Spacer()
    }
    .padding(20)
    .background(Color.hackersBackground)
}
