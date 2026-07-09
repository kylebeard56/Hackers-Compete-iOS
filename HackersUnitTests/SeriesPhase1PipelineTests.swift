@testable import Hackers
import XCTest

@MainActor
final class SeriesPhase1PipelineTests: XCTestCase {
    private enum StubError: Error {
        case failed
    }

    private final class SnapshotSourceStub: SeriesRoundSnapshotSource {
        var failingComponent: SeriesRoundSnapshotComponent?
        var delay: Duration = .zero
        private(set) var calls: [SeriesRoundSnapshotComponent: Int] = [:]
        private var activeComponentCountByRoundID: [String: Int] = [:]
        private(set) var maximumActiveRoundCount = 0
        private(set) var maximumActiveComponentCount = 0

        init(failingComponent: SeriesRoundSnapshotComponent? = nil, delay: Duration = .zero) {
            self.failingComponent = failingComponent
            self.delay = delay
        }

        func round(id: String) async -> Result<Round, Error> {
            await begin(.round, roundID: id)
            defer { end(roundID: id) }
            return failingComponent == .round ? .failure(StubError.failed) : .success(Round(id: id))
        }

        func participants(roundID: String) async -> Result<[RoundParticipant], Error> {
            await begin(.participants, roundID: roundID)
            defer { end(roundID: roundID) }
            return failingComponent == .participants ? .failure(StubError.failed) : .success([])
        }

        func teams(roundID: String) async -> Result<[RoundTeam], Error> {
            await begin(.teams, roundID: roundID)
            defer { end(roundID: roundID) }
            return failingComponent == .teams ? .failure(StubError.failed) : .success([])
        }

        func teeGroups(roundID: String) async -> Result<[TeeTimeGroup], Error> {
            await begin(.teeGroups, roundID: roundID)
            defer { end(roundID: roundID) }
            return failingComponent == .teeGroups ? .failure(StubError.failed) : .success([])
        }

        func segments(roundID: String) async -> Result<[RoundSegment], Error> {
            await begin(.segments, roundID: roundID)
            defer { end(roundID: roundID) }
            return failingComponent == .segments ? .failure(StubError.failed) : .success([])
        }

        func scores(roundID: String) async -> Result<[ScoreEntry], Error> {
            await begin(.scores, roundID: roundID)
            defer { end(roundID: roundID) }
            return failingComponent == .scores ? .failure(StubError.failed) : .success([])
        }

        func scoringGroups(roundID: String) async -> Result<[RoundScoringGroup], Error> {
            await begin(.scoringGroups, roundID: roundID)
            defer { end(roundID: roundID) }
            return failingComponent == .scoringGroups ? .failure(StubError.failed) : .success([])
        }

        private func begin(_ component: SeriesRoundSnapshotComponent, roundID: String) async {
            calls[component, default: 0] += 1
            activeComponentCountByRoundID[roundID, default: 0] += 1
            maximumActiveRoundCount = max(maximumActiveRoundCount, activeComponentCountByRoundID.count)
            maximumActiveComponentCount = max(
                maximumActiveComponentCount,
                activeComponentCountByRoundID.values.reduce(0, +)
            )
            if delay > .zero {
                try? await Task.sleep(for: delay)
            } else {
                await Task.yield()
            }
        }

        private func end(roundID: String) {
            let nextCount = (activeComponentCountByRoundID[roundID] ?? 1) - 1
            if nextCount == 0 {
                activeComponentCountByRoundID[roundID] = nil
            } else {
                activeComponentCountByRoundID[roundID] = nextCount
            }
        }
    }

    private final class StandingsWriterStub: SeriesStandingsWriting {
        var result: Result<Void, Error>
        private(set) var callCount = 0

        init(result: Result<Void, Error>) {
            self.result = result
        }

        func replace(
            deleting: [SeriesStanding],
            upserting: [SeriesStanding]
        ) async -> Result<Void, Error> {
            callCount += 1
            return result
        }
    }

    func testSnapshotLoaderReportsEveryFailedComponent() async {
        for component in SeriesRoundSnapshotComponent.allCases {
            let source = SnapshotSourceStub(failingComponent: component)
            let loader = SeriesRoundSnapshotLoader(source: source)

            let result = await loader.load(roundID: "round_1")

            guard case .failure(let failure) = result else {
                return XCTFail("Expected \(component.rawValue) failure")
            }
            XCTAssertEqual(failure.component, component)
            XCTAssertEqual(failure.roundID, "round_1")
        }
    }

    func testSnapshotLoaderFetchesIndependentComponentsConcurrently() async {
        let source = SnapshotSourceStub(delay: .milliseconds(20))
        let loader = SeriesRoundSnapshotLoader(source: source)

        guard case .success = await loader.load(roundID: "round_1") else {
            return XCTFail("Expected snapshot")
        }

        XCTAssertEqual(source.maximumActiveComponentCount, SeriesRoundSnapshotComponent.allCases.count)
        XCTAssertEqual(source.calls.values.reduce(0, +), SeriesRoundSnapshotComponent.allCases.count)
    }

    func testSnapshotRepositoryCoalescesInFlightRequestsAndCachesResult() async {
        let source = SnapshotSourceStub(delay: .milliseconds(20))
        let repository = SeriesRoundSnapshotRepository(
            loader: SeriesRoundSnapshotLoader(source: source)
        )

        let first = Task { @MainActor in
            await repository.snapshot(roundID: "round_1", policy: .reload)
        }
        await Task.yield()
        let second = Task { @MainActor in
            await repository.snapshot(roundID: "round_1", policy: .reload)
        }
        guard case .success = await first.value,
              case .success = await second.value,
              case .success = await repository.snapshot(roundID: "round_1", policy: .useCache) else {
            return XCTFail("Expected snapshots")
        }

        XCTAssertEqual(source.calls[.round], 1)
        XCTAssertEqual(source.calls.values.reduce(0, +), SeriesRoundSnapshotComponent.allCases.count)
    }

    func testInvalidationPreventsCanceledLoadFromRepopulatingCache() async {
        let source = SnapshotSourceStub(delay: .milliseconds(20))
        let repository = SeriesRoundSnapshotRepository(
            loader: SeriesRoundSnapshotLoader(source: source)
        )

        let canceledLoad = Task { @MainActor in
            await repository.snapshot(roundID: "round_1", policy: .reload)
        }
        await Task.yield()
        repository.invalidate(roundID: "round_1")
        _ = await canceledLoad.value

        source.failingComponent = .round
        let nextLoad = await repository.snapshot(roundID: "round_1", policy: .useCache)

        guard case .failure(let failure) = nextLoad else {
            return XCTFail("Expected a fresh load after invalidation")
        }
        XCTAssertEqual(failure.component, .round)
        XCTAssertEqual(source.calls[.round], 2)
    }

    func testBulkSnapshotPrefetchHonorsRoundConcurrencyLimit() async {
        let source = SnapshotSourceStub(delay: .milliseconds(15))
        let repository = SeriesRoundSnapshotRepository(
            loader: SeriesRoundSnapshotLoader(source: source)
        )

        let results = await repository.snapshots(
            roundIDs: ["round_1", "round_2", "round_3", "round_4"],
            policy: .reload,
            maxConcurrent: 2
        )

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(source.maximumActiveRoundCount, 2)
        XCTAssertEqual(source.calls[.round], 4)
    }

    func testPointAwardDiffIsIdempotent() {
        let existing = award(id: "award_1", points: 10)
        var equivalent = existing
        equivalent.awardedAt = .init()
        equivalent.lastUpdatedAt = .init()

        let unchanged = SeriesPointAwardsPublicationPlanner.plan(
            existing: [existing],
            computed: [equivalent],
            rebuiltTracks: [.team]
        )
        XCTAssertEqual(unchanged.writeCount, 0)

        equivalent.totalPoints = 11
        let changed = SeriesPointAwardsPublicationPlanner.plan(
            existing: [existing],
            computed: [equivalent],
            rebuiltTracks: [.team]
        )
        XCTAssertEqual(changed.deleting.count, 0)
        XCTAssertEqual(changed.upserting.map(\.totalPoints), [11])
    }

    func testStandingsPublicationIsIdempotentAndPreservesCreatedAt() {
        let existing = standing(id: "team_red", points: 10, rank: 1)
        var equivalent = existing
        equivalent.createdAt = .init()
        equivalent.lastUpdatedAt = .init()

        let unchanged = SeriesStandingsPublicationPlanner.plan(
            existing: [existing],
            computed: [equivalent],
            track: nil
        )
        XCTAssertEqual(unchanged.writeCount, 0)
        XCTAssertEqual(unchanged.published.first?.createdAt, existing.createdAt)

        equivalent.totalPoints = 12
        let changed = SeriesStandingsPublicationPlanner.plan(
            existing: [existing],
            computed: [equivalent],
            track: nil
        )
        XCTAssertEqual(changed.upserting.count, 1)
        XCTAssertEqual(changed.upserting.first?.createdAt, existing.createdAt)

        let secondRun = SeriesStandingsPublicationPlanner.plan(
            existing: changed.published,
            computed: [equivalent],
            track: nil
        )
        XCTAssertEqual(secondRun.writeCount, 0)
    }

    func testFailedStandingsWriterDoesNotReturnPublishedReplacement() async {
        let writer = StandingsWriterStub(result: .failure(StubError.failed))
        let service = SeriesStandingsPublicationService(writer: writer)
        let existing = standing(id: "team_red", points: 10, rank: 1)
        let computed = standing(id: "team_red", points: 12, rank: 1)

        let result = await service.publish(existing: [existing], computed: [computed], track: nil)

        guard case .failure = result else { return XCTFail("Expected publication failure") }
        XCTAssertEqual(writer.callCount, 1)
        XCTAssertEqual(existing.totalPoints, 10)
    }

    func testIdempotentStandingsPublicationSkipsWriter() async {
        let writer = StandingsWriterStub(result: .success(()))
        let service = SeriesStandingsPublicationService(writer: writer)
        let existing = standing(id: "team_red", points: 10, rank: 1)
        var computed = existing
        computed.createdAt = .init()
        computed.lastUpdatedAt = .init()

        let result = await service.publish(existing: [existing], computed: [computed], track: nil)

        guard case .success(let plan) = result else { return XCTFail("Expected no-op publication") }
        XCTAssertEqual(plan.writeCount, 0)
        XCTAssertEqual(writer.callCount, 0)
        XCTAssertEqual(plan.published, [existing])
    }

    func testAwardWriteFailureCannotFinalizeRound() {
        XCTAssertNil(
            SeriesViewModel.resolvedAwardsStatus(
                proposedStatus: .finalized,
                writeSucceeded: false
            )
        )
        XCTAssertEqual(
            SeriesViewModel.resolvedAwardsStatus(
                proposedStatus: .needsReview,
                writeSucceeded: true
            ),
            .needsReview
        )
    }

    func testLinkedStateMergeDoesNotOverwriteConcurrentRoundEdit() {
        let original = SeriesRound(id: "series_round", status: .planned, notes: "Original")
        var proposed = original
        proposed.status = .lobby
        proposed.startedAt = .init()
        var current = original
        current.status = .canceled
        current.notes = "Commissioner edit"

        let merged = SeriesViewModel.mergingLinkedStateChanges(
            original: original,
            proposed: proposed,
            current: current
        )

        XCTAssertEqual(merged?.status, .canceled)
        XCTAssertEqual(merged?.startedAt, proposed.startedAt)
        XCTAssertEqual(merged?.notes, "Commissioner edit")
    }

    private func award(id: String, points: Double) -> SeriesPointAward {
        SeriesPointAward(
            id: id,
            seriesRoundID: "round_1",
            awardTrack: .team,
            competitorType: .team,
            competitorID: "red",
            competitorName: "Red",
            placement: 1,
            basePoints: points,
            totalPoints: points,
            source: .automatic,
            parentID: "series_1"
        )
    }

    private func standing(id: String, points: Double, rank: Int) -> SeriesStanding {
        SeriesStanding(
            id: id,
            awardTrack: .team,
            competitorType: .team,
            competitorID: "red",
            competitorName: "Red",
            totalPoints: points,
            roundsCounted: 1,
            wins: 1,
            topThrees: 1,
            lastPlacement: 1,
            bestPlacement: 1,
            rank: rank,
            parentID: "series_1"
        )
    }
}
