import XCTest
@testable import Hackers

final class PersonalHandicapCalculationTests: XCTestCase {
    private func snapshot(id: String = "r1", format: String = "stroke_play", holes: Int = 18) -> RoundSnapshot {
        let tee = Tee(id: "tee", name: "White", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        let course = CourseSegment(courseInfo: .init(id: "course", name: "Course", totalHoles: 18, tees: [tee]),
                                   holeRange: .init(startHole: 1, endHole: holes), defaultTee: "tee")
        let time = Time(for: Date(timeIntervalSince1970: 1_700_000_000))
        let round = Round(id: id, status: .complete, players: ["p1"], firstScoredAt: time,
                          configuration: .init(formatSummary: .init(templateID: format), courses: [course]),
                          createdAt: time, lastUpdatedAt: time)
        let participant = RoundParticipant(id: "participant", playerID: "p1", teeBoxID: "tee")
        let segment = RoundSegment(id: "segment", roundID: id, holeRange: course.holeRange, templateID: format,
                                  scoringUnits: [.init(id: "participant", owner: .participant, ownerIDs: ["participant"])])
        let scores = (1...holes).map { ScoreEntry(id: "h\($0)", holeNumber: $0, segmentID: "segment",
            scoringUnitID: "participant", participantIDs: ["participant"], strokes: 5, parentID: id) }
        return .init(round: round, participants: [participant], segments: [segment], scoring: scores)
    }

    private func review(_ snapshot: RoundSnapshot, purpose: PersonalHandicapRoundPurpose = .acceptable) -> PersonalHandicapRoundReview {
        PersonalHandicapEligibility.review(snapshot, playerID: "p1", purpose: purpose)
    }

    private func pool(_ values: [Double], holes: Int = 18, starting: Int = 0) -> ([PersonalHandicapRoundReview], [PersonalHandicapVerifiedDifferential]) {
        var reviews: [PersonalHandicapRoundReview] = []
        var inputs: [PersonalHandicapVerifiedDifferential] = []
        for (offset, value) in values.enumerated() {
            let n = offset + starting
            var r = review(snapshot(id: "r\(n)", holes: holes))
            r.score = .init(playerID: "p1", roundID: "r\(n)", roundTitle: "Round \(n)",
                playedAt: .init(for: Date(timeIntervalSince1970: 1_700_000_000 + Double(n) * 86400)),
                holeCount: holes, grossScore: 90, exclusionReason: nil)
            reviews.append(r)
            inputs.append(.init(playerID: "p1", roundID: "r\(n)", revision: r.revision, unroundedValue: value,
                                indexInEffect: nil, postingID: "posting\(n)"))
        }
        return (reviews, inputs)
    }

    private func rebuild(_ values: [Double], holes: Int = 18) -> PersonalHandicapRebuild {
        let (reviews, inputs) = pool(values, holes: holes)
        return PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, verified: inputs)
    }

    func testCaptainsChoiceAndStoredAliasesNeverQualifyEvenWithFakeIndividualCards() {
        for id in ["captains_choice", "scramble", "Captain’s Choice", "CAPTAIN'S CHOICE", "two man scramble", "two-man scramble", "2 man scramble", "2-man scramble", "four_man_scramble"] {
            let r = review(snapshot(format: id))
            XCTAssertEqual(r.qualifyingHoles, 0, id)
            XCTAssertTrue(r.score.exclusionReason?.contains("Scramble") == true, id)
            let rebuilt = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [r])
            XCTAssertEqual(rebuilt.calculation.qualifyingHoles, 0)
            XCTAssertTrue(rebuilt.calculation.poolScoreIDs.isEmpty)
            XCTAssertTrue(rebuilt.history.isEmpty)
        }
    }

    func testSegmentIDDetectsScrambleDespiteDifferentRoundSummaryAndDisplayName() {
        var s = snapshot()
        s.round.name = "Stroke Play Championship"
        s.segments[0].templateID = "captains_choice"
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        s = snapshot()
        s.round.name = "Captain's Choice" // display name alone does not classify the actual game
        XCTAssertEqual(review(s).qualifyingHoles, 18)
    }

    func testScrambleRemainsVisibleInPersonalReviewAndDoesNotAlterOriginalHistoryOrStatisticsInput() {
        let s = snapshot(format: "captains_choice")
        let originalScores = s.scoring
        let rebuilt = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(s)])
        XCTAssertEqual(rebuilt.scores.map(\.roundID), [s.round.id])
        XCTAssertNotNil(rebuilt.scores[0].exclusionReason)
        XCTAssertEqual(s.scoring, originalScores)
        XCTAssertEqual(s.round.status, .complete)
        XCTAssertEqual(s.round.players, ["p1"])
    }

    func testIndividualStrokePlayMatchPlayAndBestBallCardsQualifyRegardlessOfTeamMembership() {
        for format in ["stroke_play", "stroke_play_gross", "match_play_individual", "best_ball", "best_ball_matchup", "better ball", "four_ball", "stableford"] {
            var s = snapshot(format: format)
            s.participants[0].teamID = "team1"
            XCTAssertEqual(review(s).qualifyingHoles, 18, format)
            XCTAssertNil(review(s).score.exclusionReason, format)
        }
    }

    func testLeagueIndividualScoreQualifiesAndLeagueAllowancesAreUnchanged() {
        var s = snapshot()
        s.participants[0].seriesMemberID = "member"
        s.participants[0].leagueHandicapStrokesAtCreation = 5
        s.participants[0].adjustedHandicap = 8
        let frozen = s.participants[0]
        XCTAssertEqual(review(s).qualifyingHoles, 18)
        XCTAssertEqual(s.participants[0], frozen)
    }

    func testTeamOnlyAlternateShotShambleAndUnknownFormatsDoNotCount() {
        for format in ["alternate_shot", "shamble", "two_man_shamble", "vegas", "invented_format"] {
            XCTAssertEqual(review(snapshot(format: format)).qualifyingHoles, 0, format)
        }
        var s = snapshot(format: "best_ball")
        for i in s.scoring.indices { s.scoring[i].participantIDs = ["participant", "partner"] }
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        s = snapshot(); s.round.configuration.scoreOwnerScope = .partnership
        XCTAssertEqual(review(s).qualifyingHoles, 0)
    }

    func testPracticeUnofficialAndUnverifiedAcceptabilityCannotQualify() {
        let s = snapshot()
        for purpose in [PersonalHandicapRoundPurpose.practice, .unofficial, .unverified] {
            XCTAssertEqual(review(s, purpose: purpose).qualifyingHoles, 0)
        }
        XCTAssertNotNil(PersonalHandicapEligibility.review(s, playerID: "p1").score.pendingReason)
    }

    func testIncompleteLiveDuplicateAndPickedUpCardsAreNotSilentlyFilled() {
        var s = snapshot(); s.scoring.removeLast()
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        XCTAssertNotNil(review(s).score.pendingReason) // 17 holes may be valid only after official partial-round review
        s = snapshot(); s.round.status = .live
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        s = snapshot(); s.scoring.append(s.scoring[0])
        XCTAssertTrue(review(s).score.exclusionReason?.contains("Duplicate") == true)
        s = snapshot(); s.scoring[0].pickedUp = true
        XCTAssertEqual(review(s).qualifyingHoles, 0)
    }

    func testLegacyMissingCourseOrPlayDateRemainsPending() {
        var s = snapshot(); s.round.firstScoredAt = nil
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        XCTAssertEqual(review(s).score.pendingReason, "Actual play date is not recorded")
        s = snapshot(); s.round.configuration.courses[0].holeRange = .init()
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        XCTAssertNotNil(review(s).score.pendingReason)
    }

    func testNineHoleMetadataMustBeExactAndNeverEstimatedFromEighteen() {
        XCTAssertEqual(review(snapshot(holes: 9)).qualifyingHoles, 9)
        var s = snapshot(holes: 9)
        let tee = s.configuration.courses[0].courseInfo.tees[0]
        s.round.configuration.courses[0].courseInfo.tees = [.init(id: tee.id, name: tee.name, gender: tee.gender,
            totalHoles: 18, holes: tee.holes, ratingFull: 72, slopeFull: 113,
            ratingFront: nil, slopeFront: nil, ratingBack: nil, slopeBack: nil)]
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        XCTAssertNotNil(review(s).score.pendingReason)
    }

    func testIdentityAndConflictingGrossDataFailClosed() {
        var s = snapshot(); s.participants.append(s.participants[0])
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        s = snapshot(); s.scoring[0].relativeToPar = 0
        XCTAssertEqual(review(s).qualifyingHoles, 0)
        XCTAssertEqual(PersonalHandicapEligibility.review(snapshot(), playerID: "other").qualifyingHoles, 0)
    }

    func testFiftyFourActualHolesRequiredIncludingNineHoleScores() {
        XCTAssertNil(rebuild([12, 15]).calculation.qualifiedIndex)
        XCTAssertEqual(rebuild([12, 15, 17]).calculation.qualifiedIndex, 10)
        XCTAssertNil(rebuild([12, 15, 17, 18, 19], holes: 9).calculation.qualifiedIndex)
        let sixNines = rebuild([12, 15, 17, 18, 19, 20], holes: 9)
        XCTAssertEqual(sixNines.calculation.qualifyingHoles, 54)
        XCTAssertEqual(sixNines.calculation.qualifiedIndex, 12.5) // 6 scores: average lowest 2 minus 1
    }

    func testMixedNinesAndEighteensRequireFiftyFourActualHoles() {
        let (eighteens, eighteenInputs) = pool([12, 15])
        let (nines, nineInputs) = pool([17, 19], holes: 9, starting: 2)
        let before = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: eighteens + [nines[0]], verified: eighteenInputs + [nineInputs[0]])
        XCTAssertEqual(before.calculation.qualifyingHoles, 45)
        XCTAssertNil(before.calculation.qualifiedIndex)
        let after = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: eighteens + nines, verified: eighteenInputs + nineInputs)
        XCTAssertEqual(after.calculation.qualifyingHoles, 54)
        XCTAssertEqual(after.calculation.qualifiedIndex, 11)
    }

    func testProviderResponsesForAnotherPlayerCannotEstablishAnIndex() {
        let (r, d) = pool([12, 15, 17])
        let other = d.map { PersonalHandicapVerifiedDifferential(playerID: "other", roundID: $0.roundID,
            revision: $0.revision, unroundedValue: $0.unroundedValue, indexInEffect: nil, postingID: $0.postingID) }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: other)
        XCTAssertEqual(result.calculation.status, .blocked)
        XCTAssertNil(result.calculation.qualifiedIndex)
        XCTAssertTrue(result.history.isEmpty)
    }

    func testScrambleCannotFinishQualificationOrEnterPoolOrTrend() {
        var (r, d) = pool([12, 15])
        let scramble = review(snapshot(id: "scramble", format: "captains_choice"))
        r.append(scramble)
        d.append(.init(playerID: "p1", roundID: "scramble", revision: scramble.revision, unroundedValue: 1, indexInEffect: nil, postingID: "scramble"))
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: d)
        XCTAssertEqual(result.calculation.qualifyingHoles, 36)
        XCTAssertNil(result.calculation.qualifiedIndex)
        XCTAssertFalse(result.calculation.poolScoreIDs.contains("scramble"))
        XCTAssertTrue(result.history.isEmpty)
    }

    func testManualTransitionRetainsSourceAndFrozenHistoricalParticipants() throws {
        let manual = try ManualPersonalHandicap(value: 22.6, source: .external)
        var profile = PersonalHandicapProfile(manual: manual, calculation: rebuild([12, 15]).calculation)
        XCTAssertEqual(profile.effectiveIndex, 22.6)
        var player = Player(id: "p1", userID: "u1", name: .init("Test", "Player"))
        player.personalHandicap = profile
        let config = snapshot().configuration
        let frozen = PersonalHandicapRoundPrefill.participant(snapshot().participants[0], player: player,
            configuration: .init(courses: config.courses, handicapIndexBasis: .eighteenHole, handicapEntryFormat: .courseHandicap), isLeagueRound: false)
        profile.calculation = rebuild([12, 15, 17]).calculation
        XCTAssertEqual(profile.effectiveIndex, 10)
        XCTAssertEqual(profile.effectiveSource, .calculated)
        XCTAssertEqual(profile.manual, manual)
        XCTAssertEqual(frozen.handicapIndex, 22.6)
        player.personalHandicap = profile
        let league = PersonalHandicapRoundPrefill.participant(snapshot().participants[0], player: player,
            configuration: config, isLeagueRound: true)
        XCTAssertNil(league.personalHandicapInput)
    }

    func testMissingOfficialInputsNeverBecomeZeroOrSelectiveScoreOmission() {
        let (r, d) = pool([12, 15, 17])
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: Array(d.dropLast()))
        XCTAssertEqual(result.calculation.status, .blocked)
        XCTAssertNil(result.calculation.qualifiedIndex)
        XCTAssertTrue(result.calculation.poolScoreIDs.isEmpty)
        XCTAssertNotNil(result.scores.last?.pendingReason)
    }

    func testDuplicatePostingAndDuplicateRoundRevisionsCannotInflateQualification() {
        let (r, d) = pool([12, 15, 17])
        let twice = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r + r, verified: d)
        XCTAssertEqual(twice.calculation.qualifyingHoles, 54)
        let duplicate = PersonalHandicapVerifiedDifferential(playerID: "p1", roundID: "r2", revision: r[2].revision,
            unroundedValue: 17, indexInEffect: nil, postingID: "posting0")
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: Array(d.prefix(2)) + [duplicate])
        XCTAssertEqual(result.calculation.qualifyingHoles, 36)
        XCTAssertNil(result.calculation.qualifiedIndex)
        XCTAssertEqual(result.scores.last?.exclusionReason, "Duplicate handicap posting")
    }

    func testCorrectionsRebuildChronologicallyAndInvalidateOldProviderResponses() {
        var (r, d) = pool([12, 15, 17])
        let original = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r.reversed(), verified: d)
        XCTAssertEqual(original.history.map(\.roundID), ["r2"])
        r[0].revision += 1
        let stale = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: d)
        XCTAssertNil(stale.calculation.qualifiedIndex)
        d[0] = .init(playerID: "p1", roundID: "r0", revision: r[0].revision, unroundedValue: 8, indexInEffect: nil, postingID: "posting0")
        XCTAssertEqual(PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: d).calculation.qualifiedIndex, 6)
        var excluded = review(snapshot(id: "r0", format: "scramble")); excluded.revision = r[0].revision + 1
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r + [excluded], verified: d)
        XCTAssertEqual(result.calculation.qualifyingHoles, 36)
        XCTAssertNil(result.calculation.qualifiedIndex)
    }

    func testFullTableBestEightLatestTwentyAndMaximumIndex() {
        let expected = [3:1,4:1,5:1,6:2,7:2,8:2,9:3,10:3,11:3,12:4,13:4,14:4,15:5,16:5,17:6,18:6,19:7,20:8]
        for (count, selected) in expected { XCTAssertEqual(PersonalHandicapRules.selection(count: count)?.count, selected) }
        XCTAssertNil(PersonalHandicapRules.selection(count: 2))
        let result = rebuild([0] + Array(repeating: 20, count: 20))
        XCTAssertFalse(result.calculation.poolScoreIDs.contains("r0"))
        XCTAssertEqual(result.calculation.poolScoreIDs.count, 20)
        XCTAssertEqual(result.calculation.countingScoreIDs.count, 8)
        XCTAssertEqual(rebuild([90, 91, 92]).calculation.qualifiedIndex, 54)
    }

    func testDifferentialPCCAndOfficialNineExpectedScoreTreatment() throws {
        XCTAssertEqual(try PersonalHandicapRules.differential(adjustedGross: 90, rating: 72, slope: 113, holes: 18, pcc: 2), 16)
        XCTAssertThrowsError(try PersonalHandicapRules.differential(adjustedGross: 90, rating: 72, slope: 113, holes: 18, pcc: nil))
        XCTAssertThrowsError(try PersonalHandicapRules.differential(adjustedGross: 45, rating: 36, slope: 113, holes: 9, pcc: 0))
        XCTAssertEqual(try PersonalHandicapRules.differential(adjustedGross: 45, rating: 36, slope: 113, holes: 9, pcc: 2, expectedNineHoleDifferential: 8.3), 16.3, accuracy: 0.0001)
        XCTAssertThrowsError(try PersonalHandicapRules.differential(adjustedGross: 80, rating: 72, slope: 113, holes: 17, pcc: 0))
        XCTAssertEqual(PersonalHandicapRules.tenth(-1.55), -1.5)
        XCTAssertEqual(PersonalHandicapRules.tenth(-1.56), -1.6)
    }

    func testNetDoubleBogeyUsesUnrestrictedStrokesAndPlusHandicaps() {
        XCTAssertEqual(PersonalHandicapRules.maximumHoleScore(par: 4, establishedIndex: false, unrestrictedCourseHandicap: 0, strokes: 0), 9)
        XCTAssertEqual(PersonalHandicapRules.maximumHoleScore(par: 4, establishedIndex: true, unrestrictedCourseHandicap: 25, strokes: 2), 8)
        XCTAssertEqual(PersonalHandicapRules.maximumHoleScore(par: 4, establishedIndex: true, unrestrictedCourseHandicap: -2, strokes: -1), 5)
        XCTAssertEqual(PersonalHandicapRules.maximumHoleScore(par: 4, establishedIndex: true, unrestrictedCourseHandicap: 60, strokes: 4), 9)
    }

    func testExceptionalReductionUsesUnroundedDifferentialAndDilutes() {
        XCTAssertEqual(PersonalHandicapRules.exceptionalReduction(unroundedDifferential: 3.01, indexInEffect: 10), 0)
        XCTAssertEqual(PersonalHandicapRules.exceptionalReduction(unroundedDifferential: 3, indexInEffect: 10), -1)
        XCTAssertEqual(PersonalHandicapRules.exceptionalReduction(unroundedDifferential: 0, indexInEffect: 10), -2)
        var (r, d) = pool(Array(repeating: 20, count: 20) + [13])
        d[20] = .init(playerID: "p1", roundID: "r20", revision: r[20].revision, unroundedValue: 13, indexInEffect: 20, postingID: "posting20")
        let exceptional = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: d)
        XCTAssertEqual(exceptional.calculation.qualifiedIndex, 18.1)
        let (laterR, laterD) = pool(Array(repeating: 20, count: 20), starting: 21)
        r += laterR; d += laterD
        XCTAssertEqual(PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: d).calculation.qualifiedIndex, 20)
    }

    func testSoftHardCapsAndLowIndexStartAfterTwentyScores() {
        XCTAssertEqual(PersonalHandicapRules.capped(14, lowIndex: 10), 13.5)
        XCTAssertEqual(PersonalHandicapRules.capped(30, lowIndex: 10), 15)
        XCTAssertEqual(PersonalHandicapRules.capped(5, lowIndex: 10), 5)
        XCTAssertEqual(PersonalHandicapRules.capped(30, lowIndex: nil), 30)
        XCTAssertNil(rebuild(Array(repeating: 10, count: 19)).calculation.lowHandicapIndex)
        let result = rebuild(Array(repeating: 10, count: 20) + Array(repeating: 30, count: 20))
        XCTAssertEqual(result.calculation.lowHandicapIndex, 10)
        XCTAssertEqual(result.calculation.qualifiedIndex, 15)
    }

    func testProgressHistoryStatusAndLegacyCodableRemainCompatible() throws {
        let result = rebuild([12, 15, 17, 18])
        XCTAssertEqual(result.history.map(\.roundID), ["r2", "r3"])
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(result.scores[0], calculation: result.calculation), "Counts")
        var pending = result.scores[0]; pending.pendingReason = "Official inputs missing"
        XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(pending, calculation: result.calculation), "Pending")
        let data = try JSONEncoder().encode(result.calculation)
        XCTAssertEqual(try JSONDecoder().decode(PersonalHandicapCalculation.self, from: data), result.calculation)
        let legacy = try JSONEncoder().encode(result.scores[0])
        XCTAssertNil(try JSONDecoder().decode(PersonalHandicapScoreRecord.self, from: legacy).pendingReason)
    }
}
