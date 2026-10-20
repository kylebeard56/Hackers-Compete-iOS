import XCTest
@testable import Hackers

final class RoundHandicapRegressionTests: XCTestCase {
    private func course(_ segment: HoleSegment = .full18) -> CourseSegment {
        let tee = Tee(id: "white", name: "White", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113,
            ratingBack: 36, slopeBack: 113)
        return CourseSegment(courseInfo: .init(id: "course", name: "Course", totalHoles: 18, tees: [tee]),
            holeRange: segment.holeRange, defaultTee: tee.id)
    }

    func testMixedEntryRosterRecalculatesCourseAndHoleChangesUnderStrokesDefault() {
        let indexPlayer = HandicapCalculator.participant(.init(id: "index", teeBoxID: "white"),
            applying: 18, format: .courseHandicap, courseSegment: course(), handicapStrokeBasis: .eighteenHole)
        let manualPlayer = HandicapCalculator.participant(.init(id: "manual", teeBoxID: "white"),
            applying: 12, format: .strokes, courseSegment: course())
        var roster = [indexPlayer, manualPlayer]
        for segment in [HoleSegment.front9, .back9, .full18] {
            roster = HandicapCalculator.recomputedParticipants(roster, format: .strokes,
                courseSegment: course(segment), handicapStrokeBasis: .eighteenHole)
            XCTAssertEqual(roster[0].adjustedHandicap, segment == .full18 ? 18 : 9)
            XCTAssertEqual(roster[0].handicapIndex, 18)
            XCTAssertTrue(HandicapCalculator.isReady(roster[0], format: .strokes,
                courseSegment: course(segment), indexBasis: .eighteenHole))
            XCTAssertEqual(roster[1], manualPlayer)
        }
    }

    func testMixedEntryDefaultTeeChangeRecalculatesIndexPlayer() {
        // An empty player tee uses the round's default tee.
        let player = HandicapCalculator.participant(.init(id: "index"),
            applying: 18, format: .courseHandicap, courseSegment: course())
        var changedCourse = course()
        let harderTee = Tee(id: "blue", name: "Blue", gender: "male", totalHoles: 18,
            holes: changedCourse.courseInfo.tees[0].holes, ratingFull: 75, slopeFull: 113,
            ratingFront: nil, slopeFront: nil, ratingBack: nil, slopeBack: nil)
        changedCourse.courseInfo.tees.append(harderTee)
        changedCourse.defaultTee = harderTee.id
        let updated = HandicapCalculator.recomputedParticipants([player], format: .strokes,
            courseSegment: changedCourse, handicapStrokeBasis: .eighteenHole)[0]
        XCTAssertEqual(updated.adjustedHandicap, 21)
        XCTAssertTrue(HandicapCalculator.isReady(updated, format: .strokes,
            courseSegment: changedCourse, indexBasis: .eighteenHole))
    }

    func testRemovingCourseInvalidatesIndexButKeepsManualAllowance() {
        let index = HandicapCalculator.participant(.init(id: "index", teeBoxID: "white"),
            applying: 18, format: .courseHandicap, courseSegment: course())
        let manual = HandicapCalculator.participant(.init(id: "manual"),
            applying: 8, format: .strokes, courseSegment: course())
        let updated = HandicapCalculator.recomputedParticipants([index, manual], format: .strokes,
            courseSegment: nil, handicapStrokeBasis: .eighteenHole)
        XCTAssertNil(updated[0].handicapResolution?.effectiveStrokes)
        XCTAssertFalse(HandicapCalculator.isReady(updated[0], format: .strokes,
            courseSegment: nil, indexBasis: .eighteenHole))
        XCTAssertEqual(updated[1], manual)
    }

    func testGrossOverrideAllowsMissingHandicapsAndNetOverrideStillRequiresThem() {
        for mode in SeriesHandicapMode.allCases {
            var settings = SeriesSettings(experiencePreset: .trip, useTeams: false)
            settings.handicapConfig = .init(mode: mode, strokeBasis: .eighteenHole, entryFormat: .courseHandicap)
            let series = Series(id: "series", name: "Trip", commissionerUserID: "owner", settings: settings)
            let member = SeriesMember(id: "member", playerID: "player", name: Name("Player"), parentID: series.id)
            for entryFormat in [HandicapEntryFormat.courseHandicap, .strokes] {
                var round = SeriesRound(id: "round",
                    roundConfig: .init(scoreBasisOverride: .gross, handicapEntryFormat: entryFormat), parentID: series.id)
                XCTAssertFalse(SeriesRoundHandicapSetup.requiresHandicaps(series: series, round: round))
                XCTAssertTrue(SeriesRoundHandicapSetup.issues(series: series, round: round,
                    members: [member], handicaps: [:], course: course()).isEmpty)
                round.roundConfig.scoreBasisOverride = .net
                XCTAssertTrue(SeriesRoundHandicapSetup.requiresHandicaps(series: series, round: round))
                XCTAssertFalse(SeriesRoundHandicapSetup.issues(series: series, round: round,
                    members: [member], handicaps: [:], course: course()).isEmpty)
            }
        }
    }

    func testGrossRoundDoesNotRequireOptionalIndexToResolve() {
        let series = Series(id: "series", name: "Trip", commissionerUserID: "owner")
        let member = SeriesMember(id: "member", playerID: "player", name: Name("Player"), parentID: series.id)
        var round = SeriesRound(id: "round", roundConfig: .init(scoreBasisOverride: .gross), parentID: series.id)
        round.handicapInputs[member.id] = .init(method: .personalIndex, value: 18, teeBoxID: "missing-tee")
        XCTAssertTrue(SeriesRoundHandicapSetup.issues(series: series, round: round,
            members: [member], handicaps: [:], course: course()).isEmpty)
        round.roundConfig.scoreBasisOverride = .net
        XCTAssertFalse(SeriesRoundHandicapSetup.issues(series: series, round: round,
            members: [member], handicaps: [:], course: course()).isEmpty)
    }

    func testLiveAndPausedSyncRejectsReinterpretingFrozenNineHoleAllowance() throws {
        let series = Series(id: "series", name: "Trip", commissionerUserID: "owner")
        var round = SeriesRound(id: "round", parentID: series.id)
        round.roundConfig.handicapEntryFormat = .strokes
        round.roundConfig.handicapStrokeBasis = .eighteenHole
        let oldConfiguration = SeriesRoundCreationMapping.roundConfiguration(series: series, seriesRound: round,
            courseSegment: course(.front9), competitionScope: SeriesRoundCreationMapping.resolvedCompetitionScope(for: round))
        let member = SeriesMember(id: "member", playerID: "player", name: Name("Player"), parentID: series.id)
        let participants = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: [member], roundID: round.id, teamMappings: [:], memberAssignments: [:],
            handicaps: [member.id: .init(memberID: member.id, computedIndex: 18)],
            courseSegment: course(.front9), handicapEntryFormat: .strokes,
            handicapStrokeBasis: .eighteenHole, hostPlayerID: nil)
        let player = try XCTUnwrap(participants.first)
        XCTAssertNotNil(player.handicapSnapshot)
        let snapshot = RoundSnapshot(round: .init(configuration: oldConfiguration), participants: participants)
        XCTAssertEqual(ScoringEngine.handicapStrokesForPlayedHoles(
            handicap: player.lockedHandicapAllowance, basis: snapshot.handicapStrokeBasis, holesInPlay: 9), 9)

        round.roundConfig.handicapEntryFormat = .courseHandicap
        let proposed = SeriesRoundCreationMapping.roundConfiguration(series: series, seriesRound: round,
            courseSegment: course(.front9), competitionScope: SeriesRoundCreationMapping.resolvedCompetitionScope(for: round))
        XCTAssertEqual(ScoringEngine.handicapStrokesForPlayedHoles(
            handicap: player.lockedHandicapAllowance,
            basis: proposed.resolvedHandicapStrokeBasis(holeCount: 9), holesInPlay: 9), 18)
        for status in [RoundStatus.live, .paused] {
            for options in [
                SeriesRoundSyncOptions(syncPlayerData: true),
                .init(syncFormat: true), .init(syncOrganization: true), .init(syncHandicapSettings: true)
            ] {
                XCTAssertNotNil(SeriesRoundSyncPlanning.validateFrozenHandicapBasis(
                    snapshot: snapshot, proposedConfiguration: proposed, options: options, roundStatus: status))
                XCTAssertNil(SeriesRoundSyncPlanning.validateFrozenHandicapBasis(
                    snapshot: snapshot, proposedConfiguration: oldConfiguration, options: options, roundStatus: status))
                XCTAssertNil(SeriesRoundSyncPlanning.validateFrozenHandicapBasis(
                    snapshot: snapshot, proposedConfiguration: proposed, options: options, roundStatus: .lobby))
            }
        }
        XCTAssertNil(SeriesRoundSyncPlanning.validateFrozenHandicapBasis(
            snapshot: snapshot, proposedConfiguration: proposed, options: .init(syncMatchups: true), roundStatus: .live))
        var unfrozen = snapshot
        unfrozen.participants = [.init(id: "new-player")]
        XCTAssertNil(SeriesRoundSyncPlanning.validateFrozenHandicapBasis(
            snapshot: unfrozen, proposedConfiguration: proposed, options: .init(syncHandicapSettings: true), roundStatus: .live))
    }
}
