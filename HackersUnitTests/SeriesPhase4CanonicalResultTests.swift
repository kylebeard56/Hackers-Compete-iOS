@testable import Hackers
import XCTest

@MainActor
final class SeriesPhase4CanonicalResultTests: XCTestCase {
    private final class ResultWriterStub: SeriesRoundResultWriting {
        private(set) var callCount = 0

        func publishIfNeeded(
            _ result: SeriesRoundResult
        ) async -> Result<SeriesRoundResultPublicationDecision, Error> {
            callCount += 1
            return .success(.publish)
        }
    }

    func testV1PublishedAwardsMatchCanonicalProjection() {
        let existing = award(id: "team_red", points: 10)
        var computed = existing
        computed.totalPoints = 12
        computed.basePoints = 12

        let plan = SeriesPointAwardsPublicationPlanner.plan(
            existing: [existing],
            computed: [computed],
            rebuiltTracks: [.team]
        )
        let projections = SeriesRoundCanonicalBuilder.awardProjections(from: plan.published)

        XCTAssertEqual(plan.published.map(\.id), projections.map(\.id))
        XCTAssertEqual(plan.published.map(\.totalPoints), projections.map(\.totalPoints))
        XCTAssertEqual(projections.first?.totalPoints, 12)
    }

    func testAwardProjectionIgnoresPublicationTimestamps() {
        let original = award(id: "team_red", points: 10)
        var retried = original
        retried.awardedAt = .init()
        retried.createdAt = .init()
        retried.lastUpdatedAt = .init()

        let first = SeriesRoundCanonicalBuilder.awardProjections(from: [original])
        let second = SeriesRoundCanonicalBuilder.awardProjections(from: [retried])

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            SeriesRoundCanonicalBuilder.hash(first),
            SeriesRoundCanonicalBuilder.hash(second)
        )
    }

    func testGenerationIDIsDeterministicAndChangesForCorrection() {
        let first = SeriesRoundCanonicalBuilder.generationID(
            sourceRevision: "score_72",
            policyFingerprint: "policy_a"
        )
        let retry = SeriesRoundCanonicalBuilder.generationID(
            sourceRevision: "score_72",
            policyFingerprint: "policy_a"
        )
        let correction = SeriesRoundCanonicalBuilder.generationID(
            sourceRevision: "score_71",
            policyFingerprint: "policy_a"
        )

        XCTAssertEqual(first, retry)
        XCTAssertNotEqual(first, correction)
        XCTAssertEqual(first.count, 64)
    }

    func testRetryDoesNotPublishDuplicateGeneration() {
        let result = canonicalResult(id: "generation_a", sourceUpdatedAt: 10)
        let state = SeriesRoundCanonicalBuilder.processingState(for: result, previous: nil)

        XCTAssertEqual(
            SeriesRoundResultPublicationPlanner.decision(
                for: result,
                currentState: state,
                resultAlreadyExists: true
            ),
            .alreadyPublished
        )
    }

    func testStaleListenerCannotReplaceNewerProcessingState() {
        let stale = canonicalResult(id: "generation_old", sourceUpdatedAt: 10)
        let current = canonicalResult(id: "generation_new", sourceUpdatedAt: 20)
        let state = SeriesRoundCanonicalBuilder.processingState(for: current, previous: nil)

        XCTAssertEqual(
            SeriesRoundResultPublicationPlanner.decision(
                for: stale,
                currentState: state,
                resultAlreadyExists: false
            ),
            .stale
        )
    }

    func testOutOfOrderNewerCompletionCanAdvanceState() {
        let old = canonicalResult(id: "generation_old", sourceUpdatedAt: 10)
        let new = canonicalResult(id: "generation_new", sourceUpdatedAt: 20)
        let oldState = SeriesRoundCanonicalBuilder.processingState(for: old, previous: nil)

        XCTAssertEqual(
            SeriesRoundResultPublicationPlanner.decision(
                for: new,
                currentState: oldState,
                resultAlreadyExists: false
            ),
            .publish
        )
    }

    func testCanceledPublicationSkipsWriter() async {
        let writer = ResultWriterStub()
        let service = SeriesRoundResultPublicationService(writer: writer)
        let result = canonicalResult(id: "generation_a", sourceUpdatedAt: 10)
        let task = Task { @MainActor in
            await Task.yield()
            return await service.publish(result)
        }
        task.cancel()

        guard case .failure(let error) = await task.value else {
            return XCTFail("Expected cancellation")
        }
        XCTAssertTrue(error is CancellationError)
        XCTAssertEqual(writer.callCount, 0)
    }

    func testCanonicalHashingBenchmarkIsBoundedForLeagueRefreshVolume() {
        let payload = (0..<100).map { "round_\($0)_score_\(72 + ($0 % 5))" }

        measure {
            for value in payload {
                _ = SeriesRoundCanonicalBuilder.generationID(
                    sourceRevision: value,
                    policyFingerprint: "policy_a"
                )
            }
        }
    }

    private func award(id: String, points: Double) -> SeriesPointAward {
        SeriesPointAward(
            id: id,
            seriesRoundID: "series_round_1",
            awardTrack: .team,
            competitorType: .team,
            competitorID: id,
            competitorName: "Red",
            profileKind: .placement,
            placement: 1,
            basePoints: points,
            totalPoints: points,
            source: .automatic,
            parentID: "series_1"
        )
    }

    private func canonicalResult(id: String, sourceUpdatedAt: Double) -> SeriesRoundResult {
        SeriesRoundResult(
            id: id,
            seriesRoundID: "series_round_1",
            linkedRoundID: "round_1",
            sourceRevision: "source_\(id)",
            sourceUpdatedAt: sourceUpdatedAt,
            policyRevisionID: "policy_revision_1",
            policyFingerprint: "policy_a",
            processorVersion: 1,
            semanticHash: "semantic_\(id)",
            compatibility: [],
            performanceMetrics: [],
            pointAwards: [],
            handicapSamples: [],
            parentID: "series_1"
        )
    }
}
