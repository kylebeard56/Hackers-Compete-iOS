//
//  LiveRoundHoleOrderingTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

// MARK: - Pure ordering (LiveRoundHoleOrdering)

final class LiveRoundHoleOrderingTests: XCTestCase {

    func testCourseHoleNumbers_nilRange_defaultsThrough18() {
        let holes = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: nil)
        XCTAssertEqual(holes, Array(1...18))
    }

    func testCourseHoleNumbers_frontNine() {
        let holes = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: HoleRange(startHole: 1, endHole: 9))
        XCTAssertEqual(holes, Array(1...9))
    }

    func testCourseHoleNumbers_endHoleZeroUses18() {
        let holes = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: HoleRange(startHole: 1, endHole: 0))
        XCTAssertEqual(holes.last, 18)
    }

    func testPlayOrdered_startingHole7_rotatesFrontNine() {
        let course = Array(1...9)
        let ordered = LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 7)
        XCTAssertEqual(ordered, [7, 8, 9, 1, 2, 3, 4, 5, 6])
    }

    func testPlayOrdered_startingHole9_wrapsToFront() {
        let course = Array(1...9)
        let ordered = LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 9)
        XCTAssertEqual(ordered, [9, 1, 2, 3, 4, 5, 6, 7, 8])
    }

    func testPlayOrdered_startingHoleZero_returnsCourseOrder() {
        let course = Array(1...9)
        XCTAssertEqual(
            LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 0),
            course
        )
    }

    func testPlayOrdered_startingHoleNotInCourse_returnsCourseOrder() {
        let course = Array(1...9)
        XCTAssertEqual(
            LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 99),
            course
        )
    }

    func testPlayOrdered_firstHole_isIdentity() {
        let course = Array(1...9)
        XCTAssertEqual(
            LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 1),
            course
        )
    }

    func testPlayOrderHoleNumbers_resolvesTeeGroup() {
        let group = TeeTimeGroup(
            id: "g1",
            index: 0,
            startingHole: 7,
            createdAt: .init(),
            parentID: "r1"
        )
        let ordered = LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: HoleRange(startHole: 1, endHole: 9),
            teeGroupID: "g1",
            teeGroups: [group]
        )
        XCTAssertEqual(ordered, [7, 8, 9, 1, 2, 3, 4, 5, 6])
    }

    func testPlayOrderHoleNumbers_nilGroupID_isCourseOrder() {
        let group = TeeTimeGroup(
            id: "g1",
            index: 0,
            startingHole: 7,
            createdAt: .init(),
            parentID: "r1"
        )
        let ordered = LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: HoleRange(startHole: 1, endHole: 9),
            teeGroupID: nil,
            teeGroups: [group]
        )
        XCTAssertEqual(ordered, Array(1...9))
    }

    // MARK: - Past / future in play order (error styling)

    func testIncompletePast_startOn9_current9_hole1IsFuture() {
        let play = [9, 1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertFalse(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 1, currentHole: 9)
        )
    }

    func testIncompletePast_startOn9_current3_hole1IsPast() {
        let play = [9, 1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 1, currentHole: 3)
        )
    }

    func testIncompletePast_startOn9_onHole2_hole9WasSkippedIncomplete() {
        let play = [9, 1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 9, currentHole: 1)
        )
    }

    func testIncompletePast_startOn7_current7_hole1IsFuture() {
        let play = [7, 8, 9, 1, 2, 3, 4, 5, 6]
        XCTAssertFalse(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 1, currentHole: 7)
        )
    }

    func testIncompletePast_unknownHole_returnsFalse() {
        let play = [1, 2, 3]
        XCTAssertFalse(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 99, currentHole: 2)
        )
    }
}

// MARK: - LiveRoundViewModel integration

@MainActor
final class LiveRoundViewModelHoleOrderingTests: XCTestCase {

    private func boundViewModel(snapshot: RoundSnapshot) async -> LiveRoundViewModel {
        let appSession = AppSession()
        if let id = snapshot.participants.first?.id {
            appSession.ephemeralParticipantID = id
        }
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        await vm.ensureParticipantResolved()
        return vm
    }

    func testHoleNumbers_clampsExtremeCurrentHoleIndex_noCrash() async {
        let vm = await boundViewModel(snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 1))
        vm.currentHoleIndex = 10_000
        XCTAssertEqual(vm.currentHoleNumber, 9)
        vm.currentHoleIndex = -50
        XCTAssertEqual(vm.currentHoleNumber, 1)
    }

    func testHoleNumbers_startOnNine_orderAndFutureHolesNotError() async {
        let vm = await boundViewModel(snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 9))
        vm.currentHoleIndex = 0

        XCTAssertEqual(vm.holeNumbers, [9, 1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(vm.holeState(for: 9), .current)
        XCTAssertEqual(vm.holeState(for: 1), .unscored)
        XCTAssertEqual(vm.holeState(for: 2), .unscored)
        XCTAssertEqual(vm.holeState(for: 8), .unscored)
    }

    /// Past hole in play order, still unscored → error styling (skipped).
    func testHoleState_onHole1_withoutScoringHole9_hole9IsError() async {
        let vm = await boundViewModel(snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 9))
        vm.selectHole(1)

        XCTAssertEqual(vm.holeState(for: 1), .current)
        XCTAssertEqual(vm.holeState(for: 9), .error)
    }

    func testHoleCompletion_allHolesScored_progressComplete() async {
        let vm = await boundViewModel(
            snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 7, scoreAllHoles: true)
        )

        for h in 1...9 {
            XCTAssertEqual(vm.holeCompletionProgress(holeNumber: h), 1.0, "hole \(h)")
        }
        XCTAssertNil(vm.nextUnscoredHoleNumber)
    }

    func testHoleState_allScored_currentHole7_restCompleted() async {
        let vm = await boundViewModel(
            snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 7, scoreAllHoles: true)
        )
        vm.selectHole(7)

        XCTAssertEqual(vm.holeState(for: 7), .current)
        for h in 1...9 where h != 7 {
            XCTAssertEqual(vm.holeState(for: h), .completed, "hole \(h)")
        }
    }

    // MARK: - Snapshot factory

    private static func makeSnapshotNineHolesStarting(
        groupStartingHole: Int,
        scoreAllHoles: Bool = false
    ) -> RoundSnapshot {
        let roundID = "lr_order_test"
        let groupID = "g_order"
        let segmentID = "seg_order"

        let participant = RoundParticipant(
            id: "p1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Test", "Player"),
            teeBoxID: "tee1",
            groupID: groupID,
            teeOrder: 1,
            isHost: true,
            parentID: roundID
        )

        let teeGroup = TeeTimeGroup(
            id: groupID,
            index: 0,
            startingHole: groupStartingHole,
            createdAt: .init(),
            parentID: roundID
        )

        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 9),
            scoringUnits: [
                ScoringUnit(
                    id: "su_p1",
                    owner: .participant,
                    ownerIDs: ["p1"],
                    scoringMethod: .individual
                ),
            ],
            parentID: roundID
        )

        let round = Round(
            id: roundID,
            shareCode: "TST",
            createdBy: "u1",
            status: .live,
            players: ["pl1"],
            configuration: RoundConfiguration(
                primaryFormat: .strokePlay,
                courses: [
                    CourseSegment(
                        courseInfo: CourseInfo(),
                        holeRange: HoleRange(startHole: 1, endHole: 9),
                        defaultTee: "tee1"
                    ),
                ]
            )
        )

        var scoring: [ScoreEntry] = []
        if scoreAllHoles {
            for hole in 1...9 {
                scoring.append(
                    ScoreEntry(
                        id: ScoreEntry.makeID(hole: hole, segment: segmentID, scoringUnit: "su_p1"),
                        holeNumber: hole,
                        segmentID: segmentID,
                        groupID: groupID,
                        scoringUnitID: "su_p1",
                        participantIDs: ["p1"],
                        strokes: 4,
                        pickedUp: false,
                        entryID: "p1",
                        parentID: roundID
                    )
                )
            }
        }

        return RoundSnapshot(
            round: round,
            participants: [participant],
            teams: [],
            teeGroups: [teeGroup],
            segments: [segment],
            scoring: scoring
        )
    }
}
