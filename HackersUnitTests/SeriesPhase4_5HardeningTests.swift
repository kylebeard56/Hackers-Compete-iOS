@testable import Hackers
import XCTest

@MainActor
final class SeriesPhase4_5HardeningTests: XCTestCase {
    func testTiebreakPolicyRoundTripPreservesOrderedScoringAverageRule() throws {
        let tiebreak = SeriesTiebreakRule(
            id: "lowest_average",
            metric: .scoringAverage,
            direction: .lowestFirst,
            scoreComponent: .total,
            minimumEligibleRounds: 2
        )
        let policy = SeriesStandingsPolicy(rules: [
            SeriesStandingsRule(id: "team", track: .team, tiebreakers: [tiebreak])
        ])

        let decoded = try JSONDecoder().decode(
            SeriesStandingsPolicy.self,
            from: JSONEncoder().encode(policy)
        )

        XCTAssertEqual(decoded.rules.first?.resolvedTiebreakers, [tiebreak])
        XCTAssertEqual(decoded.rules.first?.resolvedTiebreakers.first?.minimumEligibleRounds, 2)
    }

    func testProcessingInputChangeCreatesNewSourceRevisionWithoutChangingProfileID() {
        let seriesRound = canonicalSeriesRound()
        let snapshot = RoundSnapshot(round: Round(id: "round", configuration: .init()))
        let firstProfile = placementProfile(points: 10)
        let correctedProfile = placementProfile(points: 12)
        let firstInputs = SeriesRoundCanonicalBuilder.processingInputs(
            teamProfile: firstProfile,
            individualProfile: nil,
            handicapConfig: .init(),
            members: [],
            teams: []
        )
        let correctedInputs = SeriesRoundCanonicalBuilder.processingInputs(
            teamProfile: correctedProfile,
            individualProfile: nil,
            handicapConfig: .init(),
            members: [],
            teams: []
        )

        let first = SeriesRoundCanonicalBuilder.sourceRevision(
            seriesRound: seriesRound,
            snapshot: snapshot,
            mappings: [],
            processingInputs: firstInputs
        )
        let corrected = SeriesRoundCanonicalBuilder.sourceRevision(
            seriesRound: seriesRound,
            snapshot: snapshot,
            mappings: [],
            processingInputs: correctedInputs
        )

        XCTAssertNotEqual(first, corrected)
    }

    func testScoringGroupChangeCreatesNewSourceRevision() {
        let round = canonicalSeriesRound()
        let firstSnapshot = RoundSnapshot(
            round: Round(id: "round", configuration: .init()),
            scoringGroups: [RoundScoringGroup(id: "pair", memberIDs: ["a", "b"])]
        )
        let correctedSnapshot = RoundSnapshot(
            round: Round(id: "round", configuration: .init()),
            scoringGroups: [RoundScoringGroup(id: "pair", memberIDs: ["a", "c"])]
        )

        XCTAssertNotEqual(
            SeriesRoundCanonicalBuilder.sourceRevision(seriesRound: round, snapshot: firstSnapshot, mappings: []),
            SeriesRoundCanonicalBuilder.sourceRevision(seriesRound: round, snapshot: correctedSnapshot, mappings: [])
        )
    }

    func testSegmentTimestampOnlyChangeDoesNotCreateGeneration() {
        let round = canonicalSeriesRound()
        let firstSegment = RoundSegment(
            id: "segment",
            roundID: "round",
            holeRange: .init(startHole: 1, endHole: 9),
            lastUpdatedAt: Time(iso: "2026-01-01T00:00:00Z", unix: 1)
        )
        var touchedSegment = firstSegment
        touchedSegment.lastUpdatedAt = Time(iso: "2026-01-02T00:00:00Z", unix: 2)

        XCTAssertEqual(
            SeriesRoundCanonicalBuilder.sourceRevision(
                seriesRound: round,
                snapshot: RoundSnapshot(round: Round(id: "round"), segments: [firstSegment]),
                mappings: []
            ),
            SeriesRoundCanonicalBuilder.sourceRevision(
                seriesRound: round,
                snapshot: RoundSnapshot(round: Round(id: "round"), segments: [touchedSegment]),
                mappings: []
            )
        )
    }

    func testBestTwoNineHoleMetricCarriesAggregateParSeventyTwo() throws {
        let seriesRound = canonicalSeriesRound()
        let holeValues = Dictionary(uniqueKeysWithValues: (1...9).map { hole in
            (hole, ScoringRow.HoleValue(rawStrokes: 8, netStrokes: 8, points: 0, pickedUp: false))
        })
        let scoringResult = ScoringResult(
            rows: [ScoringRow(
                scoringUnitID: "red",
                participantIDs: ["a", "b", "c", "d"],
                countingParticipantIDs: ["a", "b"],
                owner: .team,
                holeValues: holeValues,
                total: 72,
                holesPlayed: 9
            )],
            template: FormatTemplateRegistry.bestBall
        )
        let snapshot = metricSnapshot()

        let metric = try XCTUnwrap(
            SeriesRoundCanonicalBuilder.performanceMetrics(
                from: scoringResult,
                seriesRound: seriesRound,
                snapshot: snapshot
            ).first
        )

        XCTAssertEqual(metric.context?.expectedHoleCount, 9)
        XCTAssertEqual(metric.context?.aggregatePar, 72)
        XCTAssertEqual(metric.scoreToPar, 0)
        XCTAssertEqual(metric.isComplete, true)
    }

    func testPendingAndFailedStatesRetryButMissingLegacyStateDoesNotBackfill() {
        XCTAssertFalse(SeriesRoundCanonicalRetryPlanner.needsProcessing(state: nil))
        XCTAssertTrue(SeriesRoundCanonicalRetryPlanner.needsProcessing(state: processingState(status: .pending)))
        XCTAssertTrue(SeriesRoundCanonicalRetryPlanner.needsProcessing(state: processingState(status: .failed)))
        XCTAssertFalse(SeriesRoundCanonicalRetryPlanner.needsProcessing(state: processingState(status: .completed)))
    }

    func testPendingStateDoesNotSuppressPublishingMissingResult() {
        let result = canonicalResult(id: "generation")
        let pending = SeriesRoundCanonicalBuilder.processingState(
            for: result,
            previous: nil,
            status: .pending,
            now: SeriesBehaviorFixtures.fixedTime
        )

        XCTAssertNil(pending.completedAt)
        XCTAssertEqual(
            SeriesRoundResultPublicationPlanner.decision(
                for: result,
                currentState: pending,
                resultAlreadyExists: false
            ),
            .publish
        )
    }

    func testExistingResultWithoutCompletedPointerRepairsState() {
        XCTAssertEqual(
            SeriesRoundResultPublicationPlanner.decision(
                for: canonicalResult(id: "generation"),
                currentState: nil,
                resultAlreadyExists: true
            ),
            .repairState
        )
    }

    func testScoringProfileRevisionPreservesRootAndAdvancesSequence() {
        var existing = placementProfile(points: 10)
        existing.revisionRootID = "profile_root"
        existing.revisionSequence = 3
        let proposed = placementProfile(points: 12)

        let revision = SeriesViewModel.revisedScoringProfile(
            proposed,
            existing: existing,
            allProfiles: [existing],
            id: "profile_revision_4",
            createdAt: SeriesBehaviorFixtures.fixedTime
        )

        XCTAssertEqual(revision.id, "profile_revision_4")
        XCTAssertEqual(revision.revisionRootID, "profile_root")
        XCTAssertEqual(revision.revisionSequence, 4)
        XCTAssertEqual(revision.placementRules.first?.points, 12)
    }

    func testSequentialTeeStartMismatchProducesDivergence() {
        var desired = SeriesRoundConfiguration()
        desired.sequentialTeeStartsEnabled = true
        let series = Series(id: "series", settings: .init())
        let seriesRound = SeriesRound(id: "series_round", roundConfig: desired, parentID: "series")
        var linkedConfig = RoundConfiguration()
        linkedConfig.sequentialTeeStartsEnabled = false
        let linked = Round(id: "round", status: .lobby, configuration: linkedConfig)

        let divergence = SeriesRoundConfigurationReconciler.divergence(
            series: series,
            seriesRound: seriesRound,
            linkedRound: linked
        )

        XCTAssertTrue(divergence?.fields.contains(.teeStarts) == true)
    }

    func testShadowValidatorDetectsPersistedAwardDrift() {
        let award = SeriesPointAward(
            id: "red",
            seriesRoundID: "series_round",
            awardTrack: .team,
            competitorType: .team,
            competitorID: "red",
            competitorName: "Red",
            profileKind: .placement,
            basePoints: 10,
            totalPoints: 10,
            parentID: "series"
        )
        var result = canonicalResult(id: "generation")
        result.pointAwards = SeriesRoundCanonicalBuilder.awardProjections(from: [award])
        XCTAssertTrue(
            SeriesRoundShadowValidator.validate(authoritativeAwards: [award], canonicalResult: result).isEquivalent
        )

        result.pointAwards = []
        let drift = SeriesRoundShadowValidator.validate(authoritativeAwards: [award], canonicalResult: result)
        XCTAssertEqual(drift.missingAwardIDs, ["red"])
        XCTAssertFalse(drift.isEquivalent)
    }

    func testLegacyCanonicalResultDecodesWithoutPhaseFourPointFiveFields() throws {
        let encoded = try JSONEncoder().encode(canonicalResult(id: "legacy"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "processing_inputs")
        let metrics = try XCTUnwrap(object["performance_metrics"] as? [[String: Any]])
        object["performance_metrics"] = metrics.map { metric in
            var legacy = metric
            legacy.removeValue(forKey: "context")
            legacy.removeValue(forKey: "score_to_par")
            legacy.removeValue(forKey: "is_complete")
            return legacy
        }

        let decoded = try JSONDecoder().decode(
            SeriesRoundResult.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.processingInputs)
        XCTAssertNil(decoded.performanceMetrics.first?.context)
    }

    private func placementProfile(points: Double) -> SeriesScoringProfile {
        SeriesScoringProfile(
            id: "team_profile",
            name: "Team placement",
            competitorType: .team,
            kind: .placement,
            placementRules: [SeriesPlacementRule(id: "first", rankStart: 1, rankEnd: 1, points: points)],
            parentID: "series"
        )
    }

    private func canonicalSeriesRound() -> SeriesRound {
        var round = SeriesBehaviorFixtures.configuredRound
        round.roundID = "round"
        round.roundConfig.formatTemplateID = FormatTemplateRegistry.bestBall.id
        round.roundConfig.teamScoring = .init(mode: .bestN, count: 2, scope: .perRound)
        return round
    }

    private func metricSnapshot() -> RoundSnapshot {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) }
        let tee = Tee(
            id: "white",
            name: "White",
            gender: "male",
            totalHoles: 18,
            holes: holes,
            ratingFull: 72,
            slopeFull: 113,
            ratingFront: 36,
            slopeFront: 113,
            ratingBack: 36,
            slopeBack: 113
        )
        let course = CourseSegment(
            courseInfo: CourseInfo(
                id: "course",
                golfCourseApiID: nil,
                name: "Course",
                totalHoles: 18,
                tees: [tee]
            ),
            holeRange: .init(startHole: 1, endHole: 9),
            defaultTee: "white"
        )
        var configuration = RoundConfiguration(
            courses: [course],
            teamScoring: .init(mode: .bestN, count: 2, scope: .perRound)
        )
        configuration.formatSummary = RoundFormatSummary(from: FormatTemplateRegistry.bestBall)
        return RoundSnapshot(
            round: Round(id: "round", configuration: configuration),
            teams: [RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init())],
            segments: [RoundSegment(id: "segment", holeRange: .init(startHole: 1, endHole: 9))]
        )
    }

    private func canonicalResult(id: String) -> SeriesRoundResult {
        SeriesRoundResult(
            id: id,
            seriesRoundID: "series_round",
            linkedRoundID: "round",
            sourceRevision: "source_\(id)",
            sourceUpdatedAt: 10,
            policyRevisionID: nil,
            policyFingerprint: "policy",
            processorVersion: SeriesRoundCanonicalBuilder.processorVersion,
            semanticHash: "semantic",
            compatibility: [],
            performanceMetrics: [SeriesRoundPerformanceMetric(
                scoringUnitID: "red",
                participantIDs: [],
                countingParticipantIDs: [],
                owner: .team,
                total: 72,
                holesPlayed: 9,
                rawStrokes: 72,
                netStrokes: 72,
                points: 0
            )],
            pointAwards: [],
            handicapSamples: [],
            parentID: "series"
        )
    }

    private func processingState(status: SeriesRoundProcessingStatus) -> SeriesRoundProcessingState {
        SeriesRoundProcessingState(
            id: "series_round",
            latestGenerationID: "generation",
            sourceRevision: "source",
            sourceUpdatedAt: 10,
            policyFingerprint: "policy",
            processorVersion: SeriesRoundCanonicalBuilder.processorVersion,
            resultSemanticHash: "semantic",
            status: status,
            parentID: "series"
        )
    }
}
