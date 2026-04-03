//
//  SeriesLeaderboardView.swift
//  Hackers
//

import SwiftUI

private enum LeaderboardStandingsSegment: String, CaseIterable {
    case team = "Team"
    case individual = "Individual"
}

struct SeriesLeaderboardView: View {
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette
    var onOpenRoundDetails: ((SeriesRound) -> Void)? = nil
    var onManageLeagueSettings: (() -> Void)? = nil

    @State private var standingsSegment: LeaderboardStandingsSegment = .individual

    var body: some View {
        VStack(spacing: 16) {
            settingsSection
            standingsMainSection
            roundHistorySection
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("League Settings".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            settingsRow(label: "Default course", value: viewModel.series.defaultCourse?.cachedName ?? "Choose per round")
            settingsRow(label: "Default format", value: viewModel.series.settings.defaultRoundConfig.template.name)
            settingsRow(
                label: "Team points",
                value: viewModel.scoringProfiles.first(where: { $0.id == viewModel.series.settings.defaultTeamScoringProfileID })?.name ?? "None"
            )
            settingsRow(
                label: "Individual points",
                value: viewModel.scoringProfiles.first(where: { $0.id == viewModel.series.settings.defaultIndividualScoringProfileID })?.name ?? "None"
            )
            settingsRow(label: "Handicaps", value: viewModel.series.handicapConfig.isEnabled ? "Enabled" : "Off")
            settingsRow(label: "Teams", value: viewModel.usesTeams ? "Enabled" : "Off")

            if let onManageLeagueSettings {
                Button {
                    Haptics.fire(.light)
                    onManageLeagueSettings()
                } label: {
                    Text("Manage league settings")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .whiteGlassCardShadow(color: palette.shadowColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    @ViewBuilder
    private var standingsMainSection: some View {
        let useTeam = viewModel.series.settings.useTeamStandings
        let useIndividual = viewModel.series.settings.useIndividualStandings

        if !useTeam && !useIndividual {
            VStack(spacing: 12) {
                Text("Standings".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                EmptyStateView(
                    imageName: EmptyStatePreset.seriesStandings.imageName,
                    title: EmptyStatePreset.seriesStandings.title,
                    subtitle: "Turn on team or individual standings in league settings to publish a leaderboard."
                )
                .frame(minHeight: 200)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true)
        } else if useTeam && useIndividual {
            VStack(spacing: 12) {
                Text("Standings".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                Picker("", selection: $standingsSegment) {
                    Text("Team").tag(LeaderboardStandingsSegment.team)
                    Text("Individual").tag(LeaderboardStandingsSegment.individual)
                }
                .pickerStyle(.segmented)

                if standingsSegment == .team {
                    standingsTableContent(sectionTitle: nil, standings: viewModel.teamStandings)
                } else {
                    standingsTableContent(sectionTitle: nil, standings: viewModel.individualStandings)
                }
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true)
        } else if useTeam {
            VStack(spacing: 12) {
                standingsTableContent(sectionTitle: "Team Standings", standings: viewModel.teamStandings)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true)
        } else {
            VStack(spacing: 12) {
                standingsTableContent(sectionTitle: "Individual Standings", standings: viewModel.individualStandings)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true)
        }
    }

    @ViewBuilder
    private func standingsTableContent(sectionTitle: String?, standings: [SeriesStanding]) -> some View {
        if let sectionTitle {
            Text(sectionTitle.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
        }

        if standings.isEmpty {
            EmptyStateView(
                imageName: EmptyStatePreset.seriesStandings.imageName,
                title: EmptyStatePreset.seriesStandings.title,
                subtitle: "Awards and standings from completed rounds will appear here."
            )
            .frame(minHeight: 200)
        } else {
            standingsHeader
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                standingRow(standing, rank: index + 1)
            }
        }
    }

    private var roundHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round History".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()

            if viewModel.rounds.isEmpty {
                Text("Schedule a round to start building weekly results.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                ForEach(viewModel.rounds.sorted(by: { $0.index < $1.index }), id: \.id) { round in
                    roundHistoryRow(round)
                }
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            Text(value)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.trailing)
        }
    }

    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 28, alignment: .center)
            Text("Name")
                .alignLeading()
            Text("Pts")
                .frame(width: 44, alignment: .trailing)
            Text("W")
                .frame(width: 32, alignment: .trailing)
            Text("Rds")
                .frame(width: 36, alignment: .trailing)
        }
        .fontStyle(kFontName, size: 12, weight: .semibold)
        .foregroundStyle(Color.neutral)
    }

    private func standingRow(_ standing: SeriesStanding, rank: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(rank)")
                .frame(width: 28, alignment: .center)
                .fontStyle(kFontName, size: 15, weight: rank <= 3 ? .bold : .semibold)
                .foregroundStyle(rank <= 3 ? Color.accentGreen : palette.foregroundColor)

            Text(standing.competitorName)
                .fontStyle(kFontName, size: 14, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .alignLeading()

            Text(String(format: "%.1f", standing.totalPoints))
                .frame(width: 44, alignment: .trailing)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text("\(standing.wins)")
                .frame(width: 32, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            Text("\(standing.roundsCounted)")
                .frame(width: 36, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .padding(.vertical, 6)
    }

    private func roundHistoryRow(_ round: SeriesRound) -> some View {
        let roundAwards = viewModel.pointAwards(for: round)
        let status = viewModel.effectiveStatus(for: round)
        let isTappable = onOpenRoundDetails != nil && (status == .complete || roundAwards.isPopulated)
        let title = round.title.isEmpty ? "Round \(round.index + 1)" : round.title
        let awardsLabel = round.awardsStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized

        return Button {
            guard isTappable else { return }
            onOpenRoundDetails?(round)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(status.rawValue.capitalized)
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(statusTint(for: status))

                        Text(kDot)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)

                        Text(awardsLabel)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    .multilineTextAlignment(.leading)

                    if round.isAdjusted {
                        Chip(
                            text: "Adjusted",
                            size: .tiny,
                            foreground: .orange,
                            background: Color.orange.opacity(0.18)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(roundAwards.count) awards")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if isTappable {
                        Icon(name: "f054", size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral2)
                    }
                }
                .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.borderColor, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.neutral6.opacity(0.3)))
            )
        }
        .buttonStyle(.plain)
    }

    private func statusTint(for status: SeriesRoundStatus) -> Color {
        switch status {
        case .planned: return .neutral
        case .lobby, .live: return .accentGreen
        case .complete: return .systemBlue
        case .canceled: return .systemError
        }
    }
}
