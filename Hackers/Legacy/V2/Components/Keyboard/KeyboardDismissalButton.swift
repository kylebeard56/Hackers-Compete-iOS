//
//  KeyboardDismissalButton.swift
//  Hackers
//
//  Created by Kyle Beard on 1/31/23.
//

import SwiftUI

struct KeyboardDismissalButton: View {
    var body: some View {
        Button(action: {
            UIApplication.shared.endEditing()
            Haptics.fire(.light)
        }) {
            ZStack {
                Circle()
                    .fill(Color.systemCard)
                    .frame(width: 40, height: 40)
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .alignBottom()
    }
}

struct KeyboardDismissalButton_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardDismissalButton()
    }
}
