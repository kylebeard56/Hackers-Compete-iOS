@testable import Hackers
import Combine
import XCTest

@MainActor
final class RoundSessionReloadTests: XCTestCase {
    func testSuccessfulOneShotRefreshRestoresScoringReadiness() async {
        let expected = MockLiveRound2v2.snapshot
        let session = RoundSession { roundID, preferServer in
            XCTAssertEqual(roundID, expected.round.id)
            XCTAssertTrue(preferServer)
            return expected
        }
        // Set the profile before assigning an ID to avoid attaching real listeners.
        await session.transitionProfile(to: .liveRound)
        session.roundID = expected.round.id
        makeReady(session)

        var states: [RoundInitialLoadState] = []
        let subscription = session.$initialLoadState.sink { states.append($0) }
        await session.refreshOneShotSnapshot()

        XCTAssertEqual(states, [.ready, .loading, .ready])
        XCTAssertEqual(session.snapshot.round.id, expected.round.id)
        XCTAssertTrue(session.isScoringSnapshotReady)
        XCTAssertTrue(session.canPersistScores)
        XCTAssertFalse(session.completeInitialLoadTrackingIfTimedOut(asOf: .distantFuture))
        subscription.cancel()
        session.stop()
    }

    func testFailedRefreshKeepsScoringLockedAndAllowsListenerRecovery() async {
        let session = RoundSession { _, _ in
            throw NSError(domain: "RoundSessionReloadTests", code: 1)
        }
        await session.transitionProfile(to: .liveRound)
        session.roundID = MockLiveRound2v2.roundID
        session.snapshot = MockLiveRound2v2.snapshot
        makeReady(session)

        await session.refreshOneShotSnapshot()

        XCTAssertFalse(session.canPersistScores)
        XCTAssertTrue(session.completeInitialLoadTrackingIfTimedOut(asOf: .distantFuture))
        XCTAssertEqual(session.initialLoadState, .timedOut)
        for type in RoundSubscriptionProfile.liveRound.listenerTypes {
            _ = session.recordInitialSnapshotReady(for: type)
        }
        XCTAssertEqual(session.initialLoadState, .ready)
        XCTAssertTrue(session.canPersistScores)
        session.stop()
    }

    func testSupersededRefreshCannotUnlockTheNewLoad() async {
        weak var activeSession: RoundSession?
        let session = RoundSession { _, _ in
            // Simulate a profile/reload change while the fetch is in flight.
            activeSession?.beginInitialLoadTracking(for: .liveRound, source: "newer_load")
            return MockLiveRound2v2.snapshot
        }
        activeSession = session
        await session.transitionProfile(to: .liveRound)
        session.roundID = MockLiveRound2v2.roundID
        let originalRoundID = session.snapshot.round.id

        await session.refreshOneShotSnapshot()

        XCTAssertEqual(session.snapshot.round.id, originalRoundID)
        XCTAssertEqual(session.initialLoadState, .loading)
        XCTAssertFalse(session.canPersistScores)
        session.stop()
    }

    func testReloadTimesOutWithoutTheInitialViewTask() async {
        let session = RoundSession()
        makeReady(session)
        XCTAssertTrue(session.canPersistScores)

        let timedOut = expectation(description: "Session owns the reload timeout")
        let subscription = session.$initialLoadState.sink { state in
            if state == .timedOut { timedOut.fulfill() }
        }
        session.beginInitialLoadTracking(for: .liveRound, source: "foreground_reload")
        XCTAssertFalse(session.canPersistScores)

        await fulfillment(of: [timedOut], timeout: RoundSession.initialListenerReadinessTimeout + 5)

        XCTAssertEqual(session.initialLoadState, .timedOut)
        XCTAssertFalse(session.canPersistScores)
        subscription.cancel()
        session.stop()
    }

    func testReloadDisablesScorecardEditingAndRoundCompletionUntilReady() async throws {
        let session = RoundSession()
        session.snapshot = MockLiveRound2v2.snapshot
        let app = AppSession(restoresAuthentication: false)
        app.activeRoundID = session.snapshot.round.id
        let participant = try XCTUnwrap(session.snapshot.participants.first)
        app.ephemeralParticipantID = participant.id
        let model = LiveRoundViewModel()
        model.seriesAccessOverride = .init(seriesID: nil, isCommissioner: false)
        model.bind(appSession: app, roundSession: session)
        await model.ensureParticipantResolved()
        makeReady(session)
        model.restoreCurrentHole(5)
        XCTAssertTrue(model.canCompleteActualGroup)
        XCTAssertTrue(model.canEditScorecard(participant: participant))

        session.beginInitialLoadTracking(for: .liveRound, source: "foreground_reload")
        XCTAssertFalse(model.canCompleteActualGroup)
        XCTAssertFalse(model.canEditScorecard(participant: participant))
        XCTAssertEqual(model.currentHoleNumber, 5)

        for type in RoundSubscriptionProfile.liveRound.listenerTypes {
            _ = session.recordInitialSnapshotReady(for: type)
        }
        XCTAssertTrue(model.canCompleteActualGroup)
        XCTAssertTrue(model.canEditScorecard(participant: participant))
        XCTAssertEqual(model.currentHoleNumber, 5)
        session.stop()
    }

    private func makeReady(_ session: RoundSession) {
        session.beginInitialLoadTracking(for: .liveRound, source: "live_listeners")
        for type in RoundSubscriptionProfile.liveRound.listenerTypes {
            _ = session.recordInitialSnapshotReady(for: type)
        }
    }
}
