//
//  SeriesLeaderboardView.swift
//  Hackers
//

import SwiftUI

private enum LeaderboardStandingsSegment: String, CaseIterable {
    case team = "Team"
    case individual = "Individual"
}

private enum SeriesIndividualLeaderboardMode: String, CaseIterable {
    case placement = "Placement"
    case stats = "Stats"
}

private enum SeriesIndividualStatsSort: String, CaseIterable {
    case averageDifferential = "Avg Diff"
    case handicapIndex = "Handicap Index"
    case roundsPlayed = "Rounds Played"
    case averageGross = "Gross Avg"
    case averageNet = "Net Avg"

    var label: String {
        rawValue
    }

    func menuSubtitle(config: HandicapComputationConfigDTO) -> String? {
        switch self {
        case .averageDifferential:
            return "Average gross score vs course rating/slope or par"
        case .handicapIndex:
            return Self.handicapIndexSubtitle(config: config)
        case .roundsPlayed:
            return nil
        case .averageGross:
            return "Average gross strokes across completed rounds"
        case .averageNet:
            return "Average gross strokes less current handicap index"
        }
    }

    var accessibilityLabel: String {
        "Sort by \(label)"
    }

    private static func handicapIndexSubtitle(config dto: HandicapComputationConfigDTO) -> String {
        let config = dto.toConfig()
        let poolCount = max(1, config.rollingPoolSize ?? 20)
        let usedCount = max(1, config.gamesUsed(forPoolCount: poolCount))

        if let rollingPoolSize = config.rollingPoolSize, rollingPoolSize > 0 {
            return "Current league handicap index using \(usedCount) of last \(rollingPoolSize) scores"
        }

        switch config.scorePoolPolicy {
        case .bestOfUsedCount:
            return "Current league handicap index using up to \(usedCount) lowest scores"
        case .latestOfUsedCount:
            return "Current league handicap index using up to \(usedCount) latest scores"
        }
    }
}

struct SeriesLeaderboardView: View {
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette
    var onOpenRoundDetails: ((SeriesRound) -> Void)? = nil
    var onManageLeagueSettings: (() -> Void)? = nil

    @State private var standingsSegment: LeaderboardStandingsSegment = .individual
    @State private var individualLeaderboardMode: SeriesIndividualLeaderboardMode = .stats
    @State private var individualStatsSort: SeriesIndividualStatsSort = .averageDifferential
    @State private var selectedTeamStanding: SeriesStanding?

    var body: some View {
        VStack(spacing: 16) {
            settingsSection
            standingsMainSection
            roundHistorySection
        }
        .sheet(item: $selectedTeamStanding) { standing in
            SeriesTeamDetailSheet(viewModel: viewModel, standing: standing)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.series.experiencePreset.settingsTitle.uppercased())
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
            settingsRow(label: "Handicaps", value: viewModel.series.handicapConfig.mode.displayName)
            settingsRow(label: "Teams", value: viewModel.usesTeams ? "Enabled" : "Off")
            if viewModel.isSeriesScoreboardEligible {
                Toggle(isOn: Binding(
                    get: { viewModel.series.settings.showScoreboardTile },
                    set: { value in
                        Task { await viewModel.setScoreboardVisible(value) }
                    }
                )) {
                    Text("Scoreboard")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
                .tint(Color.accentGreen)
            }

            if let onManageLeagueSettings {
                Button {
                    Haptics.fire(.light)
                    onManageLeagueSettings()
                } label: {
                    Text("Manage \(viewModel.series.experiencePreset.displayName.lowercased()) settings")
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
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
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
            .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
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
                    standingsTableContent(sectionTitle: nil, standings: viewModel.teamStandings, isTeam: true)
                } else {
                    individualLeaderboardContent(sectionTitle: nil)
                }
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
        } else if useTeam {
            VStack(spacing: 12) {
                standingsTableContent(sectionTitle: "Team Standings", standings: viewModel.teamStandings, isTeam: true)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
        } else {
            VStack(spacing: 12) {
                individualLeaderboardContent(sectionTitle: "Individual Standings")
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
        }
    }

    @ViewBuilder
    private func individualLeaderboardContent(sectionTitle: String?) -> some View {
        if let sectionTitle {
            Text(sectionTitle.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
        }

        if viewModel.hasIndividualPlacementConfigured {
            individualLeaderboardControls

            switch individualLeaderboardMode {
            case .placement:
                standingsTableContent(sectionTitle: nil, standings: viewModel.individualStandings, isTeam: false)
            case .stats:
                individualStatsTableContent(rows: sortedStatsRows)
            }
        } else {
            standingsTableContent(sectionTitle: nil, standings: viewModel.individualStandings, isTeam: false)
        }
    }

    @ViewBuilder
    private func standingsTableContent(sectionTitle: String?, standings: [SeriesStanding], isTeam: Bool) -> some View {
        if let sectionTitle {
            Text(sectionTitle.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
        }

        if isTeam, shouldShowRefreshAwardsButton(isTeam: true) {
            refreshAwardsButton(isTeam: true)
        }

        if standings.isEmpty {
            EmptyStateView(
                imageName: EmptyStatePreset.seriesStandings.imageName,
                title: EmptyStatePreset.seriesStandings.title,
                subtitle: "Awards and standings from completed rounds will appear here."
            )
            .frame(minHeight: 200)
        } else {
            let showsAverage = standings.contains { primaryTiebreakSummary(for: $0)?.average != nil }
            standingsHeader(isTeam: isTeam, showsAverage: showsAverage)
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                standingRow(standing, rank: index + 1, isTeam: isTeam, showsAverage: showsAverage)
            }
        }

        if shouldShowRefreshAwardsButton(isTeam: isTeam) {
            refreshAwardsButton(isTeam: isTeam)
        }
    }

    private func shouldShowRefreshAwardsButton(isTeam: Bool) -> Bool {
        isTeam ? viewModel.canRebuildAutomaticAwards : viewModel.canRebuildIndividualStandings
    }

    private func refreshAwardsButton(isTeam: Bool) -> some View {
        let isRefreshing = isTeam
            ? viewModel.isRebuildingAutomaticAwards
            : viewModel.isRebuildingIndividualStandings

        return Button {
            Haptics.fire(.light)
            Task {
                if isTeam {
                    await viewModel.rebuildAutomaticAwardsAndStandingsForCompletedRounds()
                } else {
                    await viewModel.rebuildIndividualPlacementAwardsAndStandings()
                }
            }
        } label: {
            if isTeam {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))

                    Text(isRefreshing ? "Refreshing standings..." : "A scoring update is available. Refresh standings.")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .alignLeading()
                }
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Label(
                    isRefreshing ? "Refreshing..." : "Refresh",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassCardEffect(cornerRadius: 12, tint: Color.accentGreen.opacity(0.14), shadowOpacity: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
    }

    private var individualLeaderboardControls: some View {
        HStack {
            individualLeaderboardModeChip

            Spacer(minLength: 0)

            if individualLeaderboardMode == .stats {
                individualStatsSortChip
            }
        }
    }

    private var individualLeaderboardModeChip: some View {
        Menu {
            ForEach(SeriesIndividualLeaderboardMode.allCases, id: \.self) { mode in
                Button {
                    Haptics.fire(.light)
                    individualLeaderboardMode = mode
                } label: {
                    Label(
                        mode.rawValue,
                        systemImage: individualLeaderboardMode == mode ? "checkmark" : "circle"
                    )
                }
            }
        } label: {
            chipLabel(individualLeaderboardMode.rawValue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Individual leaderboard mode")
        .accessibilityValue(individualLeaderboardMode.rawValue)
    }

    private var individualStatsSortChip: some View {
        Menu {
            ForEach(SeriesIndividualStatsSort.allCases, id: \.self) { sort in
                Button {
                    Haptics.fire(.light)
                    individualStatsSort = sort
                } label: {
                    Label(
                        sort.label,
                        systemImage: individualStatsSort == sort ? "checkmark" : "circle"
                    )
                    if let menuSubtitle = sort.menuSubtitle(config: viewModel.series.handicapConfig.config) {
                        Text(menuSubtitle)
                    }
                }
            }
        } label: {
            chipLabel("Sort by \(individualStatsSort.label)")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Individual stats sort")
        .accessibilityValue(individualStatsSort.accessibilityLabel)
    }

    private func chipLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .fontStyle(kFontName, size: 12, weight: .semibold)
        .foregroundStyle(palette.foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
    }

    @ViewBuilder
    private func individualStatsTableContent(rows: [SeriesIndividualStatsRow]) -> some View {
        if rows.isEmpty {
            EmptyStateView(
                imageName: EmptyStatePreset.seriesStandings.imageName,
                title: EmptyStatePreset.seriesStandings.title,
                subtitle: "Round stats from completed rounds will appear here."
            )
            .frame(minHeight: 200)
        } else {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    individualStatsHeader
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        individualStatsRow(row, rank: index + 1)
                    }
                }
                .frame(width: 416)
            }
            .scrollIndicators(.hidden)
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
        .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
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

    private func standingsHeader(isTeam: Bool, showsAverage: Bool) -> some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 28, alignment: .center)
            Text("Name")
                .alignLeading()
            Text(isTeam ? "Pts" : "Points")
                .frame(width: isTeam ? 44 : (showsAverage ? 52 : 64), alignment: .trailing)
            if showsAverage {
                Text("Avg")
                    .frame(width: 48, alignment: .trailing)
            }
            if isTeam {
                if !showsAverage {
                    Text("W")
                        .frame(width: 32, alignment: .trailing)
                }
                Text("Rds")
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .fontStyle(kFontName, size: 12, weight: .semibold)
        .foregroundStyle(Color.neutral)
    }

    private var individualStatsHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 28, alignment: .center)
            Text("Name")
                .frame(width: 128, alignment: .leading)
            Text("Diff")
                .frame(width: 52, alignment: .trailing)
            Text("HCP")
                .frame(width: 48, alignment: .trailing)
            Text("Played")
                .frame(width: 52, alignment: .trailing)
            Text("Gross")
                .frame(width: 56, alignment: .trailing)
            Text("Net")
                .frame(width: 52, alignment: .trailing)
        }
        .fontStyle(kFontName, size: 12, weight: .semibold)
        .foregroundStyle(Color.neutral)
    }

    private var sortedStatsRows: [SeriesIndividualStatsRow] {
        viewModel.individualStatsRows.sorted { lhs, rhs in
            switch individualStatsSort {
            case .averageDifferential:
                if let result = compareFiniteAscending(lhs.averageDifferential, rhs.averageDifferential) {
                    return result
                }
            case .handicapIndex:
                if let result = compareFiniteAscending(lhs.currentHandicap, rhs.currentHandicap) {
                    return result
                }
            case .roundsPlayed:
                if lhs.roundsPlayed != rhs.roundsPlayed {
                    return lhs.roundsPlayed > rhs.roundsPlayed
                }
            case .averageGross:
                if let result = compareFiniteAscending(lhs.averageGross, rhs.averageGross) {
                    return result
                }
            case .averageNet:
                if let result = compareFiniteAscending(lhs.averageNet, rhs.averageNet) {
                    return result
                }
            }

            return nameSort(lhs, rhs)
        }
    }

    private func compareFiniteAscending(_ lhs: Double?, _ rhs: Double?) -> Bool? {
        let left = finiteValue(lhs)
        let right = finiteValue(rhs)
        switch (left, right) {
        case let (l?, r?) where l != r:
            return l < r
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return nil
        }
    }

    private func finiteValue(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private func nameSort(_ lhs: SeriesIndividualStatsRow, _ rhs: SeriesIndividualStatsRow) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    @ViewBuilder
    private func standingRow(
        _ standing: SeriesStanding,
        rank: Int,
        isTeam: Bool,
        showsAverage: Bool
    ) -> some View {
        if isTeam {
            Button {
                Haptics.fire(.light)
                selectedTeamStanding = standing
            } label: {
                standingRowContent(standing, rank: rank, isTeam: true, showsAverage: showsAverage)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View details for \(standing.competitorName)")
        } else {
            standingRowContent(standing, rank: rank, isTeam: false, showsAverage: showsAverage)
        }
    }

    private func standingRowContent(
        _ standing: SeriesStanding,
        rank: Int,
        isTeam: Bool,
        showsAverage: Bool
    ) -> some View {
        HStack(spacing: 0) {
            Text("\(rank)")
                .frame(width: 28, alignment: .center)
                .fontStyle(kFontName, size: 15, weight: rank <= 3 ? .bold : .semibold)
                .foregroundStyle(palette.foregroundColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(standing.competitorName)
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)

                if isTeam, let subtitle = viewModel.teamRosterSubtitle(for: standing.competitorID) {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                }
            }
            .alignLeading()

            Text(standing.totalPoints.seriesPointsDisplayString)
                .frame(width: isTeam ? 44 : (showsAverage ? 52 : 64), alignment: .trailing)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            if showsAverage {
                Text(formattedTiebreakAverage(for: standing))
                    .frame(width: 48, alignment: .trailing)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .monospacedDigit()
            }

            if isTeam {
                if !showsAverage {
                    Text("\(standing.wins)")
                        .frame(width: 32, alignment: .trailing)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Text("\(standing.roundsCounted)")
                    .frame(width: 36, alignment: .trailing)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

                Icon(name: "f054", size: 10, weight: .regular)
                    .foregroundStyle(Color.neutral2)
                    .frame(width: 16, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }

    private func primaryTiebreakSummary(for standing: SeriesStanding) -> SeriesStandingTiebreakSummary? {
        standing.tiebreakSummaries?.first
    }

    private func formattedTiebreakAverage(for standing: SeriesStanding) -> String {
        guard let summary = primaryTiebreakSummary(for: standing),
              summary.isEligible else { return "—" }
        return SeriesStandingsAverageFormatter.string(summary.average)
    }

    private func individualStatsRow(_ row: SeriesIndividualStatsRow, rank: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(rank)")
                .frame(width: 28, alignment: .center)
                .fontStyle(kFontName, size: 15, weight: rank <= 3 ? .bold : .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text(row.name)
                .fontStyle(kFontName, size: 14, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .frame(width: 128, alignment: .leading)

            Text(differentialDisplay(row.averageDifferential))
                .frame(width: 52, alignment: .trailing)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text(handicapDisplay(row.currentHandicap))
                .frame(width: 48, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            Text("\(row.roundsPlayed)")
                .frame(width: 52, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            Text(scoreAverageDisplay(row.averageGross))
                .frame(width: 56, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .monospacedDigit()

            Text(scoreAverageDisplay(row.averageNet))
                .frame(width: 52, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(individualStatsAccessibilityLabel(row, rank: rank))
    }

    private func differentialDisplay(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        let rounded = abs(value) < 0.05 ? 0 : value
        let formatted = String(format: "%.1f", rounded)
        return rounded > 0 ? "+\(formatted)" : formatted
    }

    private func handicapDisplay(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return String(format: "%.1f", value)
    }

    private func scoreAverageDisplay(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    private func individualStatsAccessibilityLabel(_ row: SeriesIndividualStatsRow, rank: Int) -> String {
        "Rank \(rank), \(row.name), average differential \(differentialDisplay(row.averageDifferential)), handicap index \(handicapDisplay(row.currentHandicap)), \(row.roundsPlayed) rounds played, gross average \(scoreAverageDisplay(row.averageGross)), net average \(scoreAverageDisplay(row.averageNet))"
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
                    if roundAwards.count > 0 {
                        Text("\(roundAwards.count) awards")
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                    }

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

private struct SeriesTeamDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let standing: SeriesStanding

    @State private var insight: SeriesTeamInsight?
    @State private var isLoading = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: insight?.teamName ?? standing.competitorName,
                subtitle: insight?.rosterSubtitle,
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let insight {
                        overviewSection(insight)
                        if let tiebreakSummary {
                            tiebreakSection(tiebreakSummary)
                        }
                        topContributorSection(insight)
                        playerFormSection(insight)
                        scheduleSection(insight)
                    } else {
                        loadingSection
                    }

                    Spacer(minLength: 0)
                        .frame(height: 24)
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .task(id: standing.id) {
            isLoading = true
            insight = await viewModel.teamInsight(for: standing)
            isLoading = false
        }
    }

    private var loadingSection: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.accentGreen)
            Text(isLoading ? "Loading team details..." : "No team details available.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func overviewSection(_ insight: SeriesTeamInsight) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(title: "Points", value: insight.totalPoints.seriesPointsDisplayString)
            statTile(title: "Record", value: insight.record.displayString)
            statTile(title: "Avg Points", value: insight.averagePoints.map(SeriesTeamInsightBuilder.formatDecimal) ?? "—")
            statTile(title: "Avg Score", value: insight.averageGrossScore.map(SeriesTeamInsightBuilder.formatDecimal) ?? "—")
            statTile(title: "Score Spread", value: insight.scoreSpread.map { "±\(SeriesTeamInsightBuilder.formatDecimal($0))" } ?? "—")
            statTile(title: "Roster", value: "\(insight.roster.count)")
        }
        .padding(16)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private var tiebreakSummary: SeriesStandingTiebreakSummary? {
        standing.tiebreakSummaries?.first
    }

    private func tiebreakSection(_ summary: SeriesStandingTiebreakSummary) -> some View {
        let averageText = SeriesStandingsAverageFormatter.string(summary.average)

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Scoring Average")

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tiebreakComponentTitle(summary.scoreComponent))
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                    Text(summary.isEligible ? "Eligible tiebreak" : "Needs \(summary.minimumEligibleRounds) rounds")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)
                Text(averageText)
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .monospacedDigit()
            }
            .padding(12)
            .background(palette.cardEmbeddedRowBackground)
            .clipShape(.rect(cornerRadius: 8))

            ForEach(summary.roundValues, id: \.seriesRoundID) { value in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(roundTitle(for: value.seriesRoundID))
                            .fontStyle(kFontName, size: 13, weight: .medium)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                        Text("\(value.expectedHoleCount) holes")
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    Spacer(minLength: 0)
                    Text(SeriesStandingsAverageFormatter.string(value.value))
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func roundTitle(for seriesRoundID: String) -> String {
        viewModel.rounds.first(where: { $0.id == seriesRoundID })?.title ?? "Round"
    }

    private func tiebreakComponentTitle(_ component: SeriesTiebreakScoreComponent) -> String {
        switch component {
        case .total: return "Scoring total average"
        case .rawStrokes: return "Raw stroke average"
        case .netStrokes: return "Net stroke average"
        case .scoreToPar: return "Average score to par"
        }
    }

    private func topContributorSection(_ insight: SeriesTeamInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Top Contributor")

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
                    .frame(width: 42, height: 42)
                    .background(Color.accentGreen.opacity(colorScheme.translucent))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.topContributorName)
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text(insight.topContributorDetail)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(palette.cardEmbeddedRowBackground)
            .cornerRadius(16)
        }
        .padding(16)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func playerFormSection(_ insight: SeriesTeamInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Player Form")

            if insight.playerPerformances.isEmpty {
                Text("No active roster members yet.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                VStack(spacing: 10) {
                    ForEach(insight.playerPerformances) { player in
                        playerFormRow(player)
                    }
                }
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func scheduleSection(_ insight: SeriesTeamInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Schedule")

            if insight.scheduleRows.isEmpty {
                Text("Schedule a round to start building team history.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                VStack(spacing: 10) {
                    ForEach(insight.scheduleRows) { row in
                        scheduleRow(row)
                    }
                }
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral)
            Text(value)
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardEmbeddedRowBackground)
        .cornerRadius(16)
    }

    private func playerFormRow(_ player: SeriesTeamPlayerPerformance) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)

                Text(playerSubtitle(player))
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(player.points.seriesPointsDisplayString) pts")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                if let trendLabel = player.trendLabel {
                    Text(trendLabel)
                        .fontStyle(kFontName, size: 11, weight: .medium)
                        .foregroundStyle(playerTrendTint(for: player.trendKind))
                }
            }
        }
        .padding(14)
        .background(palette.cardEmbeddedRowBackground)
        .cornerRadius(16)
    }

    private func scheduleRow(_ row: SeriesTeamScheduleRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)

                Text("vs \(row.opponentName) • \(row.statusLabel)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.outcomeLabel)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(outcomeTint(for: row.outcomeKind))
                    .lineLimit(1)
                if let pointsLabel = row.pointsLabel {
                    Text(pointsLabel)
                        .fontStyle(kFontName, size: 11, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
        .padding(14)
        .background(palette.cardEmbeddedRowBackground)
        .cornerRadius(16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 13, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
    }

    private func playerSubtitle(_ player: SeriesTeamPlayerPerformance) -> String {
        var parts = ["\(player.roundsPlayed) rds"]
        if let averageGross = player.averageGross {
            parts.append("\(SeriesTeamInsightBuilder.formatDecimal(averageGross)) avg")
        }
        if let bestGross = player.bestGross {
            parts.append("\(bestGross) best")
        }
        return parts.joined(separator: " • ")
    }

    private func outcomeTint(for kind: SeriesTeamScheduleOutcomeKind) -> Color {
        switch kind {
        case .win: return .accentGreen
        case .loss: return .systemError
        case .tie, .placement: return .systemBlue
        case .pending: return .neutral
        }
    }

    private func playerTrendTint(for kind: SeriesTeamPlayerTrendKind?) -> Color {
        switch kind {
        case .improved: return .accentGreen
        case .worse: return .systemError
        case .steady, .none: return .neutral
        }
    }
}
