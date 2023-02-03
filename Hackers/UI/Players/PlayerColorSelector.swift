//
//  PlayerColorSelector.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

struct PlayerColorSelector: View {
    @Environment(\.dismiss) var dismiss
    @Binding var color: GameColor
    var width: CGFloat
    var diameter: CGFloat = 28
    var keyboardEmbedded: Bool = false
    
    var body: some View {
        HStack(spacing: (width - diameter * 7) / 6) {
            makeCircle(color: GameColor.blue, selected: color == .blue)
            makeCircle(color: GameColor.green, selected: color == .green)
            makeCircle(color: GameColor.purple, selected: color == .purple)
            makeCircle(color: GameColor.indigo, selected: color == .indigo)
            makeCircle(color: GameColor.red, selected: color == .red)
            makeCircle(color: GameColor.orange, selected: color == .orange)
            makeCircle(color: GameColor.yellow, selected: color == .yellow)
        }
    }
    
    private func makeCircle(color: GameColor, selected: Bool) -> some View {
        Button(action: {
            self.color = color
            if !keyboardEmbedded { dismiss() } // Note: don't dismiss keyboard on color selection.
            Haptics.fire(.light)
        }) {
            VStack {
                if selected {
                    Circle()
                        .fill(color.value)
                        .frame(width: diameter, height: diameter)
                } else {
                    Circle()
                        .stroke(color.value, lineWidth: 3)
                        .frame(width: diameter, height: diameter)
                }
            }
        }
        
    }
}

struct PlayerColorSelector_Previews: PreviewProvider {
    static var previews: some View {
        PlayerColorSelector(color: .constant(.blue), width: 400)
    }
}
