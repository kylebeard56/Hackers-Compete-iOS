import XCTest
@testable import Hackers

/// Local integration of durable resume state, snapshot hydration and the actual
/// live-round model. Firebase writes and OS/device suspension are separate checks.
@MainActor
final class InternalRoundResumeReleaseTests: XCTestCase {
    private func snapshot(_ range: HoleRange) -> RoundSnapshot {
        var snapshot = MockLiveRound2v2.snapshot
        snapshot.round.configuration.courses[0].holeRange = range
        snapshot.teeGroups = []
        let participant = snapshot.participants[0]
        let segment = RoundSegment(id: "release-segment", roundID: snapshot.round.id, holeRange: range,
            templateID: FormatTemplateRegistry.strokePlay.id,
            scoringUnits: snapshot.participants.map { .init(id: $0.id, owner: .participant, ownerIDs: [$0.id]) })
        snapshot.segments = [segment]
        snapshot.scoring = [range.startHole, range.startHole + 1].enumerated().map { offset, hole in
            ScoreEntry(id: ScoreEntry.makeID(hole: hole, segment: segment.id, scoringUnit: participant.id),
                holeNumber: hole, segmentID: segment.id, scoringUnitID: participant.id,
                participantIDs: [participant.id], strokes: 4 + offset, entryID: participant.id,
                parentID: snapshot.round.id)
        }
        return snapshot
    }

    private func model(_ snapshot: RoundSnapshot, app: AppSession, session: RoundSession) async -> LiveRoundViewModel {
        session.snapshot = snapshot
        app.activeRoundID = snapshot.round.id
        app.ephemeralParticipantID = snapshot.participants[0].id
        let model = LiveRoundViewModel()
        model.seriesAccessOverride = .init(seriesID: nil, isCommissioner: false)
        model.bind(appSession: app, roundSession: session)
        await model.ensureParticipantResolved()
        try? await Task.sleep(for: .milliseconds(50))
        return model
    }

    func testNineAndEighteenHoleNavigationPreservesPreviouslyEnteredScores() async {
        for range in [HoleRange(startHole: 1, endHole: 9), .init(startHole: 10, endHole: 18), .init(startHole: 1, endHole: 18)] {
            let snapshot = snapshot(range)
            let session = RoundSession()
            let app = AppSession(restoresAuthentication: false)
            let model = await model(snapshot, app: app, session: session)
            let participantID = snapshot.participants[0].id
            model.restoreCurrentHole(range.startHole)
            for hole in [range.startHole + 1, range.endHole, range.startHole] {
                model.selectHole(hole)
                XCTAssertEqual(model.currentHoleNumber, hole)
                XCTAssertEqual(model.grossStrokes(for: participantID, holeNumber: range.startHole), 4)
                XCTAssertEqual(model.grossStrokes(for: participantID, holeNumber: range.startHole + 1), 5)
                XCTAssertEqual(session.snapshot.scoring, snapshot.scoring, "Navigation must not write default scores")
            }
            session.stop()
        }
    }

    func testDurableResumeSurvivesNewAppSessionAndRestoresHoleWithSavedScores() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "InternalRoundResumeReleaseTests.\(UUID().uuidString)"))
        let store = UserDefaultsRoundResumeStore(defaults: defaults)
        defer { store.clearAll() }
        let snapshot = snapshot(.init(startHole: 10, endHole: 18))
        let originalApp = AppSession(roundResumeStore: store, restoresAuthentication: false)
        originalApp.activeRoundID = snapshot.round.id
        originalApp.updateLiveRoundResume(selectedHole: 15, selectedTab: .table)
        // This is the durable store used by the scene-background callback.
        let reopened = AppSession(roundResumeStore: store, restoresAuthentication: false)
        XCTAssertEqual(reopened.roundResumeState?.selectedHole, 15)
        let session = RoundSession()
        let model = await model(snapshot, app: reopened, session: session)
        model.restoreCurrentHole(reopened.roundResumeState?.selectedHole)
        XCTAssertEqual(model.currentHoleNumber, 15)
        XCTAssertEqual(model.grossStrokes(for: snapshot.participants[0].id, holeNumber: 10), 4)
        XCTAssertEqual(model.grossStrokes(for: snapshot.participants[0].id, holeNumber: 11), 5)
        XCTAssertEqual(session.snapshot.scoring, snapshot.scoring)
        session.stop()
    }

    func testRepeatedListenerHydrationKeepsRestoredHoleAndDoesNotResetScores() async {
        let snapshot = snapshot(.init(startHole: 1, endHole: 18))
        let session = RoundSession()
        let app = AppSession(restoresAuthentication: false)
        let model = await model(snapshot, app: app, session: session)
        model.restoreCurrentHole(7)
        for _ in 0..<3 {
            session.beginInitialLoadTracking(for: .liveRound, source: "foreground_reload")
            XCTAssertFalse(session.canPersistScores)
            session.snapshot = snapshot
            try? await Task.sleep(for: .milliseconds(50))
            for type in RoundSubscriptionProfile.liveRound.listenerTypes {
                _ = session.recordInitialSnapshotReady(for: type)
            }
            XCTAssertTrue(session.canPersistScores)
            XCTAssertEqual(model.currentHoleNumber, 7)
            XCTAssertEqual(session.snapshot.scoring, snapshot.scoring)
            XCTAssertEqual(model.grossStrokes(for: snapshot.participants[0].id, holeNumber: 1), 4)
        }
        session.stop()
    }
}
