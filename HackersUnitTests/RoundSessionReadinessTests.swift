//
//  RoundSessionReadinessTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

@MainActor
final class RoundSessionReadinessTests: XCTestCase {
    func testBeginInitialLoadTrackingRetainsLobbyReadyTypesWhenTransitioningToLive() {
        let session = RoundSession()
        let lobbyTypes = RoundSubscriptionProfile.lobby.listenerTypes
        session.beginInitialLoadTracking(for: .lobby, startedAt: Date(), source: "test")

        for type in lobbyTypes {
            _ = session.recordInitialSnapshotReady(for: type)
        }

        session.beginInitialLoadTracking(
            for: .liveRound,
            startedAt: Date(),
            source: "test",
            retainingReadyTypes: lobbyTypes
        )

        XCTAssertTrue(session.recordInitialSnapshotReady(for: .scoring))
        XCTAssertTrue(session.isScoringSnapshotReady)
    }

    func testLiveRoundReadinessTimesOutSetsFlags() {
        let session = RoundSession()
        let startedAt = Date()
        session.beginInitialLoadTracking(for: .liveRound, startedAt: startedAt, source: "test")

        let beforeTimeout = session.completeInitialLoadTrackingIfTimedOut(
            asOf: startedAt.addingTimeInterval(RoundSession.initialListenerReadinessTimeout - 1)
        )
        XCTAssertFalse(beforeTimeout)
        XCTAssertFalse(session.isScoringSnapshotReady)
        XCTAssertFalse(session.didTimeOutInitialLoad)

        let atTimeout = session.completeInitialLoadTrackingIfTimedOut(
            asOf: startedAt.addingTimeInterval(RoundSession.initialListenerReadinessTimeout)
        )
        XCTAssertTrue(atTimeout)
        XCTAssertTrue(session.isScoringSnapshotReady)
        XCTAssertTrue(session.didTimeOutInitialLoad)
    }
}
