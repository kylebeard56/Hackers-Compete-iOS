//
//  RoundSessionLifecycleTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class RoundSubscriptionProfileTests: XCTestCase {
    func testLobbyProfileExcludesScoringListener() {
        XCTAssertFalse(RoundSubscriptionProfile.lobby.listenerTypes.contains(.scoring))
        XCTAssertTrue(RoundSubscriptionProfile.lobby.listenerTypes.contains(.participant))
        XCTAssertTrue(RoundSubscriptionProfile.lobby.listenerTypes.contains(.segment))
    }

    func testLiveRoundProfileUsesAllListeners() {
        XCTAssertEqual(RoundSubscriptionProfile.liveRound.listenerTypes, Set(RoundRegistrationType.allCases))
    }

    func testRoundOutcomeProfileUsesOneShotBehavior() {
        XCTAssertFalse(RoundSubscriptionProfile.roundOutcome.usesLiveListeners)
        XCTAssertTrue(RoundSubscriptionProfile.roundOutcome.listenerTypes.isEmpty)
    }

    func testListenerPolicyAppliesLatencyCompensatedLocalWrites() {
        XCTAssertTrue(
            RoundSession.shouldApplyListenerSnapshot(
                hasPendingWrites: true,
                isFromCache: true
            )
        )
    }

    func testListenerPolicyAppliesServerAndCacheSnapshots() {
        XCTAssertTrue(
            RoundSession.shouldApplyListenerSnapshot(
                hasPendingWrites: false,
                isFromCache: false
            )
        )
        XCTAssertTrue(
            RoundSession.shouldApplyListenerSnapshot(
                hasPendingWrites: false,
                isFromCache: true
            )
        )
    }
}

@MainActor
final class RoundSessionLifecycleTests: XCTestCase {
    func testShouldReuseSameRoundWhenRecentlyActive() {
        let session = RoundSession()
        session.roundID = "round_1"
        session.recordSessionActivity(at: Date())

        XCTAssertFalse(session.shouldRebuildSession(for: "round_1", asOf: Date()))
    }

    func testShouldRebuildSameRoundAfterStaleInterval() {
        let session = RoundSession()
        session.roundID = "round_1"
        session.recordSessionActivity(
            at: Date().addingTimeInterval(-(RoundSession.staleSessionInterval + 5))
        )

        XCTAssertTrue(session.shouldRebuildSession(for: "round_1", asOf: Date()))
    }

    func testShouldRebuildWhenRoundChanges() {
        let session = RoundSession()
        session.roundID = "round_1"
        session.recordSessionActivity(at: Date())

        XCTAssertTrue(session.shouldRebuildSession(for: "round_2", asOf: Date()))
        XCTAssertEqual(session.rebuildReason(for: "round_2", asOf: Date()), .newRound)
    }

    func testShouldRebuildAfterLongBackgroundFlag() {
        let session = RoundSession()
        session.roundID = "round_1"
        session.recordSessionActivity(at: Date())
        session.markNeedsRefreshAfterLongBackground()

        XCTAssertTrue(session.shouldRebuildSession(for: "round_1", asOf: Date()))
        XCTAssertEqual(session.rebuildReason(for: "round_1", asOf: Date()), .staleBackground)
    }

    func testShouldUseColdStartReasonWithoutCurrentRound() {
        let session = RoundSession()

        XCTAssertEqual(session.rebuildReason(for: "round_1", asOf: Date()), .coldStart)
    }

    func testInitialSnapshotTrackingEmitsOnlyWhenAllExpectedListenersReady() {
        let session = RoundSession()
        session.beginInitialLoadTracking(for: .lobby, startedAt: Date(), source: "live_listeners")

        XCTAssertFalse(session.recordInitialSnapshotReady(for: .round))
        XCTAssertFalse(session.recordInitialSnapshotReady(for: .participant))
        XCTAssertFalse(session.recordInitialSnapshotReady(for: .segment))
        XCTAssertFalse(session.recordInitialSnapshotReady(for: .team))
        XCTAssertFalse(session.recordInitialSnapshotReady(for: .teeGroup))
        XCTAssertTrue(session.recordInitialSnapshotReady(for: .scoringGroup))
        XCTAssertFalse(session.recordInitialSnapshotReady(for: .round))
    }

    func testLobbyToLiveRoundTransitionRetainsReadinessForExistingListeners() {
        let session = RoundSession()
        let lobbyTypes = RoundSubscriptionProfile.lobby.listenerTypes
        session.beginInitialLoadTracking(for: .lobby, startedAt: Date(), source: "live_listeners")

        for type in lobbyTypes {
            _ = session.recordInitialSnapshotReady(for: type)
        }

        session.beginInitialLoadTracking(
            for: .liveRound,
            startedAt: Date(),
            source: "live_listeners",
            retainingReadyTypes: lobbyTypes
        )

        XCTAssertTrue(session.recordInitialSnapshotReady(for: .scoring))
        XCTAssertTrue(session.isScoringSnapshotReady)
    }

    func testLiveRoundReadinessTimesOutInsteadOfWaitingForever() {
        let session = RoundSession()
        let startedAt = Date()
        session.beginInitialLoadTracking(
            for: .liveRound,
            startedAt: startedAt,
            source: "live_listeners"
        )

        XCTAssertFalse(
            session.completeInitialLoadTrackingIfTimedOut(
                asOf: startedAt.addingTimeInterval(RoundSession.initialListenerReadinessTimeout - 1)
            )
        )
        XCTAssertFalse(session.isScoringSnapshotReady)
        XCTAssertFalse(session.didTimeOutInitialLoad)

        XCTAssertTrue(
            session.completeInitialLoadTrackingIfTimedOut(
                asOf: startedAt.addingTimeInterval(RoundSession.initialListenerReadinessTimeout)
            )
        )
        XCTAssertTrue(session.isScoringSnapshotReady)
        XCTAssertTrue(session.didTimeOutInitialLoad)
    }

    func testListenerErrorThrottleSuppressesDuplicateEventsInsideCooldown() {
        let session = RoundSession()
        let error = NSError(domain: "Firestore", code: 7)
        let now = Date()

        XCTAssertTrue(
            session.shouldEmitListenerError(
                roundID: "round_1",
                profile: .liveRound,
                listenerType: .scoring,
                error: error,
                at: now
            )
        )

        XCTAssertFalse(
            session.shouldEmitListenerError(
                roundID: "round_1",
                profile: .liveRound,
                listenerType: .scoring,
                error: error,
                at: now.addingTimeInterval(60)
            )
        )

        XCTAssertTrue(
            session.shouldEmitListenerError(
                roundID: "round_1",
                profile: .liveRound,
                listenerType: .scoring,
                error: error,
                at: now.addingTimeInterval(RoundSession.listenerErrorThrottleInterval + 1)
            )
        )
    }
}
