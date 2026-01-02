//
//  GameLobby+Common.swift
//  Hackers
//
//  Created by Kyle Beard on 12/5/25.
//

import SwiftUI

extension GameLobby {
    func stackedSubtitle(value: String, label: String, size: CGFloat = 17) -> some View {
        VStack(spacing: 4) {
            Text(value.uppercased())
                .fontStyle(.poppins, size: size, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            Text(label.uppercased())
                .fontStyle(.poppins, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }
    
    @ViewBuilder
    func underlineTab(for tab: PlayerTab) -> some View {
        let isSelected = tab == playerTab
        
        Button(action: {
            Haptics.fire(.light)
            withAnimation(.linear(duration: 0.2)) {
                playerTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Text(tab.name.uppercased())
                    .fontStyle(.poppins, size: 17, weight: isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? palette.foregroundColor : .neutral)
                
                RoundedRectangle(cornerRadius: 2)
                    .foregroundStyle(Color.accentGreen)
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
    }
}

extension View {
    func tileEffect(for palette: DesignPalette) -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(palette.cardColor)
            .cornerRadius(radius: 12)
    }
    
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
