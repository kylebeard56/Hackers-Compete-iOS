import XCTest
@testable import Hackers

final class SeriesHandicapIndexLimitTests: XCTestCase {
    func testAndrewsTripIndex17ReceivesAll23StrokesWithMaximumIndex21() throws {
        let resolution = resolve(17)
        XCTAssertEqual(resolution.calculation.courseHandicap, 23)
        XCTAssertEqual(resolution.effectiveStrokes, 23)
        XCTAssertEqual(resolution.calculation.calculationIndex, 17)
        let snapshot = try XCTUnwrap(resolution.snapshot())
        XCTAssertEqual(snapshot.authoritativeCourseHandicap, 23)
        XCTAssertEqual(snapshot.effectiveStrokes, 23)
        XCTAssertEqual(snapshot.maximumHandicap, 21)
        let strokes = (1...18).map {
            ScoringEngine.strokesReceived(handicap: snapshot.effectiveStrokes, holeNumber: $0,
                holes: tee().holes, playedHoleNumbers: Array(1...18), useHandicaps: true,
                handicapStrokeBasis: .eighteenHole)
        }
        XCTAssertEqual(strokes.reduce(0, +), 23)
        XCTAssertEqual(strokes.filter { $0 == 2 }.count, 5)
        XCTAssertEqual(72 - strokes.reduce(0, +), 49)
    }

    func testIndexAboveMaximumIsLimitedBeforeTeeConversionWithoutErasingEnteredIndex() throws {
        let resolution = resolve(30)
        XCTAssertEqual(resolution.handicapIndex, 30)
        XCTAssertEqual(resolution.calculation.handicapIndex, 30)
        XCTAssertEqual(resolution.calculation.maximumIndex, 21)
        XCTAssertEqual(resolution.calculation.calculationIndex, 21)
        XCTAssertEqual(resolution.calculation.courseHandicap, 28)
        XCTAssertEqual(resolution.effectiveStrokes, 28)
        let saved = try JSONDecoder().decode(CourseHandicapCalculation.self,
            from: JSONEncoder().encode(resolution.calculation))
        XCTAssertEqual(saved, resolution.calculation)
    }

    func testMaximumIsAppliedToEighteenHoleIndexBeforeNineHoleConversion() {
        for segment in [HoleSegment.front9, .back9] {
            let resolution = resolve(30, segment: segment)
            XCTAssertEqual(resolution.calculation.maximumIndex, 21)
            XCTAssertEqual(resolution.calculation.calculationIndex, 10.5)
            XCTAssertEqual(resolution.calculation.courseHandicap, 14)
            XCTAssertEqual(resolution.effectiveStrokes, 14)
        }
    }

    func testPlusIndexIsNotTurnedIntoScratchByIndexMaximum() {
        XCTAssertEqual(resolve(-4).effectiveStrokes, -4)
    }

    func testExplicitRoundStrokesAreSeparateFromSeriesIndexMaximum() {
        let member = SeriesMember(id: "m", name: Name("Offline", "Player"), parentID: "series")
        let course = CourseSegment(courseInfo: .init(id: "course", name: "Tobacco Road", totalHoles: 18, tees: [tee()]),
            holeRange: HoleSegment.full18.holeRange, defaultTee: "ripper")
        let result = SeriesCourseHandicapResolver.resolve(effectiveIndex: nil, member: member,
            courseSegment: course, entryFormat: .courseHandicap, handicapStrokeBasis: .eighteenHole,
            maximumHandicap: 21, roundInput: .init(method: .strokes, value: 30, teeBoxID: "ripper"))
        XCTAssertEqual(result.effectiveStrokes, 30)
        XCTAssertNil(result.handicapIndex)
    }

    func testExistingFrozenLeagueAllowanceIsNotRecalculatedDuringLiveSync() throws {
        var snapshot = try XCTUnwrap(resolve(17).snapshot())
        snapshot.effectiveStrokes = 21
        snapshot.calculation?.maximumIndex = nil
        snapshot.calculatorFingerprint = "series-course-hcp-v2"
        let member = SeriesMember(id: "m", playerID: "p", name: Name("Saved", "Player"), parentID: "series")
        let original = RoundParticipant(id: "p", name: member.name, teeBoxID: "ripper",
            originalHandicap: 17, adjustedHandicap: 21, handicapIndex: 17,
            leagueHandicapStrokesAtCreation: 21, handicapSnapshot: snapshot,
            seriesMemberID: "m", parentID: "round")
        let course = CourseSegment(courseInfo: .init(id: "course", name: "Tobacco Road", totalHoles: 18, tees: [tee()]),
            holeRange: HoleSegment.full18.holeRange, defaultTee: "ripper")
        let updated = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(participants: [original],
            roundID: "round", participatingMembers: [member], teamLinks: [:], memberAssignments: [:],
            handicaps: ["m": .init(memberID: "m", computedIndex: 17)], courseSegment: course,
            handicapEntryFormat: .courseHandicap, handicapStrokeBasis: .eighteenHole,
            preserveFrozenRoundSetup: true, hostPlayerID: nil, preserveManualHandicapEdits: false)
        XCTAssertEqual(updated.first?.handicapSnapshot, original.handicapSnapshot)
        XCTAssertEqual(updated.first?.adjustedHandicap, 21)
        XCTAssertEqual(updated.first?.lockedHandicapAllowance, 21)
        let restored = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.handicapSnapshot, snapshot)
        XCTAssertNil(restored.handicapSnapshot?.calculation?.maximumIndex)
    }

    func testCommissionerCanRetain23StrokesAboveTheIndexMaximumWithoutChangingSnapshot() throws {
        let snapshot = try XCTUnwrap(resolve(17).snapshot())
        let original = RoundParticipant(id: "p", name: Name("Player"), originalHandicap: 17,
            adjustedHandicap: 23, handicapIndex: 17, leagueHandicapStrokesAtCreation: 23,
            handicapSnapshot: snapshot)
        let edited = original.applyingLeagueHandicapOverride(25, maximum: nil)
        XCTAssertEqual(edited.adjustedHandicap, 25)
        XCTAssertEqual(edited.handicapSnapshot, snapshot)
        XCTAssertEqual(edited.restoringLeagueHandicapComputedBaseline()?.lockedHandicapAllowance, 23)
    }

    private func resolve(_ index: Double, segment: HoleSegment = .full18) -> SeriesCourseHandicapResolution {
        SeriesCourseHandicapResolver.resolve(effectiveIndex: index, memberID: "m", memberName: "Player",
            requestedTeeID: "ripper", tee: tee(), courseID: "course", courseName: "Tobacco Road",
            holeSegment: segment, entryFormat: .courseHandicap, handicapStrokeBasis: .eighteenHole,
            maximumHandicap: 21)
    }

    private func tee() -> Tee {
        Tee(id: "ripper", name: "Ripper", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: $0 == 18 ? 3 : 4, yardage: 350, handicap: $0) },
            ratingFull: 72.5, slopeFull: 145, ratingFront: 36.5, slopeFront: 145,
            ratingBack: 36, slopeBack: 145)
    }
}
