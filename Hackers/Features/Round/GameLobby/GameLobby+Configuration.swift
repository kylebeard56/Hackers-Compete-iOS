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

            if teamsEnabled && snapshot.activeTemplate.subject == .team {
                fieldMatchupsRow
            }

            if templateSupportsBestN {
                bestNRow
            }
            
            maxScoreRow
        }
        .padding(16)
        .glassCardEffect()
    }
    
    private var templateSupportsBestN: Bool {
        snapshot.activeTemplate.pipeline.contains { stage in
            if case .select = stage { return true }
            return false
        }
    }

    @ViewBuilder
    private var fieldMatchupsRow: some View {
        let current = snapshot.configuration.resolvedCompetitionScope

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Field vs Matchups")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Text("Field: all teams ranked together. Matchups: head-to-head pairings.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach([CompetitionScope.field, CompetitionScope.matchup], id: \.self) { scope in
                    let label = scope == .field ? "Field" : "Matchups"
                    let match = scope == current
                    Button {
                        Haptics.fire(.light)
                        Task { await roundSession.setCompetitionScope(scope) }
                    } label: {
                        Chip(
                            text: label,
                            foreground: match ? .white : palette.foregroundColor,
                            background: match ? Color.accentGreen : Color.neutral6
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bestNRow: some View {
        let ranks = bestNRanksFromTemplate
        guard ranks.count > 1 else { return }

        let current = bestNSelected
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Best N")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Text("Number of scores that count per team per hole")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(ranks, id: \.self) { n in
                    let label = "Best \(n)"
                    let match = n == current
                    Button {
                        Haptics.fire(.light)
                        Task { await roundSession.setBestN(n) }
                    } label: {
                        Chip(
                            text: label,
                            foreground: match ? .white : palette.foregroundColor,
                            background: match ? Color.accentGreen : Color.neutral6
                        )
                    }
                }
            }
        }
    }

    private var bestNRanksFromTemplate: [Int] {
        for stage in snapshot.activeTemplate.pipeline {
            if case .select(let sel) = stage, let ranks = sel.includeRanks, !ranks.isEmpty {
                return ranks.sorted()
            }
        }
        return []
    }

    private var bestNSelected: Int {
        snapshot.configuration.bestNSelected
            ?? bestNRanksFromTemplate.first
            ?? 1
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
