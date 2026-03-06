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
                    formatChipRow
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
                FullScorecardView(viewModel: viewModel, participant: participant)
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

    private var formatChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                formatChip(snapshot.gameFormat.type.displayName, icon: snapshot.gameFormat.type.icon)
            }
            .padding(.vertical, 4)
        }
    }

    private func formatChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Icon(name: icon, size: 14, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCardEffect(shape: .capsule, interactive: false)
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
                    outcomeLeaderboardList(rows: viewModel.leaderboardRows)
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
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                OutcomeLeaderboardRowView(
                    palette: palette,
                    placeLabel: row.placeLabel,
                    row: row,
                    teamColor: viewModel.teamColor(for: row.participant),
                    nameDisplayFormat: viewModel.nameDisplayFormat,
                    isCompleted: participantCompleted(row.participant),
                    hasAttachedScorecard: false,
                    onTap: { presentedParticipant = row.participant }
                )
                if index != rows.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
    }

    private func outcomeGroupedLeaderboard(sections: [LiveRoundViewModel.GroupedLeaderboardSection]) -> some View {
        VStack(spacing: 4) {
            ForEach(sections) { section in
                VStack(spacing: 8) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        OutcomeLeaderboardRowView(
                            palette: palette,
                            placeLabel: row.placeLabel,
                            row: row,
                            teamColor: viewModel.teamColor(for: row.participant),
                            nameDisplayFormat: viewModel.nameDisplayFormat,
                            isCompleted: participantCompleted(row.participant),
                            hasAttachedScorecard: false,
                            onTap: { presentedParticipant = row.participant }
                        )
                        if index != section.rows.count - 1 {
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

    private func participantCompleted(_ participant: RoundParticipant) -> Bool {
        let holes = snapshot.holeRange.map { Array($0.startHole...$0.endHole) } ?? Array(1...18)
        let participantScores = snapshot.scoring.filter {
            $0.scoringUnitID == participant.id && $0.strokes != nil
        }
        let scoredHoles = Set(participantScores.map(\.holeNumber))
        return holes.allSatisfy { scoredHoles.contains($0) }
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
            Text("Completed")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral2)
        }
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
