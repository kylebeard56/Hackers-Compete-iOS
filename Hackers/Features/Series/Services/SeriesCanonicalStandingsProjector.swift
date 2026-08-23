import Foundation

enum SeriesCanonicalStandingsProjectionError: Error, Equatable {
    case authorityDisabled
    case missingProcessingState(seriesRoundID: String)
    case incompleteProcessingState(seriesRoundID: String)
    case staleProcessor(seriesRoundID: String)
    case missingResult(seriesRoundID: String)
    case invalidResultPointer(seriesRoundID: String)
    case policyFingerprintMismatch(seriesRoundID: String)
    case missingRuleCompatibility(seriesRoundID: String, ruleID: String)
    case invalidRuleCompatibility(seriesRoundID: String, ruleID: String)
    case invalidTiebreakPolicy(seriesRoundID: String, ruleID: String)
    case ambiguousTrackPolicy(seriesRoundID: String, track: SeriesAwardTrack)
    case mixedTiebreakPolicy(track: SeriesAwardTrack)
    case incompatibleTiebreakMetrics(track: SeriesAwardTrack, ruleID: String)

    var telemetryValue: String {
        switch self {
        case .authorityDisabled: return "authority_disabled"
        case .missingProcessingState: return "missing_processing_state"
        case .incompleteProcessingState: return "incomplete_processing_state"
        case .staleProcessor: return "stale_processor"
        case .missingResult: return "missing_result"
        case .invalidResultPointer: return "invalid_result_pointer"
        case .policyFingerprintMismatch: return "policy_fingerprint_mismatch"
        case .missingRuleCompatibility: return "missing_rule_compatibility"
        case .invalidRuleCompatibility: return "invalid_rule_compatibility"
        case .invalidTiebreakPolicy: return "invalid_tiebreak_policy"
        case .ambiguousTrackPolicy: return "ambiguous_track_policy"
        case .mixedTiebreakPolicy: return "mixed_tiebreak_policy"
        case .incompatibleTiebreakMetrics: return "incompatible_tiebreak_metrics"
        }
    }
}

struct SeriesCanonicalStandingsProjection {
    let standings: [SeriesStanding]
    let generationIDs: [String]
}

enum SeriesStandingsReadSource: Equatable {
    case legacy
    case canonical
    case legacyFallback(SeriesCanonicalStandingsProjectionError)
}

enum SeriesCanonicalStandingsProjector {
    static func project(
        series: Series,
        completedRounds: [SeriesRound],
        processingStates: [SeriesRoundProcessingState],
        results: [SeriesRoundResult],
        now: Time = .init()
    ) -> Result<SeriesCanonicalStandingsProjection, SeriesCanonicalStandingsProjectionError> {
        guard series.settings.standingsReadAuthority == .canonicalWhenReady else {
            return .failure(.authorityDisabled)
        }

        let stateByRoundID = processingStates.reduce(into: [String: SeriesRoundProcessingState]()) {
            $0[$1.id] = $1
        }
        let resultByID = results.reduce(into: [String: SeriesRoundResult]()) {
            $0[$1.id] = $1
        }
        let orderedRounds = completedRounds.sorted {
            if $0.index != $1.index { return $0.index < $1.index }
            return $0.id < $1.id
        }

        var selectedResults: [SelectedRoundResult] = []
        var tiebreakersByTrack: [SeriesAwardTrack: [SeriesTiebreakRule]] = [:]

        for round in orderedRounds {
            guard let state = stateByRoundID[round.id] else {
                return .failure(.missingProcessingState(seriesRoundID: round.id))
            }
            guard state.status == .completed else {
                return .failure(.incompleteProcessingState(seriesRoundID: round.id))
            }
            guard state.processorVersion == SeriesRoundCanonicalBuilder.processorVersion else {
                return .failure(.staleProcessor(seriesRoundID: round.id))
            }
            guard let result = resultByID[state.latestGenerationID] else {
                return .failure(.missingResult(seriesRoundID: round.id))
            }
            guard result.seriesRoundID == round.id,
                  result.id == state.latestGenerationID,
                  result.sourceRevision == state.sourceRevision,
                  result.sourceUpdatedAt == state.sourceUpdatedAt,
                  result.policyFingerprint == state.policyFingerprint,
                  result.processorVersion == state.processorVersion,
                  result.semanticHash == state.resultSemanticHash else {
                return .failure(.invalidResultPointer(seriesRoundID: round.id))
            }

            let resolvedPolicy = SeriesStandingsPolicyResolver.resolve(
                round: round,
                settings: series.settings
            )
            guard resolvedPolicy.hasValidFingerprint,
                  result.policyFingerprint == resolvedPolicy.fingerprint else {
                return .failure(.policyFingerprintMismatch(seriesRoundID: round.id))
            }

            var eligibleTracks = Set<SeriesAwardTrack>()
            for track in SeriesAwardTrack.allCases {
                let rules = resolvedPolicy.policy.rules.filter { $0.track == track }
                guard rules.count <= 1 else {
                    return .failure(.ambiguousTrackPolicy(seriesRoundID: round.id, track: track))
                }
                guard let rule = rules.first else { continue }
                guard SeriesStandingsPolicyResolver.isValidTiebreakPolicy(rule) else {
                    return .failure(.invalidTiebreakPolicy(seriesRoundID: round.id, ruleID: rule.id))
                }
                guard let compatibility = result.compatibility.first(where: {
                    $0.ruleID == rule.id && $0.awardTrack == track
                }) else {
                    return .failure(.missingRuleCompatibility(seriesRoundID: round.id, ruleID: rule.id))
                }
                switch compatibility.classification {
                case "eligible", "normalized":
                    eligibleTracks.insert(track)
                    if let existing = tiebreakersByTrack[track], existing != rule.resolvedTiebreakers {
                        return .failure(.mixedTiebreakPolicy(track: track))
                    }
                    tiebreakersByTrack[track] = rule.resolvedTiebreakers
                case "excluded":
                    break
                default:
                    return .failure(.invalidRuleCompatibility(seriesRoundID: round.id, ruleID: rule.id))
                }
            }
            selectedResults.append(SelectedRoundResult(
                seriesRound: round,
                result: result,
                eligibleTracks: eligibleTracks
            ))
        }

        if let incompatibility = metricContextIncompatibility(
            selectedResults: selectedResults,
            tiebreakersByTrack: tiebreakersByTrack
        ) {
            return .failure(incompatibility)
        }

        let standings = buildStandings(
            selectedResults: selectedResults,
            tiebreakersByTrack: tiebreakersByTrack,
            seriesID: series.id,
            now: now
        )
        return .success(SeriesCanonicalStandingsProjection(
            standings: standings,
            generationIDs: selectedResults.map(\.result.id)
        ))
    }

    private struct SelectedRoundResult {
        let seriesRound: SeriesRound
        let result: SeriesRoundResult
        let eligibleTracks: Set<SeriesAwardTrack>
    }

    private struct StandingAccumulator {
        var standing: SeriesStanding
        var roundIDs = Set<String>()
        var metricOwnerIDsByRound: [String: Set<String>] = [:]
    }

    private struct CohortKey: Hashable {
        let track: SeriesAwardTrack
        let totalPoints: Double
    }

    private struct MetricSignature: Hashable {
        let scoringFamily: SeriesRoundScoringFamily
        let scoreBasis: ScoreBasis
        let expectedHoleCount: Int
        let aggregatePar: Double?
        let teamScoring: RoundTeamScoringConfiguration?
    }

    private static func metricContextIncompatibility(
        selectedResults: [SelectedRoundResult],
        tiebreakersByTrack: [SeriesAwardTrack: [SeriesTiebreakRule]]
    ) -> SeriesCanonicalStandingsProjectionError? {
        for (track, rules) in tiebreakersByTrack {
            for rule in rules {
                var signatures = Set<MetricSignature>()
                for selected in selectedResults where selected.eligibleTracks.contains(track) {
                    let ownerIDs = Set(selected.result.pointAwards.compactMap { award in
                        award.awardTrack == track ? award.roundOwnerID : nil
                    })
                    for metric in selected.result.performanceMetrics where ownerIDs.contains(metric.scoringUnitID) {
                        guard metric.isComplete == true, let context = metric.context else { continue }
                        let aggregatePar: Double?
                        switch rule.scoreComponent {
                        case .scoreToPar:
                            aggregatePar = nil
                        case .total, .rawStrokes, .netStrokes:
                            guard let value = context.aggregatePar else {
                                return .incompatibleTiebreakMetrics(track: track, ruleID: rule.id)
                            }
                            aggregatePar = value
                        }
                        signatures.insert(MetricSignature(
                            scoringFamily: context.scoringFamily,
                            scoreBasis: context.scoreBasis,
                            expectedHoleCount: context.expectedHoleCount,
                            aggregatePar: aggregatePar,
                            teamScoring: track == .team ? context.teamScoring : nil
                        ))
                    }
                }
                if signatures.count > 1 {
                    return .incompatibleTiebreakMetrics(track: track, ruleID: rule.id)
                }
            }
        }
        return nil
    }

    private static func buildStandings(
        selectedResults: [SelectedRoundResult],
        tiebreakersByTrack: [SeriesAwardTrack: [SeriesTiebreakRule]],
        seriesID: String,
        now: Time
    ) -> [SeriesStanding] {
        var accumulators: [String: StandingAccumulator] = [:]

        for selected in selectedResults {
            for award in selected.result.pointAwards where selected.eligibleTracks.contains(award.awardTrack) {
                let standingID = SeriesStanding.standingID(
                    for: award.awardTrack,
                    competitorID: award.competitorID
                )
                var accumulator = accumulators[standingID] ?? StandingAccumulator(
                    standing: SeriesStanding(
                        id: standingID,
                        awardTrack: award.awardTrack,
                        competitorType: award.competitorType,
                        competitorID: award.competitorID,
                        competitorName: award.competitorName,
                        createdAt: now,
                        lastUpdatedAt: now,
                        parentID: seriesID
                    )
                )
                accumulator.standing.competitorName = award.competitorName
                accumulator.standing.totalPoints += award.totalPoints
                accumulator.standing.wins += award.placement == 1 ? 1 : 0
                accumulator.standing.topThrees += (award.placement ?? .max) <= 3 ? 1 : 0
                accumulator.standing.lastPlacement = award.placement
                if let placement = award.placement {
                    accumulator.standing.bestPlacement = min(
                        accumulator.standing.bestPlacement ?? placement,
                        placement
                    )
                }
                accumulator.roundIDs.insert(selected.seriesRound.id)
                if let ownerID = award.roundOwnerID {
                    accumulator.metricOwnerIDsByRound[selected.seriesRound.id, default: []].insert(ownerID)
                }
                accumulators[standingID] = accumulator
            }
        }

        for key in Array(accumulators.keys) {
            guard var accumulator = accumulators[key] else { continue }
            accumulator.standing.roundsCounted = accumulator.roundIDs.count
            accumulator.standing.tiebreakSummaries = summaries(
                for: accumulator,
                rules: tiebreakersByTrack[accumulator.standing.awardTrack] ?? [],
                selectedResults: selectedResults
            )
            accumulators[key] = accumulator
        }

        let standings = accumulators.values.map(\.standing)
        let activeRules = activeRulesByCohort(
            standings: standings,
            tiebreakersByTrack: tiebreakersByTrack
        )
        var ranked: [SeriesStanding] = []
        for track in SeriesAwardTrack.allCases {
            let sorted = standings.filter { $0.awardTrack == track }.sorted { lhs, rhs in
                canonicalSort(lhs, rhs, activeRules: activeRules)
            }
            for (index, var standing) in sorted.enumerated() {
                standing.rank = index + 1
                ranked.append(standing)
            }
        }
        return ranked
    }

    private static func summaries(
        for accumulator: StandingAccumulator,
        rules: [SeriesTiebreakRule],
        selectedResults: [SelectedRoundResult]
    ) -> [SeriesStandingTiebreakSummary]? {
        guard rules.isPopulated else { return nil }
        return rules.map { rule in
            let roundValues = selectedResults.compactMap { selected -> SeriesStandingRoundTiebreakValue? in
                guard selected.eligibleTracks.contains(accumulator.standing.awardTrack),
                      let ownerIDs = accumulator.metricOwnerIDsByRound[selected.seriesRound.id],
                      let metric = selected.result.performanceMetrics.first(where: {
                          ownerIDs.contains($0.scoringUnitID)
                      }),
                      metric.isComplete == true,
                      let context = metric.context,
                      context.scoringFamily == .strokePlay,
                      let value = metricValue(metric, component: rule.scoreComponent) else {
                    return nil
                }
                return SeriesStandingRoundTiebreakValue(
                    seriesRoundID: selected.seriesRound.id,
                    value: value,
                    aggregatePar: context.aggregatePar,
                    expectedHoleCount: context.expectedHoleCount
                )
            }
            .sorted { lhs, rhs in
                let lhsIndex = selectedResults.first { $0.seriesRound.id == lhs.seriesRoundID }?.seriesRound.index ?? .max
                let rhsIndex = selectedResults.first { $0.seriesRound.id == rhs.seriesRoundID }?.seriesRound.index ?? .max
                return lhsIndex == rhsIndex ? lhs.seriesRoundID < rhs.seriesRoundID : lhsIndex < rhsIndex
            }
            let average = roundValues.isEmpty
                ? nil
                : roundValues.reduce(0) { $0 + $1.value } / Double(roundValues.count)
            return SeriesStandingTiebreakSummary(
                ruleID: rule.id,
                metric: rule.metric,
                direction: rule.direction,
                scoreComponent: rule.scoreComponent,
                average: average,
                roundsCounted: roundValues.count,
                minimumEligibleRounds: rule.minimumEligibleRounds,
                isEligible: roundValues.count >= rule.minimumEligibleRounds,
                roundValues: roundValues
            )
        }
    }

    private static func metricValue(
        _ metric: SeriesRoundPerformanceMetric,
        component: SeriesTiebreakScoreComponent
    ) -> Double? {
        switch component {
        case .total: return metric.total
        case .rawStrokes: return metric.rawStrokes.map(Double.init)
        case .netStrokes: return metric.netStrokes.map(Double.init)
        case .scoreToPar: return metric.scoreToPar
        }
    }

    private static func activeRulesByCohort(
        standings: [SeriesStanding],
        tiebreakersByTrack: [SeriesAwardTrack: [SeriesTiebreakRule]]
    ) -> [CohortKey: [SeriesTiebreakRule]] {
        Dictionary(grouping: standings) { CohortKey(track: $0.awardTrack, totalPoints: $0.totalPoints) }
            .mapValues { cohort in
                (tiebreakersByTrack[cohort.first?.awardTrack ?? .individual] ?? []).filter { rule in
                    cohort.allSatisfy { standing in
                        standing.tiebreakSummaries?.first(where: { $0.ruleID == rule.id })?.isEligible == true
                    }
                }
            }
    }

    private static func canonicalSort(
        _ lhs: SeriesStanding,
        _ rhs: SeriesStanding,
        activeRules: [CohortKey: [SeriesTiebreakRule]]
    ) -> Bool {
        if lhs.totalPoints != rhs.totalPoints { return lhs.totalPoints > rhs.totalPoints }
        let cohort = CohortKey(track: lhs.awardTrack, totalPoints: lhs.totalPoints)
        for rule in activeRules[cohort] ?? [] {
            let lhsValue = lhs.tiebreakSummaries?.first { $0.ruleID == rule.id }?.average
            let rhsValue = rhs.tiebreakSummaries?.first { $0.ruleID == rule.id }?.average
            guard let lhsValue, let rhsValue, lhsValue != rhsValue else { continue }
            switch rule.direction {
            case .lowestFirst: return lhsValue < rhsValue
            case .highestFirst: return lhsValue > rhsValue
            }
        }
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.bestPlacement != rhs.bestPlacement {
            return (lhs.bestPlacement ?? .max) < (rhs.bestPlacement ?? .max)
        }
        if lhs.competitorName != rhs.competitorName { return lhs.competitorName < rhs.competitorName }
        return lhs.id < rhs.id
    }
}
