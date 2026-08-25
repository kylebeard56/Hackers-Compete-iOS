@testable import Hackers
import XCTest

@MainActor
final class SeriesPhase5CanonicalStandingsTests: XCTestCase {
    func testLegacySettingsDecodeWithoutCanonicalAuthority() throws {
        let encoded = try JSONEncoder().encode(SeriesSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "standings_read_authority")

        let decoded = try JSONDecoder().decode(
            SeriesSettings.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.standingsReadAuthority, .legacy)
    }

    func testCanonicalAuthorityRequiresCompleteLatestGenerationCoverage() {
        let fixture = fixture(roundScores: [
            ["red": 72.8, "blue": 73.4]
        ])

        let result = SeriesCanonicalStandingsProjector.project(
            series: fixture.series,
            completedRounds: fixture.rounds,
            processingStates: [],
            results: fixture.results
        )

        XCTAssertEqual(result.failure, .missingProcessingState(seriesRoundID: "series_round_1"))
    }

    func testLegacyAuthorityNeverConsumesCanonicalResults() {
        var fixture = fixture(roundScores: [["red": 72.8, "blue": 73.4]])
        fixture.series.settings.standingsReadAuthority = .legacy

        XCTAssertEqual(fixture.projection().failure, .authorityDisabled)
    }

    func testUnderspecifiedScoringAveragePolicyIsInvalidAtAuthoringBoundary() {
        let unsafePolicy = SeriesStandingsPolicy(rules: [SeriesStandingsRule(
            id: "team_primary",
            track: .team,
            tiebreakers: [SeriesTiebreakRule(id: "average")]
        )])
        let revision = SeriesStandingsPolicyResolver.makeRevision(
            id: "unsafe",
            sequence: 1,
            policy: unsafePolicy
        )
        var settings = SeriesSettings(
            useTeams: true,
            useIndividualStandings: false,
            useTeamStandings: true,
            standingsPolicyRevision: revision
        )
        settings.defaultRoundConfig.formatTemplateID = FormatTemplateRegistry.bestBall.id
        let round = SeriesRound(
            id: "round",
            roundConfig: settings.defaultRoundConfig,
            policyBinding: SeriesStandingsPolicyResolver.binding(for: revision, substitutesScore: false),
            parentID: "series"
        )

        let compatibility = SeriesStandingsPolicyResolver.compatibility(
            for: round,
            in: Series(id: "series", settings: settings)
        )

        guard case .invalid(let reasons) = compatibility.first?.classification else {
            return XCTFail("Expected invalid tiebreak policy")
        }
        XCTAssertTrue(reasons.contains(.invalidTiebreakRule("team_primary")))
    }

    func testLowerComprehensiveAverageBreaksTiedPoints() throws {
        let fixture = fixture(roundScores: [
            ["red": 72.6, "blue": 73.2],
            ["red": 73.0, "blue": 73.6]
        ])

        let projection = try XCTUnwrap(try fixture.projection().get())
        let red = try XCTUnwrap(projection.standings.first { $0.competitorID == "red" })
        let blue = try XCTUnwrap(projection.standings.first { $0.competitorID == "blue" })
        let redSummary = try XCTUnwrap(red.tiebreakSummaries?.first)

        XCTAssertEqual(red.totalPoints, blue.totalPoints)
        XCTAssertEqual(red.rank, 1)
        XCTAssertEqual(blue.rank, 2)
        XCTAssertEqual(try XCTUnwrap(redSummary.average), 72.8, accuracy: 0.0001)
        XCTAssertEqual(redSummary.roundValues.map(\.seriesRoundID), ["series_round_1", "series_round_2"])
        XCTAssertEqual(redSummary.roundValues.map(\.aggregatePar), [72, 72])
    }

    func testTiebreakIsSkippedForWholeCohortWhenOneCompetitorLacksMinimumRounds() throws {
        var fixture = fixture(roundScores: [
            ["red": 72.0, "blue": 74.0],
            ["red": 72.0, "blue": 74.0]
        ])
        fixture.results[1].pointAwards = fixture.results[1].pointAwards.map { award in
            guard award.competitorID == "blue" else { return award }
            return award.replacingRoundOwnerID(nil)
        }
        fixture.refreshState(at: 1)

        let projection = try fixture.projection().get()
        let blue = try XCTUnwrap(projection.standings.first { $0.competitorID == "blue" })
        let red = try XCTUnwrap(projection.standings.first { $0.competitorID == "red" })

        XCTAssertEqual(blue.rank, 1, "Fallback name ordering should remain authoritative for the incomplete cohort")
        XCTAssertEqual(red.rank, 2)
        XCTAssertEqual(blue.tiebreakSummaries?.first?.isEligible, false)
        XCTAssertEqual(red.tiebreakSummaries?.first?.isEligible, true)
    }

    func testPendingStateFallsBackInsteadOfPublishingPartialCanonicalStandings() {
        var fixture = fixture(roundScores: [
            ["red": 72.8, "blue": 73.4]
        ])
        fixture.states[0].status = .pending

        XCTAssertEqual(
            fixture.projection().failure,
            .incompleteProcessingState(seriesRoundID: "series_round_1")
        )
    }

    func testMixedRoundTiebreakPoliciesAreRejected() {
        var fixture = fixture(roundScores: [
            ["red": 72.8, "blue": 73.4],
            ["red": 72.8, "blue": 73.4]
        ])
        let alternate = Self.policy(direction: .highestFirst)
        let alternateRevision = SeriesStandingsPolicyResolver.makeRevision(
            id: "policy_2",
            sequence: 2,
            policy: alternate,
            createdAt: SeriesBehaviorFixtures.fixedTime
        )
        fixture.rounds[1].policyBinding = SeriesStandingsPolicyResolver.binding(
            for: alternateRevision,
            substitutesScore: false
        )
        fixture.results[1].policyRevisionID = alternateRevision.id
        fixture.results[1].policyFingerprint = alternateRevision.resolvedPolicyFingerprint
        fixture.refreshState(at: 1)

        XCTAssertEqual(fixture.projection().failure, .mixedTiebreakPolicy(track: .team))
    }

    func testRawAverageRejectsMixedAggregatePar() {
        var fixture = fixture(roundScores: [
            ["red": 72.0, "blue": 73.0],
            ["red": 70.0, "blue": 71.0]
        ])
        fixture.results[1].performanceMetrics = fixture.results[1].performanceMetrics.map { metric in
            metric.replacingAggregatePar(70)
        }
        fixture.refreshState(at: 1)

        XCTAssertEqual(
            fixture.projection().failure,
            .incompatibleTiebreakMetrics(track: .team, ruleID: "lowest_average")
        )
    }

    func testAwardCorrectionChangesCanonicalSourceAndGenerationIdentity() {
        let round = SeriesRound(id: "series_round", roundID: "round", parentID: "series")
        let snapshot = RoundSnapshot(round: Round(id: "round"))
        let firstAward = sourceAward(points: 10, updatedAt: 10)
        let correctedAward = sourceAward(points: 12, updatedAt: 20)
        let firstSource = SeriesRoundCanonicalBuilder.sourceRevision(
            seriesRound: round,
            snapshot: snapshot,
            mappings: [],
            awards: [firstAward]
        )
        let correctedSource = SeriesRoundCanonicalBuilder.sourceRevision(
            seriesRound: round,
            snapshot: snapshot,
            mappings: [],
            awards: [correctedAward]
        )

        XCTAssertNotEqual(firstSource, correctedSource)
        XCTAssertNotEqual(
            SeriesRoundCanonicalBuilder.generationID(sourceRevision: firstSource, policyFingerprint: "policy"),
            SeriesRoundCanonicalBuilder.generationID(sourceRevision: correctedSource, policyFingerprint: "policy")
        )
        XCTAssertEqual(SeriesRoundCanonicalBuilder.processorVersion, 3)
    }

    func testCanonicalProjectionBenchmarkIsBoundedForLeagueScale() {
        let scores = (0..<24).map { round in
            Dictionary(uniqueKeysWithValues: (0..<20).map { team in
                ("team_\(team)", 70 + Double((round + team) % 8))
            })
        }
        let fixture = fixture(roundScores: scores)

        measure {
            _ = fixture.projection()
        }
    }

    private func fixture(roundScores: [[String: Double]]) -> Fixture {
        let policy = Self.policy(direction: .lowestFirst)
        let revision = SeriesStandingsPolicyResolver.makeRevision(
            id: "policy_1",
            sequence: 1,
            policy: policy,
            createdAt: SeriesBehaviorFixtures.fixedTime
        )
        let binding = SeriesStandingsPolicyResolver.binding(for: revision, substitutesScore: false)
        var settings = SeriesSettings(
            useTeams: true,
            useIndividualStandings: false,
            useTeamStandings: true,
            standingsPolicyRevision: revision,
            standingsReadAuthority: .canonicalWhenReady
        )
        settings.defaultRoundConfig.formatTemplateID = FormatTemplateRegistry.bestBall.id
        let series = Series(id: "series", settings: settings)
        let context = SeriesRoundPerformanceMetricContext(
            formatTemplateID: FormatTemplateRegistry.bestBall.id,
            scoringFamily: .strokePlay,
            scoreBasis: .gross,
            expectedHoleCount: 9,
            aggregatePar: 72,
            teamScoring: .init(mode: .bestN, count: 2, scope: .perRound)
        )
        var rounds: [SeriesRound] = []
        var results: [SeriesRoundResult] = []
        var states: [SeriesRoundProcessingState] = []

        for (roundIndex, scores) in roundScores.enumerated() {
            let sequence = roundIndex + 1
            let seriesRoundID = "series_round_\(sequence)"
            let round = SeriesRound(
                id: seriesRoundID,
                index: roundIndex,
                status: .complete,
                roundID: "round_\(sequence)",
                completedAt: SeriesBehaviorFixtures.fixedTime,
                policyBinding: binding,
                parentID: series.id
            )
            let awards = scores.keys.sorted().map { teamID in
                SeriesRoundPointAwardProjection(
                    id: "\(seriesRoundID)_\(teamID)",
                    awardTrack: .team,
                    competitorType: .team,
                    competitorID: teamID,
                    competitorName: displayName(teamID),
                    profileKind: .placement,
                    placement: nil,
                    tieGroupSize: nil,
                    basePoints: 10,
                    bonusPoints: 0,
                    totalPoints: 10,
                    source: .automatic,
                    roundOwnerID: "\(seriesRoundID)_owner_\(teamID)",
                    reason: nil
                )
            }
            let metrics = scores.keys.sorted().map { teamID in
                SeriesRoundPerformanceMetric(
                    scoringUnitID: "\(seriesRoundID)_owner_\(teamID)",
                    participantIDs: [],
                    countingParticipantIDs: [],
                    owner: .team,
                    total: scores[teamID] ?? 0,
                    holesPlayed: 9,
                    rawStrokes: Int(scores[teamID] ?? 0),
                    netStrokes: nil,
                    points: 0,
                    context: context,
                    scoreToPar: (scores[teamID] ?? 0) - 72,
                    isComplete: true
                )
            }
            let result = SeriesRoundResult(
                id: "generation_\(sequence)",
                seriesRoundID: seriesRoundID,
                linkedRoundID: "round_\(sequence)",
                sourceRevision: "source_\(sequence)",
                sourceUpdatedAt: Double(sequence),
                policyRevisionID: revision.id,
                policyFingerprint: revision.resolvedPolicyFingerprint,
                processorVersion: SeriesRoundCanonicalBuilder.processorVersion,
                semanticHash: "semantic_\(sequence)",
                compatibility: [SeriesRoundRuleCompatibilityProjection(
                    ruleID: "team_primary",
                    awardTrack: .team,
                    classification: "eligible",
                    details: []
                )],
                performanceMetrics: metrics,
                pointAwards: awards,
                handicapSamples: [],
                parentID: series.id
            )
            rounds.append(round)
            results.append(result)
            states.append(SeriesRoundCanonicalBuilder.processingState(
                for: result,
                previous: nil,
                now: SeriesBehaviorFixtures.fixedTime
            ))
        }
        return Fixture(series: series, rounds: rounds, results: results, states: states)
    }

    private static func policy(direction: SeriesTiebreakDirection) -> SeriesStandingsPolicy {
        SeriesStandingsPolicy(rules: [SeriesStandingsRule(
            id: "team_primary",
            track: .team,
            acceptedScoreBases: [.gross],
            acceptedHoleCounts: [9],
            acceptedScoringFamilies: [.strokePlay],
            requiredTeamScoring: .init(mode: .bestN, count: 2, scope: .perRound),
            tiebreakers: [SeriesTiebreakRule(
                id: "lowest_average",
                metric: .scoringAverage,
                direction: direction,
                scoreComponent: .total,
                minimumEligibleRounds: 2
            )]
        )])
    }

    private func sourceAward(points: Double, updatedAt: Double) -> SeriesPointAward {
        SeriesPointAward(
            id: "award",
            seriesRoundID: "series_round",
            awardTrack: .team,
            competitorType: .team,
            competitorID: "red",
            competitorName: "Red",
            profileKind: .manual,
            basePoints: points,
            totalPoints: points,
            source: .manual,
            createdAt: Time(iso: "2026-01-01T00:00:00Z", unix: 1),
            lastUpdatedAt: Time(iso: "2026-01-01T00:00:00Z", unix: updatedAt),
            parentID: "series"
        )
    }

    private func displayName(_ id: String) -> String {
        id.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    private struct Fixture {
        var series: Series
        var rounds: [SeriesRound]
        var results: [SeriesRoundResult]
        var states: [SeriesRoundProcessingState]

        func projection() -> Result<SeriesCanonicalStandingsProjection, SeriesCanonicalStandingsProjectionError> {
            SeriesCanonicalStandingsProjector.project(
                series: series,
                completedRounds: rounds,
                processingStates: states,
                results: results,
                now: SeriesBehaviorFixtures.fixedTime
            )
        }

        mutating func refreshState(at index: Int) {
            states[index] = SeriesRoundCanonicalBuilder.processingState(
                for: results[index],
                previous: states[index],
                now: SeriesBehaviorFixtures.fixedTime
            )
        }
    }
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

private extension SeriesRoundPointAwardProjection {
    func replacingRoundOwnerID(_ id: String?) -> Self {
        SeriesRoundPointAwardProjection(
            id: self.id,
            awardTrack: awardTrack,
            competitorType: competitorType,
            competitorID: competitorID,
            competitorName: competitorName,
            profileKind: profileKind,
            placement: placement,
            tieGroupSize: tieGroupSize,
            basePoints: basePoints,
            bonusPoints: bonusPoints,
            totalPoints: totalPoints,
            source: source,
            roundOwnerID: id,
            reason: reason
        )
    }
}

private extension SeriesRoundPerformanceMetric {
    func replacingAggregatePar(_ aggregatePar: Double) -> Self {
        let updatedContext = context.map {
            SeriesRoundPerformanceMetricContext(
                formatTemplateID: $0.formatTemplateID,
                scoringFamily: $0.scoringFamily,
                scoreBasis: $0.scoreBasis,
                expectedHoleCount: $0.expectedHoleCount,
                aggregatePar: aggregatePar,
                teamScoring: $0.teamScoring
            )
        }
        return SeriesRoundPerformanceMetric(
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            countingParticipantIDs: countingParticipantIDs,
            owner: owner,
            total: total,
            holesPlayed: holesPlayed,
            rawStrokes: rawStrokes,
            netStrokes: netStrokes,
            points: points,
            context: updatedContext,
            scoreToPar: scoreToPar,
            isComplete: isComplete
        )
    }
}
