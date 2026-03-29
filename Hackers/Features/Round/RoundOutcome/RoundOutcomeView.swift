//
//  RoundOutcomeView.swift
//  Hackers
//
//  Empty state outcome view for completed golf rounds.
//

import SwiftUI

struct RoundOutcomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession

    @StateObject private var viewModel = LiveRoundViewModel()

    @State private var showEditRoundSheet = false
    @State private var showFullScorecard = false
    @State private var presentedParticipant: RoundParticipant?

    private var snapshot: RoundSnapshot { roundSession.snapshot }
    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .yellow)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    //navPadding

                    metadataTile
                    outcomeScoringChips
                    viewFullScorecardButton
                    leaderboardTile
                }
                .padding(.horizontal, 16)
                .padding(.top, UIApplication.shared.topSafeAreaInset)
                .padding(.bottom, 100)
            }

            outcomeNavHeader
                .padding(.horizontal, 16)
                .alignTop()
        }
        .navigationBarBackButtonHidden(true)
        .task {
            if let id = appSession.activeRoundID {
                if roundSession.roundID != id || !roundSession.isRunning {
                    await roundSession.start(for: id)
                }
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
                    allowsScoreEditing: appSession.roundOutcomeAllowsEditing
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

            Text("Round outcome".uppercased())
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var metadataTile: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text("\(snapshot.gameFormat.type.displayName) \(kDot) \(holeCount) holes")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
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

    @ViewBuilder
    private var outcomeScoringChips: some View {
        let chips = viewModel.availableLeaderboardChips
        if chips.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.rawValue) { chip in
                        let isSelected = viewModel.effectiveLeaderboardChip == chip
                        Button {
                            Haptics.fire(.light)
                            viewModel.selectedLeaderboardChip = chip
                        } label: {
                            Text(chip.label)
                                .fontStyle(kFontName, size: 13, weight: isSelected ? .semibold : .medium)
                                .foregroundStyle(isSelected ? palette.foregroundColor : Color.neutral2)
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
            }
            .padding(.bottom, 4)
        }
    }

    private var viewFullScorecardButton: some View {
        Button {
            Haptics.fire(.light)
            if snapshot.participants.isPopulated {
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
            Text("Leaderboard".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            Line()

            if !viewModel.leaderboardRows.isEmpty {
                leaderboardPickers
            }

            if viewModel.leaderboardRows.isEmpty {
                Text("No players in this round yet.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 20)
                    .alignCenter()
            } else {
                switch viewModel.leaderboardMode {
                case .individual:
                    outcomeLeaderboardList(rows: viewModel.effectiveLeaderboardRows)
                case .team:
                    outcomeGroupedLeaderboard(sections: viewModel.teamLeaderboardSections)
                case .teeGroup:
                    outcomeGroupedLeaderboard(sections: viewModel.teeGroupLeaderboardSections)
                }
            }

            Line()

            leaderboardFooter
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private var leaderboardPickers: some View {
        let modes = viewModel.availableLeaderboardModes
        let showModePicker = modes.count > 1

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                if showModePicker {
                    Picker("", selection: $viewModel.leaderboardMode) {
                        ForEach(modes, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Spacer(minLength: 0)
                if viewModel.handicapsEnabled {
                    Picker("", selection: $viewModel.scoreBasis) {
                        Text("Gross").tag(ScoreBasis.gross)
                        Text("Net").tag(ScoreBasis.net)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }
            VStack(spacing: 8) {
                if showModePicker {
                    Picker("", selection: $viewModel.leaderboardMode) {
                        ForEach(modes, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if viewModel.handicapsEnabled {
                    Picker("", selection: $viewModel.scoreBasis) {
                        Text("Gross").tag(ScoreBasis.gross)
                        Text("Net").tag(ScoreBasis.net)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }
        }
    }

    private func outcomeLeaderboardList(rows: [LiveRoundViewModel.LeaderboardRow]) -> some View {
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        let avg = viewModel.overallAvgForDisplay
        let avgBreakParticipantID: String? = {
            let scoreOrdered = rows.filter { !$0.isPinned }.sorted {
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
                    teamColor: viewModel.teamColor(for: row.participant),
                    nameDisplayFormat: viewModel.nameDisplayFormat,
                    usesFormatDisplay: row.totalPoints != nil,
                    isHighestWinsFormat: isHighestWins,
                    onTap: { presentedParticipant = row.participant }
                )

                if row.id != rows.last?.id {
                    Divider().opacity(0.25)
                } else if showAvgLineAfterLast {
                    outcomeAvgBreaklineDivider(avg)
                }
            }
        }
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

    private func outcomeGroupedLeaderboard(sections: [LiveRoundViewModel.GroupedLeaderboardSection]) -> some View {
        let isHighestWins = snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        return VStack(spacing: 4) {
            ForEach(sections) { section in
                outcomeGroupSectionHeader(section)

                VStack(spacing: 8) {
                    ForEach(section.rows) { row in
                        OutcomeLeaderboardRowView(
                            palette: palette,
                            placeLabel: row.placeLabel,
                            row: row,
                            teamColor: viewModel.teamColor(for: row.participant),
                            nameDisplayFormat: viewModel.nameDisplayFormat,
                            usesFormatDisplay: row.totalPoints != nil,
                            isHighestWinsFormat: isHighestWins,
                            onTap: { presentedParticipant = row.participant }
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

    private var leaderboardFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = snapshot.courseInfo?.name, name.isPopulated {
                Text(name.uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
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

    let roundSession = RoundSession()
    roundSession.snapshot = MockCompletedRound.completedSnapshot(roundID: "mock_complete_0")
    roundSession.roundID = "mock_complete_0"

    return RoundOutcomeView()
        .environmentObject(appSession)
        .environmentObject(roundSession)
}
