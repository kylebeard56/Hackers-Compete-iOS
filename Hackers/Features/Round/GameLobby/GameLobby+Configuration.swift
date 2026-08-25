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
            
            HStack(spacing: 12) {
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

                Spacer(minLength: 0)

                Toggle("", isOn: $handicapsEnabled)
                    .labelsHidden()
                    .tint(.accentGreen)
                    .onChange(of: handicapsEnabled) {
                        Task {
                            await roundSession.toggleHandicaps(handicapsEnabled)
                        }
                    }

                if handicapsEnabled {
                    handicapOptionsMenu
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
            .disabled(snapshot.isVegasFormat)
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
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
    }

    private var courseHandicapAvailable: Bool {
        HandicapCalculator.hasCourseHandicapData(courseSegment: snapshot.courseSegment)
    }

    private var handicapOptionsMenu: some View {
        HandicapOptionsMenu(
            handicapEntryFormat: $handicapEntryFormat,
            handicapNormalizationMode: $handicapNormalizationMode,
            handicapStrokeBasis: $handicapStrokeBasis,
            courseHandicapAvailable: courseHandicapAvailable,
            competitionScope: snapshot.configuration.resolvedCompetitionScope,
            resolvedAutoBasis: snapshot.handicapStrokeBasis,
            palette: palette,
            courseHandicapSubtitle: courseHandicapMenuSubtitle,
            onEntryFormatChanged: { next in
                Task { await roundSession.setHandicapEntryFormat(next, maximumHandicap: effectiveSeriesLeagueHandicapMaximum) }
            },
            onNormalizationModeChanged: { next in
                Task { await roundSession.setHandicapNormalizationMode(next) }
            },
            onStrokeBasisChanged: { next in
                Task { await roundSession.setHandicapStrokeBasis(next, maximumHandicap: effectiveSeriesLeagueHandicapMaximum) }
            }
        )
    }

    private var courseHandicapMenuSubtitle: String {
        courseHandicapAvailable
            ? "Convert index entries using the selected tee rating and slope"
            : "Select a course and tee with rating/slope to use index entries"
    }

    @ViewBuilder
    private var maxScoreRow: some View {
        let current = snapshot.gameFormat.configuration.maxScoreOverPar
        let hasCoursePars = snapshot.defaultTee?.holes.contains { $0.par > 0 } == true

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
                ForEach(MaxScoreOverPar.selectableCases(hasCoursePars: hasCoursePars), id: \.self) { option in
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
