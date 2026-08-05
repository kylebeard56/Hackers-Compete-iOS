//
//  SeriesRuntimeStore.swift
//  Hackers
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

struct SeriesRoundRuntimeState: Hashable {
    let id: String
    let title: String
    let index: Int
    let status: String
    let scheduledAt: Time?
    let roundID: String?
    let startedAt: Time?
    let completedAt: Time?
    let courseOverride: SeriesCourseSelection?
    let roundConfig: SeriesRoundConfiguration
    let policyBinding: SeriesRoundPolicyBinding?
    let teamScoringProfileID: String?
    let individualScoringProfileID: String?
    let matchupPlans: [SeriesRoundMatchupPlan]
    let plannedMatchups: [SeriesRoundPlannedMatchup]
    let plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    let partnershipPlans: [SeriesRoundPartnershipPlan]
    let notes: String?
    let awardsStatus: String
    let awardsFinalizedAt: Time?
    let automaticAwardsEngineVersion: Int
    let lastScoreAdjustmentAt: Time?
    let lastScoreAdjustmentByMemberID: String?
    let lastScoreAdjustmentReason: String?
    let scoreAdjustmentCount: Int

    init(_ round: SeriesRound) {
        id = round.id
        title = round.title
        index = round.index
        status = round.status.rawValue
        scheduledAt = round.scheduledAt
        roundID = round.roundID
        startedAt = round.startedAt
        completedAt = round.completedAt
        courseOverride = round.courseOverride
        roundConfig = round.roundConfig
        policyBinding = round.policyBinding
        teamScoringProfileID = round.teamScoringProfileID
        individualScoringProfileID = round.individualScoringProfileID
        matchupPlans = round.matchupPlans
        plannedMatchups = round.plannedMatchups
        plannedTeeGroups = round.plannedTeeGroups
        partnershipPlans = round.partnershipPlans
        notes = round.notes
        awardsStatus = round.awardsStatus.rawValue
        awardsFinalizedAt = round.awardsFinalizedAt
        automaticAwardsEngineVersion = round.automaticAwardsEngineVersion
        lastScoreAdjustmentAt = round.lastScoreAdjustmentAt
        lastScoreAdjustmentByMemberID = round.lastScoreAdjustmentByMemberID
        lastScoreAdjustmentReason = round.lastScoreAdjustmentReason
        scoreAdjustmentCount = round.scoreAdjustmentCount
    }
}

struct SeriesRoundsInvalidationPlan: Equatable {
    let hasSemanticChanges: Bool
    let activeLinkedRoundIDs: Set<String>
    let addedActiveLinkedRoundIDs: Set<String>
    let removedActiveLinkedRoundIDs: Set<String>
    let addedAttendanceRoundIDs: Set<String>
    let removedAttendanceRoundIDs: Set<String>
    let shouldResolveStandings: Bool
    let shouldRefreshConfigurationDivergences: Bool
}

enum SeriesRuntimeSubscriptionPolicy {
    static func activeLinkedRoundIDs(in rounds: [SeriesRound]) -> Set<String> {
        Set(rounds.compactMap { round in
            guard round.status == .planned || round.status == .lobby || round.status == .live,
                  let roundID = round.roundID,
                  roundID.isPopulated else {
                return nil
            }
            return roundID
        })
    }

    static func attendanceRoundIDs(in rounds: [SeriesRound], attendanceEnabled: Bool) -> Set<String> {
        guard attendanceEnabled else { return [] }
        return Set(rounds.compactMap { round in
            round.status == .planned && round.roundID == nil ? round.id : nil
        })
    }

    static func listenerBudget(activeLinkedRoundCount: Int, canonicalStandingsEnabled: Bool) -> Int {
        2 + (canonicalStandingsEnabled ? 2 : 0) + activeLinkedRoundCount
    }

    static func invalidationPlan(
        previous: [SeriesRound],
        updated: [SeriesRound],
        attendanceEnabled: Bool
    ) -> SeriesRoundsInvalidationPlan {
        let previousStates = previous.map(SeriesRoundRuntimeState.init)
        let updatedStates = updated.map(SeriesRoundRuntimeState.init)
        let previousActiveIDs = activeLinkedRoundIDs(in: previous)
        let updatedActiveIDs = activeLinkedRoundIDs(in: updated)
        let previousAttendanceIDs = attendanceRoundIDs(in: previous, attendanceEnabled: attendanceEnabled)
        let updatedAttendanceIDs = attendanceRoundIDs(in: updated, attendanceEnabled: attendanceEnabled)

        let previousStandingsInputs = previous.map(SeriesRoundStandingsInput.init)
        let updatedStandingsInputs = updated.map(SeriesRoundStandingsInput.init)
        let previousConfigurationInputs = previous.map {
            SeriesRoundConfigurationInput(round: $0)
        }
        let updatedConfigurationInputs = updated.map {
            SeriesRoundConfigurationInput(round: $0)
        }

        return SeriesRoundsInvalidationPlan(
            hasSemanticChanges: previousStates != updatedStates,
            activeLinkedRoundIDs: updatedActiveIDs,
            addedActiveLinkedRoundIDs: updatedActiveIDs.subtracting(previousActiveIDs),
            removedActiveLinkedRoundIDs: previousActiveIDs.subtracting(updatedActiveIDs),
            addedAttendanceRoundIDs: updatedAttendanceIDs.subtracting(previousAttendanceIDs),
            removedAttendanceRoundIDs: previousAttendanceIDs.subtracting(updatedAttendanceIDs),
            shouldResolveStandings: previousStandingsInputs != updatedStandingsInputs,
            shouldRefreshConfigurationDivergences: previousConfigurationInputs != updatedConfigurationInputs
        )
    }
}

private struct SeriesRoundStandingsInput: Hashable {
    let id: String
    let roundID: String?
    let status: String
    let policyBinding: SeriesRoundPolicyBinding?

    init(round: SeriesRound) {
        id = round.id
        roundID = round.roundID
        status = round.status.rawValue
        policyBinding = round.policyBinding
    }
}

private struct SeriesRoundConfigurationInput: Hashable {
    let id: String
    let roundID: String?
    let title: String
    let scheduledAt: Time?
    let courseOverride: SeriesCourseSelection?
    let roundConfig: SeriesRoundConfiguration
    let teamScoringProfileID: String?
    let individualScoringProfileID: String?
    let matchupPlans: [SeriesRoundMatchupPlan]
    let plannedMatchups: [SeriesRoundPlannedMatchup]
    let plannedTeeGroups: [SeriesRoundPlannedTeeGroup]
    let partnershipPlans: [SeriesRoundPartnershipPlan]

    init(round: SeriesRound) {
        id = round.id
        roundID = round.roundID
        title = round.title
        scheduledAt = round.scheduledAt
        courseOverride = round.courseOverride
        roundConfig = round.roundConfig
        teamScoringProfileID = round.teamScoringProfileID
        individualScoringProfileID = round.individualScoringProfileID
        matchupPlans = round.matchupPlans
        plannedMatchups = round.plannedMatchups
        plannedTeeGroups = round.plannedTeeGroups
        partnershipPlans = round.partnershipPlans
    }
}

struct SeriesHandicapProjection {
    struct ScoreSelection {
        let poolIDs: Set<String>
        let countingIDs: Set<String>
    }

    let handicapsByMemberID: [String: SeriesMemberHandicap]
    let scoreSelectionsByMemberID: [String: ScoreSelection]
}

struct SeriesHandicapTrendPoint: Identifiable, Equatable, Sendable {
    let sourceRoundID: String
    let roundTitle: String
    let date: Date
    let computedIndex: Double

    var id: String { sourceRoundID }
}

enum SeriesHandicapProjectionService {
    static func project(
        members: [SeriesMember],
        scores: [SeriesHandicapScore],
        overrides: [SeriesHandicapOverride],
        handicapConfig: SeriesHandicapConfig
    ) -> SeriesHandicapProjection {
        var handicaps = Dictionary(uniqueKeysWithValues: members.map {
            ($0.id, SeriesMemberHandicap(id: $0.id, memberID: $0.id))
        })
        guard handicapConfig.isEnabled else {
            return SeriesHandicapProjection(
                handicapsByMemberID: handicaps,
                scoreSelectionsByMemberID: [:]
            )
        }

        let config = handicapConfig.config.toConfig()
        let overridesByMember = Dictionary(uniqueKeysWithValues: overrides.map { ($0.memberID, $0) })
        let eligibleScoresByMember = Dictionary(
            grouping: scores.filter(\.countsTowardHandicapIndex),
            by: \.memberID
        )
        var selections: [String: SeriesHandicapProjection.ScoreSelection] = [:]

        for member in members {
            let samples = (eligibleScoresByMember[member.id] ?? []).map { score in
                HandicapScoreSample(
                    id: score.id,
                    gross: grossForIndex(score, config: config),
                    recordedAt: score.recordedAt,
                    sortOrder: score.sortOrder
                )
            }
            let result = computeHandicapIndex(samples: samples, config: config)
            let override = overridesByMember[member.id]
            handicaps[member.id] = SeriesMemberHandicap(
                id: member.id,
                memberID: member.id,
                computedIndex: result?.handicapIndex,
                overrideIndex: override?.overrideIndex,
                isOverridden: override?.isEnabled == true
            )
            selections[member.id] = SeriesHandicapProjection.ScoreSelection(
                poolIDs: result?.poolSampleIDs ?? [],
                countingIDs: result?.selectedSampleIDs ?? []
            )
        }

        return SeriesHandicapProjection(
            handicapsByMemberID: handicaps,
            scoreSelectionsByMemberID: selections
        )
    }

    /// Replays completed league rounds with today's handicap rules. Baselines are
    /// included in every point, but only completed round scores produce points.
    static func trend(
        memberID: String,
        scores: [SeriesHandicapScore],
        rounds: [SeriesRound],
        handicapConfig: SeriesHandicapConfig
    ) -> [SeriesHandicapTrendPoint] {
        guard handicapConfig.isEnabled else { return [] }
        let config = handicapConfig.config.toConfig()
        let eligibleMemberScores = scores.filter {
            $0.memberID == memberID && $0.countsTowardHandicapIndex
        }
        let baselines = eligibleMemberScores.filter { $0.source == .baseline }

        let completedRounds = rounds
            .filter { $0.status == .complete && ($0.roundID?.isPopulated == true || $0.id.isPopulated) }
            .sorted { lhs, rhs in
                let lhsDate = lhs.completedAt ?? lhs.scheduledAt ?? lhs.createdAt
                let rhsDate = rhs.completedAt ?? rhs.scheduledAt ?? rhs.createdAt
                if lhsDate.unix != rhsDate.unix { return lhsDate.unix < rhsDate.unix }
                return lhs.index < rhs.index
            }

        var accumulatedScores = baselines
        var points: [SeriesHandicapTrendPoint] = []

        for round in completedRounds {
            let sourceIDs = Set([round.roundID, round.id].compactMap { $0 }.filter(\.isPopulated))
            let roundScores = eligibleMemberScores.filter { score in
                score.source == .round && score.sourceRoundID.map(sourceIDs.contains) == true
            }
            guard roundScores.isPopulated else { continue }
            accumulatedScores.append(contentsOf: roundScores)

            let samples = accumulatedScores.map { score in
                HandicapScoreSample(
                    id: score.id,
                    gross: grossForIndex(score, config: config),
                    recordedAt: score.recordedAt,
                    sortOrder: score.sortOrder
                )
            }
            guard let result = computeHandicapIndex(samples: samples, config: config) else { continue }

            let title = round.title.isPopulated ? round.title : "Round \(round.index + 1)"
            let pointDate = Date(timeIntervalSince1970: (round.completedAt ?? round.scheduledAt ?? round.createdAt).unix)
            points.append(
                SeriesHandicapTrendPoint(
                    sourceRoundID: round.roundID ?? round.id,
                    roundTitle: title,
                    date: pointDate,
                    computedIndex: result.handicapIndex
                )
            )
        }

        return points
    }

    static func grossForIndex(
        _ score: SeriesHandicapScore,
        config: HandicapComputationConfig
    ) -> Double {
        if score.source == .baseline, score.baselineStrokeBasis == .eighteenHole {
            return normalizedBaselineGrossForHandicapIndex(
                gross: score.score,
                par: score.par,
                defaultParForIndex: config.defaultParForIndex
            ) ?? score.score
        }

        guard config.usesCourseRatingSlopeAdjustment, score.source == .round,
              let rating = score.courseRating,
              let slope = score.courseSlope else {
            return score.score
        }
        return normalizedGrossForHandicapIndex(
            gross: score.score,
            rating: rating,
            slope: slope,
            defaultParForIndex: config.defaultParForIndex
        ) ?? score.score
    }
}

@MainActor
final class SeriesRealtimeSourceStore {
    struct Callbacks {
        let didReceiveSeries: @MainActor (Series) async -> Void
        let didReceiveRounds: @MainActor ([SeriesRound]) async -> Void
        let didReceiveCanonicalStates: @MainActor ([SeriesRoundProcessingState]) async -> Void
        let didReceiveCanonicalResults: @MainActor ([SeriesRoundResult]) async -> Void
        let didReceiveLinkedRound: @MainActor (Round) async -> Void
        let didFail: @MainActor (String, Error) -> Void
    }

    private let callbacks: Callbacks
    private var seriesID: String?
    private var seriesListener: ListenerRegistration?
    private var roundsListener: ListenerRegistration?
    private var canonicalStatesListener: ListenerRegistration?
    private var canonicalResultsListener: ListenerRegistration?
    private var linkedRoundListeners: [String: ListenerRegistration] = [:]

    init(callbacks: Callbacks) {
        self.callbacks = callbacks
    }

    deinit {
        seriesListener?.remove()
        roundsListener?.remove()
        canonicalStatesListener?.remove()
        canonicalResultsListener?.remove()
        linkedRoundListeners.values.forEach { $0.remove() }
    }

    var activeListenerCount: Int {
        (seriesListener == nil ? 0 : 1)
            + (roundsListener == nil ? 0 : 1)
            + (canonicalStatesListener == nil ? 0 : 1)
            + (canonicalResultsListener == nil ? 0 : 1)
            + linkedRoundListeners.count
    }

    var currentSeriesID: String? { seriesID }

    func start(seriesID: String, canonicalStandingsEnabled: Bool) {
        if self.seriesID == seriesID, seriesListener != nil, roundsListener != nil {
            configureCanonicalListeners(enabled: canonicalStandingsEnabled)
            return
        }

        stop()
        self.seriesID = seriesID
        let seriesDocument = Firestore.firestore()
            .collection(Collections.series.name)
            .document(seriesID)

        seriesListener = seriesDocument
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Series source listener failed", error) }
                    return
                }
                guard let snapshot, snapshot.exists, !snapshot.metadata.hasPendingWrites else { return }
                do {
                    let series = try snapshot.data(as: Series.self)
                    Task { @MainActor [weak self] in
                        guard let self, self.seriesID == seriesID else { return }
                        await self.callbacks.didReceiveSeries(series)
                    }
                } catch {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Series source listener decode failed", error) }
                }
            }

        roundsListener = seriesDocument
            .collection(SeriesSubcollection.rounds.rawValue)
            .order(by: "index")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Series rounds source listener failed", error) }
                    return
                }
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                do {
                    let rounds = try snapshot.documents
                        .map { try $0.data(as: SeriesRound.self) }
                        .sorted {
                            if $0.index != $1.index { return $0.index < $1.index }
                            return $0.id < $1.id
                        }
                    Task { @MainActor [weak self] in
                        guard let self, self.seriesID == seriesID else { return }
                        await self.callbacks.didReceiveRounds(rounds)
                    }
                } catch {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Series rounds source listener decode failed", error) }
                }
            }

        configureCanonicalListeners(enabled: canonicalStandingsEnabled)
    }

    func configureCanonicalListeners(enabled: Bool) {
        guard enabled, let seriesID else {
            stopCanonicalListeners()
            return
        }
        guard canonicalStatesListener == nil, canonicalResultsListener == nil else { return }

        let seriesDocument = Firestore.firestore()
            .collection(Collections.series.name)
            .document(seriesID)
        canonicalStatesListener = seriesDocument
            .collection(SeriesSubcollection.roundProcessingStates.rawValue)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Canonical processing listener failed", error) }
                    return
                }
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                do {
                    let states = try snapshot.documents.map { try $0.data(as: SeriesRoundProcessingState.self) }
                    Task { @MainActor [weak self] in
                        guard let self, self.seriesID == seriesID else { return }
                        await self.callbacks.didReceiveCanonicalStates(states)
                    }
                } catch {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Canonical processing listener decode failed", error) }
                }
            }
        canonicalResultsListener = seriesDocument
            .collection(SeriesSubcollection.roundResults.rawValue)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Canonical results listener failed", error) }
                    return
                }
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                do {
                    let results = try snapshot.documents.map { try $0.data(as: SeriesRoundResult.self) }
                    Task { @MainActor [weak self] in
                        guard let self, self.seriesID == seriesID else { return }
                        await self.callbacks.didReceiveCanonicalResults(results)
                    }
                } catch {
                    Task { @MainActor [weak self] in self?.callbacks.didFail("Canonical results listener decode failed", error) }
                }
            }
    }

    @discardableResult
    func reconcileLinkedRoundListeners(roundIDs: Set<String>) -> Set<String> {
        let staleRoundIDs = Set(linkedRoundListeners.keys).subtracting(roundIDs)
        for roundID in staleRoundIDs {
            linkedRoundListeners[roundID]?.remove()
            linkedRoundListeners[roundID] = nil
        }

        for roundID in roundIDs where linkedRoundListeners[roundID] == nil {
            linkedRoundListeners[roundID] = Firestore.firestore()
                .collection(Collections.rounds.name)
                .document(roundID)
                .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                    guard let self else { return }
                    if let error {
                        Task { @MainActor [weak self] in self?.callbacks.didFail("Linked round listener failed", error) }
                        return
                    }
                    guard let snapshot, snapshot.exists, !snapshot.metadata.hasPendingWrites else { return }
                    do {
                        let round = try snapshot.data(as: Round.self)
                        Task { @MainActor [weak self] in
                            guard let self, self.linkedRoundListeners[roundID] != nil else { return }
                            await self.callbacks.didReceiveLinkedRound(round)
                        }
                    } catch {
                        Task { @MainActor [weak self] in self?.callbacks.didFail("Linked round listener decode failed", error) }
                    }
                }
        }
        return staleRoundIDs
    }

    func stop() {
        seriesListener?.remove()
        roundsListener?.remove()
        seriesListener = nil
        roundsListener = nil
        stopCanonicalListeners()
        linkedRoundListeners.values.forEach { $0.remove() }
        linkedRoundListeners = [:]
        seriesID = nil
    }

    private func stopCanonicalListeners() {
        canonicalStatesListener?.remove()
        canonicalResultsListener?.remove()
        canonicalStatesListener = nil
        canonicalResultsListener = nil
    }
}

// MARK: - Live round projections

enum ProjectionConfidence: String, Codable, Sendable {
    case limited
    case medium
    case high

    static func resolve(sampleCount: Int) -> Self {
        switch sampleCount {
        case 36...: .high
        case 12...: .medium
        default: .limited
        }
    }
}

struct ProjectionTrendPoint: Identifiable, Hashable, Sendable {
    let holeNumber: Int
    let value: Int

    var id: Int { holeNumber }
}

struct ProjectionBandPoint: Identifiable, Hashable, Sendable {
    let holeNumber: Int
    let lower: Int
    let median: Int
    let upper: Int

    var id: Int { holeNumber }
}

struct PlayerFinishProjection: Hashable, Sendable {
    let participantID: String
    let scoreBasis: ScoreBasis
    let holesCompleted: Int
    let sampleCount: Int
    let confidence: ProjectionConfidence
    let lowerFinish: Int
    let medianFinish: Int
    let upperFinish: Int
    let actualTrend: [ProjectionTrendPoint]
    let projectedTrend: [ProjectionBandPoint]
}

struct MatchupProbability: Hashable, Sendable {
    let matchupID: String
    let leftWin: Int
    let tie: Int
    let rightWin: Int
    let confidence: ProjectionConfidence
    let isSupported: Bool
    let unsupportedReason: String?

    static func unsupported(matchupID: String, reason: String) -> Self {
        .init(
            matchupID: matchupID,
            leftWin: 0,
            tie: 0,
            rightWin: 0,
            confidence: .limited,
            isSupported: false,
            unsupportedReason: reason
        )
    }
}

struct RoundProjectionSnapshot: Sendable {
    let revision: String
    let scoreBasis: ScoreBasis
    let projections: [String: PlayerFinishProjection]
    let matchupProbabilities: [String: MatchupProbability]
}

struct ProjectionHistoricalSample: Hashable, Sendable {
    let grossRelativeToPar: Int
    let weight: Double
}

struct ProjectionHoleInput: Hashable, Sendable {
    let holeNumber: Int
    let par: Int
    let strokesReceived: Int
    let recordedGross: Int?
    let historicalSamples: [ProjectionHistoricalSample]
}

struct PlayerProjectionInput: Hashable, Sendable {
    let participantID: String
    let scoreBasis: ScoreBasis
    let handicapAllowance: Int
    let holes: [ProjectionHoleInput]
}

struct PlayerProjectionSimulation: Sendable {
    let projection: PlayerFinishProjection
    let finishScenarios: [Int]
    let holeScenarios: [[Int]]
    let grossHoleScenarios: [[Int]]
}

actor RoundProjectionSimulator {
    static let shared = RoundProjectionSimulator()

    func simulate(
        input: PlayerProjectionInput,
        iterations: Int = 5_000,
        seed: UInt64
    ) throws -> PlayerProjectionSimulation {
        let runCount = max(250, iterations)
        let holes = input.holes.sorted { $0.holeNumber < $1.holeNumber }
        let sampleCount = Set(holes.flatMap(\.historicalSamples)).count
        let confidence = ProjectionConfidence.resolve(sampleCount: sampleCount)
        var random = ProjectionSeededGenerator(seed: seed)
        var finishScenarios: [Int] = []
        finishScenarios.reserveCapacity(runCount)
        var holeScenarios: [[Int]] = []
        holeScenarios.reserveCapacity(runCount)
        var grossHoleScenarios: [[Int]] = []
        grossHoleScenarios.reserveCapacity(runCount)
        var pathSamples = Array(repeating: [Int](), count: holes.count)
        for index in pathSamples.indices {
            pathSamples[index].reserveCapacity(runCount)
        }

        for run in 0..<runCount {
            if run.isMultiple(of: 128), Task.isCancelled { throw CancellationError() }
            var cumulative = 0
            var scenarioHoles: [Int] = []
            scenarioHoles.reserveCapacity(holes.count)
            var scenarioGrossHoles: [Int] = []
            scenarioGrossHoles.reserveCapacity(holes.count)
            for (index, hole) in holes.enumerated() {
                let gross: Int
                if let recordedGross = hole.recordedGross {
                    gross = recordedGross
                } else {
                    let relative = sampledRelativeScore(
                        hole: hole,
                        handicapAllowance: input.handicapAllowance,
                        holeCount: holes.count,
                        random: &random
                    )
                    gross = max(1, hole.par + relative)
                }
                let basisStrokes = input.scoreBasis == .net
                    ? gross - hole.strokesReceived
                    : gross
                cumulative += basisStrokes - hole.par
                scenarioHoles.append(basisStrokes - hole.par)
                scenarioGrossHoles.append(gross - hole.par)
                pathSamples[index].append(cumulative)
            }
            finishScenarios.append(cumulative)
            holeScenarios.append(scenarioHoles)
            grossHoleScenarios.append(scenarioGrossHoles)
        }

        let actualTrend = actualTrend(input: input, holes: holes)
        let firstProjectedIndex = max(0, actualTrend.count - 1)
        let projectedTrend = holes.indices.compactMap { index -> ProjectionBandPoint? in
            guard index >= firstProjectedIndex else { return nil }
            let values = pathSamples[index].sorted()
            guard values.isPopulated else { return nil }
            return ProjectionBandPoint(
                holeNumber: holes[index].holeNumber,
                lower: percentile(values, fraction: 0.10),
                median: percentile(values, fraction: 0.50),
                upper: percentile(values, fraction: 0.90)
            )
        }
        let orderedFinish = finishScenarios.sorted()
        let projection = PlayerFinishProjection(
            participantID: input.participantID,
            scoreBasis: input.scoreBasis,
            holesCompleted: holes.filter { $0.recordedGross != nil }.count,
            sampleCount: sampleCount,
            confidence: confidence,
            lowerFinish: percentile(orderedFinish, fraction: 0.10),
            medianFinish: percentile(orderedFinish, fraction: 0.50),
            upperFinish: percentile(orderedFinish, fraction: 0.90),
            actualTrend: actualTrend,
            projectedTrend: projectedTrend
        )
        return PlayerProjectionSimulation(
            projection: projection,
            finishScenarios: finishScenarios,
            holeScenarios: holeScenarios,
            grossHoleScenarios: grossHoleScenarios
        )
    }

    private func actualTrend(
        input: PlayerProjectionInput,
        holes: [ProjectionHoleInput]
    ) -> [ProjectionTrendPoint] {
        var cumulative = 0
        var points: [ProjectionTrendPoint] = []
        for hole in holes {
            guard let gross = hole.recordedGross else { continue }
            let basisStrokes = input.scoreBasis == .net ? gross - hole.strokesReceived : gross
            cumulative += basisStrokes - hole.par
            points.append(ProjectionTrendPoint(holeNumber: hole.holeNumber, value: cumulative))
        }
        return points
    }

    private func sampledRelativeScore(
        hole: ProjectionHoleInput,
        handicapAllowance: Int,
        holeCount: Int,
        random: inout ProjectionSeededGenerator
    ) -> Int {
        let usable = hole.historicalSamples.filter { $0.weight > 0 }
        let totalWeight = usable.reduce(0) { $0 + $1.weight }
        if totalWeight > 0, random.nextUnit() < min(0.90, 0.55 + Double(usable.count) * 0.02) {
            var target = random.nextUnit() * totalWeight
            for sample in usable {
                target -= sample.weight
                if target <= 0 {
                    return max(-3, min(6, sample.grossRelativeToPar))
                }
            }
        }

        let mean = Double(max(0, handicapAllowance)) / Double(max(1, holeCount))
        let gaussian = random.nextGaussian()
        return max(-3, min(6, Int((mean + gaussian * 1.25).rounded())))
    }

    private func percentile(_ sorted: [Int], fraction: Double) -> Int {
        guard let first = sorted.first else { return 0 }
        let index = Int((Double(sorted.count - 1) * fraction).rounded())
        return sorted.indices.contains(index) ? sorted[index] : first
    }
}

actor MatchupProbabilitySimulator {
    static let shared = MatchupProbabilitySimulator()

    func simulate(
        snapshot sourceSnapshot: RoundSnapshot,
        scoreBasis: ScoreBasis,
        playerSimulations: [String: PlayerProjectionSimulation]
    ) async throws -> [String: MatchupProbability] {
        let template = sourceSnapshot.resolvedActiveTemplate
        guard template.inputMode == .strokes, template.scoreSource == .individual else {
            return unsupportedProbabilities(
                snapshot: sourceSnapshot,
                reason: "Odds aren’t available for custom or shared-score formats."
            )
        }
        guard let segment = sourceSnapshot.roundSegment,
              let tee = sourceSnapshot.defaultTee ?? sourceSnapshot.tees.first else {
            return unsupportedProbabilities(
                snapshot: sourceSnapshot,
                reason: "Course scoring context is incomplete."
            )
        }

        let activeParticipants = sourceSnapshot.participants.filter { participant in
            sourceSnapshot.configuration.substitutesScore || !participant.isSubstitute
        }
        let availableSimulations = activeParticipants.compactMap { playerSimulations[$0.id] }
        guard availableSimulations.count == activeParticipants.count,
              let runCount = availableSimulations.map({ $0.grossHoleScenarios.count }).min(),
              runCount > 0 else {
            return unsupportedProbabilities(
                snapshot: sourceSnapshot,
                reason: "Not enough scoring context is available yet."
            )
        }

        let holeNumbers = segment.holeRange.holeNumbers
        var snapshot = sourceSnapshot
        snapshot.participants = snapshot.participants.map { participant in
            var frozen = participant
            frozen.adjustedHandicap = participant.lockedHandicapAllowance
            return frozen
        }
        let scoreSlots = activeParticipants.flatMap { participant in
            holeNumbers.enumerated().map { index, holeNumber in
                ScenarioScoreSlot(
                    participantID: participant.id,
                    holeIndex: index,
                    entry: ScoreEntry(
                        id: ScoreEntry.makeID(
                            hole: holeNumber,
                            segment: segment.id,
                            scoringUnit: participant.id
                        ),
                        holeNumber: holeNumber,
                        segmentID: segment.id,
                        groupID: participant.groupID ?? "",
                        scoringUnitID: participant.id,
                        participantIDs: [participant.id],
                        relativeToPar: 0,
                        entryMode: .relativeToPar,
                        pickedUp: false,
                        entryID: participant.id,
                        parentID: snapshot.round.id
                    )
                )
            }
        }
        let matchupIDs = (segment.matchups ?? []).map(\.id)
        let workerCount = min(runCount, max(1, min(8, ProcessInfo.processInfo.activeProcessorCount)))
        let runsPerWorker = Int(ceil(Double(runCount) / Double(workerCount)))
        var counts = Dictionary(uniqueKeysWithValues: matchupIDs.map { ($0, MatchupCounts()) })

        try await withThrowingTaskGroup(of: [String: MatchupCounts].self) { group in
            for start in stride(from: 0, to: runCount, by: runsPerWorker) {
                let range = start..<min(runCount, start + runsPerWorker)
                group.addTask {
                    try self.evaluateRuns(
                        range,
                        snapshot: snapshot,
                        segment: segment,
                        holes: tee.holes,
                        scoreBasis: scoreBasis,
                        scoreSlots: scoreSlots,
                        matchupIDs: matchupIDs,
                        playerSimulations: playerSimulations
                    )
                }
            }
            for try await partial in group {
                for (matchupID, value) in partial {
                    counts[matchupID, default: .init()].merge(value)
                }
            }
        }

        let confidence = availableSimulations.map(\.projection.confidence).min {
            confidenceRank($0) < confidenceRank($1)
        } ?? .limited
        return Dictionary(uniqueKeysWithValues: (segment.matchups ?? []).map { matchup in
            let value = counts[matchup.id] ?? .init()
            let completedRuns = value.leftWins + value.ties + value.rightWins
            guard completedRuns > 0, value.unsupportedRuns == 0 else {
                return (
                    matchup.id,
                    .unsupported(
                        matchupID: matchup.id,
                        reason: "This matchup’s aggregation can’t be reproduced from player strokes."
                    )
                )
            }
            let left = Int((Double(value.leftWins) / Double(completedRuns) * 100).rounded())
            let tie = min(
                100 - left,
                Int((Double(value.ties) / Double(completedRuns) * 100).rounded())
            )
            return (
                matchup.id,
                MatchupProbability(
                    matchupID: matchup.id,
                    leftWin: left,
                    tie: tie,
                    rightWin: max(0, 100 - left - tie),
                    confidence: confidence,
                    isSupported: true,
                    unsupportedReason: nil
                )
            )
        })
    }

    private nonisolated func outcome(
        matchupResult: MatchupScoringResult,
        template: GameTemplate
    ) -> MatchupOutcome {
        let pairingIDs = matchupResult.matchup.pairingIDs()
        guard pairingIDs.count == 2 else { return .unsupported }
        if let automaticWinner = matchupResult.minimumCountStatus?.autoWinnerSideID {
            return automaticWinner == pairingIDs[0] ? .left : .right
        }
        if matchupResult.minimumCountStatus?.bothSidesUnderMinimum == true { return .tie }
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
        guard let left = rowMap[pairingIDs[0]]?.total,
              let right = rowMap[pairingIDs[1]]?.total else { return .unsupported }
        guard MatchupScoreComparison.totalsDiffer(left, right) else { return .tie }
        let highestWins = matchupResult.isPointsFormat ?? (template.leaderboardSort == .highestWins)
        if highestWins {
            return left > right ? .left : .right
        }
        return left < right ? .left : .right
    }

    private nonisolated func evaluateRuns(
        _ range: Range<Int>,
        snapshot sourceSnapshot: RoundSnapshot,
        segment: RoundSegment,
        holes: [Hole],
        scoreBasis: ScoreBasis,
        scoreSlots: [ScenarioScoreSlot],
        matchupIDs: [String],
        playerSimulations: [String: PlayerProjectionSimulation]
    ) throws -> [String: MatchupCounts] {
        var snapshot = sourceSnapshot
        var values = Dictionary(uniqueKeysWithValues: matchupIDs.map { ($0, MatchupCounts()) })
        for run in range {
            if run.isMultiple(of: 32) { try Task.checkCancellation() }
            snapshot.scoring = scoreSlots.compactMap { slot in
                guard let scenario = playerSimulations[slot.participantID]?.grossHoleScenarios[run],
                      scenario.indices.contains(slot.holeIndex) else { return nil }
                var entry = slot.entry
                entry.relativeToPar = scenario[slot.holeIndex]
                return entry
            }
            let result = ScoringEngine.computeSnapshotResult(
                snapshot: snapshot,
                segment: segment,
                holes: holes,
                basis: scoreBasis,
                scoreLookupSegmentIDs: [segment.id]
            )
            for matchupResult in result.matchupResults {
                let matchupID = matchupResult.matchup.id
                guard var value = values[matchupID] else { continue }
                switch outcome(matchupResult: matchupResult, template: result.template) {
                case .left: value.leftWins += 1
                case .tie: value.ties += 1
                case .right: value.rightWins += 1
                case .unsupported: value.unsupportedRuns += 1
                }
                values[matchupID] = value
            }
        }
        return values
    }

    private func unsupportedProbabilities(
        snapshot: RoundSnapshot,
        reason: String
    ) -> [String: MatchupProbability] {
        Dictionary(uniqueKeysWithValues: (snapshot.roundSegment?.matchups ?? []).map {
            ($0.id, .unsupported(matchupID: $0.id, reason: reason))
        })
    }

    private func confidenceRank(_ value: ProjectionConfidence) -> Int {
        switch value {
        case .limited: 0
        case .medium: 1
        case .high: 2
        }
    }

    private enum MatchupOutcome {
        case left
        case tie
        case right
        case unsupported
    }

    private struct ScenarioScoreSlot {
        let participantID: String
        let holeIndex: Int
        let entry: ScoreEntry
    }

    private struct MatchupCounts: Sendable {
        var leftWins = 0
        var ties = 0
        var rightWins = 0
        var unsupportedRuns = 0

        mutating func merge(_ other: MatchupCounts) {
            leftWins += other.leftWins
            ties += other.ties
            rightWins += other.rightWins
            unsupportedRuns += other.unsupportedRuns
        }
    }
}

struct ProjectionHoldoutObservation: Equatable, Sendable {
    let actualFinish: Int
    let lowerFinish: Int
    let upperFinish: Int
}

enum MatchupCalibrationOutcome: Equatable, Sendable {
    case left
    case tie
    case right
}

struct MatchupCalibrationObservation: Equatable, Sendable {
    let leftProbability: Double
    let tieProbability: Double
    let rightProbability: Double
    let outcome: MatchupCalibrationOutcome
}

enum ProjectionCalibrationMetrics {
    /// Share of hidden finishes captured by the advertised projection interval.
    static func intervalCoverage(_ observations: [ProjectionHoldoutObservation]) -> Double? {
        guard !observations.isEmpty else { return nil }
        let captured = observations.filter {
            $0.actualFinish >= $0.lowerFinish && $0.actualFinish <= $0.upperFinish
        }.count
        return Double(captured) / Double(observations.count)
    }

    /// Multiclass Brier score. Lower is better and zero is perfectly calibrated.
    static func brierScore(_ observations: [MatchupCalibrationObservation]) -> Double? {
        guard !observations.isEmpty else { return nil }
        let total = observations.reduce(0.0) { partial, observation in
            let outcome: (left: Double, tie: Double, right: Double)
            switch observation.outcome {
            case .left: outcome = (1, 0, 0)
            case .tie: outcome = (0, 1, 0)
            case .right: outcome = (0, 0, 1)
            }
            let leftError = observation.leftProbability - outcome.left
            let tieError = observation.tieProbability - outcome.tie
            let rightError = observation.rightProbability - outcome.right
            return partial + leftError * leftError + tieError * tieError + rightError * rightError
        }
        return total / Double(observations.count)
    }

    static func playerIntervalsMeetRolloutGate(
        _ observations: [ProjectionHoldoutObservation]
    ) -> Bool {
        guard let coverage = intervalCoverage(observations) else { return false }
        return (0.70...0.90).contains(coverage)
    }

    static func matchupProbabilitiesMeetRolloutGate(
        observations: [MatchupCalibrationObservation],
        handicapBaseline: [MatchupCalibrationObservation]
    ) -> Bool {
        guard let projectionScore = brierScore(observations),
              let baselineScore = brierScore(handicapBaseline) else { return false }
        return projectionScore <= baselineScore
    }
}

private struct ProjectionSeededGenerator: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextGaussian() -> Double {
        let first = max(0.000_001, nextUnit())
        let second = nextUnit()
        return sqrt(-2 * log(first)) * cos(2 * .pi * second)
    }
}

enum ProjectionSeed {
    static func make(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
