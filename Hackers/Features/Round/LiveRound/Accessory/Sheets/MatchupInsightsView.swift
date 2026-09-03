//
//  MatchupInsightsView.swift
//  Hackers
//
//  Shared live and completed-round matchup detail.
//

import SwiftUI

struct MatchupInsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: LiveRoundViewModel
    let section: MatchupLeaderboardSection
    let matchIndex: Int

    @State private var probabilityTimeline: MatchupProbabilityTimeline?
    @State private var scoreTimeline: [MatchupScoreTrendPoint] = []
    @State private var isLoadingProbabilityTimeline = false
    @State private var presentedParticipant: RoundParticipant?

    private var palette: DesignPalette {
        .init(theme: .primary, scheme: colorScheme)
    }

    private var currentSection: MatchupLeaderboardSection {
        viewModel.matchupSections.first(where: { $0.id == section.id }) ?? section
    }

    private var presentation: MatchupResultPresentation {
        viewModel.matchupPresentation(in: currentSection)
    }

    private var isFinal: Bool {
        viewModel.snapshot.round.status == .complete
            || viewModel.isLiveMatchupFullyScored(currentSection)
    }

    private var outcomeStatus: LiveRoundViewModel.OutcomeMatchupStatus {
        viewModel.outcomeMatchupStatus(for: currentSection)
    }

    private var statusTitle: String {
        if isFinal {
            return outcomeStatus.title
        }
        if presentation.isTie, presentation.hasCompleteSides {
            return "Match tied"
        }
        if let winningSideID = presentation.winningSideID,
           let leadingSide = presentation.side(id: winningSideID) {
            return "\(leadingSide.title) leads"
        }
        return "Matchup in progress"
    }

    private var statusDetail: String {
        if isFinal {
            return outcomeStatus.detail
        }
        return presentation.hasCompleteSides
            ? presentation.scorelineDetail
            : "Waiting for both sides to post scores"
    }

    private var leftColor: Color {
        presentation.sides.first?.accentColor ?? viewModel.theme.color
    }

    private var rightColor: Color {
        guard presentation.sides.count > 1 else { return .accentPurple }
        return presentation.sides[1].accentColor ?? .accentPurple
    }

    private var totalHoles: Int {
        viewModel.snapshot.segments.first {
            $0.matchups?.contains(where: { $0.id == section.matchup.id }) == true
        }?.holeRange.count ?? viewModel.courseOrderHoleNumbers.count
    }

    private var holesCompleted: Int {
        scoreTimeline.last?.holesCompleted
            ?? presentation.sides.flatMap(\.participants)
                .map { viewModel.holesPlayedCount(for: $0.id) }
                .max()
            ?? 0
    }

    private var currentProbability: MatchupProbability? {
        if let current = viewModel.publishableMatchupProbabilities[section.matchup.id] {
            return current
        }
        return probabilityTimeline?.latest
    }

    private var analyticsTaskID: String {
        [
            viewModel.matchupProbabilityRevision(
                for: section.matchup,
                scoreBasis: viewModel.matchupProbabilityScoreBasis
            ),
            viewModel.matchupScoreBasis.rawValue,
            viewModel.shouldShowMatchupProbabilities ? "visible" : "hidden"
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    MatchupScoreboardCard(
                        presentation: presentation,
                        matchIndex: matchIndex,
                        statusTitle: statusTitle,
                        statusDetail: statusDetail,
                        isFinal: isFinal,
                        holesCompleted: holesCompleted,
                        totalHoles: totalHoles,
                        leftColor: leftColor,
                        rightColor: rightColor,
                        palette: palette
                    )

                    if viewModel.handicapsEnabled {
                        Picker("Matchup scoring basis", selection: $viewModel.matchupScoreBasis) {
                            Text("Gross").tag(ScoreBasis.gross)
                            Text("Net").tag(ScoreBasis.net)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint("Changes displayed matchup scores; win probability remains on the competition basis")
                    }

                    MatchupMomentumCard(
                        probabilityTimeline: probabilityTimeline,
                        currentProbability: currentProbability,
                        scoreTimeline: scoreTimeline,
                        leftName: presentation.sides.first?.title ?? "Left side",
                        rightName: presentation.sides.dropFirst().first?.title ?? "Right side",
                        leftColor: leftColor,
                        rightColor: rightColor,
                        probabilityBasis: viewModel.matchupProbabilityScoreBasis,
                        displayedScoreBasis: viewModel.matchupScoreBasis,
                        isPointsFormat: presentation.isPointsFormat,
                        isFinal: isFinal,
                        isLoading: isLoadingProbabilityTimeline,
                        palette: palette
                    )

                    if !isFinal,
                       let probabilities = currentProbability?.participantCountingProbabilities,
                       probabilities.isPopulated {
                        MatchupCountingChancesCard(
                            sides: presentation.sides,
                            probabilities: probabilities,
                            isFinal: isFinal,
                            palette: palette
                        )
                    }

                    MatchupPlayersCard(
                        sides: presentation.sides,
                        scoreBasis: viewModel.matchupScoreBasis,
                        isPointsFormat: presentation.isPointsFormat,
                        isFinal: isFinal,
                        viewModel: viewModel,
                        palette: palette,
                        onSelectParticipant: presentParticipant
                    )
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(palette.backgroundColor.opacity(0.98))
            .navigationTitle("Matchup insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                        .bold()
                }
            }
        }
        .task(id: analyticsTaskID) {
            await loadAnalytics()
        }
        .sheet(item: $presentedParticipant) { participant in
            PlayerInsightsView(viewModel: viewModel, participant: participant)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .captureScreen("matchup_insights")
    }

    private func presentParticipant(_ participant: RoundParticipant) {
        Haptics.fire(.light)
        presentedParticipant = participant
    }

    private func loadAnalytics() async {
        probabilityTimeline = nil
        scoreTimeline = viewModel.shouldShowMatchupProbabilities
            ? viewModel.matchupScoreTimeline(
                for: section.matchup,
                scoreBasis: viewModel.matchupScoreBasis
            )
            : []

        guard viewModel.shouldShowMatchupProbabilities else {
            probabilityTimeline = .unsupported(
                "Win probability is hidden until secret scoring is revealed."
            )
            isLoadingProbabilityTimeline = false
            return
        }

        isLoadingProbabilityTimeline = true
        let timeline = await viewModel.matchupProbabilityTimeline(
            for: section.matchup,
            scoreBasis: viewModel.matchupProbabilityScoreBasis
        )
        guard !Task.isCancelled else { return }
        probabilityTimeline = timeline
        isLoadingProbabilityTimeline = false
    }
}
