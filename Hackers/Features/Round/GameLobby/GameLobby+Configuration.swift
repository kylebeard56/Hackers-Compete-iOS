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

            if teamsEnabled {
                Toggle(isOn: Binding(
                    get: { teamColorsEnabled },
                    set: { newValue in
                        teamColorsEnabled = newValue
                        Task { await roundSession.setTeamColorsEnabled(newValue) }
                    }
                ), label: {
                    VStack(spacing: 4) {
                        Text("Team colors")
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()

                        Text("Color-coded team names and avatars, or neutral styling with Team 1, Team 2…")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                    }
                })
                .tint(.accentGreen)
            }

            Toggle(isOn: $sequentialTeeStartsEnabled) {
                VStack(spacing: 4) {
                    Text("Shotgun start")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()

                    Text("New tee groups pick up the next open tee box at the same tee time instead of always starting on hole 1.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            }
            .tint(.accentGreen)
            .onChange(of: sequentialTeeStartsEnabled) {
                Task {
                    await roundSession.toggleSequentialTeeStarts(sequentialTeeStartsEnabled)
                }
            }

            maxScoreRow
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    @ViewBuilder
    private var maxScoreRow: some View {
        let current = snapshot.gameFormat.configuration.maxScoreOverPar

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
                Text(current.displayName)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.charcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                    .whiteGlassCardShadow(color: palette.shadowColor)
            }
        }
    }
}
