import XCTest
@testable import Hackers

final class RoundParticipantHandicapOverrideTests: XCTestCase {
    func testComputedBaselinePrefersLeagueSeedAndFallsBackToSnapshot() {
        var participant = participant(baseline: 12, adjusted: 12)
        participant.handicapSnapshot = snapshot(effectiveStrokes: 14)
        XCTAssertEqual(participant.leagueHandicapComputedBaseline, 12)

        participant.leagueHandicapStrokesAtCreation = nil
        XCTAssertEqual(participant.leagueHandicapComputedBaseline, 14)
    }

    func testRoundOverrideBecomesLockedScoringAllowance() {
        let original = participant(baseline: 12, adjusted: 12)
        var participant = original.applyingLeagueHandicapOverride(9, maximum: 18)
        participant.handicapSnapshot = snapshot(effectiveStrokes: 12)

        XCTAssertTrue(participant.isLeagueHandicapModifiedFromCreation)
        XCTAssertEqual(participant.lockedHandicapAllowance, 9)
        XCTAssertEqual(participant.originalHandicap, original.originalHandicap)
        XCTAssertEqual(participant.handicapIndex, 8.4)
        XCTAssertEqual(participant.handicapSnapshot?.effectiveStrokes, 12)
    }

    func testRestoringBaselineRemovesRoundOverride() {
        let participant = participant(baseline: 12, adjusted: 9)
            .restoringLeagueHandicapComputedBaseline()

        XCTAssertFalse(participant?.isLeagueHandicapModifiedFromCreation ?? true)
        XCTAssertEqual(participant?.lockedHandicapAllowance, 12)
    }

    func testRoundOverrideClampsWithoutChangingLeagueInputs() {
        var original = participant(baseline: 12, adjusted: 12)
        original.handicapSnapshot = snapshot(effectiveStrokes: 12)

        let aboveMaximum = original.applyingLeagueHandicapOverride(30, maximum: 18)
        let belowMinimum = original.applyingLeagueHandicapOverride(-2, maximum: 18)

        XCTAssertEqual(aboveMaximum.adjustedHandicap, 18)
        XCTAssertEqual(belowMinimum.adjustedHandicap, 0)
        XCTAssertEqual(aboveMaximum.originalHandicap, original.originalHandicap)
        XCTAssertEqual(aboveMaximum.handicapIndex, original.handicapIndex)
        XCTAssertEqual(aboveMaximum.leagueHandicapStrokesAtCreation, original.leagueHandicapStrokesAtCreation)
        XCTAssertEqual(aboveMaximum.handicapSnapshot, original.handicapSnapshot)
    }

    private func participant(baseline: Int, adjusted: Int) -> RoundParticipant {
        RoundParticipant(
            id: "participant",
            originalHandicap: 8,
            adjustedHandicap: adjusted,
            handicapIndex: 8.4,
            leagueHandicapStrokesAtCreation: baseline,
            parentID: "round"
        )
    }

    private func snapshot(effectiveStrokes: Int) -> RoundParticipantHandicapSnapshot {
        RoundParticipantHandicapSnapshot(
            authoritativeCourseHandicap: effectiveStrokes,
            handicapIndex: 8.4,
            effectiveStrokes: effectiveStrokes,
            courseID: "course",
            courseName: "Course",
            teeBoxID: "tee",
            teeName: "White",
            teeGender: "male",
            holeSegment: .front9,
            courseRating: 35,
            courseSlope: 113,
            par: 36,
            handicapStrokeBasis: .nineHole,
            maximumHandicap: 36,
            entryFormat: .courseHandicap,
            calculatorFingerprint: "test",
            selectedHandicapScoreIDs: [],
            calculatedAt: .init(),
            source: .league
        )
    }
}
