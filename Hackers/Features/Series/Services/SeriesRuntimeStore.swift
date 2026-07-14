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

    private static func grossForIndex(
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
