//
//  GameLobby+Format.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI

extension GameLobby {
    @ViewBuilder
    var gameFormatSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 14) {
                Text("Game Format".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()
                
                VStack(spacing: 12) {
//                    ZStack {
//                        Circle()
//                            .fill(Color.accentGreen.opacity(colorScheme.translucent))
//                        Icon(name: snapshot.gameFormat.type.icon, size: 40, weight: .regular)
//                            .foregroundStyle(Color.accentGreen)
//                    }
//                    .frame(width: 80, height: 80)
                    
                    Icon(name: snapshot.gameFormat.type.icon, size: 40, weight: .regular)
                        .foregroundStyle(Color.accentGreen)
                        .padding(20)
                        .glassCardEffect(cornerRadius: 12, tint: Color.accentGreen.opacity(colorScheme.translucent))
                        .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                    
                    Text(snapshot.gameFormat.type.displayName)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                    
                    Text(snapshot.gameFormat.type.summaryText)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    Haptics.fire(.error)
                    // fake door button rn
                } label: {
                    Text("Change format")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                        .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                }
                .padding(.top, 16)
            }
            .padding(16)
            .glassCardEffect()
            
//            GlassButton(
//                title: "Change format",
//                height: 40,
//                fillWidth: false,
//                fontSize: 15,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: {
//                    // Fake door for MVP expansion testing
//                }
//            )
        }
    }
}
