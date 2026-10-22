@testable import Hackers
import XCTest

@MainActor
final class RoundSessionConcurrencyTests: XCTestCase {
    func testNewestRefreshWinsWhenRequestsCompleteOutOfOrder() async {
        let loader = ControlledSnapshotLoader()
        let session = await makeSession(loader: loader)
        defer { loader.cancelPending(); session.stop() }

        let firstStarted = expectation(description: "First refresh is suspended")
        loader.onRequest = { if $0 == 0 { firstStarted.fulfill() } }
        let first = Task { await session.refreshOneShotSnapshot() }
        await fulfillment(of: [firstStarted], timeout: 2)

        let secondStarted = expectation(description: "Second refresh is suspended")
        loader.onRequest = { if $0 == 1 { secondStarted.fulfill() } }
        let second = Task { await session.refreshOneShotSnapshot() }
        await fulfillment(of: [secondStarted], timeout: 2)
        XCTAssertFalse(session.canPersistScores)

        loader.complete(1, with: .success(snapshot(named: "newer")))
        await second.value
        let acceptedAt = session.lastSnapshotReceivedAt
        XCTAssertEqual(session.snapshot.round.name, "newer")
        XCTAssertEqual(session.initialLoadState, .ready)
        XCTAssertTrue(session.canPersistScores)

        loader.complete(0, with: .success(snapshot(named: "older")))
        await first.value
        XCTAssertEqual(session.snapshot.round.name, "newer")
        XCTAssertEqual(session.lastSnapshotReceivedAt, acceptedAt)
        XCTAssertEqual(session.initialLoadState, .ready)
        XCTAssertTrue(session.canPersistScores)
        XCTAssertEqual(loader.requestedRoundIDs, ["round", "round"])
        XCTAssertEqual(loader.preferServerValues, [true, true])
    }

    func testOlderFailureCannotDemoteANewerSuccessfulRefresh() async {
        let loader = ControlledSnapshotLoader()
        let session = await makeSession(loader: loader)
        defer { loader.cancelPending(); session.stop() }

        let firstStarted = expectation(description: "First refresh is suspended")
        loader.onRequest = { if $0 == 0 { firstStarted.fulfill() } }
        let first = Task { await session.refreshOneShotSnapshot() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectation(description: "Second refresh is suspended")
        loader.onRequest = { if $0 == 1 { secondStarted.fulfill() } }
        let second = Task { await session.refreshOneShotSnapshot() }
        await fulfillment(of: [secondStarted], timeout: 2)

        loader.complete(1, with: .success(snapshot(named: "newer")))
        await second.value
        loader.complete(0, with: .failure(CancellationError()))
        await first.value

        XCTAssertEqual(session.snapshot.round.name, "newer")
        XCTAssertEqual(session.initialLoadState, .ready)
        XCTAssertTrue(session.canPersistScores)
        XCTAssertFalse(session.completeInitialLoadTrackingIfTimedOut(asOf: .distantFuture))
    }

    func testStopDiscardsAnInFlightSnapshotAndLateReadinessCallbacks() async {
        let loader = ControlledSnapshotLoader()
        let session = await makeSession(loader: loader)
        defer { loader.cancelPending(); session.stop() }
        let started = expectation(description: "Refresh is suspended")
        loader.onRequest = { _ in started.fulfill() }
        let refresh = Task { await session.refreshOneShotSnapshot() }
        await fulfillment(of: [started], timeout: 2)

        session.stop()
        loader.complete(0, with: .success(snapshot(named: "stale")))
        await refresh.value
        for type in RoundRegistrationType.allCases {
            XCTAssertFalse(session.recordInitialSnapshotReady(for: type))
        }

        XCTAssertNil(session.roundID)
        XCTAssertEqual(session.snapshot.round.id, "")
        XCTAssertNil(session.snapshot.round.name)
        XCTAssertNil(session.lastSnapshotReceivedAt)
        XCTAssertEqual(session.initialLoadState, .idle)
        XCTAssertEqual(session.currentProfile, .oneShot)
        XCTAssertFalse(session.isScoringSnapshotReady)
        XCTAssertTrue(session.activeListeners.isEmpty)
        XCTAssertFalse(session.completeInitialLoadTrackingIfTimedOut(asOf: .distantFuture))
    }

    func testSlowSuccessfulRefreshRecoversAfterReadinessTimeout() async {
        let loader = ControlledSnapshotLoader()
        let session = await makeSession(loader: loader)
        defer { loader.cancelPending(); session.stop() }
        let started = expectation(description: "Refresh is suspended")
        loader.onRequest = { _ in started.fulfill() }
        let refresh = Task { await session.refreshOneShotSnapshot() }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertTrue(session.completeInitialLoadTrackingIfTimedOut(asOf: .distantFuture))
        XCTAssertEqual(session.initialLoadState, .timedOut)
        XCTAssertFalse(session.canPersistScores)

        loader.complete(0, with: .success(snapshot(named: "recovered")))
        await refresh.value

        XCTAssertEqual(session.snapshot.round.name, "recovered")
        XCTAssertEqual(session.initialLoadState, .ready)
        XCTAssertTrue(session.canPersistScores)
        XCTAssertFalse(session.didTimeOutInitialLoad)
        XCTAssertFalse(session.completeInitialLoadTrackingIfTimedOut(asOf: .distantFuture))
    }

    func testInvalidActivationCannotReplaceExistingSessionOrFetchData() async {
        var fetchCount = 0
        let session = RoundSession { _, _ in
            fetchCount += 1
            return .init()
        }
        defer { session.stop() }
        session.roundID = "round"
        session.snapshot = snapshot(named: "preserved")

        for invalidID in ["", " \n\t", "/", "rounds/other"] {
            await session.activate(roundID: invalidID, profile: .roundOutcome)
            XCTAssertEqual(session.roundID, "round")
            XCTAssertEqual(session.snapshot.round.name, "preserved")
            XCTAssertEqual(session.currentProfile, .oneShot)
            XCTAssertEqual(session.initialLoadState, .idle)
            XCTAssertTrue(session.activeListeners.isEmpty)
        }
        XCTAssertEqual(fetchCount, 0)
    }

    func testDuplicateListenerCallbacksCannotReplaceMissingScoringSnapshot() {
        let session = RoundSession()
        defer { session.stop() }
        session.beginInitialLoadTracking(for: .liveRound, source: "test")

        for type in RoundRegistrationType.allCases where type != .scoring {
            for _ in 0..<3 {
                XCTAssertFalse(session.recordInitialSnapshotReady(for: type))
            }
        }
        XCTAssertEqual(session.initialLoadState, .loading)
        XCTAssertFalse(session.canPersistScores)
        XCTAssertTrue(session.recordInitialSnapshotReady(for: .scoring))
        XCTAssertFalse(session.recordInitialSnapshotReady(for: .scoring))
        XCTAssertEqual(session.initialLoadState, .ready)
        XCTAssertTrue(session.canPersistScores)
    }

    private func makeSession(loader: ControlledSnapshotLoader) async -> RoundSession {
        let session = RoundSession { roundID, preferServer in
            try await loader.load(roundID: roundID, preferServer: preferServer)
        }
        // Select the live profile before assigning an ID; no real listeners attach.
        await session.transitionProfile(to: .liveRound)
        session.roundID = "round"
        return session
    }

    private func snapshot(named name: String) -> RoundSnapshot {
        .init(round: .init(id: "round", name: name))
    }
}

@MainActor
private final class ControlledSnapshotLoader {
    var onRequest: ((Int) -> Void)?
    private(set) var requestedRoundIDs: [String] = []
    private(set) var preferServerValues: [Bool] = []
    private var continuations: [Int: CheckedContinuation<RoundSnapshot, Error>] = [:]

    func load(roundID: String, preferServer: Bool) async throws -> RoundSnapshot {
        let index = requestedRoundIDs.count
        requestedRoundIDs.append(roundID)
        preferServerValues.append(preferServer)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[index] = continuation
            onRequest?(index)
        }
    }

    func complete(_ index: Int, with result: Result<RoundSnapshot, Error>) {
        guard let continuation = continuations.removeValue(forKey: index) else {
            XCTFail("No suspended snapshot request at index \(index)")
            return
        }
        continuation.resume(with: result)
    }

    func cancelPending() {
        for continuation in continuations.values {
            continuation.resume(throwing: CancellationError())
        }
        continuations.removeAll()
    }
}
