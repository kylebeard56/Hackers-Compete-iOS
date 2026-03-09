//
//  GameLobby+Configuration.swift
//  Hackers
//
//  Created by Kyle Beard on 2/16/26.
//

import SwiftUI

extension GameLobby {
    @ViewBuilder
    var gameConfigurationSection: some View {
        VStack(spacing: 14) {
            Text("Configuration".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            Toggle(isOn: $handicapsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Handicaps")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Allocate strokes for each player")
                        .fontStyle(kFontName, size: 12, weight: .regular)
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
            
            Toggle(isOn: $teamsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Teams")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Organize and compete as groups")
                        .fontStyle(kFontName, size: 12, weight: .regular)
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

            competitionStyleRow

            maxScoreRow
        }
        .padding(16)
        .glassCardEffect()
    }
    
    @ViewBuilder
    private var competitionStyleRow: some View {
        let current = snapshot.configuration.resolvedCompetitionScope
        let displayName = current == .matchup ? "Matchups" : "Field"

        Menu {
            Button {
                Haptics.fire(.light)
                if playerTab == .matchups {
                    playerTab = .roster
                }
                Task { await roundSession.setCompetitionScope(.field) }
            } label: {
                Text("Field")
                Text("Compete against everyone else")
            }
            Button {
                Haptics.fire(.light)
                Task { await roundSession.setCompetitionScope(.matchup) }
            } label: {
                Text("Matchups")
                Text("Head-to-head assignments")
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Competition style")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()

                    Text("Field scoring or head-to-head")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }

                Spacer(minLength: 0)

                Text(displayName)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.charcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
            }
        }
    }

    @ViewBuilder
    private var maxScoreRow: some View {
        let current = snapshot.gameFormat.configuration.maxScoreOverPar

        Menu {
            ForEach(MaxScoreOverPar.allCases, id: \.self) { option in
                Button {
                    Haptics.fire(.light)
                    Task {
                        await roundSession.setMaxScoreOverPar(option)
                    }
                } label: {
                    HStack {
                        Text(option.displayName)
                        if option == current {
                            Icon(name: "f00c", size: 12, weight: .solid)
                        }
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max score")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Highest score allowed per hole")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
                
                Spacer(minLength: 0)
                
                Text(current.displayName)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.charcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                
            }
        }
    }
}
