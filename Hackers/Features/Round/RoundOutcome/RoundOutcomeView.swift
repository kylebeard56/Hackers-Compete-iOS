//
//  RoundOutcomeView.swift
//  Hackers
//
//  Empty state outcome view for completed golf rounds.
//

import Flow
import SwiftUI

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

    private var snapshot: RoundSnapshot { roundSession.snapshot }
    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .yellow)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if let summary = viewModel.outcomePersonalSummary {
                            OutcomeSummaryTilesView(
                                palette: palette,
                                summary: summary,
                                adjustedIndexSubtitle: viewModel.outcomeAdjustedIndexSubtitle(for: summary.participant),
                                scoreFormatter: { viewModel.scoreToParLabel($0) }
                            )
                        }

                        courseTile
                        outcomeScoringChips
                        viewFullScorecardButton
                        leaderboardTile

                        ForEach(viewModel.outcomeGroupedSectionSets) { set in
                            OutcomeGroupedLeaderboardTileView(
                                title: set.title,
                                sections: set.sections,
                                palette: palette,
                                nameDisplayFormat: viewModel.nameDisplayFormat,
                                showsSectionTotal: viewModel.showsGroupedLeaderboardSectionTotal,
                                formattedGroupedSectionSum: viewModel.formattedGroupedSectionSum(_:),
                                formattedAvgScore: viewModel.formattedAvgScore(_:),
                                onRowTap: { handleOutcomeRowTap($0) }
                            )
                        }

                        if viewModel.matchupSections.isPopulated {
                            matchupsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, UIApplication.shared.topSafeAreaInset)
                    .padding(.bottom, 100)
                    .frame(width: proxy.size.width, alignment: .top)
                }
            }

            outcomeNavHeader
                .padding(.horizontal, 16)
                .alignTop()
        }
        .navigationBarBackButtonHidden(true)
        .task {
            if let id = appSession.activeRoundID {
                await roundSession.activate(roundID: id, profile: .roundOutcome)
            }
            viewModel.bind(appSession: appSession, roundSession: roundSession)
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
        Text("Round outcome".uppercased())
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
        let showsScoreBasis = viewModel.handicapsEnabled

        if chips.count > 1 || showsScoreBasis {
            VStack(alignment: .leading, spacing: 10) {
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

                if showsScoreBasis {
                    Picker("", selection: $viewModel.scoreBasis) {
                        Text("Gross").tag(ScoreBasis.gross)
                        Text("Net").tag(ScoreBasis.net)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
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

            if viewModel.effectiveLeaderboardRows.isEmpty {
                Text("No players in this round yet.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 20)
                    .alignCenter()
            } else {
                outcomeLeaderboardHeader
                outcomeLeaderboardList(rows: viewModel.outcomeLeaderboardRows)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
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

    private var matchupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matchups".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            ForEach(Array(viewModel.matchupSections.enumerated()), id: \.element.id) { index, section in
                OutcomeMatchupTileView(
                    section: section,
                    matchIndex: index + 1,
                    viewModel: viewModel,
                    palette: palette,
                    snapshot: snapshot,
                    onParticipantTap: { presentedParticipant = $0 }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
