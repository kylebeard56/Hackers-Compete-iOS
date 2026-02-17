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
            
            Line()
            
            HStack(spacing: 8) {
                Icon(name: snapshot.gameFormat.type.icon, size: 20, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                Text(snapshot.gameFormat.type.displayName.uppercased())
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
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
            
            Line()
            
            Text("Configuration".uppercased())
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .alignLeading()
            
            Toggle(isOn: $handicapsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Handicaps".uppercased())
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Allocate strokes for each player")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            })
            .tint(.accentGreen)
            .onChange(of: handicapsEnabled) {
                Task {
                    await roundSession.toggleHandicaps(handicapsEnabled)
                }
            }
            
            Line()
            
            Toggle(isOn: $teamsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Teams".uppercased())
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Organize and compete as groups")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            })
            .tint(.accentGreen)
            .onChange(of: teamsEnabled) {
                Task {
                    if playerTab == .teams && !teamsEnabled {
                        playerTab = .roster
                    }
                    await roundSession.toggleTeams(teamsEnabled)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }
}
