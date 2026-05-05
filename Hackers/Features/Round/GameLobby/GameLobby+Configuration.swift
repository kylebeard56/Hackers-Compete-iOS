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
        Menu {
            Button {
                guard courseHandicapAvailable else { return }
                Haptics.fire(.light)
                let next: HandicapEntryFormat = handicapEntryFormat == .courseHandicap ? .strokes : .courseHandicap
                handicapEntryFormat = next
                Task { await roundSession.setHandicapEntryFormat(next, maximumHandicap: seriesLeagueHandicapMaximum) }
            } label: {
                Label(
                    "Course Handicap",
                    systemImage: handicapEntryFormat == .courseHandicap ? "checkmark.circle.fill" : "circle"
                )
                Text(courseHandicapMenuSubtitle)
            }
            .menuActionDismissBehavior(.disabled)
            .disabled(!courseHandicapAvailable)

            Button {
                Haptics.fire(.light)
                let next: HandicapNormalizationMode = handicapNormalizationMode == .off
                    ? (snapshot.configuration.resolvedCompetitionScope == .matchup ? .matchup : .field)
                    : .off
                handicapNormalizationMode = next
                Task { await roundSession.setHandicapNormalizationMode(next) }
            } label: {
                Label(
                    "Normalize Handicaps",
                    systemImage: handicapNormalizationMode == .off ? "circle" : "checkmark.circle.fill"
                )
                Text(normalizeHandicapsMenuSubtitle)
            }
            .menuActionDismissBehavior(.disabled)

            Menu {
                Button {
                    Haptics.fire(.light)
                    handicapStrokeBasis = nil
                    Task { await roundSession.setHandicapStrokeBasis(nil, maximumHandicap: seriesLeagueHandicapMaximum) }
                } label: {
                    HStack {
                        Text("Auto")
                        if handicapStrokeBasis == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                ForEach(SeriesHandicapStrokeBasis.allCases, id: \.self) { basis in
                    Button {
                        Haptics.fire(.light)
                        handicapStrokeBasis = basis
                        Task { await roundSession.setHandicapStrokeBasis(basis, maximumHandicap: seriesLeagueHandicapMaximum) }
                    } label: {
                        HStack {
                            Text(basis.displayName)
                            if handicapStrokeBasis == basis {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Hole Basis", systemImage: "circle.grid.2x1")
                Text(handicapStrokeBasisDescription)
            }
            .menuActionDismissBehavior(.disabled)
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.charcoal)
                .frame(width: 44, height: 44)
                .glassCardEffect(cornerRadius: 22, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                .whiteGlassCardShadow(color: palette.shadowColor)
                .accessibilityLabel("Handicap options")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var courseHandicapMenuSubtitle: String {
        courseHandicapAvailable
            ? "Convert index entries using the selected tee rating and slope"
            : "Select a course and tee with rating/slope to use index entries"
    }

    private var normalizeHandicapsMenuSubtitle: String {
        snapshot.configuration.resolvedCompetitionScope == .matchup
            ? "Play each matchup from the lowest handicap in that pairing"
            : "Play the field from the lowest handicap"
    }

    private var handicapStrokeBasisDisplay: String {
        handicapStrokeBasis?.displayName ?? "Auto"
    }

    private var handicapStrokeBasisDescription: String {
        if handicapStrokeBasis == nil {
            return "Auto currently uses \(snapshot.handicapStrokeBasis.displayName)"
        }
        return "\(handicapStrokeBasisDisplay) values"
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
