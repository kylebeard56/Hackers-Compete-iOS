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
        VStack(spacing: 14) {
            Text("Game Format".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            VStack(spacing: 12) {
                Icon(name: snapshot.gameFormat.type.icon, size: 40, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                
                Text(snapshot.gameFormat.type.displayName)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Text(snapshot.gameFormat.type.summaryText)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.center)
            }
            
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
        .padding(16)
        .glassCardEffect()
    }
}
