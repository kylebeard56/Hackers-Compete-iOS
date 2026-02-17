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
                    .foregroundStyle(Color.neutral)
                    .alignCenter()
                
                VStack(spacing: 12) {
                    ZStack {
                        Icon(name: snapshot.gameFormat.type.icon, size: 40, weight: .regular)
                            .foregroundStyle(Color.accentGreen)
                    }
                    .frame(width: 56, height: 56)
                    .glassCardEffect(shape: .circle, tint: palette.glassButtonColor)
                    
                    Text(snapshot.gameFormat.type.displayName)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                    
                    Text(snapshot.gameFormat.type.summaryText)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .glassCardEffect()
            
            GlassButton(
                title: "Change format",
                height: 40,
                fillWidth: false,
                fontSize: 15,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    // Fake door for MVP expansion testing
                }
            )
        }
    }
}
