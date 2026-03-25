//
//  SeriesLeaderboardView.swift
//  Hackers
//

import SwiftUI

struct SeriesLeaderboardView: View {
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette
    var onOpenRoundDetails: ((SeriesRound) -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            settingsSection
            announcementsSection
            if viewModel.series.settings.useTeamStandings {
                teamSection
            }
            if viewModel.series.settings.useIndividualStandings {
                individualSection
            }
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
        }
        .padding(16)
        .glassCardEffect()
    }

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Commissioner Notes".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            if viewModel.activeAnnouncements.isEmpty {
                Text("No active announcements")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                ForEach(viewModel.activeAnnouncements, id: \.id) { announcement in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "megaphone.fill")
                                .foregroundStyle(Color.accentGreen)
                            Text(announcement.title.isEmpty ? "Note from commissioner" : announcement.title)
                                .fontStyle(kFontName, size: 14, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                        }

                        Text(announcement.message)
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)

                        Text("Active until \(announcement.endsAt.formattedDate)")
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral2)
                    }
                    .padding(12)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    private var individualSection: some View {
        standingsSection(
            title: "Individual Standings",
            standings: viewModel.individualStandings
        )
    }

    private var teamSection: some View {
        standingsSection(
            title: "Team Standings",
            standings: viewModel.teamStandings
        )
    }

    private func standingsSection(title: String, standings: [SeriesStanding]) -> some View {
        VStack(spacing: 12) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            if standings.isEmpty {
                Text("No standings yet")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 16)
            } else {
                standingsHeader
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    standingRow(standing, rank: index + 1)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    private var roundHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round History".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

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
        .glassCardEffect()
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
        let isTappable = onOpenRoundDetails != nil && (viewModel.effectiveStatus(for: round) == .complete || roundAwards.isPopulated)

        return Button {
            guard isTappable else { return }
            onOpenRoundDetails?(round)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(round.title.isEmpty ? "Round \(round.index + 1)" : round.title)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    HStack(spacing: 6) {
                        Text(viewModel.effectiveStatus(for: round).rawValue.capitalized)
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(statusTint(for: viewModel.effectiveStatus(for: round)))

                        Text(kDot)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)

                        Text(round.awardsStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    if round.isAdjusted {
                        Chip(
                            text: "Adjusted",
                            size: .tiny,
                            foreground: .orange,
                            background: Color.orange.opacity(0.18)
                        )
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(roundAwards.count) awards")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)

                    if isTappable {
                        Icon(name: "f054", size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.whiteGlassButtonColor.opacity(0.55))
            .cornerRadius(14)
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
