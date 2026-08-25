//
//  SeriesRouterView.swift
//  Hackers
//
//  Version-routed Series detail. Active V2 records never fall back to V1 UI.
//

import SwiftUI

struct SeriesRouterView: View {
    @EnvironmentObject private var appSession: AppSession
    let seriesID: String

    var body: some View {
        Group {
            switch routedRecord {
            case .v2:
                SeriesV2View(seriesID: seriesID)
            case .v1:
                SeriesView(seriesID: seriesID)
            case nil:
                ProgressView("Loading series…")
                    .task { await appSession.loadSeries() }
            }
        }
    }

    private var routedRecord: SeriesRecord? {
        if let record = appSession.seriesRecords.first(where: { $0.id == seriesID }) {
            return record
        }
        // Legacy-only preview/session state is safe to treat as V1. An active V2 route
        // is always represented in `seriesRecords` by the server-owned selector.
        return appSession.seriesList.first(where: { $0.id == seriesID }).map(SeriesRecord.v1)
    }
}

private struct SeriesV2RoundSelection: Identifiable {
    let id: String
}

struct SeriesV2View: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSession: AppSession

    let seriesID: String

    @State private var series: SeriesV2?
    @State private var rounds: [RoundV2] = []
    @State private var resultStates: [String: SeriesRoundResultStateV2] = [:]
    @State private var cardStates: [String: SeriesRoundCardViewState] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRound: SeriesV2RoundSelection?

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .green)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Color.clear.frame(height: 76)

                    if let series {
                        seriesHeader(series)
                    }

                    if isLoading && rounds.isEmpty {
                        ProgressView("Loading rounds…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if rounds.isEmpty {
                        EmptyStateView(preset: .mySeries)
                    } else {
                        ForEach(sortedRounds, id: \.id) { round in
                            roundCard(round)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.systemError)
                    }

                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 16)
            }

            navigationBar.alignTop()
        }
        .navigationBarBackButtonHidden()
        .task(id: seriesID) { await load() }
        .sheet(item: $selectedRound) { selection in
            SeriesV2RoundDetailView(
                roundID: selection.id,
                state: cardStates[selection.id],
                palette: palette
            )
        }
    }

    private var sortedRounds: [RoundV2] {
        rounds.sorted {
            let lhs = $0.seriesContext?.roundIndex ?? .max
            let rhs = $1.seriesContext?.roundIndex ?? .max
            if lhs != rhs { return lhs < rhs }
            return ($0.schedule?.scheduledAt.unix ?? .greatestFiniteMagnitude)
                < ($1.schedule?.scheduledAt.unix ?? .greatestFiniteMagnitude)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 44, height: 44)
                    .glassCardEffect(shape: .circle, tint: palette.cardColor)
            }
            .buttonStyle(.plain)

            Text(series?.name ?? "Series")
                .fontStyle(kFontName, size: 18, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func seriesHeader(_ value: SeriesV2) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value.name)
                .fontStyle(kFontName, size: 24, weight: .bold)
                .foregroundStyle(palette.foregroundColor)
            Text("\(value.roundCount) rounds · \(value.completedRoundCount) completed")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
            if let description = value.description, description.isPopulated {
                Text(description)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(cornerRadius: 14, forceMaterial: true, tint: palette.cardColor)
    }

    private func roundCard(_ round: RoundV2) -> some View {
        let state = cardStates[round.id] ?? baseState(for: round)
        return VStack(alignment: .leading, spacing: 12) {
            SeriesRoundCardSummaryView(state: state, palette: palette)

            PrimaryButton(
                appearance: .fill,
                title: state.primaryAction == .viewResults ? "View results" : "Round details",
                labelColor: .white,
                buttonColor: Color.accentGreen,
                theme: palette.theme,
                height: 40,
                fillWidth: true,
                fontSize: 14,
                isDisabled: .constant(false),
                isLoading: .constant(false),
                onTap: { selectedRound = .init(id: round.id) }
            )
        }
        .padding(16)
        .glassCardEffect(cornerRadius: 14, forceMaterial: true, tint: palette.cardColor)
    }

    private func baseState(for round: RoundV2) -> SeriesRoundCardViewState {
        let lifecycle = V2SeriesRoundCardAdapter.lifecycle(
            round: round,
            resultState: resultStates[round.id]
        )
        let config = V2SeriesRoundCardAdapter.resolvedConfiguration(round: round)
        return SeriesRoundCardViewState(
            id: round.id,
            canonicalRoundID: round.id,
            title: round.name.isPopulated ? round.name ?? "Round" : "Round \((round.seriesContext?.roundIndex ?? 0) + 1)",
            courseName: round.configuration.courses.first?.courseInfo.name ?? "Course TBD",
            scheduleLabel: SeriesRoundCardFormatting.scheduleLabel(
                lifecycle: lifecycle,
                scheduledAt: round.schedule?.scheduledAt
            ),
            lifecycle: lifecycle,
            presentationKind: config.presentationKind,
            formatLabel: config.formatName,
            scoringRuleLabel: config.scoringRuleLabel,
            scoreBasis: config.scoreBasis,
            showsHandicap: config.usesHandicaps,
            isProvisional: lifecycle == .live,
            sides: [],
            viewer: nil,
            participantCountLabel: round.participantPlayerIDs.isEmpty ? nil : "\(round.participantPlayerIDs.count) players",
            primaryAction: V2SeriesRoundCardAdapter.primaryAction(
                round: round,
                resultState: resultStates[round.id]
            ),
            isAdjusted: false,
            setupDiffers: false
        )
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if case .v2(let cached)? = appSession.seriesRecords.first(where: { $0.id == seriesID }) {
            series = cached
        }

        async let seriesResult = FirebaseService.shared.fetchSeriesV2(id: seriesID)
        async let roundsResult = FirebaseService.shared.fetchSeriesRoundsV2(seriesID: seriesID)
        async let statesResult = FirebaseService.shared.fetchSeriesRoundResultStatesV2(seriesID: seriesID)
        async let resultsResult = FirebaseService.shared.fetchSeriesRoundResultsV2(seriesID: seriesID)

        if case .success(let value) = await seriesResult { series = value }
        let loadedRounds = (try? await roundsResult.get()) ?? appSession.seriesV2RoundsBySeriesID[seriesID] ?? []
        let states = (try? await statesResult.get()) ?? []
        let results = (try? await resultsResult.get()) ?? []
        rounds = loadedRounds
        appSession.seriesV2RoundsBySeriesID[seriesID] = loadedRounds
        resultStates = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0) })

        let projections = Dictionary(
            grouping: results.filter { $0.cardProjection?.version == SeriesRoundCardViewState.projectionVersion },
            by: \.linkedRoundID
        ).compactMapValues { values in
            values.sorted { $0.generatedAt.unix > $1.generatedAt.unix }.first?.cardProjection?.state
        }
        let viewerPlayerID = await AppData.shared.getPrimaryPlayer()?.id

        var built: [String: SeriesRoundCardViewState] = [:]
        for round in loadedRounds {
            let lifecycle = V2SeriesRoundCardAdapter.lifecycle(round: round, resultState: resultStates[round.id])
            switch await FirebaseService.shared.fetchRoundSnapshotV2(roundID: round.id) {
            case .success(let snapshot):
                built[round.id] = SeriesRoundCardStateBuilder.build(
                    snapshot: snapshot.scoringSnapshot(),
                    context: .init(
                        id: round.id,
                        canonicalRoundID: round.id,
                        title: round.name.isPopulated ? round.name ?? "Round" : "Round \((round.seriesContext?.roundIndex ?? 0) + 1)",
                        scheduleLabel: SeriesRoundCardFormatting.scheduleLabel(
                            lifecycle: lifecycle,
                            scheduledAt: round.schedule?.scheduledAt
                        ),
                        lifecycle: lifecycle,
                        configuration: V2SeriesRoundCardAdapter.resolvedConfiguration(round: round),
                        primaryAction: V2SeriesRoundCardAdapter.primaryAction(
                            round: round,
                            resultState: resultStates[round.id],
                            isViewerParticipant: snapshot.participants.contains { $0.playerID == viewerPlayerID }
                        ),
                        viewerPlayerID: viewerPlayerID,
                        viewerMemberID: nil,
                        isAdjusted: false,
                        setupDiffers: false
                    )
                )
            case .failure:
                if var projected = projections[round.id] {
                    projected.id = round.id
                    projected.canonicalRoundID = round.id
                    projected.lifecycle = lifecycle
                    built[round.id] = projected
                } else {
                    built[round.id] = baseState(for: round)
                }
            }
        }
        cardStates = built
    }
}

private struct SeriesV2RoundDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let roundID: String
    let state: SeriesRoundCardViewState?
    let palette: DesignPalette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let state {
                        SeriesRoundCardSummaryView(state: state, palette: palette)
                            .padding(16)
                            .glassCardEffect(cornerRadius: 14, forceMaterial: true, tint: palette.cardColor)
                    }
                    Text("Canonical round ID")
                        .fontStyle(kFontName, size: 11, weight: .medium)
                        .foregroundStyle(Color.neutral)
                    Text(roundID)
                        .font(.footnote.monospaced())
                        .foregroundStyle(palette.foregroundColor)
                        .textSelection(.enabled)
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
            .navigationTitle("Round details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
