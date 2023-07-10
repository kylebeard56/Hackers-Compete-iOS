//
//  KeyboardColorButton.swift
//  Hackers
//
//  Created by Kyle Beard on 4/2/23.
//

import SwiftUI

struct KeyboardColorButton: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var selectedColor: GameColor
    @Binding var reveal: Bool
    var onSelect: (GameColor) -> Void
    @State private var animate: Bool = false
    
    var body: some View {
        content
            .frame(width: 40)
            .frame(minHeight: 40)
            .background(backgroundBlur)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 0)
            .alignBottom()
            .onChange(of: reveal, perform: { value in
                withAnimation(.linear(duration: 0.16)) {
                    animate = value
                }
            })
    }
    
    private var backgroundBlur: some View {
        ZStack {
            Blur(style: colorScheme.blurStyle)
            Color.systemCard.opacity(0.925)
        }
    }
    
    private var content: some View {
        VStack(spacing: 24) {
            if animate {
                makeCircle(color: GameColor.blue, selected: selectedColor == .blue)
                makeCircle(color: GameColor.green, selected: selectedColor == .green)
                makeCircle(color: GameColor.purple, selected: selectedColor == .purple)
                makeCircle(color: GameColor.indigo, selected: selectedColor == .indigo)
                makeCircle(color: GameColor.pink, selected: selectedColor == .pink)
                makeCircle(color: GameColor.orange, selected: selectedColor == .orange)
            } else {
                makeCircle(color: selectedColor, selected: true)
            }
        }
        .padding(.vertical, animate ? 12 : 0)
    }
    
    private let diameter: CGFloat = 16
    private func makeCircle(color: GameColor, selected: Bool) -> some View {
        Button(action: {
            reveal.toggle()
            onSelect(color)
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

struct KeyboardColorButton_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardColorButton(selectedColor: .blue, reveal: .false, onSelect: { _ in })
    }
}
