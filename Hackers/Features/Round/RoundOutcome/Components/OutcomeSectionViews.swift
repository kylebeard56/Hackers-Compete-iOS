//
//  OutcomeSectionViews.swift
//  Hackers
//
//  Created by Codex on 4/9/26.
//

import SwiftUI

struct OutcomeSummaryTilesView: View {
    let palette: DesignPalette
    let summary: LiveRoundViewModel.OutcomePersonalSummary
    let adjustedIndexSubtitle: String?
    let scoreFormatter: (Int) -> String

    var body: some View {
        HStack(spacing: 12) {
            OutcomeSummaryTile(
                palette: palette,
                eyebrow: "Your score",
                title: summary.participant.name.fullName,
                subtitle: summary.tee.name
            ) {
                        HStack(spacing: 16) {
                            scoreMetric("Gross", value: scoreFormatter(summary.grossScoreToPar))
                            scoreMetric("Net", value: scoreFormatter(summary.netScoreToPar))
                        }
                    }

            OutcomeSummaryTile(
                palette: palette,
                eyebrow: "Adjusted index",
                title: summary.adjustedIndex.map { String(format: "%.1f", $0) } ?? "—",
                subtitle: adjustedIndexSubtitle
            ) {
                EmptyView()
            }
        }
    }

    private func scoreMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral2)
            Text(value)
                .fontStyle(kFontName, size: 22, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OutcomeExpandableCourseSummaryCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let palette: DesignPalette
    let title: String
    let subtitle: String?
    let location: String?
    let holesText: String
    let parText: String
    let teeText: String
    let yardsText: String
    let rows: [LiveRoundViewModel.OutcomeHolePerformanceRow]
    @Binding var isExpanded: Bool
    @Binding var sort: LiveRoundViewModel.OutcomeHoleSort
    @Binding var metricMode: LiveRoundViewModel.OutcomeHoleMetricMode
    let metricFormatter: (Double?, LiveRoundViewModel.OutcomeHoleMetricMode, Bool) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                Haptics.fire(.light)
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    OutcomeCourseSummaryContent(
                        palette: palette,
                        title: title,
                        subtitle: subtitle,
                        location: location,
                        holesText: holesText,
                        parText: parText,
                        teeText: teeText,
                        yardsText: yardsText
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.neutral2)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if isExpanded {
                Line(color: Color.white.opacity(colorScheme.isDark ? 0.10 : 0.16))

                HStack(alignment: .center, spacing: 12) {
                    sortMenu
                    Spacer(minLength: 0)
                    Picker("", selection: $metricMode) {
                        ForEach(LiveRoundViewModel.OutcomeHoleMetricMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                VStack(spacing: 10) {
                    breakdownHeader

                    if rows.isEmpty {
                        Text("No hole data yet.")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(rows) { row in
                                OutcomeCourseHolePerformanceRowView(
                                    palette: palette,
                                    row: row,
                                    metricMode: metricMode,
                                    metricFormatter: metricFormatter
                                )

                                if row.id != rows.last?.id {
                                    Divider().opacity(0.14)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(interactive: false)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(LiveRoundViewModel.OutcomeHoleSort.allCases, id: \.self) { option in
                Button {
                    Haptics.fire(.light)
                    sort = option
                } label: {
                    HStack {
                        Text(option.label)
                        if sort == option {
                            Icon(name: "f00c", size: 12, weight: .solid)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Icon(name: "chevron.down", size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral3)

                Text(sort.label)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(height: 34)
            .padding(.horizontal, 12)
            .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
            .whiteGlassCardShadow(color: palette.shadowColor)
        }
    }

    private var breakdownHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Hole".uppercased())
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral2)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                headerMetric("Best")
                headerMetric("Avg")
                headerMetric("Worst")
            }
        }
    }

    private func headerMetric(_ title: String) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(Color.neutral2)
            .frame(width: OutcomeCourseHolePerformanceRowView.metricColumnWidth, alignment: .trailing)
    }
}

private struct OutcomeCourseSummaryContent: View {
    let palette: DesignPalette
    let title: String
    let subtitle: String?
    let location: String?
    let holesText: String
    let parText: String
    let teeText: String
    let yardsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Course".uppercased())
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral2)

                Text(title.uppercased())
                    .fontStyle(kFontName, size: 18, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(2)

                if let subtitle, subtitle.isPopulated {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }

                if let location, location.isPopulated {
                    Text(location)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 24) {
                courseStat("Holes", value: holesText)
                courseStat("Par", value: parText)
                courseStat("Tee", value: teeText)
                courseStat("Yards", value: yardsText)
            }
        }
    }

    private func courseStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral2)
            Text(value)
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
    }
}

private struct OutcomeCourseHolePerformanceRowView: View {
    @Environment(\.colorScheme) private var colorScheme

    static let metricColumnWidth: CGFloat = 54

    let palette: DesignPalette
    let row: LiveRoundViewModel.OutcomeHolePerformanceRow
    let metricMode: LiveRoundViewModel.OutcomeHoleMetricMode
    let metricFormatter: (Double?, LiveRoundViewModel.OutcomeHoleMetricMode, Bool) -> String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hole \(row.holeNumber)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(colorScheme.isDark ? 0.34 : 0.12))
                    )

                Text(metadataLine)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 10) {
                metricText(bestValue, prefersInteger: metricMode == .total)
                metricText(averageValue, prefersInteger: false)
                metricText(worstValue, prefersInteger: metricMode == .total)
            }
            .padding(.top, 4)
        }
    }

    private var metadataLine: String {
        let par = row.par.map(String.init) ?? "—"
        let yardage = row.yardage.map { "\($0) yd" } ?? "— yd"
        let handicap = row.handicap.map { "HCP \($0)" } ?? "HCP —"
        return "Par \(par) \(kDot) \(yardage) \(kDot) \(handicap)"
    }

    private var bestValue: Double? {
        switch metricMode {
        case .total:
            row.bestGross.map(Double.init)
        case .diff:
            row.bestDiff
        }
    }

    private var averageValue: Double? {
        switch metricMode {
        case .total:
            row.averageGross
        case .diff:
            row.averageDiff
        }
    }

    private var worstValue: Double? {
        switch metricMode {
        case .total:
            row.worstGross.map(Double.init)
        case .diff:
            row.worstDiff
        }
    }

    private func metricText(_ value: Double?, prefersInteger: Bool) -> some View {
        Text(metricFormatter(value, metricMode, prefersInteger))
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .monospacedDigit()
            .frame(width: Self.metricColumnWidth, alignment: .trailing)
    }
}

struct OutcomeGroupedLeaderboardTileView: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let sections: [LiveRoundViewModel.GroupedLeaderboardSection]
    let palette: DesignPalette
    let nameDisplayFormat: NameDisplayFormat
    let showsSectionTotal: Bool
    let formattedGroupedSectionSum: (Double) -> String
    let formattedAvgScore: (Double) -> String
    let onRowTap: (LiveRoundViewModel.LeaderboardRow) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            Line()

            VStack(spacing: 4) {
                ForEach(sections) { section in
                    groupHeader(section)

                    VStack(spacing: 8) {
                        ForEach(section.rows) { row in
                            OutcomeLeaderboardRowView(
                                palette: palette,
                                placeLabel: row.placeLabel,
                                row: row,
                                teamColor: row.teamColor,
                                nameDisplayFormat: nameDisplayFormat,
                                usesFormatDisplay: row.totalPoints != nil,
                                onTap: { onRowTap(row) }
                            )

                            if row.id != section.rows.last?.id {
                                Divider().opacity(0.15)
                            }
                        }
                    }
                    .padding(.leading, 6)

                    if section.id != sections.last?.id {
                        Line(color: Color.white.opacity(colorScheme.isDark ? 0.10 : 0.16))
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private func groupHeader(_ section: LiveRoundViewModel.GroupedLeaderboardSection) -> some View {
        HStack(spacing: 8) {
            Text(section.name.uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(section.color ?? Color.neutral)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if showsSectionTotal {
                    statLabel("Tot", value: formattedGroupedSectionSum(section.sumAggregatedScore))
                }
                statLabel("Avg", value: formattedAvgScore(section.avgScoreToPar))
            }
        }
        .padding(.vertical, 4)
    }

    private func statLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral2)
            Text(value)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
    }
}

struct OutcomeMatchupTileView: View {
    let section: MatchupLeaderboardSection
    let matchIndex: Int
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let snapshot: RoundSnapshot
    let onParticipantTap: (RoundParticipant) -> Void

    private var status: LiveRoundViewModel.OutcomeMatchupStatus {
        viewModel.outcomeMatchupStatus(for: section)
    }

    private var presentation: MatchupResultPresentation {
        viewModel.matchupPresentation(in: section)
    }

    private var isPointsFormat: Bool {
        viewModel.engineResult.template.leaderboardSort == .highestWins
    }

    private var matchupMode: MatchupMode {
        section.matchup.effectiveMode
    }

    private var participantMap: [String: RoundParticipant] {
        Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
    }

    private var teamMap: [String: RoundTeam] {
        Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })
    }

    private var scoringGroupMap: [String: RoundScoringGroup] {
        Dictionary(uniqueKeysWithValues: snapshot.scoringGroups.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Match \(matchIndex)".uppercased())
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.neutral2)

                    Text(status.title)
                        .fontStyle(kFontName, size: 18, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(status.detail)
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                ForEach(section.matchup.pairingIDs(), id: \.self) { scoringUnitID in
                    matchupSideRow(scoringUnitID: scoringUnitID)
                }
            }

            outcomeMembersTable
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassCardEffect(interactive: false)
    }

    @ViewBuilder
    private func matchupSideRow(scoringUnitID: String) -> some View {
        let side = presentation.side(id: scoringUnitID)
        let isWinner = status.winningScoringUnitID == side?.id
        let accent = side?.accentColor ?? accentColor(for: scoringUnitID)
        let totalText = side?.scoreLabel ?? formattedMatchupTotal(nil)
        let sideTitle = side.map(\.title) ?? viewModel.outcomeMatchupSideName(scoringUnitID: scoringUnitID, matchup: section.matchup)
        let sideSubtitle = side.flatMap(\.subtitle) ?? subtitle(for: scoringUnitID)

        HStack(spacing: 12) {
            Text(totalText)
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(isWinner ? (accent ?? palette.foregroundColor) : palette.foregroundColor)
                .frame(width: 48, height: 48)
                .glassCardEffect(
                    shape: .circle,
                    interactive: false,
                    tint: palette.whiteGlassButtonColor,
                    strokeOpacity: isWinner ? 0.46 : 0.26,
                    shadowOpacity: 0.10
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sideTitle)
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(isWinner ? (accent ?? palette.foregroundColor) : palette.foregroundColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    resultChip(isWinner: isWinner, accent: accent)
                }

                if let subtitle = sideSubtitle, subtitle.isPopulated {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func resultChip(isWinner: Bool, accent: Color?) -> some View {
        if isWinner {
            resultChip("Winner", tint: accent ?? palette.foregroundColor)
        } else if status.isTie {
            resultChip("Tie", tint: Color.neutral)
        }
    }

    private func resultChip(_ title: String, tint: Color) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .fixedSize(horizontal: true, vertical: false)
    }

    private var outcomeMembersTable: some View {
        let columns = viewModel.handicapsEnabled ? ["Player", "HCP", "Gross", "Net"] : ["Player", "HCP", "Gross"]
        let scoreColumnWidth: CGFloat = 52
        let memberItems = matchupMemberItems

        return VStack(spacing: 0) {
            Line(color: Color.neutral6.opacity(0.5))
                .padding(.bottom, 12)

            HStack(spacing: 12) {
                Text(columns[0])
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(columns.dropFirst()), id: \.self) { title in
                    Text(title)
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .frame(minWidth: scoreColumnWidth, alignment: .trailing)
                }
            }
            .padding(.bottom, 8)

            ForEach(memberItems.indices, id: \.self) { index in
                let item = memberItems[index]
                OutcomeMatchupPlayerRowView(
                    participant: item.participant,
                    isActive: item.side.isParticipantActive(item.participant),
                    viewModel: viewModel,
                    palette: palette,
                    scoreColumnWidth: scoreColumnWidth,
                    onTap: { onParticipantTap(item.participant) }
                )

                if index != memberItems.count - 1 {
                    Divider().opacity(0.18)
                }
            }
        }
    }

    private var matchupMemberItems: [(participant: RoundParticipant, side: MatchupResultPresentation.Side)] {
        presentation.sides.flatMap { side in
            side.participants.map { ($0, side) }
        }
        .sorted {
            viewModel.matchupParticipantDisplaySort(
                lhs: $0.participant,
                rhs: $1.participant,
                isPointsFormat: isPointsFormat
            )
        }
    }

    private func accentColor(for scoringUnitID: String) -> Color? {
        switch matchupMode {
        case .team:
            return teamMap[scoringUnitID]?.displaySwatchColor
        case .individual:
            return participantMap[scoringUnitID].flatMap { viewModel.teamColor(for: $0) }
        case .partnership, .teeGroup, .scoreOwner:
            return scoringGroupMap[scoringUnitID].flatMap { viewModel.scoringGroupAccentColor($0) }
        }
    }

    private func subtitle(for scoringUnitID: String) -> String? {
        switch matchupMode {
        case .team:
            let members = viewModel.matchupSideParticipants(scoringUnitID: scoringUnitID, matchup: section.matchup)
                .map { viewModel.formatDisplayName(for: $0) }
                .filter(\.isPopulated)
            return members.isPopulated ? members.joined(separator: ", ") : nil
        case .individual:
            return nil
        case .partnership, .teeGroup, .scoreOwner:
            return scoringGroupMap[scoringUnitID].flatMap { viewModel.scoringGroupSubtitle($0) }
        }
    }

    private func formattedMatchupTotal(_ total: Double?) -> String {
        guard let total else { return "—" }
        return viewModel.formattedMatchupTotal(total, isPointsFormat: isPointsFormat)
    }
}

private struct OutcomeSummaryTile<Content: View>: View {
    let palette: DesignPalette
    let eyebrow: String
    let title: String
    let subtitle: String?
    let content: Content

    init(
        palette: DesignPalette,
        eyebrow: String,
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral2)

            Text(title)
                .fontStyle(kFontName, size: 19, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)

            content

            if let subtitle, subtitle.isPopulated {
                Text(subtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(16)
        .glassCardEffect(interactive: false)
    }
}

private struct OutcomeMatchupPlayerRowView: View {
    let participant: RoundParticipant
    let isActive: Bool
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let scoreColumnWidth: CGFloat
    let onTap: () -> Void

    private var teamColor: Color? {
        viewModel.teamColor(for: participant)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(participant.name.fullName)
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(isActive ? palette.foregroundColor : Color.neutral2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isActive {
                        Circle()
                            .fill(teamColor ?? Color.accentGreen)
                            .frame(width: 8, height: 8)
                    }
                }

                Text("\(participant.adjustedHandicap)")
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)

                Text(viewModel.scoreToParLabel(viewModel.scoreToPar(for: participant, basis: .gross)))
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(isActive ? palette.foregroundColor : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)

                if viewModel.handicapsEnabled {
                    Text(viewModel.scoreToParLabel(viewModel.scoreToPar(for: participant, basis: .net)))
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(isActive ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
                        .frame(minWidth: scoreColumnWidth, alignment: .trailing)
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
