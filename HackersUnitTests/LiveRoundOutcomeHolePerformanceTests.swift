//
//  LiveRoundOutcomeHolePerformanceTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

@MainActor
final class LiveRoundOutcomeHolePerformanceTests: XCTestCase {

    private func boundViewModel(
        snapshot: RoundSnapshot,
        participantID: String = "participant_1"
    ) async -> LiveRoundViewModel {
        let appSession = AppSession()
        appSession.ephemeralParticipantID = participantID

        let roundSession = RoundSession()
        roundSession.snapshot = snapshot

        let viewModel = LiveRoundViewModel()
        viewModel.bind(appSession: appSession, roundSession: roundSession)
        await viewModel.ensureParticipantResolved()
        await Task.yield()
        await Task.yield()
        return viewModel
    }

    func testOutcomeHolePerformanceRows_computeStatsUsingActiveParticipantsOnly() async throws {
        let viewModel = await boundViewModel(snapshot: Self.makeOutcomeSnapshot())

        let rows = viewModel.outcomeHolePerformanceRows(sortedBy: .holeNumber)
        let hole1 = try XCTUnwrap(rows.first(where: { $0.holeNumber == 1 }))

        XCTAssertEqual(hole1.bestGross, 4)
        XCTAssertEqual(try XCTUnwrap(hole1.averageGross), 4.5, accuracy: 0.001)
        XCTAssertEqual(hole1.worstGross, 5)
        XCTAssertEqual(try XCTUnwrap(hole1.bestDiff), -1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(hole1.averageDiff), -0.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(hole1.worstDiff), 0, accuracy: 0.001)
    }

    func testOutcomeHolePerformanceRows_excludesPickedUpEntriesWithoutStrokes() async throws {
        let viewModel = await boundViewModel(snapshot: Self.makeOutcomeSnapshot())

        let hole1 = try XCTUnwrap(
            viewModel.outcomeHolePerformanceRows(sortedBy: .holeNumber)
                .first(where: { $0.holeNumber == 1 })
        )

        XCTAssertEqual(try XCTUnwrap(hole1.averageGross), 4.5, accuracy: 0.001)
        XCTAssertEqual(hole1.worstGross, 5)
    }

    func testOutcomeHolePerformanceRows_sortByDifficultyDescendingAverageDiff() async {
        let viewModel = await boundViewModel(snapshot: Self.makeOutcomeSnapshot())

        let rows = viewModel.outcomeHolePerformanceRows(sortedBy: .difficulty)

        XCTAssertEqual(rows.first?.holeNumber, 2)
        XCTAssertEqual(rows.dropFirst().first?.holeNumber, 1)
    }

    func testOutcomeHolePerformanceRows_useCurrentViewerTeeMetadata() async throws {
        let viewModel = await boundViewModel(snapshot: Self.makeOutcomeSnapshot())

        let hole1 = try XCTUnwrap(
            viewModel.outcomeHolePerformanceRows(sortedBy: .holeNumber)
                .first(where: { $0.holeNumber == 1 })
        )

        XCTAssertEqual(hole1.par, 5)
        XCTAssertEqual(hole1.yardage, 510)
        XCTAssertEqual(hole1.handicap, 2)
    }

    func testOutcomeHolePerformanceRows_includeRowsForUnscoredHoles() async throws {
        let viewModel = await boundViewModel(snapshot: Self.makeOutcomeSnapshot())

        let hole3 = try XCTUnwrap(
            viewModel.outcomeHolePerformanceRows(sortedBy: .holeNumber)
                .first(where: { $0.holeNumber == 3 })
        )

        XCTAssertNil(hole3.bestGross)
        XCTAssertNil(hole3.averageGross)
        XCTAssertNil(hole3.worstGross)
        XCTAssertNil(hole3.averageDiff)
    }

    func testFormattedOutcomeHoleMetric_supportsTotalAndSignedDiffFormats() async {
        let viewModel = await boundViewModel(snapshot: Self.makeOutcomeSnapshot())

        XCTAssertEqual(
            viewModel.formattedOutcomeHoleMetric(4, mode: .total, prefersInteger: true),
            "4"
        )
        XCTAssertEqual(
            viewModel.formattedOutcomeHoleMetric(4.2, mode: .total, prefersInteger: false),
            "4.2"
        )
        XCTAssertEqual(
            viewModel.formattedOutcomeHoleMetric(4.15, mode: .total, prefersInteger: false),
            "4.15"
        )
        XCTAssertEqual(
            viewModel.formattedOutcomeHoleMetric(0.15, mode: .diff, prefersInteger: false),
            "+0.15"
        )
    }
}

private extension LiveRoundOutcomeHolePerformanceTests {
    static func makeOutcomeSnapshot() -> RoundSnapshot {
        var snapshot = MockCompletedRound.completedSnapshot(roundID: "outcome_hole_stats")

        let viewerTee = makeTee(
            id: "viewer_tee",
            name: "Gold",
            holeOverrides: [
                1: Hole(number: 1, par: 5, yardage: 510, handicap: 2),
                2: Hole(number: 2, par: 4, yardage: 455, handicap: 6)
            ]
        )
        let defaultTee = makeTee(
            id: "default_tee",
            name: "Blue",
            holeOverrides: [
                1: Hole(number: 1, par: 4, yardage: 430, handicap: 8),
                2: Hole(number: 2, par: 4, yardage: 405, handicap: 10)
            ]
        )

        let courseInfo = CourseInfo(
            id: "course_id",
            name: "Outcome Test Course",
            totalHoles: 18,
            tees: [defaultTee, viewerTee]
        )

        snapshot.round.configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            courses: [
                CourseSegment(
                    courseInfo: courseInfo,
                    holeRange: HoleRange(startHole: 1, endHole: 18),
                    defaultTee: defaultTee.id
                )
            ]
        )

        snapshot.participants = [
            makeParticipant(id: "participant_1", playerID: "player_1", teeBoxID: viewerTee.id, presenceStatus: .active),
            makeParticipant(id: "participant_2", playerID: "player_2", teeBoxID: defaultTee.id, presenceStatus: .active),
            makeParticipant(id: "participant_3", playerID: "player_3", teeBoxID: defaultTee.id, presenceStatus: .active),
            makeParticipant(id: "participant_4", playerID: "player_4", teeBoxID: defaultTee.id, presenceStatus: .noShow)
        ]

        snapshot.segments = [
            RoundSegment(
                id: "segment_1",
                roundID: snapshot.round.id,
                holeRange: HoleRange(startHole: 1, endHole: 18),
                gameFormat: .strokePlay,
                scoringUnits: snapshot.participants.map { participant in
                    ScoringUnit(
                        id: "unit_\(participant.id)",
                        owner: .participant,
                        ownerIDs: [participant.id],
                        scoringMethod: .individual
                    )
                },
                createdAt: .init(),
                lastUpdatedAt: .init(),
                parentID: snapshot.round.id
            )
        ]

        snapshot.scoring = [
            makeScoreEntry(roundID: snapshot.round.id, participantID: "participant_1", holeNumber: 1, strokes: 4),
            makeScoreEntry(roundID: snapshot.round.id, participantID: "participant_2", holeNumber: 1, strokes: 5),
            makeScoreEntry(roundID: snapshot.round.id, participantID: "participant_3", holeNumber: 1, strokes: nil, pickedUp: true),
            makeScoreEntry(roundID: snapshot.round.id, participantID: "participant_4", holeNumber: 1, strokes: 9),
            makeScoreEntry(roundID: snapshot.round.id, participantID: "participant_1", holeNumber: 2, strokes: 5),
            makeScoreEntry(roundID: snapshot.round.id, participantID: "participant_2", holeNumber: 2, strokes: 6)
        ]

        return snapshot
    }

    static func makeParticipant(
        id: String,
        playerID: String,
        teeBoxID: String,
        presenceStatus: RoundParticipantPresenceStatus
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            userID: "user_\(id)",
            playerID: playerID,
            name: Name("Player", String(id.suffix(1))),
            teeBoxID: teeBoxID,
            originalHandicap: 10,
            adjustedHandicap: 10,
            teamID: nil,
            groupID: "group_1",
            teeOrder: Int(id.suffix(1)) ?? 1,
            isHost: id == "participant_1",
            presenceStatus: presenceStatus,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "outcome_hole_stats"
        )
    }

    static func makeScoreEntry(
        roundID: String,
        participantID: String,
        holeNumber: Int,
        strokes: Int?,
        pickedUp: Bool = false
    ) -> ScoreEntry {
        ScoreEntry(
            id: "h\(holeNumber)_\(participantID)",
            holeNumber: holeNumber,
            segmentID: "segment_1",
            groupID: "group_1",
            scoringUnitID: "unit_\(participantID)",
            participantIDs: [participantID],
            strokes: strokes,
            pickedUp: pickedUp,
            entryID: participantID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    static func makeTee(
        id: String,
        name: String,
        holeOverrides: [Int: Hole]
    ) -> Tee {
        let holes = (1...18).map { holeNumber in
            holeOverrides[holeNumber] ?? Hole(
                number: holeNumber,
                par: 4,
                yardage: 360 + holeNumber,
                handicap: holeNumber
            )
        }

        return Tee(
            id: id,
            name: name,
            gender: Gender.male.rawValue,
            totalHoles: 18,
            holes: holes,
            ratingFull: 72.0,
            slopeFull: 121,
            ratingFront: 36.0,
            slopeFront: 121,
            ratingBack: 36.0,
            slopeBack: 121
        )
    }
}
