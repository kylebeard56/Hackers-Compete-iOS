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

    func testSharedScorePartnershipRowsDriveLeaderboardAndScorecard() async throws {
        let viewModel = await boundViewModel(
            snapshot: Self.makeSharedPartnershipSnapshot(),
            participantID: "p1"
        )

        let rows = viewModel.effectiveLeaderboardRows

        XCTAssertEqual(rows.map(\.id), ["pair_1", "pair_2"])
        XCTAssertTrue(rows.allSatisfy(\.isSharedScoreUnit))
        XCTAssertEqual(rows[0].participant.id, "p1")
        XCTAssertEqual(rows[0].participants.map(\.id), ["p1", "p2"])
        XCTAssertEqual(rows[1].participants.map(\.id), ["p3", "p4"])
        XCTAssertEqual(rows[0].scoreToPar, 0)
        XCTAssertEqual(rows[1].scoreToPar, 1)
        XCTAssertEqual(viewModel.scorecardParticipants.map(\.id), ["pair_1", "pair_2"])
        XCTAssertEqual(viewModel.scoringUnitGrossStrokes(scoringUnitID: "pair_1", holeNumber: 1), 4)
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

    static func makeSharedPartnershipSnapshot() -> RoundSnapshot {
        let roundID = "shared_partnership_round"
        let segmentID = "shared_partnership_segment"
        let tee = makeTee(id: "shared_tee", name: "Blue", holeOverrides: [
            1: Hole(number: 1, par: 4, yardage: 420, handicap: 8)
        ])
        let courseInfo = CourseInfo(
            id: "shared_course",
            name: "Shared Score Club",
            totalHoles: 18,
            tees: [tee]
        )
        let template = FormatTemplateRegistry.captainsChoice
        let format = GameFormat(
            type: .strokePlay,
            configuration: GameConfiguration(
                method: .aggregate,
                basis: .gross,
                handicap: .scramble2Player,
                requiresTeams: true
            )
        )
        let round = Round(
            id: roundID,
            status: .live,
            configuration: RoundConfiguration(
                primaryFormat: format,
                formatSummary: RoundFormatSummary(from: template),
                courses: [
                    CourseSegment(
                        courseInfo: courseInfo,
                        holeRange: HoleRange(startHole: 1, endHole: 18),
                        defaultTee: tee.id
                    )
                ],
                scoreOwnerScope: .partnership,
                sharedScoreHandicapConfig: .scramble2Player
            )
        )
        let participants = [
            makeSharedParticipant(id: "p1", first: "John", last: "Smith", teamID: "red", teeID: tee.id, teeOrder: 1, roundID: roundID),
            makeSharedParticipant(id: "p2", first: "Tyler", last: "Davis", teamID: "red", teeID: tee.id, teeOrder: 2, roundID: roundID),
            makeSharedParticipant(id: "p3", first: "Alice", last: "Lee", teamID: "blue", teeID: tee.id, teeOrder: 3, roundID: roundID),
            makeSharedParticipant(id: "p4", first: "Morgan", last: "Ray", teamID: "blue", teeID: tee.id, teeOrder: 4, roundID: roundID),
        ]
        let groups = [
            RoundScoringGroup(id: "pair_1", teamID: "red", teeGroupID: "group_1", kind: .partnership, memberIDs: ["p1", "p2"], parentID: roundID),
            RoundScoringGroup(id: "pair_2", teamID: "blue", teeGroupID: "group_1", kind: .partnership, memberIDs: ["p3", "p4"], parentID: roundID),
        ]
        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 18),
            gameFormat: format,
            templateID: template.id,
            scoringUnits: groups.map {
                ScoringUnit(id: $0.id, owner: .scoreOwner, ownerIDs: $0.memberIDs, scoringMethod: .aggregate)
            },
            parentID: roundID
        )

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: [
                RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init(), parentID: roundID),
                RoundTeam(id: "blue", name: "Blue", color: "blue", index: 1, createdAt: .init(), parentID: roundID),
            ],
            scoringGroups: groups,
            segments: [segment],
            scoring: [
                makeSharedScoreEntry(roundID: roundID, segmentID: segmentID, scoringUnitID: "pair_1", participantIDs: ["p1", "p2"], holeNumber: 1, strokes: 4),
                makeSharedScoreEntry(roundID: roundID, segmentID: segmentID, scoringUnitID: "pair_2", participantIDs: ["p3", "p4"], holeNumber: 1, strokes: 5),
            ]
        )
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

    static func makeSharedParticipant(
        id: String,
        first: String,
        last: String,
        teamID: String,
        teeID: String,
        teeOrder: Int,
        roundID: String
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            userID: "user_\(id)",
            playerID: "player_\(id)",
            name: Name(first, last),
            teeBoxID: teeID,
            originalHandicap: 10,
            adjustedHandicap: 10,
            teamID: teamID,
            groupID: "group_1",
            teeOrder: teeOrder,
            isHost: id == "p1",
            presenceStatus: .active,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    static func makeSharedScoreEntry(
        roundID: String,
        segmentID: String,
        scoringUnitID: String,
        participantIDs: [String],
        holeNumber: Int,
        strokes: Int
    ) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: scoringUnitID),
            holeNumber: holeNumber,
            segmentID: segmentID,
            groupID: "group_1",
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            strokes: strokes,
            pickedUp: false,
            entryID: participantIDs.first ?? scoringUnitID,
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
