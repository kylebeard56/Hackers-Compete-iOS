@testable import Hackers
import XCTest

final class SeriesPhase7MigrationTests: XCTestCase {
    func testAuthorityTransitionPreservesFreshSettingsAndRejectsStalePolicy() throws {
        var fixture = try makeFixture(roundCount: 1)
        fixture.settings.defaultRoundConfig.notes = "Edited on another device"
        let current = Series(id: "series", settings: fixture.settings)

        let activated = try SeriesStandingsAuthorityTransition.applying(
            .canonicalWhenReady,
            to: current,
            expectedPolicyRevisionID: fixture.revision.id,
            now: SeriesBehaviorFixtures.fixedTime
        ).get()
        XCTAssertEqual(activated.settings.defaultRoundConfig.notes, "Edited on another device")
        XCTAssertEqual(activated.settings.standingsReadAuthority, .canonicalWhenReady)
        XCTAssertEqual(activated.lastUpdatedAt, SeriesBehaviorFixtures.fixedTime)

        XCTAssertThrowsError(try SeriesStandingsAuthorityTransition.applying(
            .canonicalWhenReady,
            to: current,
            expectedPolicyRevisionID: "replaced_policy"
        ).get()) { error in
            XCTAssertEqual(error as? SeriesStandingsAuthorityTransitionError, .policyRevisionChanged)
        }
    }

    func testPlannerRecognizesCurrentGenerationAndRejectsStaleSource() throws {
        let fixture = try makeFixture(roundCount: 1)

        let ready = SeriesStandingsMigrationPlanner.plan(
            revision: fixture.revision,
            substitutesScore: fixture.settings.substitutesScore,
            completedRounds: fixture.rounds,
            expectedSourceRevisions: ["series_round_1": "source_1"],
            unavailableRoundIDs: [],
            processingStates: fixture.states,
            results: fixture.results
        )
        XCTAssertTrue(ready.isReadyForActivation)
        XCTAssertEqual(ready.readyGenerationIDs, ["generation_1"])

        let stale = SeriesStandingsMigrationPlanner.plan(
            revision: fixture.revision,
            substitutesScore: fixture.settings.substitutesScore,
            completedRounds: fixture.rounds,
            expectedSourceRevisions: ["series_round_1": "corrected_source"],
            unavailableRoundIDs: [],
            processingStates: fixture.states,
            results: fixture.results
        )
        XCTAssertEqual(stale.pendingItems.count, 1)
        XCTAssertEqual(stale.pendingItems.first?.disposition, .needsPreparation(.staleSource))
    }

    func testInterruptedBackfillResumesAfterCompletedPointers() throws {
        let fixture = try makeFixture(roundCount: 7)
        let expectedSources = Dictionary(uniqueKeysWithValues: (1...7).map {
            ("series_round_\($0)", "source_\($0)")
        })
        let interrupted = SeriesStandingsMigrationPlanner.plan(
            revision: fixture.revision,
            substitutesScore: fixture.settings.substitutesScore,
            completedRounds: fixture.rounds,
            expectedSourceRevisions: expectedSources,
            unavailableRoundIDs: [],
            processingStates: Array(fixture.states.prefix(5)),
            results: Array(fixture.results.prefix(5))
        )

        XCTAssertEqual(interrupted.readyItems.count, 5)
        XCTAssertEqual(interrupted.pendingItems.map(\.id), ["series_round_6", "series_round_7"])
        XCTAssertEqual(
            interrupted.nextBatch(limit: SeriesViewModel.standingsMigrationBatchSize).map(\.id),
            ["series_round_6", "series_round_7"]
        )

        let resumed = SeriesStandingsMigrationPlanner.plan(
            revision: fixture.revision,
            substitutesScore: fixture.settings.substitutesScore,
            completedRounds: fixture.rounds,
            expectedSourceRevisions: expectedSources,
            unavailableRoundIDs: [],
            processingStates: fixture.states,
            results: fixture.results
        )
        XCTAssertTrue(resumed.isReadyForActivation)
        XCTAssertTrue(resumed.nextBatch(limit: 5).isEmpty)
    }

    func testPlannerBlocksMissingLinkedRoundAndUnavailableSnapshot() throws {
        var fixture = try makeFixture(roundCount: 2)
        fixture.rounds[0].roundID = nil

        let plan = SeriesStandingsMigrationPlanner.plan(
            revision: fixture.revision,
            substitutesScore: fixture.settings.substitutesScore,
            completedRounds: fixture.rounds,
            expectedSourceRevisions: [:],
            unavailableRoundIDs: ["series_round_2"],
            processingStates: [],
            results: []
        )

        XCTAssertEqual(plan.blockedItems.count, 2)
        XCTAssertEqual(plan.blockedItems[0].disposition, .blocked(.missingLinkedRound))
        XCTAssertEqual(plan.blockedItems[1].disposition, .blocked(.snapshotUnavailable))
    }

    func testPlannerBlocksInvalidCompatibilityInsteadOfRetryingForever() throws {
        var fixture = try makeFixture(roundCount: 1)
        fixture.results[0].compatibility = [SeriesRoundRuleCompatibilityProjection(
            ruleID: fixture.revision.policy.rules[0].id,
            awardTrack: .team,
            classification: "invalid",
            details: ["unsupported"]
        )]
        fixture.states[0] = SeriesRoundCanonicalBuilder.processingState(
            for: fixture.results[0],
            previous: nil,
            now: SeriesBehaviorFixtures.fixedTime
        )

        let plan = SeriesStandingsMigrationPlanner.plan(
            revision: fixture.revision,
            substitutesScore: fixture.settings.substitutesScore,
            completedRounds: fixture.rounds,
            expectedSourceRevisions: ["series_round_1": "source_1"],
            unavailableRoundIDs: [],
            processingStates: fixture.states,
            results: fixture.results
        )

        XCTAssertEqual(plan.blockedItems.first?.disposition, .blocked(.invalidCompatibility))
    }

    func testDualReadComparisonAllowsExplainedOrderingChanges() throws {
        let fixture = try makeFixture(roundCount: 1, awards: [
            Self.award(id: "red", competitorID: "red", points: 10),
            Self.award(id: "blue", competitorID: "blue", points: 10)
        ])
        let legacy = [
            standing(id: "team_red", competitorID: "red", points: 10, rank: 1),
            standing(id: "team_blue", competitorID: "blue", points: 10, rank: 2)
        ]
        let canonical = [
            standing(id: "team_blue", competitorID: "blue", points: 10, rank: 1),
            standing(id: "team_red", competitorID: "red", points: 10, rank: 2)
        ]

        let comparison = SeriesStandingsMigrationComparator.compare(
            legacyStandings: legacy,
            canonicalStandings: canonical,
            orderedCanonicalResults: fixture.results,
            seriesID: "series"
        )

        XCTAssertTrue(comparison.isActivationSafe)
        XCTAssertEqual(comparison.unexplainedMismatchCount, 0)
        XCTAssertEqual(comparison.tracksWithOrderingChanges, [.team])
        XCTAssertEqual(comparison.authorityChangedStandingIDs, ["team_blue", "team_red"])
    }

    func testDualReadComparisonBlocksAwardDrift() throws {
        let fixture = try makeFixture(roundCount: 1)
        let legacy = [standing(id: "team_red", competitorID: "red", points: 11, rank: 1)]
        let canonical = [standing(id: "team_red", competitorID: "red", points: 10, rank: 1)]

        let comparison = SeriesStandingsMigrationComparator.compare(
            legacyStandings: legacy,
            canonicalStandings: canonical,
            orderedCanonicalResults: fixture.results,
            seriesID: "series"
        )

        XCTAssertFalse(comparison.isActivationSafe)
        XCTAssertEqual(comparison.mismatchedLegacyStandingIDs, ["team_red"])
        XCTAssertEqual(comparison.unexplainedMismatchCount, 1)
    }

    func testDualReadComparisonReportsMissingAndUnexpectedCompetitors() throws {
        let fixture = try makeFixture(roundCount: 1, awards: [
            Self.award(id: "red", competitorID: "red", points: 10),
            Self.award(id: "blue", competitorID: "blue", points: 8)
        ])
        let legacy = [
            standing(id: "team_red", competitorID: "red", points: 10, rank: 1),
            standing(id: "team_green", competitorID: "green", points: 8, rank: 2)
        ]

        let comparison = SeriesStandingsMigrationComparator.compare(
            legacyStandings: legacy,
            canonicalStandings: legacy,
            orderedCanonicalResults: fixture.results,
            seriesID: "series"
        )

        XCTAssertEqual(comparison.missingLegacyStandingIDs, ["team_blue"])
        XCTAssertEqual(comparison.unexpectedLegacyStandingIDs, ["team_green"])
        XCTAssertEqual(comparison.unexplainedMismatchCount, 2)
        XCTAssertFalse(comparison.isActivationSafe)
    }

    private func makeFixture(
        roundCount: Int,
        awards: [SeriesRoundPointAwardProjection]? = nil
    ) throws -> Fixture {
        var settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        settings.useIndividualStandings = false
        settings.useTeamStandings = true
        let revision = try SeriesStandingsRollout.makeRevision(
            settings: settings,
            draft: .init(team: .init(isEnabled: true)),
            id: "policy",
            createdAt: SeriesBehaviorFixtures.fixedTime
        ).get()
        settings.standingsPolicyRevision = revision
        let binding = SeriesStandingsPolicyResolver.binding(
            for: revision,
            substitutesScore: settings.substitutesScore
        )
        let rule = try XCTUnwrap(revision.policy.rules.first)
        var rounds: [SeriesRound] = []
        var results: [SeriesRoundResult] = []
        var states: [SeriesRoundProcessingState] = []

        for sequence in 1...roundCount {
            let roundID = "series_round_\(sequence)"
            let resultAwards = awards ?? [Self.award(
                id: "red_\(sequence)",
                competitorID: "red",
                points: 10
            )]
            let round = SeriesRound(
                id: roundID,
                index: sequence - 1,
                status: .complete,
                roundID: "round_\(sequence)",
                policyBinding: binding,
                parentID: "series"
            )
            let result = SeriesRoundResult(
                id: "generation_\(sequence)",
                seriesRoundID: roundID,
                linkedRoundID: "round_\(sequence)",
                sourceRevision: "source_\(sequence)",
                sourceUpdatedAt: Double(sequence),
                policyRevisionID: revision.id,
                policyFingerprint: revision.resolvedPolicyFingerprint,
                processorVersion: SeriesRoundCanonicalBuilder.processorVersion,
                semanticHash: "semantic_\(sequence)",
                compatibility: [SeriesRoundRuleCompatibilityProjection(
                    ruleID: rule.id,
                    awardTrack: .team,
                    classification: "eligible",
                    details: []
                )],
                performanceMetrics: [],
                pointAwards: resultAwards,
                handicapSamples: [],
                parentID: "series"
            )
            rounds.append(round)
            results.append(result)
            states.append(SeriesRoundCanonicalBuilder.processingState(
                for: result,
                previous: nil,
                now: SeriesBehaviorFixtures.fixedTime
            ))
        }
        return Fixture(
            settings: settings,
            revision: revision,
            rounds: rounds,
            results: results,
            states: states
        )
    }

    private static func award(
        id: String,
        competitorID: String,
        points: Double
    ) -> SeriesRoundPointAwardProjection {
        SeriesRoundPointAwardProjection(
            id: id,
            awardTrack: .team,
            competitorType: .team,
            competitorID: competitorID,
            competitorName: competitorID.capitalized,
            profileKind: .placement,
            placement: 1,
            tieGroupSize: nil,
            basePoints: points,
            bonusPoints: 0,
            totalPoints: points,
            source: .automatic,
            roundOwnerID: competitorID,
            reason: nil
        )
    }

    private func standing(
        id: String,
        competitorID: String,
        points: Double,
        rank: Int
    ) -> SeriesStanding {
        SeriesStanding(
            id: id,
            awardTrack: .team,
            competitorType: .team,
            competitorID: competitorID,
            competitorName: competitorID.capitalized,
            totalPoints: points,
            roundsCounted: 1,
            wins: 1,
            topThrees: 1,
            bestPlacement: 1,
            rank: rank,
            parentID: "series"
        )
    }
}

private struct Fixture {
    var settings: SeriesSettings
    let revision: SeriesPolicyRevision
    var rounds: [SeriesRound]
    var results: [SeriesRoundResult]
    var states: [SeriesRoundProcessingState]
}
