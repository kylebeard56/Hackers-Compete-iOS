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

    private var leftColor: Color {
        presentation.sides.first?.accentColor ?? viewModel.theme.color
    }

    private var rightColor: Color {
        guard presentation.sides.count > 1 else { return .accentPurple }
        return presentation.sides[1].accentColor ?? .accentPurple
    }

    private var matchupParticipants: [RoundParticipant] {
        var seenParticipantIDs = Set<String>()
        return presentation.sides.flatMap(\.participants).filter {
            seenParticipantIDs.insert($0.id).inserted
        }
    }

    private var matchupScorecardHeight: CGFloat {
        min(620, max(360, CGFloat(matchupParticipants.count) * 54 + 230))
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

                    matchupScorecard
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
        .captureScreen("matchup_insights")
    }

    @ViewBuilder
    private var matchupScorecard: some View {
        if let participant = matchupParticipants.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scorecard")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                FullScorecardView(
                    viewModel: viewModel,
                    participant: participant,
                    allowsScoreEditing: false,
                    initialSelectedScoringUnitID: participant.id,
                    presentation: .embeddedInsights,
                    includedParticipantIDs: Set(matchupParticipants.map(\.id))
                )
                .frame(height: matchupScorecardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardEffect(interactive: false, forceMaterial: true)
        }
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
