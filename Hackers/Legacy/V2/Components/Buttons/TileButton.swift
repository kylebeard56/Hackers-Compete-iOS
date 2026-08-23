//
//  TileButton.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/24.
//

import SwiftUI

struct TileButton: View {
    @Environment(\.colorScheme) var colorScheme
    var icon: String = ""
    var label: String = ""
    var foregroundColor: Color = .systemBlack
    var backgroundColor: Color = .systemGray5
    var onTap: (() -> Void)?
    
    var body: some View {
        Button(action: {
            if let onTap { onTap() }
            Haptics.fire(.light)
        }) {
            VStack(spacing: 10) {
                Icon(name: icon, size: 24, maxSize: 24, weight: .regular)
                    .alignCenter()
                Text(label)
                    .font(.dmSans, size: 13, weight: .medium)
                    .alignCenter()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        Spacer()
        HStack(spacing: 10) {
            TileButton(icon: "f201", label: "Stats and trends")
            TileButton(icon: "f201", label: "Manage teams")
        }
        
        HStack(spacing: 10) {
            TileButton(icon: "f201", label: "Set handicaps")
            TileButton(icon: "f201", label: "Edit players")
        }
        Spacer()
    }
    .padding(20)
    
}
