//
//  SeriesPhase8RuntimeArchitectureTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

@MainActor
final class SeriesPhase8RuntimeArchitectureTests: XCTestCase {
    func testCompletedHistoryDoesNotIncreaseRealtimeListenerBudget() {
        let completed = (0..<500).map {
            makeRound(id: "completed_\($0)", status: .complete, linkedRoundID: "root_\($0)")
        }
        let active = [
            makeRound(id: "planned", status: .planned, linkedRoundID: "root_planned"),
            makeRound(id: "lobby", status: .lobby, linkedRoundID: "root_lobby"),
            makeRound(id: "live", status: .live, linkedRoundID: "root_live"),
            makeRound(id: "canceled", status: .canceled, linkedRoundID: "root_canceled")
        ]

        let activeIDs = SeriesRuntimeSubscriptionPolicy.activeLinkedRoundIDs(in: completed + active)

        XCTAssertEqual(activeIDs, ["root_planned", "root_lobby", "root_live"])
        XCTAssertEqual(
            SeriesRuntimeSubscriptionPolicy.listenerBudget(
                activeLinkedRoundCount: activeIDs.count,
                canonicalStandingsEnabled: false
            ),
            5
        )
        XCTAssertEqual(
            SeriesRuntimeSubscriptionPolicy.listenerBudget(
                activeLinkedRoundCount: activeIDs.count,
                canonicalStandingsEnabled: true
            ),
            7
        )
    }

    func testTimestampOnlyRoundSnapshotIsANoOp() {
        let original = makeRound(id: "round", status: .planned)
        var timestampOnlyUpdate = original
        timestampOnlyUpdate.lastUpdatedAt = Time(iso: "2030-01-01T00:00:00Z", unix: 1_893_456_000)

        let plan = SeriesRuntimeSubscriptionPolicy.invalidationPlan(
            previous: [original],
            updated: [timestampOnlyUpdate],
            attendanceEnabled: true
        )

        XCTAssertFalse(plan.hasSemanticChanges)
        XCTAssertFalse(plan.shouldResolveStandings)
        XCTAssertFalse(plan.shouldRefreshConfigurationDivergences)
        XCTAssertTrue(plan.addedActiveLinkedRoundIDs.isEmpty)
        XCTAssertTrue(plan.addedAttendanceRoundIDs.isEmpty)
    }

    func testCompletingRoundDropsRealtimeRootAndInvalidatesStandingsOnly() {
        let live = makeRound(id: "round", status: .live, linkedRoundID: "root")
        var completed = live
        completed.status = .complete
        completed.completedAt = Time(iso: "2026-07-10T12:00:00Z", unix: 1_783_685_600)

        let plan = SeriesRuntimeSubscriptionPolicy.invalidationPlan(
            previous: [live],
            updated: [completed],
            attendanceEnabled: true
        )

        XCTAssertTrue(plan.hasSemanticChanges)
        XCTAssertEqual(plan.removedActiveLinkedRoundIDs, ["root"])
        XCTAssertTrue(plan.activeLinkedRoundIDs.isEmpty)
        XCTAssertTrue(plan.shouldResolveStandings)
        XCTAssertFalse(plan.shouldRefreshConfigurationDivergences)
    }

    func testRoundConfigurationEditDoesNotReloadUnchangedRootOrStandings() {
        let original = makeRound(id: "round", status: .lobby, linkedRoundID: "root")
        var updated = original
        updated.title = "Championship Nine"

        let plan = SeriesRuntimeSubscriptionPolicy.invalidationPlan(
            previous: [original],
            updated: [updated],
            attendanceEnabled: true
        )

        XCTAssertTrue(plan.hasSemanticChanges)
        XCTAssertTrue(plan.addedActiveLinkedRoundIDs.isEmpty)
        XCTAssertTrue(plan.removedActiveLinkedRoundIDs.isEmpty)
        XCTAssertFalse(plan.shouldResolveStandings)
        XCTAssertTrue(plan.shouldRefreshConfigurationDivergences)
    }

    func testLinkingPlannedRoundMovesItFromAttendanceToRealtimeRoot() {
        let planned = makeRound(id: "round", status: .planned)
        var linked = planned
        linked.status = .lobby
        linked.roundID = "root"

        let plan = SeriesRuntimeSubscriptionPolicy.invalidationPlan(
            previous: [planned],
            updated: [linked],
            attendanceEnabled: true
        )

        XCTAssertEqual(plan.addedActiveLinkedRoundIDs, ["root"])
        XCTAssertEqual(plan.removedAttendanceRoundIDs, ["round"])
        XCTAssertTrue(plan.addedAttendanceRoundIDs.isEmpty)
    }

    func testCompletedRoundNavigationUsesPersistedSeriesStatusWithoutLoadedRoot() {
        let viewModel = SeriesViewModel()
        let completed = makeRound(id: "round", status: .complete, linkedRoundID: "root")

        XCTAssertEqual(viewModel.linkedRoundNavigationTarget(for: completed), .roundOutcome)
    }

    func testCompletedRoundScoreBadgeUsesPersistedHandicapScoreWithoutLoadedRoot() throws {
        let viewModel = SeriesViewModel()
        viewModel.currentPlayerID = "player"
        viewModel.members = [
            SeriesMember(
                id: "member",
                playerID: "player",
                name: Name("Phase", "Eight"),
                isActive: true,
                parentID: "series"
            )
        ]
        viewModel.handicapScores = [
            SeriesHandicapScore(
                id: "score",
                memberID: "member",
                score: 38,
                par: 36,
                source: .round,
                sourceRoundID: "root",
                parentID: "series"
            )
        ]

        let context = try XCTUnwrap(
            viewModel.currentUserScoreContext(
                for: makeRound(id: "round", status: .complete, linkedRoundID: "root")
            )
        )

        XCTAssertTrue(context.played)
        XCTAssertEqual(context.scoreLabel, "+2")
    }

    func testHandicapProjectionPreservesGoldenSelectionAndExclusions() throws {
        let member = SeriesMember(
            id: "member",
            playerID: "player",
            name: Name("Phase", "Eight"),
            isActive: true,
            parentID: "series"
        )
        let scores = (0..<6).map { index in
            SeriesHandicapScore(
                id: "score_\(index)",
                memberID: member.id,
                score: Double(38 + index),
                par: 36,
                source: .baseline,
                recordedAt: Time(iso: "2026-07-0\(index + 1)T00:00:00Z", unix: Double(index)),
                sortOrder: index,
                parentID: "series",
                countsTowardHandicapIndex: index != 5
            )
        }
        let handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025)
        let projection = SeriesHandicapProjectionService.project(
            members: [member],
            scores: scores,
            overrides: [],
            handicapConfig: handicapConfig
        )
        let expected = computeHandicapIndex(
            samples: scores.dropLast().map {
                HandicapScoreSample(
                    id: $0.id,
                    gross: $0.score,
                    recordedAt: $0.recordedAt,
                    sortOrder: $0.sortOrder
                )
            },
            config: handicapConfig.config.toConfig()
        )

        XCTAssertEqual(projection.handicapsByMemberID[member.id]?.computedIndex, expected?.handicapIndex)
        XCTAssertEqual(projection.scoreSelectionsByMemberID[member.id]?.poolIDs, expected?.poolSampleIDs)
        XCTAssertEqual(projection.scoreSelectionsByMemberID[member.id]?.countingIDs, expected?.selectedSampleIDs)
        XCTAssertFalse(projection.scoreSelectionsByMemberID[member.id]?.poolIDs.contains("score_5") == true)
    }

    private func makeRound(
        id: String,
        status: SeriesRoundStatus,
        linkedRoundID: String? = nil
    ) -> SeriesRound {
        SeriesRound(
            id: id,
            title: id,
            index: 0,
            status: status,
            roundID: linkedRoundID,
            createdAt: Time(iso: "2026-01-01T00:00:00Z", unix: 1_767_225_600),
            lastUpdatedAt: Time(iso: "2026-01-01T00:00:00Z", unix: 1_767_225_600),
            parentID: "series"
        )
    }
}
