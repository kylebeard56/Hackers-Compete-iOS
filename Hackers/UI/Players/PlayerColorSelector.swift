//
//  PlayerColorSelector.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

struct PlayerColorSelector: View {
    @Environment(\.dismiss) var dismiss
    @Binding var color: Color
    var width: CGFloat
    var diameter: CGFloat = 28
    var keyboardEmbedded: Bool = false
    
    var body: some View {
        HStack(spacing: (width - diameter * 7) / 6) {
            makeCircle(color: Color.systemBlue, selected: color == Color.systemBlue)
            makeCircle(color: Color.systemGreen, selected: color == Color.systemGreen)
            makeCircle(color: Color.systemPurple, selected: color == Color.systemPurple)
            makeCircle(color: Color.systemIndigo, selected: color == Color.systemIndigo)
            makeCircle(color: Color.systemRed, selected: color == Color.systemRed)
            makeCircle(color: Color.systemOrange, selected: color == Color.systemOrange)
            makeCircle(color: Color.systemYellow, selected: color == Color.systemYellow)
        }
    }
    
    private func makeCircle(color: Color, selected: Bool) -> some View {
        Button(action: {
            self.color = color
            if !keyboardEmbedded { dismiss() } // Note: don't dismiss keyboard on color selection.
            Haptics.fire(.light)
        }) {
            VStack {
                if selected {
                    Circle()
                        .fill(color)
                        .frame(width: diameter, height: diameter)
                } else {
                    Circle()
                        .stroke(color, lineWidth: 3)
                        .frame(width: diameter, height: diameter)
                }
            }
        }
        
    }
}

struct PlayerColorSelector_Previews: PreviewProvider {
    static var previews: some View {
        PlayerColorSelector(color: .constant(.white), width: 400)
    }
}
