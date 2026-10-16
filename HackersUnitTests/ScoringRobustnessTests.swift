@testable import Hackers
import XCTest

/// Existing scoring audit retained for the combined internal release.
final class ScoringRobustnessTests: XCTestCase {
    func testClearingAndReenteringStrokeScoreUpdatesTotalAndCompletion() throws {
        let participants = [participant("p1"), participant("p2")]
        var scores = [
            score("p1", hole: 1, strokes: 3),
            score("p1", hole: 2, strokes: 6),
            score("p2", hole: 1, strokes: 4),
            score("p2", hole: 2, strokes: 4),
        ]

        let original = strokePlay(scores, participants: participants)
        XCTAssertEqual(try row("p1", in: original).total, 1)
        XCTAssertEqual(original.holeStates[2], .complete)

        scores[1] = score("p1", hole: 2, strokes: nil)
        let cleared = strokePlay(scores, participants: participants)
        let clearedRow = try row("p1", in: cleared)
        XCTAssertEqual(clearedRow.total, -1)
        XCTAssertEqual(clearedRow.holesPlayed, 1)
        XCTAssertNil(clearedRow.holeValues[2])
        XCTAssertEqual(cleared.holeStates[2], .partial)
        XCTAssertEqual(try row("p2", in: cleared).holesPlayed, 2)

        scores[1] = score("p1", hole: 2, strokes: 4)
        let reentered = strokePlay(scores, participants: participants)
        XCTAssertEqual(try row("p1", in: reentered).total, -1)
        XCTAssertEqual(try row("p1", in: reentered).holesPlayed, 2)
        XCTAssertEqual(reentered.holeStates[2], .complete)
    }

    func testStablefordClearingAndCorrectingBirdieWithdrawsItsPoints() throws {
        var scores = [score("p1", hole: 1, strokes: 3), score("p1", hole: 2, strokes: 4)]
        XCTAssertEqual(try row("p1", in: stableford(scores)).total, 5)

        scores[0] = score("p1", hole: 1, strokes: nil)
        let cleared = stableford(scores)
        XCTAssertEqual(try row("p1", in: cleared).total, 2)
        XCTAssertEqual(try row("p1", in: cleared).holesPlayed, 1)
        XCTAssertNil(try row("p1", in: cleared).holeValues[1])
        XCTAssertEqual(cleared.holeStates[1], .unscored)

        scores[0] = score("p1", hole: 1, strokes: 6)
        let corrected = stableford(scores)
        XCTAssertEqual(try row("p1", in: corrected).total, 2)
        XCTAssertEqual(try row("p1", in: corrected).holesPlayed, 2)
        XCTAssertEqual(try row("p1", in: corrected).holeValues[1]?.points, 0)
        XCTAssertEqual(corrected.holeStates[1], .complete)
    }

    func testPrimarySegmentScoreWinsOverLegacyScoreRegardlessOfInputOrder() throws {
        let primary = score("p1", hole: 1, strokes: 3)
        let legacy = score("p1", hole: 1, strokes: 8, segmentID: "legacy")

        for scores in [[primary, legacy], [legacy, primary]] {
            let strokeResult = strokePlay(scores)
            XCTAssertEqual(try row("p1", in: strokeResult).total, -1)
            XCTAssertEqual(try row("p1", in: strokeResult).holeValues[1]?.rawStrokes, 3)
            XCTAssertEqual(try row("p1", in: strokeResult).holesPlayed, 1)

            let pointsResult = stableford(scores)
            XCTAssertEqual(try row("p1", in: pointsResult).total, 3)
            XCTAssertEqual(try row("p1", in: pointsResult).holeValues[1]?.rawStrokes, 3)
            XCTAssertEqual(try row("p1", in: pointsResult).holesPlayed, 1)
        }
    }

    func testClearedPrimaryScoreDoesNotResurrectLegacyScore() throws {
        let scores = [
            score("p1", hole: 1, strokes: 3, segmentID: "legacy"),
            score("p1", hole: 2, strokes: 5, segmentID: "legacy"),
            score("p1", hole: 1, strokes: nil),
        ]

        // Hole 1 was explicitly cleared in the current segment. Hole 2 has no
        // current record, so its legacy value remains a valid fallback.
        for (result, expectedTotal) in [(strokePlay(scores), 1.0), (stableford(scores), 1.0)] {
            let player = try row("p1", in: result)
            XCTAssertEqual(player.total, expectedTotal)
            XCTAssertEqual(player.holesPlayed, 1)
            XCTAssertNil(player.holeValues[1])
            XCTAssertEqual(player.holeValues[2]?.rawStrokes, 5)
            XCTAssertEqual(result.holeStates[1], .unscored)
            XCTAssertEqual(result.holeStates[2], .complete)
        }
    }

    func testScoresOutsideSegmentAndRosterDoNotAffectSegmentResult() throws {
        let boundarySegment = segment(start: 9, end: 10)
        let courseHoles = (8...11).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) }
        let scores = [
            score("p1", hole: 8, strokes: 1),
            score("p1", hole: 9, strokes: 3),
            score("p1", hole: 10, strokes: 5),
            score("p1", hole: 11, strokes: 12),
            score("removed-player", hole: 9, strokes: 1),
            score("removed-player", hole: 10, strokes: 1),
        ]
        let strokeResult = ScoringEngine.computeStrokePlay(
            scores: scores, participants: [participant("p1")], segment: boundarySegment,
            holes: courseHoles, basis: .gross, template: FormatTemplateRegistry.strokePlay
        )
        let pointsResult = ScoringEngine.computeWithPipeline(
            scores: scores, participants: [participant("p1")], teams: [], segment: boundarySegment,
            holes: courseHoles, basis: .gross, template: FormatTemplateRegistry.stableford
        )

        for (result, expectedTotal) in [(strokeResult, 0.0), (pointsResult, 4.0)] {
            XCTAssertEqual(result.rows.map(\.scoringUnitID), ["p1"])
            let player = try row("p1", in: result)
            XCTAssertEqual(player.total, expectedTotal)
            XCTAssertEqual(player.holesPlayed, 2)
            XCTAssertEqual(Set(player.holeValues.keys), Set([9, 10]))
            XCTAssertEqual(Set(result.holeStates.keys), Set([9, 10]))
            XCTAssertEqual(result.holeStates[9], .complete)
            XCTAssertEqual(result.holeStates[10], .complete)
        }
    }

    func testMatchPlayClearedOpponentScoreWithdrawsWinUntilHoleIsRescored() throws {
        var scores = [
            score("p1", hole: 1, strokes: 3),
            score("p2", hole: 1, strokes: 4),
            score("p1", hole: 2, strokes: 4),
            score("p2", hole: 2, strokes: 4),
        ]
        let matchup = TeamMatchup(id: "match", participantIDs: ["p1", "p2"], mode: .individual)
        var matchSegment = segment()
        matchSegment.matchups = [matchup]
        matchSegment.competitionScope = .matchup

        func compute() -> ScoringResult {
            ScoringEngine.computeWithPipeline(
                scores: scores, participants: [participant("p1"), participant("p2")], teams: [],
                segment: matchSegment, holes: holes, basis: .gross,
                template: FormatTemplateRegistry.matchPlayIndividual
            )
        }

        let original = compute()
        XCTAssertEqual(try row("p1", in: original).total, 1.5)
        XCTAssertEqual(try row("p2", in: original).total, 0.5)

        scores[1] = score("p2", hole: 1, strokes: nil)
        let cleared = compute()
        XCTAssertEqual(cleared.matchupResults.count, 1)
        for id in ["p1", "p2"] {
            let player = try row(id, in: cleared)
            XCTAssertEqual(player.total, 0.5, "Only the completed tie should award points")
            XCTAssertEqual(player.holesPlayed, 1)
            XCTAssertNil(player.holeValues[1])
        }
        XCTAssertEqual(cleared.holeStates[1], .partial)

        scores[1] = score("p2", hole: 1, strokes: 2)
        let corrected = compute()
        XCTAssertEqual(try row("p1", in: corrected).total, 0.5)
        XCTAssertEqual(try row("p2", in: corrected).total, 1.5)
        XCTAssertEqual(corrected.holeStates[1], .complete)
    }

    func testTeamBestBallSelectsRemainingPlayerAfterCountingScoreIsCleared() throws {
        let participants = [participant("p1", teamID: "red"), participant("p2", teamID: "red")]
        let teams = [RoundTeam(id: "red", name: "Red", color: "red", index: 0, createdAt: .init())]
        var scores = [
            score("p1", hole: 1, strokes: 3),
            score("p1", hole: 2, strokes: 5),
            score("p2", hole: 1, strokes: 4),
            score("p2", hole: 2, strokes: 4),
        ]

        func compute() -> ScoringResult {
            ScoringEngine.computeWithTeamScoring(
                scores: scores, participants: participants, teams: teams,
                segment: segment(), holes: holes, basis: .gross,
                template: FormatTemplateRegistry.strokePlay,
                teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
                matchupResolutionStyle: .roundAggregate
            )
        }

        let original = try row("red", in: compute())
        XCTAssertEqual(original.total, -1)
        XCTAssertEqual(Set(original.countingParticipantIDs), Set(["p1", "p2"]))

        scores[0] = score("p1", hole: 1, strokes: nil)
        let cleared = try row("red", in: compute())
        XCTAssertEqual(cleared.total, 0)
        XCTAssertEqual(cleared.holesPlayed, 2)
        XCTAssertEqual(cleared.holeValues[1]?.points, 0)
        XCTAssertEqual(cleared.countingParticipantIDs, ["p2"])
    }

    func testNonpositiveGrossStrokesDoNotEarnPointsOrCompleteHoles() throws {
        for invalidStrokes in [0, -1] {
            let scores = [
                score("p1", hole: 1, strokes: invalidStrokes),
                score("p1", hole: 2, strokes: 5),
            ]
            for result in [strokePlay(scores), stableford(scores)] {
                let player = try row("p1", in: result)
                XCTAssertEqual(player.total, 1, "Invalid gross strokes must not improve the player's result")
                XCTAssertEqual(player.holesPlayed, 1)
                XCTAssertNil(player.holeValues[1])
                XCTAssertEqual(result.holeStates[1], .unscored)
                XCTAssertEqual(result.holeStates[2], .complete)
            }
        }
    }

    func testZeroRelativeToParIsRecordedWhileEmptyRelativeEntryIsUnscored() throws {
        var parScore = score("p1", hole: 1, strokes: nil)
        parScore.entryMode = .relativeToPar
        parScore.relativeToPar = 0
        var emptyScore = score("p1", hole: 2, strokes: nil)
        emptyScore.entryMode = .relativeToPar
        let scores = [parScore, emptyScore]

        for (result, expectedTotal) in [(strokePlay(scores), 0.0), (stableford(scores), 2.0)] {
            let player = try row("p1", in: result)
            XCTAssertEqual(player.total, expectedTotal)
            XCTAssertEqual(player.holesPlayed, 1)
            XCTAssertEqual(player.holeValues[1]?.rawStrokes, 4)
            XCTAssertNil(player.holeValues[2])
            XCTAssertEqual(result.holeStates[1], .complete)
            XCTAssertEqual(result.holeStates[2], .unscored)
        }
    }

    private var holes: [Hole] {
        [Hole(number: 1, par: 4, yardage: 350, handicap: 1),
         Hole(number: 2, par: 4, yardage: 350, handicap: 2)]
    }

    private func participant(_ id: String, teamID: String? = nil) -> RoundParticipant {
        RoundParticipant(id: id, name: Name(id, "Test"), adjustedHandicap: 0, teamID: teamID)
    }

    private func segment(start: Int = 1, end: Int = 2) -> RoundSegment {
        RoundSegment(id: "current", roundID: "round", holeRange: HoleRange(startHole: start, endHole: end))
    }

    private func score(_ id: String, hole: Int, strokes: Int?, segmentID: String = "current") -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: hole, segment: segmentID, scoringUnit: id),
            holeNumber: hole, segmentID: segmentID, scoringUnitID: id,
            participantIDs: [id], strokes: strokes, entryID: id, parentID: "round"
        )
    }

    private func strokePlay(_ scores: [ScoreEntry], participants: [RoundParticipant]? = nil) -> ScoringResult {
        ScoringEngine.computeStrokePlay(
            scores: scores, participants: participants ?? [participant("p1")],
            segment: segment(), holes: holes, basis: .gross, template: FormatTemplateRegistry.strokePlay
        )
    }

    private func stableford(_ scores: [ScoreEntry]) -> ScoringResult {
        ScoringEngine.computeWithPipeline(
            scores: scores, participants: [participant("p1")], teams: [],
            segment: segment(), holes: holes, basis: .gross, template: FormatTemplateRegistry.stableford
        )
    }

    private func row(_ id: String, in result: ScoringResult, file: StaticString = #filePath, line: UInt = #line) throws -> ScoringRow {
        try XCTUnwrap(result.rows.first { $0.scoringUnitID == id }, "Missing scoring row for \(id)", file: file, line: line)
    }
}
