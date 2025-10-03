//
//  ButtonStyles.swift
//  Hackers
//
//  Created by Kyle Beard on 7/14/25.
//

import SwiftUI

struct HackersButtonStyle: ButtonStyle {
    var background: Color
    var radius: CGFloat?
    
    private var shape: AnyShape {
        if let radius {
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        } else {
            return AnyShape(Capsule())
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .background(background.opacity(configuration.isPressed ? 0.5 : 1))
            .clipShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.interactiveSpring, value: configuration.isPressed)
    }
}

struct HackersSecondaryButtonStyle: ButtonStyle {
    var background: Color
    var radius: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .background(background.opacity(configuration.isPressed ? 0.5 : 1))
            .cornerRadius(radius: radius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.interactiveSpring, value: configuration.isPressed)
    }
}
