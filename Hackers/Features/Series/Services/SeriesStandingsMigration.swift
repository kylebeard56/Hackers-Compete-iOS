import Foundation

enum SeriesStandingsAuthorityTransitionError: Error, Equatable, LocalizedError {
    case policyRevisionChanged

    var errorDescription: String? {
        "The standings policy changed before authority could be updated. Run the readiness check again."
    }
}

enum SeriesStandingsAuthorityTransition {
    static func applying(
        _ authority: SeriesStandingsReadAuthority,
        to current: Series,
        expectedPolicyRevisionID: String?,
        now: Time = .init()
    ) -> Result<Series, SeriesStandingsAuthorityTransitionError> {
        if let expectedPolicyRevisionID,
           current.settings.standingsPolicyRevision?.id != expectedPolicyRevisionID {
            return .failure(.policyRevisionChanged)
        }
        var updated = current
        updated.settings.standingsReadAuthority = authority
        updated.lastUpdatedAt = now
        return .success(updated)
    }
}

enum SeriesStandingsMigrationPreparationReason: String, Equatable {
    case missingPolicyBinding = "missing_policy_binding"
    case missingProcessingState = "missing_processing_state"
    case incompleteProcessingState = "incomplete_processing_state"
    case staleProcessor = "stale_processor"
    case staleSource = "stale_source"
    case stalePolicy = "stale_policy"
    case missingResult = "missing_result"
    case invalidResultPointer = "invalid_result_pointer"
    case missingCompatibility = "missing_compatibility"
}

enum SeriesStandingsMigrationBlocker: String, Equatable {
    case missingLinkedRound = "missing_linked_round"
    case snapshotUnavailable = "snapshot_unavailable"
    case invalidCompatibility = "invalid_compatibility"
}

enum SeriesStandingsMigrationDisposition: Equatable {
    case ready(generationID: String)
    case needsPreparation(SeriesStandingsMigrationPreparationReason)
    case blocked(SeriesStandingsMigrationBlocker)
}

struct SeriesStandingsMigrationItem: Equatable, Identifiable {
    let id: String
    let title: String
    let index: Int
    let disposition: SeriesStandingsMigrationDisposition
}

struct SeriesStandingsMigrationPlan: Equatable {
    let policyRevisionID: String
    let items: [SeriesStandingsMigrationItem]

    var readyItems: [SeriesStandingsMigrationItem] {
        items.filter {
            if case .ready = $0.disposition { return true }
            return false
        }
    }

    var pendingItems: [SeriesStandingsMigrationItem] {
        items.filter {
            if case .needsPreparation = $0.disposition { return true }
            return false
        }
    }

    var blockedItems: [SeriesStandingsMigrationItem] {
        items.filter {
            if case .blocked = $0.disposition { return true }
            return false
        }
    }

    var isReadyForActivation: Bool {
        pendingItems.isEmpty && blockedItems.isEmpty
    }

    var readyGenerationIDs: [String] {
        items.compactMap {
            guard case .ready(let generationID) = $0.disposition else { return nil }
            return generationID
        }
    }

    func nextBatch(limit: Int) -> [SeriesStandingsMigrationItem] {
        Array(pendingItems.prefix(max(0, limit)))
    }
}

struct SeriesStandingsMigrationComparison: Equatable {
    let missingLegacyStandingIDs: [String]
    let unexpectedLegacyStandingIDs: [String]
    let mismatchedLegacyStandingIDs: [String]
    let authorityChangedStandingIDs: [String]
    let tracksWithOrderingChanges: [SeriesAwardTrack]

    var isActivationSafe: Bool {
        missingLegacyStandingIDs.isEmpty
            && unexpectedLegacyStandingIDs.isEmpty
            && mismatchedLegacyStandingIDs.isEmpty
    }

    var unexplainedMismatchCount: Int {
        missingLegacyStandingIDs.count
            + unexpectedLegacyStandingIDs.count
            + mismatchedLegacyStandingIDs.count
    }
}

struct SeriesStandingsMigrationAssessment: Equatable {
    let plan: SeriesStandingsMigrationPlan
    let comparison: SeriesStandingsMigrationComparison?
    let projectionError: SeriesCanonicalStandingsProjectionError?

    var canActivate: Bool {
        plan.isReadyForActivation
            && projectionError == nil
            && comparison?.isActivationSafe == true
    }
}

enum SeriesStandingsMigrationPlanner {
    static func plan(
        revision: SeriesPolicyRevision,
        substitutesScore: Bool,
        completedRounds: [SeriesRound],
        expectedSourceRevisions: [String: String],
        unavailableRoundIDs: Set<String>,
        processingStates: [SeriesRoundProcessingState],
        results: [SeriesRoundResult]
    ) -> SeriesStandingsMigrationPlan {
        let binding = SeriesStandingsPolicyResolver.binding(
            for: revision,
            substitutesScore: substitutesScore
        )
        let statesByRoundID = Dictionary(uniqueKeysWithValues: processingStates.map { ($0.id, $0) })
        let resultsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        let orderedRounds = completedRounds.sorted {
            if $0.index != $1.index { return $0.index < $1.index }
            return $0.id < $1.id
        }

        let items = orderedRounds.map { round in
            SeriesStandingsMigrationItem(
                id: round.id,
                title: round.title,
                index: round.index,
                disposition: disposition(
                    round: round,
                    binding: binding,
                    revision: revision,
                    expectedSourceRevision: expectedSourceRevisions[round.id],
                    isUnavailable: unavailableRoundIDs.contains(round.id),
                    state: statesByRoundID[round.id],
                    resultsByID: resultsByID
                )
            )
        }
        return SeriesStandingsMigrationPlan(policyRevisionID: revision.id, items: items)
    }

    private static func disposition(
        round: SeriesRound,
        binding: SeriesRoundPolicyBinding,
        revision: SeriesPolicyRevision,
        expectedSourceRevision: String?,
        isUnavailable: Bool,
        state: SeriesRoundProcessingState?,
        resultsByID: [String: SeriesRoundResult]
    ) -> SeriesStandingsMigrationDisposition {
        guard round.roundID?.isPopulated == true else {
            return .blocked(.missingLinkedRound)
        }
        guard !isUnavailable, let expectedSourceRevision else {
            return .blocked(.snapshotUnavailable)
        }
        guard round.policyBinding == binding else {
            return .needsPreparation(.missingPolicyBinding)
        }
        guard let state else {
            return .needsPreparation(.missingProcessingState)
        }
        guard state.status == .completed else {
            return .needsPreparation(.incompleteProcessingState)
        }
        guard state.processorVersion == SeriesRoundCanonicalBuilder.processorVersion else {
            return .needsPreparation(.staleProcessor)
        }
        guard state.sourceRevision == expectedSourceRevision else {
            return .needsPreparation(.staleSource)
        }
        guard state.policyFingerprint == revision.resolvedPolicyFingerprint else {
            return .needsPreparation(.stalePolicy)
        }
        guard let result = resultsByID[state.latestGenerationID] else {
            return .needsPreparation(.missingResult)
        }
        guard result.id == state.latestGenerationID,
              result.seriesRoundID == round.id,
              result.linkedRoundID == round.roundID,
              result.sourceRevision == state.sourceRevision,
              result.sourceUpdatedAt == state.sourceUpdatedAt,
              result.policyRevisionID == revision.id,
              result.policyFingerprint == state.policyFingerprint,
              result.processorVersion == state.processorVersion,
              result.semanticHash == state.resultSemanticHash else {
            return .needsPreparation(.invalidResultPointer)
        }
        for rule in revision.policy.rules {
            guard let compatibility = result.compatibility.first(where: {
                $0.ruleID == rule.id && $0.awardTrack == rule.track
            }) else {
                return .needsPreparation(.missingCompatibility)
            }
            if !["eligible", "normalized", "excluded"].contains(compatibility.classification) {
                return .blocked(.invalidCompatibility)
            }
        }
        return .ready(generationID: result.id)
    }
}

enum SeriesStandingsMigrationComparator {
    static func compare(
        legacyStandings: [SeriesStanding],
        canonicalStandings: [SeriesStanding],
        orderedCanonicalResults: [SeriesRoundResult],
        seriesID: String
    ) -> SeriesStandingsMigrationComparison {
        let canonicalLegacyBaseline = legacyBaseline(
            from: orderedCanonicalResults,
            seriesID: seriesID
        )
        let legacyByID = Dictionary(uniqueKeysWithValues: legacyStandings.map { ($0.id, $0) })
        let baselineByID = Dictionary(uniqueKeysWithValues: canonicalLegacyBaseline.map { ($0.id, $0) })
        let canonicalByID = Dictionary(uniqueKeysWithValues: canonicalStandings.map { ($0.id, $0) })
        let legacyIDs = Set(legacyByID.keys)
        let baselineIDs = Set(baselineByID.keys)
        let sharedLegacyIDs = legacyIDs.intersection(baselineIDs)
        let allAuthorityIDs = legacyIDs.union(canonicalByID.keys)

        return SeriesStandingsMigrationComparison(
            missingLegacyStandingIDs: baselineIDs.subtracting(legacyIDs).sorted(),
            unexpectedLegacyStandingIDs: legacyIDs.subtracting(baselineIDs).sorted(),
            mismatchedLegacyStandingIDs: sharedLegacyIDs.filter {
                guard let legacy = legacyByID[$0], let baseline = baselineByID[$0] else { return true }
                return !sameAwardAggregate(legacy, baseline)
            }.sorted(),
            authorityChangedStandingIDs: allAuthorityIDs.filter {
                guard let legacy = legacyByID[$0], let canonical = canonicalByID[$0] else { return true }
                return !sameAuthorityAggregate(legacy, canonical)
            }.sorted(),
            tracksWithOrderingChanges: SeriesAwardTrack.allCases.filter { track in
                orderedCompetitorIDs(legacyStandings, track: track)
                    != orderedCompetitorIDs(canonicalStandings, track: track)
            }
        )
    }

    private static func legacyBaseline(
        from results: [SeriesRoundResult],
        seriesID: String
    ) -> [SeriesStanding] {
        var standingsByID: [String: SeriesStanding] = [:]
        var roundIDsByStandingID: [String: Set<String>] = [:]
        let timestamp = Time()

        for result in results {
            for award in result.pointAwards {
                let standingID = SeriesStanding.standingID(
                    for: award.awardTrack,
                    competitorID: award.competitorID
                )
                var standing = standingsByID[standingID] ?? SeriesStanding(
                    id: standingID,
                    awardTrack: award.awardTrack,
                    competitorType: award.competitorType,
                    competitorID: award.competitorID,
                    competitorName: award.competitorName,
                    createdAt: timestamp,
                    lastUpdatedAt: timestamp,
                    parentID: seriesID
                )
                standing.totalPoints += award.totalPoints
                standing.wins += award.placement == 1 ? 1 : 0
                standing.topThrees += (award.placement ?? .max) <= 3 ? 1 : 0
                if let placement = award.placement {
                    standing.bestPlacement = min(standing.bestPlacement ?? placement, placement)
                }
                standingsByID[standingID] = standing
                roundIDsByStandingID[standingID, default: []].insert(result.seriesRoundID)
            }
        }
        for id in standingsByID.keys {
            standingsByID[id]?.roundsCounted = roundIDsByStandingID[id]?.count ?? 0
        }
        return Array(standingsByID.values)
    }

    private static func sameAwardAggregate(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        lhs.awardTrack == rhs.awardTrack
            && lhs.competitorType == rhs.competitorType
            && lhs.competitorID == rhs.competitorID
            && abs(lhs.totalPoints - rhs.totalPoints) < 0.000_001
            && lhs.roundsCounted == rhs.roundsCounted
            && lhs.wins == rhs.wins
            && lhs.topThrees == rhs.topThrees
            && lhs.bestPlacement == rhs.bestPlacement
    }

    private static func sameAuthorityAggregate(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        sameAwardAggregate(lhs, rhs) && lhs.rank == rhs.rank
    }

    private static func orderedCompetitorIDs(
        _ standings: [SeriesStanding],
        track: SeriesAwardTrack
    ) -> [String] {
        standings
            .filter { $0.awardTrack == track }
            .sorted {
                if $0.rank != $1.rank { return ($0.rank ?? .max) < ($1.rank ?? .max) }
                return $0.id < $1.id
            }
            .map(\.competitorID)
    }
}
