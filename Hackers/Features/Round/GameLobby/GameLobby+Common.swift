//
//  GameLobby+Common.swift
//  Hackers
//
//  Created by Kyle Beard on 12/5/25.
//

import SwiftUI

extension View {
    func outlineEffect(for palette: DesignPalette) -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .border(palette.borderColor, width: 3, cornerRadius: 12)
            .cornerRadius(radius: 12)
    }
    
    func chevronChip() -> some View {
        HStack(spacing: 6) {
            self
            Image(systemName: "chevron.up.chevron.down")
                .fontStyle(.system, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.neutral6)
        .clipShape(Capsule())
    }
    
    func caretChip() -> some View {
        HStack(spacing: 6) {
            self
            Image(systemName: "chevron.down")
                .fontStyle(.system, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.neutral6)
        .clipShape(Capsule())
    }
}
