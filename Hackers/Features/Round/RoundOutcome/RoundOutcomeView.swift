//
//  RoundOutcomeView.swift
//  Hackers
//
//  Empty state outcome view for completed golf rounds.
//

import Flow
import SwiftUI

private enum RoundOutcomeTab: String, CaseIterable {
    case leaderboard
    case matchups

    var icon: String {
        switch self {
        case .leaderboard: "list.number"
        case .matchups: "f71d"
        }
    }

    var iconType: IconType {
        switch self {
        case .leaderboard: .sanFrancisco
        case .matchups: .fontAwesome
        }
    }

    func fontWeight(_ selection: Bool) -> FontModule.Weight {
        selection ? iconType.activeWeight : iconType.normalWeight
    }

    var title: String {
        switch self {
        case .leaderboard: "Leaderboard"
        case .matchups: "Matchups"
        }
    }
}

struct RoundOutcomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession

    @StateObject private var viewModel = LiveRoundViewModel()

    @State private var showEditRoundSheet = false
    @State private var showFullScorecard = false
    @State private var selectedFullScorecardScoringUnitID: String?
    @State private var presentedParticipant: RoundParticipant?
    @State private var isCourseBreakdownExpanded = false
    @State private var holeSort: LiveRoundViewModel.OutcomeHoleSort = .holeNumber
    @State private var holeMetricMode: LiveRoundViewModel.OutcomeHoleMetricMode = .total
    @State private var selectedOutcomeTab: RoundOutcomeTab = .leaderboard

    private var snapshot: RoundSnapshot { roundSession.snapshot }
    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .yellow)

            if visibleOutcomeTabs.count > 1 {
                TabView(selection: $selectedOutcomeTab) {
                    leaderboardPage
                        .tag(RoundOutcomeTab.leaderboard)

                    matchupsPage
                        .tag(RoundOutcomeTab.matchups)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                leaderboardPage
            }

            outcomeNavHeader
                .padding(.horizontal, 16)
                .alignTop()

            if visibleOutcomeTabs.count > 1 {
                roundOutcomeTabStripContainer
                    .padding(.horizontal, 16)
                    .alignBottom()
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            if let id = appSession.activeRoundID {
                await roundSession.activate(roundID: id, profile: .roundOutcome)
            }
            viewModel.bind(appSession: appSession, roundSession: roundSession)
        }
        .onChange(of: visibleOutcomeTabs) { _, tabs in
            if !tabs.contains(selectedOutcomeTab) {
                selectedOutcomeTab = .leaderboard
            }
        }
        .fullScreenCover(isPresented: $showEditRoundSheet) {
            GameLobby(isEditMode: true)
                .environmentObject(appSession)
                .environmentObject(roundSession)
        }
        .sheet(isPresented: $showFullScorecard) {
            if let participant = snapshot.participants.first {
                FullScorecardView(
                    viewModel: viewModel,
                    participant: participant,
                    allowsScoreEditing: appSession.roundOutcomeAllowsEditing,
                    initialSelectedScoringUnitID: selectedFullScorecardScoringUnitID
                )
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .fullScreenCover(item: $presentedParticipant) { participant in
            IndividualScorecardView(
                viewModel: viewModel,
                participant: participant
            )
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private var visibleOutcomeTabs: [RoundOutcomeTab] {
        viewModel.matchupSections.isPopulated ? [.leaderboard, .matchups] : [.leaderboard]
    }

    private var leaderboardPage: some View {
        outcomePageScroll {
            if let summary = viewModel.outcomePersonalSummary {
                OutcomeSummaryTilesView(
                    palette: palette,
                    summary: summary,
                    adjustedIndexSubtitle: viewModel.outcomeAdjustedIndexSubtitle(for: summary.participant),
                    scoreFormatter: { viewModel.scoreToParLabel($0) }
                )
            }

            courseTile
            viewFullScorecardButton
            leaderboardTile
        }
    }

    private var matchupsPage: some View {
        outcomePageScroll {
            if viewModel.matchupSections.isEmpty {
                Text("No matchup results yet.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 24)
                    .alignCenter()
            } else {
                ForEach(viewModel.orderedMatchupSections) { item in
                    OutcomeMatchupTileView(
                        section: item.section,
                        matchIndex: item.displayIndex,
                        viewModel: viewModel,
                        palette: palette,
                        snapshot: snapshot,
                        onParticipantTap: { presentedParticipant = $0 }
                    )
                }
            }
        }
    }

    private func outcomePageScroll<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    navPadding
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
                .frame(width: proxy.size.width, alignment: .top)
            }
        }
    }

    private var navPadding: some View {
        outcomeNavHeader
            .disabled(true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var outcomeNavHeader: some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                dismiss()
            }

            Spacer(minLength: 0)

            outcomeTitleCard

            Spacer(minLength: 0)

            if appSession.roundOutcomeAllowsEditing {
                Menu {
                    Button {
                        Haptics.fire(.light)
                        showEditRoundSheet = true
                    } label: {
                        Label("Edit round", systemImage: "pencil")
                    }
                    Menu {
                        Button {
                            Haptics.fire(.light)
                            viewModel.nameDisplayFormat = .firstInitialLastName
                        } label: {
                            HStack {
                                Text("J. Smith")
                                if viewModel.nameDisplayFormat == .firstInitialLastName {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button {
                            Haptics.fire(.light)
                            viewModel.nameDisplayFormat = .firstNameLastInitial
                        } label: {
                            HStack {
                                Text("John S.")
                                if viewModel.nameDisplayFormat == .firstNameLastInitial {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Label("Name display", systemImage: "person.text.rectangle")
                    }
                    .menuActionDismissBehavior(.disabled)
                    .onTapGesture {
                        Haptics.fire(.light)
                    }
                } label: {
                    NavButton(style: .glass, icon: "pencil", color: palette.foregroundColor)
                }
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var outcomeTitleCard: some View {
        Text(selectedOutcomeTab.title.uppercased())
            .fontStyle(kFontName, size: 15, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 7)
            .padding(.horizontal, 24)
            .glassCardEffect()
    }

    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: snapshot.round.lastUpdatedAt.unix)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var holeCount: Int {
        snapshot.holeRange?.count ?? 18
    }

    private var courseTile: some View {
        let participant = viewModel.outcomeParticipant
        let tee = viewModel.resolvedPlayedTee(for: participant)

        return OutcomeExpandableCourseSummaryCardView(
            palette: palette,
            title: snapshot.courseInfo?.name ?? "Course unavailable",
            subtitle: "\(formattedDate) \(kDot) \(snapshot.gameFormat.type.displayName)",
            location: courseLocationText,
            holesText: "\(holeCount)",
            parText: tee.map { "\($0.par(for: snapshot.holeSegment))" } ?? "—",
            teeText: tee?.name ?? "—",
            yardsText: tee.map { "\($0.yardage(for: snapshot.holeSegment))" } ?? "—",
            rows: viewModel.outcomeHolePerformanceRows(sortedBy: holeSort),
            isExpanded: $isCourseBreakdownExpanded,
            sort: $holeSort,
            metricMode: $holeMetricMode,
            metricFormatter: viewModel.formattedOutcomeHoleMetric(_:mode:prefersInteger:)
        )
    }

    @ViewBuilder
    private var outcomeScoringChips: some View {
        let chips = viewModel.availableLeaderboardChips

        if chips.count > 1 {
            HFlow(spacing: 8) {
                ForEach(chips, id: \.rawValue) { chip in
                    let isSelected = viewModel.effectiveLeaderboardChip == chip
                    Button {
                        Haptics.fire(.light)
                        viewModel.selectedLeaderboardChip = chip
                    } label: {
                        Text(chip.label)
                            .fontStyle(kFontName, size: 13, weight: isSelected ? .semibold : .medium)
                            .foregroundStyle(isSelected ? palette.foregroundColor : Color.neutral2)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? palette.foregroundColor.opacity(colorScheme.translucent) : Color.clear)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var viewFullScorecardButton: some View {
        Button {
            Haptics.fire(.light)
            if snapshot.participants.isPopulated {
                selectedFullScorecardScoringUnitID = nil
                showFullScorecard = true
            }
        } label: {
            HStack(spacing: 8) {
                Icon(name: "menucard", size: 18, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                Text("View full scorecard")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .glassCardEffect(interactive: true)
    }

    private var leaderboardTile: some View {
        VStack(spacing: 12) {
            Text("Overall leaderboard".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            Line()

            outcomeScoringChips
            outcomeLeaderboardPickers

            if viewModel.effectiveLeaderboardRows.isEmpty {
                Text("No players in this round yet.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 20)
                    .alignCenter()
            } else {
                switch viewModel.leaderboardMode {
                case .individual:
                    outcomeLeaderboardHeader
                    outcomeLeaderboardList(rows: viewModel.outcomeLeaderboardRows)
                case .team:
                    outcomeGroupedLeaderboardList(sections: viewModel.displayTeamLeaderboardSections)
                case .teeGroup:
                    outcomeGroupedLeaderboardList(sections: viewModel.displayTeeGroupLeaderboardSections)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private var outcomeLeaderboardPickers: some View {
        let modes = viewModel.availableLeaderboardModes
        let showModePicker = modes.count > 1

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                if showModePicker {
                    outcomeLeaderboardModePicker(modes: modes)
                }
                Spacer(minLength: 0)
                if viewModel.handicapsEnabled {
                    outcomeScoreBasisPicker
                }
            }

            VStack(spacing: 8) {
                if showModePicker {
                    outcomeLeaderboardModePicker(modes: modes)
                }
                if viewModel.handicapsEnabled {
                    outcomeScoreBasisPicker
                }
            }
        }
    }

    private func outcomeLeaderboardModePicker(modes: [LiveRoundViewModel.LeaderboardMode]) -> some View {
        Picker("", selection: $viewModel.leaderboardMode) {
            ForEach(modes, id: \.self) { mode in
                Text(viewModel.leaderboardModeLabel(for: mode)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var outcomeScoreBasisPicker: some View {
        Picker("", selection: $viewModel.scoreBasis) {
            Text("Gross").tag(ScoreBasis.gross)
            Text("Net").tag(ScoreBasis.net)
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
    }

    private func outcomeLeaderboardList(rows: [LiveRoundViewModel.LeaderboardRow]) -> some View {
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        let completeRows = rows.filter { $0.scoreCompleteness?.isComplete == true }
        let avg = viewModel.averageForDisplay(rows: completeRows) ?? viewModel.overallAvgForDisplay
        let avgBreakParticipantID: String? = {
            let scoreOrdered = completeRows.filter { !$0.isPinned }.sorted {
                let a = $0.totalPoints ?? Double($0.scoreToPar)
                let b = $1.totalPoints ?? Double($1.scoreToPar)
                if a != b { return isHighestWins ? a > b : a < b }
                return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
            }
            return scoreOrdered.first(where: { row in
                let score = row.totalPoints ?? Double(row.scoreToPar)
                return isHighestWins ? score <= avg : score >= avg
            })?.participant.id
        }()
        let showAvgLineAfterLast = avgBreakParticipantID == nil && snapshot.scoring.isPopulated

        return VStack(spacing: 10) {
            ForEach(rows) { row in
                if let id = avgBreakParticipantID, row.participant.id == id, snapshot.scoring.isPopulated {
                    outcomeAvgBreaklineDivider(avg)
                }

                OutcomeLeaderboardRowView(
                    palette: palette,
                    placeLabel: row.placeLabel,
                    row: row,
                    teamColor: row.teamColor ?? viewModel.teamColor(for: row.participant),
                    nameDisplayFormat: viewModel.nameDisplayFormat,
                    usesFormatDisplay: row.totalPoints != nil,
                    isHighestWinsFormat: isHighestWins,
                    showsHandicap: viewModel.handicapsEnabled,
                    onTap: { handleOutcomeRowTap(row) }
                )

                if row.id != rows.last?.id {
                    Divider().opacity(0.25)
                } else if showAvgLineAfterLast {
                    outcomeAvgBreaklineDivider(avg)
                }
            }
        }
    }

    private var outcomeLeaderboardHeader: some View {
        HStack(spacing: 10) {
            Text("Place")
                .frame(width: 44, alignment: .center)
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.handicapsEnabled {
                Text("HCP")
                    .frame(width: 38, alignment: .center)
            }
            Text(viewModel.scoreBasis == .net ? "Net" : "Gross")
                .frame(width: 44, alignment: .center)
            Text("Holes")
                .frame(width: 42, alignment: .center)
        }
        .fontStyle(kFontName, size: 11, weight: .medium)
        .foregroundStyle(Color.neutral)
    }

    private func outcomeAvgBreaklineDivider(_ avg: Double) -> some View {
        HStack(spacing: 12) {
            Line(color: .neutral3)
            Text("AVG: \(viewModel.formattedAvgForDisplay(avg))")
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(Color.neutral3)
            Line(color: .neutral3)
        }
    }

    private func outcomeGroupedLeaderboardList(sections: [LiveRoundViewModel.GroupedLeaderboardSection]) -> some View {
        VStack(spacing: 4) {
            ForEach(sections) { section in
                outcomeGroupSectionHeader(section)

                VStack(spacing: 8) {
                    ForEach(section.rows) { row in
                        OutcomeLeaderboardRowView(
                            palette: palette,
                            placeLabel: row.placeLabel,
                            row: row,
                            teamColor: row.teamColor ?? viewModel.teamColor(for: row.participant),
                            nameDisplayFormat: viewModel.nameDisplayFormat,
                            usesFormatDisplay: row.totalPoints != nil,
                            isHighestWinsFormat: snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins,
                            showsHandicap: viewModel.handicapsEnabled,
                            onTap: { handleOutcomeRowTap(row) }
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

    private func outcomeGroupSectionHeader(_ section: LiveRoundViewModel.GroupedLeaderboardSection) -> some View {
        HStack(spacing: 8) {
            Text(section.name.uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(section.color ?? Color.neutral)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if viewModel.showsGroupedLeaderboardSectionTotal {
                    outcomeGroupStatLabel("Tot", value: viewModel.formattedGroupedSectionSum(section.sumAggregatedScore))
                }
                outcomeGroupStatLabel("Avg", value: viewModel.formattedAvgScore(section.avgScoreToPar))
            }
        }
        .padding(.vertical, 4)
    }

    private func outcomeGroupStatLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral2)
            Text(value)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
    }

    private var roundOutcomeTabStripContainer: some View {
        HStack(spacing: 8) {
            roundOutcomeTabStrip
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
        }
        .glassCardEffect(
            shape: .capsule,
            material: .bar,
            interactive: true,
            tint: nil
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: visibleOutcomeTabs.count)
    }

    private var roundOutcomeTabStrip: some View {
        let tabWidth: CGFloat = 72
        let tabHeight: CGFloat = 48
        let tabs = visibleOutcomeTabs
        let selectedIndex = tabs.firstIndex(of: selectedOutcomeTab) ?? 0

        return ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        Haptics.fire(.light)
                        selectedOutcomeTab = tab
                    } label: {
                        Icon(name: tab.icon, size: 20, weight: tab.fontWeight(selectedOutcomeTab == tab))
                            .foregroundStyle(selectedOutcomeTab == tab ? palette.foregroundColor : Color.charcoal)
                            .frame(width: tabWidth, height: tabHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Capsule()
                .fill(palette.foregroundColor.opacity(0.125))
                .frame(width: tabWidth, height: tabHeight)
                .offset(x: CGFloat(selectedIndex) * tabWidth)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedOutcomeTab)
        }
        .frame(width: tabWidth * CGFloat(tabs.count), height: tabHeight)
    }

    private var courseLocationText: String? {
        if let street = snapshot.courseInfo?.location?.streetName, street.isPopulated {
            return street
        }
        let cityState = [snapshot.courseInfo?.location?.city, snapshot.courseInfo?.location?.state]
            .compactMap { value -> String? in
                guard let value, value.isPopulated else { return nil }
                return value
            }
        return cityState.isPopulated ? cityState.joined(separator: ", ") : nil
    }

    private func handleOutcomeRowTap(_ row: LiveRoundViewModel.LeaderboardRow) {
        if row.isSharedScoreUnit {
            selectedFullScorecardScoringUnitID = row.scoringUnitID
            showFullScorecard = true
        } else {
            presentedParticipant = row.participant
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    previewRoundOutcome()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    previewRoundOutcome()
        .preferredColorScheme(.dark)
}

@MainActor
private func previewRoundOutcome() -> some View {
    let appSession = AppSession()
    appSession.activeRoundID = "mock_complete_0"

    let snapshot = MockCompletedRound.completedSnapshot(roundID: "mock_complete_0")
    appSession.ephemeralParticipantID = snapshot.participants.first?.id

    let roundSession = RoundSession()
    roundSession.snapshot = snapshot
    roundSession.roundID = "mock_complete_0"

    return RoundOutcomeView()
        .environmentObject(appSession)
        .environmentObject(roundSession)
}
