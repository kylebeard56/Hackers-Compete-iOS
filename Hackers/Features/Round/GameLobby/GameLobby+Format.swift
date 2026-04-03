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
                    ZStack {
                        Circle()
                            .fill(Color.accentGreen.opacity(colorScheme.translucent))
                            .frame(width: 120, height: 120)
                        Icon(name: snapshot.activeTemplate.icon, size: 48, weight: .regular)
                            .foregroundStyle(Color.accentGreen)
                            .padding(24)
                    }
                    .frame(width: 120, height: 120)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)

                    Text(snapshot.activeTemplate.name.uppercased())
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)

                    Text(snapshot.activeTemplate.description)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                }

                competitionScopeBlock

                if snapshot.requiresTeams && !snapshot.isSharedScoreSource {
                    teamScoringBuilderBlock
                } else if snapshot.requiresTeams && snapshot.isSharedScoreSource {
                    Text("Best 1 round totals count toward the team score.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                        .padding(.top, 2)
                }

                if snapshot.isSharedScoreSource {
                    surpriseScoringBlock
                }

                Button {
                    Haptics.fire(.light)
                    showFormatSelectionView = true
                } label: {
                    Text("Change format")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .whiteGlassCardShadow(color: palette.shadowColor)
                }
                .padding(.top, 16)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true)
        }
    }

    private var surpriseScoringBlock: some View {
        configBuilderRow(
            title: "Surprise scoring",
            subtitle: "Scores kept secret until the end"
        ) {
            Toggle("", isOn: $secretScoringEnabled)
                .labelsHidden()
                .tint(.accentGreen)
                .onChange(of: secretScoringEnabled) {
                    Task { await roundSession.setSecretScoring(secretScoringEnabled) }
                }
        }
    }

    private var competitionScopeBlock: some View {
        configBuilderRow(
            title: "Competition",
            subtitle: "Choose a full-field leaderboard or head-to-head matchups."
        ) {
            Menu {
                Button {
                    Haptics.fire(.light)
                    if playerTab == .matchups {
                        playerTab = .roster
                    }
                    Task { await roundSession.setCompetitionScope(.field) }
                } label: {
                    HStack {
                        Text("Field")
                        if snapshot.configuration.resolvedCompetitionScope == .field {
                            Icon(name: "f00c", size: 12, weight: .solid)
                        }
                    }
                }

                Button {
                    Haptics.fire(.light)
                    Task { await roundSession.setCompetitionScope(.matchup) }
                } label: {
                    HStack {
                        Text("Matchup")
                        if snapshot.configuration.resolvedCompetitionScope == .matchup {
                            Icon(name: "f00c", size: 12, weight: .solid)
                        }
                    }
                }
            } label: {
                formatChipLabel(competitionScopeTitle)
            }
            .buttonStyle(.plain)
        }
    }

    private var teamScoringBuilderBlock: some View {
        VStack(spacing: 10) {
            configBuilderRow(
                title: "Count scores",
                subtitle: "Choose which team scores contribute to the final team total."
            ) {
                Menu {
                    countScoresButtons
                } label: {
                    formatChipLabel(teamScoringModeTitle)
                }
                .buttonStyle(.plain)
            }

            configBuilderRow(
                title: "Count by",
                subtitle: "Apply team counting on each hole or across the full round."
            ) {
                Menu {
                    ForEach(AggregationScope.allCases, id: \.self) { scope in
                        Button {
                            Haptics.fire(.light)
                            Task { await roundSession.setTeamScoringScope(scope) }
                        } label: {
                            HStack {
                                Text(scope == .perRound ? "Round" : "Hole")
                                if snapshot.configuration.teamScoring.scope == scope {
                                    Icon(name: "f00c", size: 12, weight: .solid)
                                }
                            }
                        }
                    }
                } label: {
                    formatChipLabel(snapshot.configuration.teamScoring.scope == .perRound ? "Round" : "Hole")
                }
                .buttonStyle(.plain)
            }

            if let summary = teamScoringSummaryText {
                Text(summary)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var countScoresButtons: some View {
        Button {
            Haptics.fire(.light)
            Task { await roundSession.setTeamScoringMode(.all) }
        } label: {
            HStack {
                Text("All scores")
                if snapshot.configuration.teamScoring.mode == .all {
                    Icon(name: "f00c", size: 12, weight: .solid)
                }
            }
        }

        Divider()

        ForEach(1...4, id: \.self) { count in
            Button {
                Haptics.fire(.light)
                Task {
                    await roundSession.setTeamScoringMode(.bestN)
                    await roundSession.setTeamScoringCount(count)
                }
            } label: {
                HStack {
                    Text("Best \(count)")
                    if snapshot.configuration.teamScoring.mode == .bestN,
                       snapshot.configuration.teamScoring.count == count {
                        Icon(name: "f00c", size: 12, weight: .solid)
                    }
                }
            }
        }

        Divider()

        ForEach(1...4, id: \.self) { count in
            Button {
                Haptics.fire(.light)
                Task {
                    await roundSession.setTeamScoringMode(.worstN)
                    await roundSession.setTeamScoringCount(count)
                }
            } label: {
                HStack {
                    Text("Worst \(count)")
                    if snapshot.configuration.teamScoring.mode == .worstN,
                       snapshot.configuration.teamScoring.count == count {
                        Icon(name: "f00c", size: 12, weight: .solid)
                    }
                }
            }
        }
    }

    private func configBuilderRow<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Text(subtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }

            Spacer(minLength: 0)

            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.borderColor, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.neutral6.opacity(0.3)))
        )
    }

    private func formatChipLabel(_ title: String) -> some View {
        Text(title)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(Color.charcoal)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
            .whiteGlassCardShadow(color: palette.shadowColor)
    }

    private var competitionScopeTitle: String {
        snapshot.configuration.resolvedCompetitionScope == .matchup ? "Matchup" : "Field"
    }

    private var teamScoringModeTitle: String {
        let scoring = snapshot.configuration.teamScoring
        switch scoring.mode {
        case .all:
            return "All"
        case .bestN:
            return "Best \(scoring.count)"
        case .worstN:
            return "Worst \(scoring.count)"
        }
    }

    private var teamScoringSummaryText: String? {
        let scoring = snapshot.configuration.teamScoring
        guard scoring.mode != .all else {
            return "Every player score contributes to the team result."
        }

        let qualifier = scoring.mode == .worstN ? "Worst" : "Best"
        let scope = scoring.scope == .perRound ? "round totals" : "scores on each hole"
        return "\(qualifier) \(scoring.count) \(scope) count toward the team score."
    }
}
