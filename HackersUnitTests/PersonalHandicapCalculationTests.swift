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
            r.card = nil // These fixtures specifically exercise the verified-input boundary.
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
        XCTAssertEqual(PersonalHandicapEligibility.review(s, playerID: "p1").qualifyingHoles, 18)
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

    func testLegacyRecordedScoreDateIsUsedWhileInvalidCourseRemainsPending() {
        var s = snapshot(); s.round.firstScoredAt = nil
        XCTAssertEqual(review(s).qualifyingHoles, 18)
        XCTAssertEqual(review(s).score.playedAtSource, "earliest_recorded_score")
        XCTAssertEqual(review(s).score.playedAt, s.scoring.map(\.createdAt).min { $0.unix < $1.unix })
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

    func testMissingNormalizedDifferentialsCannotBeSilentlyOmittedFromThePool() {
        let (r, d) = pool([12, 15, 17])
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: r, verified: Array(d.dropLast()))
        XCTAssertEqual(result.calculation.status, .blocked)
        XCTAssertNil(result.calculation.qualifiedIndex)
        XCTAssertEqual(result.calculation.poolScoreIDs.count, 2)
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
        XCTAssertEqual(try PersonalHandicapRules.differential(adjustedGross: 90, rating: 72, slope: 113, holes: 18, pcc: nil), 18)
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
    private func actualReviews(_ count: Int, holes: Int = 18) -> [PersonalHandicapRoundReview] {
        (0..<count).map { n in
            var source = snapshot(id: "actual\(n)", holes: holes)
            source.round.firstScoredAt = .init(for: Date(timeIntervalSince1970: 1_700_000_000 + Double(n) * 86400))
            return PersonalHandicapEligibility.review(source, playerID: "p1")
        }
    }

    func testAvailableHackersCardsProduceAnIndexWithoutAnyProvider() {
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(3))
        XCTAssertEqual(result.calculation.qualifiedIndex, 16)
        XCTAssertEqual(result.calculation.qualifyingHoles, 54)
        XCTAssertEqual(result.history.count, 1)
        XCTAssertTrue(result.scores.allSatisfy { $0.differential == 18 && $0.adjustedGrossScore == 90 })
    }

    func testMissingPCCIsStoredAsExplicitAssumedZeroAndRoundTrips() throws {
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(1))
        let score = try XCTUnwrap(result.scores.first)
        XCTAssertEqual(score.pcc?.value, 0)
        XCTAssertEqual(score.pcc?.verification, .assumed)
        XCTAssertTrue(score.pcc?.source.contains("official PCC unavailable") == true)
        XCTAssertEqual(try JSONDecoder().decode(PersonalHandicapScoreRecord.self, from: JSONEncoder().encode(score)), score)
    }

    func testVerifiedPCCOverridesTheAssumptionWithoutChangingGross() {
        var source = snapshot()
        source.round.personalHandicapPCC = .init(value: 2, verification: .verified, source: "External course/day record")
        let original = source.scoring
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(result.scores.first?.pcc?.verification, .verified)
        XCTAssertEqual(result.scores.first?.differential, 16)
        XCTAssertEqual(result.scores.first?.grossScore, 90)
        XCTAssertEqual(source.scoring, original)
    }

    func testInvalidPCCProvenanceDoesNotMasqueradeAsVerifiedOrAssumedZero() {
        for pcc in [PersonalHandicapPCC(value: 1, verification: .assumed, source: "invented"),
                    .init(value: 0, verification: .verified, source: ""),
                    .init(value: 4, verification: .verified, source: "invalid")] {
            var source = snapshot(); source.round.personalHandicapPCC = pcc
            XCTAssertEqual(review(source).qualifyingHoles, 0)
            XCTAssertNotNil(review(source).score.pendingReason)
        }
    }

    func testStandardDifferentialUsesExactRatingAndSlope() throws {
        let card = PersonalHandicapCard(holes: (1...18).map { .init(number: $0, par: 4, strokeIndex: $0, gross: 5) },
            intendedHoles: 18, rating: 73.9, slope: 143, par: 72, pcc: .assumedZero, frozenPersonalIndex: nil, partialReason: nil, initialNine: nil)
        let result = try card.assessed(index: nil)
        XCTAssertEqual(result.differential!, 113.0 / 143 * (90 - 73.9), accuracy: 0.00001)
    }

    func testInitialParPlusFiveAndFrozenPersonalNetDoubleBogeyLeaveRawCardUnchanged() {
        var source = snapshot(); source.scoring[0].strokes = 20
        let initial = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(initial.scores.first?.grossScore, 105)
        XCTAssertEqual(initial.scores.first?.adjustedGrossScore, 94)
        let played = source.round.firstScoredAt!
        source.participants[0].personalHandicapInput = .init(index: 0, source: .external,
            sourceUpdatedAt: played, capturedAt: played, basis: .eighteenHole)
        let established = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(established.scores.first?.adjustedGrossScore, 91)
        XCTAssertEqual(established.scores.first?.personalIndexAtPlay, 0)
        XCTAssertEqual(source.scoring[0].strokes, 20)
    }

    func testPlusPersonalIndexGivesBackStrokesOnHighestStrokeIndexHoles() throws {
        let card = PersonalHandicapCard(holes: (1...18).map { .init(number: $0, par: 4, strokeIndex: $0, gross: 6) },
            intendedHoles: 18, rating: 72, slope: 113, par: 72, pcc: .assumedZero, frozenPersonalIndex: -2, partialReason: nil, initialNine: nil)
        XCTAssertEqual(try card.assessed(index: -2).gross, 106)
    }

    func testLeagueAllowancesAndIntegerIndexesNeverSetPersonalHoleLimits() {
        var source = snapshot(); source.scoring[0].strokes = 20
        source.participants[0].seriesMemberID = "member"
        source.participants[0].handicapIndex = 0
        source.participants[0].adjustedHandicap = 2
        source.participants[0].leagueHandicapStrokesAtCreation = 2
        let original = source.participants[0]
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(result.scores.first?.adjustedGrossScore, 94)
        XCTAssertNil(result.scores.first?.personalIndexAtPlay)
        XCTAssertEqual(source.participants[0], original)
    }

    func testSixActualNinesEstablishUsingThreePairedDifferentials() {
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(6, holes: 9))
        XCTAssertEqual(result.calculation.qualifyingHoles, 54)
        XCTAssertEqual(result.calculation.qualifyingScoreIDs.count, 6)
        XCTAssertEqual(result.calculation.qualifiedIndex, 16)
        XCTAssertEqual(result.calculation.poolCount, 3)
        XCTAssertEqual(result.calculation.countingCount, 1)
        XCTAssertEqual(result.history.count, 1)
        XCTAssertTrue(result.scores.allSatisfy { $0.playedDifferential == 9 && $0.differential == 18 && $0.differentialMethod == .pairedNineEstimate && $0.pendingReason == nil })
        let profile = PersonalHandicapProfile(manual: try! .init(value: 23, source: .manual), calculation: result.calculation)
        XCTAssertEqual(profile.effectiveIndex, 16)
        XCTAssertEqual(profile.manual?.value, 23)
    }

    func testNineHoleHalfPCCIsRecordedAsPlayedPortionOnly() {
        var source = snapshot(holes: 9)
        source.round.personalHandicapPCC = .init(value: 1, verification: .verified, source: "Course/day")
        source.participants[0].seriesMemberID = "league member"
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(result.scores.first?.playedDifferential, 8.5)
        XCTAssertNil(result.scores.first?.differential)
        XCTAssertEqual(result.scores.first?.qualifyingHoles, 9)
        XCTAssertEqual(result.scores.first?.pcc?.verification, .verified)
    }

    func testPartialInitialRoundContributesOnlyCompletedRatedNine() {
        var source = snapshot(); source.scoring.removeLast()
        source.participants[0].personalHandicapPartialReason = PersonalHandicapPartialReason.weather.rawValue
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(result.scores.first?.holeCount, 17)
        XCTAssertEqual(result.scores.first?.grossScore, 85)
        XCTAssertEqual(result.calculation.qualifyingHoles, 9)
        XCTAssertEqual(result.scores.first?.playedDifferential, 9)
        XCTAssertNil(result.scores.first?.differential)
        XCTAssertTrue(result.history.isEmpty)
    }

    func testEstablishedPartialRoundRetainsPlayedHolesAndRequiresExpectedScore() {
        var source = snapshot(); source.scoring.removeLast()
        let date = source.round.firstScoredAt!
        source.participants[0].personalHandicapPartialReason = PersonalHandicapPartialReason.darkness.rawValue
        source.participants[0].personalHandicapInput = .init(index: 10, source: .manual, sourceUpdatedAt: date, capturedAt: date, basis: .eighteenHole)
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)])
        XCTAssertEqual(result.calculation.qualifyingHoles, 17)
        XCTAssertEqual(result.scores.first?.adjustedGrossScore, 85)
        XCTAssertNil(result.scores.first?.playedDifferential)
        XCTAssertNil(result.scores.first?.differential)
        XCTAssertNotNil(result.scores.first?.pendingReason)
    }

    func testInvalidPartialReasonAndPracticeMetadataCannotQualify() {
        var source = snapshot(); source.scoring.removeLast()
        source.participants[0].personalHandicapPartialReason = "avoid a bad hole"
        XCTAssertEqual(review(source).qualifyingHoles, 0)
        source = snapshot(); source.participants[0].personalHandicapPurpose = .practice
        XCTAssertEqual(PersonalHandicapEligibility.review(source, playerID: "p1").qualifyingHoles, 0)
        source.participants[0].personalHandicapPurpose = .unofficial
        XCTAssertEqual(PersonalHandicapEligibility.review(source, playerID: "p1").qualifyingHoles, 0)
    }

    func testLiveManualTransitionAndPersistenceProjectionRetainManualAndOtherFields() throws {
        var player = Player(id: "p1", userID: nil, name: .init("Offline", "Player"), handicaps: [.init(value: 8)])
        let manual = try ManualPersonalHandicap(value: 23, source: .external)
        player.personalHandicap = .init(manual: manual)
        let early = PersonalHandicapPersistence.applying(PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(2), manual: manual).calculation, to: player)
        XCTAssertEqual(early.personalHandicap?.effectiveIndex, 23)
        let rebuilt = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(3), manual: manual)
        let qualified = PersonalHandicapPersistence.applying(rebuilt.calculation, to: early)
        XCTAssertEqual(qualified.personalHandicap?.effectiveIndex, 16)
        XCTAssertEqual(qualified.personalHandicap?.effectiveSource, .calculated)
        XCTAssertEqual(qualified.personalHandicap?.manual, manual)
        XCTAssertEqual(qualified.handicaps, player.handicaps)
        XCTAssertEqual(qualified.name, player.name)
        XCTAssertTrue(qualified.isOffline)
        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(qualified))
        XCTAssertEqual(decoded.personalHandicap, qualified.personalHandicap)
    }

    func testNewNineUsesPriorCalculatedIndexAndPlotsAnEstimatedUpdate() {
        let full = actualReviews(3)
        var nine = review(snapshot(id: "later-nine", holes: 9))
        nine.score = .init(playerID: "p1", roundID: "later-nine", roundTitle: "Later nine",
            playedAt: .init(for: Date(timeIntervalSince1970: 1_800_000_000)), holeCount: 9, grossScore: 45, exclusionReason: nil)
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: full + [nine])
        XCTAssertEqual(result.calculation.status, .qualified)
        XCTAssertEqual(result.calculation.qualifiedIndex, 17)
        XCTAssertEqual(result.history.count, 2)
        XCTAssertEqual(result.history.last?.roundID, "later-nine")
        XCTAssertEqual(result.scores.last?.expectedScoreIndex, 16)
        XCTAssertEqual(result.scores.last?.expectedNineDifferential ?? 0, 9.52, accuracy: 0.00001)
        XCTAssertEqual(result.scores.last?.differential, 18.5)
        XCTAssertEqual(result.scores.last?.differentialMethod, .expectedNineEstimate)
    }

    func testCorrectionsAndExclusionsRebuildLiveCardsAndInvalidateOldTrend() throws {
        let original = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(3))
        var source = snapshot(id: "actual0")
        for i in source.scoring.indices { source.scoring[i].strokes = 4 }
        let corrected = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [review(source)] + Array(actualReviews(3).dropFirst()))
        XCTAssertEqual(corrected.calculation.qualifiedIndex, -2)
        XCTAssertNotEqual(corrected.calculation.inputFingerprint, original.calculation.inputFingerprint)
        source.participants[0].personalHandicapPurpose = .practice
        let excluded = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [PersonalHandicapEligibility.review(source, playerID: "p1")] + Array(actualReviews(3).dropFirst()))
        XCTAssertEqual(excluded.calculation.qualifyingHoles, 36)
        XCTAssertNil(excluded.calculation.effectiveCalculatedIndex)
        XCTAssertTrue(excluded.history.isEmpty)
        XCTAssertNotNil(excluded.scores.first?.exclusionReason)
    }

    func testUnchangedHistoryKeepsOriginalCalculationDateDuringPersistence() {
        let original = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(3), asOf: .init(iso: "", unix: 100))
        let repeated = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(3), asOf: .init(iso: "", unix: 200))
        XCTAssertTrue(PersonalHandicapPersistence.sameHistory(original.history[0], repeated.history[0]))
    }

    func testPostingMetadataAndPCCRoundTripWithoutChangingFrozenHandicaps() throws {
        var source = snapshot()
        source.participants[0].originalHandicap = 10
        source.participants[0].adjustedHandicap = 7
        source.participants[0].personalHandicapPurpose = .unofficial
        source.participants[0].personalHandicapPartialReason = "weather"
        source.round.personalHandicapPCC = .init(value: 0, verification: .verified, source: "External report")
        let participant = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(source.participants[0]))
        let round = try JSONDecoder().decode(Round.self, from: JSONEncoder().encode(source.round))
        XCTAssertEqual(participant.originalHandicap, 10)
        XCTAssertEqual(participant.adjustedHandicap, 7)
        XCTAssertEqual(participant.personalHandicapPurpose, .unofficial)
        XCTAssertEqual(round.personalHandicapPCC?.verification, .verified)
    }

    func testV2LeagueIndividualNinesAreIncludedThroughExistingScoringAdapter() throws {
        let source = snapshot(holes: 9)
        var participantData = try source.participants[0].toDictionary()
        participantData["participation_status"] = "confirmed"
        let participant = try JSONDecoder().decode(RoundParticipantV2.self, from: JSONSerialization.data(withJSONObject: participantData))
        let scores = try source.scoring.map { score -> ScoreEntryV2 in
            var data = try score.toDictionary(); data["tee_group_id"] = ""
            return try JSONDecoder().decode(ScoreEntryV2.self, from: JSONSerialization.data(withJSONObject: data))
        }
        var segmentData = try source.segments[0].toDictionary()
        segmentData["matchups"] = []; segmentData["competition_scope"] = "field"
        let segment = try JSONDecoder().decode(RoundSegmentV2.self, from: JSONSerialization.data(withJSONObject: segmentData))
        let round = RoundV2(id: source.round.id, status: .completed, configuration: .init(legacy: source.configuration), participantPlayerIDs: ["p1"])
        let v2 = RoundSnapshotV2(round: round, participants: [participant], teams: [], teeGroups: [], scoringGroups: [], segments: [segment], scores: scores)
        let r = PersonalHandicapEligibility.reviewV2(v2, playerID: "p1")
        XCTAssertEqual(r.qualifyingHoles, 9)
        XCTAssertEqual(r.score.sourceCollection, V2Collection.rounds)
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [r])
        XCTAssertEqual(result.calculation.qualifyingHoles, 9)
        XCTAssertEqual(result.scores.first?.playedDifferential, 9)
    }

    func testPendingWireStatusRemainsReadableByOriginalSandboxBuild() throws {
        let reviews = actualReviews(6, holes: 9).map { review in
            var pending = review; pending.card = nil; return pending
        }
        let pending = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews).calculation
        let data = try JSONEncoder().encode(pending)
        let dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dictionary["status"] as? String, "collecting")
        XCTAssertEqual(dictionary["calculation_pending"] as? Bool, true)
        XCTAssertEqual(try JSONDecoder().decode(PersonalHandicapCalculation.self, from: data), pending)
    }

    func testMissingTeeMetadataPreservesRecordedNineHoleGrossHistory() {
        var source = snapshot(holes: 9)
        source.participants[0].teeBoxID = "unknown tee"
        let review = PersonalHandicapEligibility.review(source, playerID: "p1")
        XCTAssertEqual(review.qualifyingHoles, 0)
        XCTAssertEqual(review.score.holeCount, 9)
        XCTAssertEqual(review.score.grossScore, 45)
        XCTAssertNotNil(review.score.pendingReason)
    }

    private func datedReview(_ day: Int, holes: Int = 9, gross: Int = 45, league: String? = nil) -> PersonalHandicapRoundReview {
        var source = snapshot(id: "dated-\(day)", holes: holes)
        source.round.firstScoredAt = .init(iso: "", unix: 1_700_000_000 + Double(day) * 86400)
        source.participants[0].seriesMemberID = league
        for i in source.scoring.indices { source.scoring[i].strokes = gross / holes + (i < gross % holes ? 1 : 0) }
        return review(source)
    }

    func testInitialPairingIsChronologicalAcrossLeaguesAndRegularRounds() {
        let cards = [datedReview(0, gross: 40, league: "league-a"), datedReview(1, holes: 18, gross: 90),
                     datedReview(2, gross: 42, league: "league-b"), datedReview(3, gross: 44), datedReview(4, gross: 46, league: "league-c")]
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards.reversed())
        XCTAssertEqual(result.calculation.qualifyingHoles, 54)
        XCTAssertEqual(result.calculation.qualifiedIndex, 8) // lowest combined 10, less initial adjustment 2
        XCTAssertEqual(result.calculation.poolCount, 3)
        XCTAssertEqual(result.scores.first?.differentialRoundIDs, ["dated-0", "dated-2"])
        XCTAssertEqual(result.scores.last?.differentialRoundIDs, ["dated-3", "dated-4"])
        XCTAssertEqual(result.scores.map(\.roundID), cards.map { $0.score.roundID })
        XCTAssertEqual(result.history.map(\.roundID), ["dated-4"])
    }

    func testUnpairedInitialNineAdvancesHolesWithoutAddingAPoolEntry() {
        let reviews = (0..<5).map { datedReview($0) }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews)
        XCTAssertEqual(result.calculation.qualifyingHoles, 45)
        XCTAssertEqual(result.calculation.poolCount, 2)
        XCTAssertNil(result.calculation.qualifiedIndex)
        XCTAssertNil(result.scores.last?.differential)
        XCTAssertNotNil(result.scores.last?.pendingReason)
        XCTAssertEqual(result.calculation.qualifyingScoreIDs.count, 5)
        XCTAssertEqual(Set(result.scores.compactMap(\.differentialID)).count, 2)
    }

    func testUnpairedInitialNineDoesNotBlockThreeValidEighteensOrGetReusedAfterEstablishment() {
        let cards = [datedReview(0)] + (1...3).map { datedReview($0, holes: 18, gross: 90) } + [datedReview(4)]
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards)
        XCTAssertEqual(result.calculation.qualifyingHoles, 72)
        XCTAssertEqual(result.calculation.poolCount, 4)
        XCTAssertNil(result.scores.first?.differential)
        XCTAssertEqual(result.scores.last?.differentialMethod, .expectedNineEstimate)
        XCTAssertEqual(result.scores.last?.differentialRoundIDs, ["dated-4"])
    }

    func testInitialPairUsesUnroundedComponentsAndRoundsOnlyTheCombinedValue() {
        var cards = [datedReview(0), datedReview(1)]
        for i in cards.indices {
            let card = cards[i].card!
            cards[i].card = .init(holes: card.holes, intendedHoles: 9, rating: 35.96, slope: 113, par: 36,
                pcc: .assumedZero, frozenPersonalIndex: nil, partialReason: nil, initialNine: nil)
        }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards)
        XCTAssertEqual(result.scores[0].playedDifferential!, 9.04, accuracy: 0.000001)
        XCTAssertEqual(result.scores[0].differential, 18.1) // 9.04 + 9.04 = 18.08; rounding each first gives 18.0.
        XCTAssertEqual(result.scores[0].differentialID, result.scores[1].differentialID)
    }

    func testMixedActualQualificationWaitsForFiftyFourHolesAndThreeEquivalents() {
        let cards = [datedReview(0, holes: 18, gross: 90), datedReview(1, holes: 18, gross: 90), datedReview(2), datedReview(3)]
        let early = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: Array(cards.dropLast()))
        XCTAssertEqual(early.calculation.qualifyingHoles, 45)
        XCTAssertNil(early.calculation.qualifiedIndex)
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards)
        XCTAssertEqual(result.calculation.qualifyingHoles, 54)
        XCTAssertEqual(result.calculation.poolCount, 3)
        XCTAssertEqual(result.calculation.qualifiedIndex, 16)
    }

    func testManualIndexNeverSuppliesExpectedNineBeforeCalculatedQualification() throws {
        let manual = try ManualPersonalHandicap(value: 40, source: .external, updatedAt: .init(iso: "", unix: 1))
        let early = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: [datedReview(0)], manual: manual)
        XCTAssertNil(early.scores[0].expectedScoreIndex)
        XCTAssertNil(early.scores[0].expectedNineDifferential)
        XCTAssertNil(early.scores[0].differential)
        XCTAssertEqual(PersonalHandicapProfile(manual: manual, calculation: early.calculation).effectiveIndex, 40)
        let qualified = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: (0..<7).map { datedReview($0) }, manual: manual)
        XCTAssertEqual(qualified.scores[6].expectedScoreIndex, 16)
        XCTAssertEqual(qualified.scores[6].differentialMethod, .expectedNineEstimate)
        let profile = PersonalHandicapProfile(manual: manual, calculation: qualified.calculation)
        XCTAssertEqual(profile.manual, manual)
        XCTAssertEqual(profile.effectiveSource, .calculated)
    }

    func testExpectedApproximationMatchesRepresentativePublishedAssociationTableValues() throws {
        // Swiss Golf 2025 table: independent points across its published -6...54 range.
        let examples: [(Double, Double)] = [(-6, -1.9), (-4, -0.9), (-2, 0.2), (0, 1.2), (2, 2.2),
            (6, 4.3), (10, 6.4), (14, 8.5), (15, 9.0), (18, 10.6), (26, 14.7), (38, 21.0), (54, 29.3)]
        for (index, expected) in examples {
            XCTAssertEqual(PersonalHandicapRules.tenth(try PersonalHandicapNineHoleEstimation.expectedDifferential(index: index)), expected, "Index \(index)")
        }
        XCTAssertEqual(try PersonalHandicapNineHoleEstimation.expectedDifferential(index: -10), -1.92, accuracy: 0.00001) // bounded at the published +6 boundary
        XCTAssertThrowsError(try PersonalHandicapNineHoleEstimation.expectedDifferential(index: .infinity))
        XCTAssertThrowsError(try PersonalHandicapNineHoleEstimation.expectedDifferential(index: 54.1))
    }

    func testExpectedApproximationMatchesUSGAWorkedExamplesAtFinalRounding() throws {
        // USGA treatment-of-nine infographic: Index 14, played differential 7.2 -> 15.7.
        let e14 = try PersonalHandicapNineHoleEstimation.expectedDifferential(index: 14)
        XCTAssertEqual(PersonalHandicapRules.tenth(7.2 + e14), 15.7)
        // USGA Understanding Expected Score infographic: Index 15, two different courses/results.
        let e15 = try PersonalHandicapNineHoleEstimation.expectedDifferential(index: 15)
        let a = try PersonalHandicapRules.playedDifferential(adjustedGross: 42, rating: 35.6, slope: 129, holes: 9, pcc: 0)
        let b = try PersonalHandicapRules.playedDifferential(adjustedGross: 50, rating: 36.1, slope: 136, holes: 9, pcc: 0)
        XCTAssertEqual(PersonalHandicapRules.tenth(a + e15), 14.6)
        XCTAssertEqual(PersonalHandicapRules.tenth(b + e15), 20.5)
    }

    func testExpectedEstimateTracksImprovingAndWorseningPreRoundIndexIncludingPlus() {
        for initialDifferential in [-2.0, 2, 15, 36, 56] {
            let (seed, verified) = pool(Array(repeating: initialDifferential, count: 3))
            let initialIndex = min(54, initialDifferential - 2)
            let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: seed + [datedReview(10)], verified: verified)
            XCTAssertEqual(result.scores.last?.expectedScoreIndex, initialIndex)
            XCTAssertEqual(result.scores.last?.expectedNineDifferential ?? 0, 0.52 * initialIndex + 1.2, accuracy: 0.000001)
            XCTAssertEqual(result.scores.last?.differentialMethod, .expectedNineEstimate)
        }
    }

    func testSequentialNineExpectedInputsUsePreviousResultsWithoutLookAhead() {
        let cards = (0..<12).map { datedReview($0, gross: $0 < 6 ? 45 : 38) }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards)
        let points = result.history
        XCTAssertEqual(points.count, 7)
        for i in 6..<12 {
            XCTAssertEqual(result.scores[i].expectedScoreIndex, points[i - 6].calculation.qualifiedIndex)
        }
        XCTAssertLessThan(result.calculation.qualifiedIndex!, 16)
    }

    func testInitialPairsOccupyOneEachInLatestTwentyAndCountingMembershipMapsToBothCards() {
        let cards = (0..<26).map { datedReview($0) }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards)
        XCTAssertEqual(result.calculation.poolCount, 20)
        XCTAssertEqual(result.calculation.countingCount, 8)
        // 3 initial pairs + 20 post-establishment nines = 23; all initial pairs have aged out.
        XCTAssertEqual(result.calculation.poolScoreIDs, Array(cards.dropFirst(6)).map { $0.score.roundID })
        let initial = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: Array(cards.prefix(6)))
        XCTAssertEqual(initial.calculation.countingScoreIDs.count, 2)
        for id in initial.calculation.countingScoreIDs {
            XCTAssertEqual(PersonalHandicapPresentation.scoreStatus(initial.scores.first { $0.id == id }!, calculation: initial.calculation), "Counts")
        }
    }

    func testLatePostingCorrectionAndExclusionRebuildPairsAndSubsequentExpectedValues() {
        let cards = (0..<8).map { datedReview($0) }
        let asOf = Time(iso: "", unix: 1_800_000_000)
        let original = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards, asOf: asOf)
        let shuffled = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards.reversed(), asOf: asOf)
        XCTAssertEqual(original.history, shuffled.history)
        var corrected = datedReview(0, gross: 36)
        corrected.revision += 100
        let changed = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards + [corrected])
        XCTAssertNotEqual(changed.calculation.qualifiedIndex, original.calculation.qualifiedIndex)
        XCTAssertNotEqual(changed.scores.last?.expectedScoreIndex, original.scores.last?.expectedScoreIndex)
        var excluded = corrected
        excluded.revision += 100
        excluded.score.exclusionReason = "Practice round"; excluded.qualifyingHoles = 0
        let removed = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards + [corrected, excluded])
        XCTAssertEqual(removed.calculation.qualifyingHoles, 63)
        XCTAssertEqual(removed.scores[1].differentialRoundIDs, ["dated-1", "dated-2"])
        let onlyFive = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: Array(cards.prefix(6)) + [excluded])
        XCTAssertEqual(onlyFive.calculation.qualifyingHoles, 45)
        XCTAssertNil(onlyFive.calculation.effectiveCalculatedIndex)
        XCTAssertTrue(onlyFive.history.isEmpty)
    }

    func testRepeatedRoundRevisionsCannotReuseANineInTwoPairs() {
        let cards = (0..<6).map { datedReview($0) }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards + cards + cards.reversed())
        XCTAssertEqual(result.scores.count, 6)
        XCTAssertEqual(result.calculation.qualifyingHoles, 54)
        XCTAssertEqual(result.calculation.poolCount, 3)
        let pairs = Dictionary(grouping: result.scores, by: { $0.differentialID! })
        XCTAssertTrue(pairs.values.allSatisfy { $0.count == 2 && Set($0.flatMap { $0.differentialRoundIDs! }).count == 2 })
    }

    func testNineCalculationMetadataPersistsAndPreservesRawSnapshotsAndLegacyRecords() throws {
        let source = snapshot(holes: 9)
        let original = source
        let r = review(source)
        var reviews = actualReviews(6, holes: 9)
        var later = r; later.score = .init(playerID: "p1", roundID: "late", roundTitle: "Late",
            playedAt: .init(iso: "", unix: 1_800_000_000), holeCount: 9, grossScore: 45, exclusionReason: nil)
        reviews.append(later)
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews)
        let data = try JSONEncoder().encode(result.scores)
        XCTAssertEqual(try JSONDecoder().decode([PersonalHandicapScoreRecord].self, from: data), result.scores)
        XCTAssertEqual(result.scores.first?.courseName, "Course")
        XCTAssertEqual(result.scores.first?.teeName, "White")
        XCTAssertEqual(result.scores.first?.slopeRating, 113)
        XCTAssertEqual(result.scores.first?.differentialMethodVersion, PersonalHandicapNineHoleEstimation.pairedVersion)
        XCTAssertEqual(result.scores.last?.differentialMethodVersion, PersonalHandicapNineHoleEstimation.expectedVersion)
        XCTAssertEqual(try JSONDecoder().decode(PersonalHandicapCalculation.self, from: JSONEncoder().encode(result.calculation)), result.calculation)
        XCTAssertEqual(source.participants, original.participants)
        XCTAssertEqual(source.scoring, original.scoring)
        // Older additive documents omit every estimation field.
        let oldJSON = "{\"player_id\":\"p1\",\"round_id\":\"old\",\"round_title\":\"Old\",\"played_at\":{\"iso\":\"\",\"unix\":1},\"hole_count\":9,\"gross_score\":45}"
        XCTAssertNil(try JSONDecoder().decode(PersonalHandicapScoreRecord.self, from: Data(oldJSON.utf8)).differentialMethod)
    }

    func testPoorLaterNinesRaiseTheIndexAndTheirExpectedComponentWithinPublishedCaps() {
        let seed = (0..<3).map { datedReview($0, holes: 18, gross: 90) }
        let later = (3..<27).map { datedReview($0, gross: 65) }
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: seed + later)
        XCTAssertEqual(result.history.first?.calculation.qualifiedIndex, 16)
        XCTAssertGreaterThan(result.calculation.qualifiedIndex!, 16)
        XCTAssertLessThanOrEqual(result.calculation.qualifiedIndex!, 54)
        XCTAssertNotNil(result.calculation.lowHandicapIndex)
        XCTAssertLessThanOrEqual(result.calculation.qualifiedIndex!, result.calculation.lowHandicapIndex! + 5)
        XCTAssertGreaterThan(result.scores.last!.expectedNineDifferential!, result.scores[3].expectedNineDifferential!)
    }

    func testExpectedNineRetainsExceptionalScoreReductionAgainstPreRoundIndex() {
        let (seed, verified) = pool([22, 22, 22])
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: seed + [datedReview(10, gross: 36)], verified: verified)
        XCTAssertEqual(result.scores.last?.expectedScoreIndex, 20)
        XCTAssertEqual(result.scores.last?.differential, 11.6)
        XCTAssertEqual(result.calculation.qualifiedIndex, 9.6) // exceptional -1, then the four-score adjustment -1
    }

    func testExpectedNineRoundsOnlyAfterCombiningBothUnroundedComponents() {
        let seed = actualReviews(3)
        var nine = datedReview(10)
        let card = nine.card!
        nine.card = .init(holes: card.holes, intendedHoles: 9, rating: 35.96, slope: 113, par: 36,
            pcc: .assumedZero, frozenPersonalIndex: nil, partialReason: nil, initialNine: nil)
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: seed + [nine])
        XCTAssertEqual(result.scores.last?.expectedScoreIndex, 16)
        XCTAssertEqual(result.scores.last?.differential, 18.6) // 9.04 + 9.52; separately rounding would give 18.5.
    }

    func testUnsupportedPartialKeepsLastValidIndexWithoutInventingNewTrend() {
        var source = snapshot(id: "partial")
        source.round.firstScoredAt = .init(iso: "", unix: 1_800_000_000)
        source.scoring.removeLast()
        source.participants[0].personalHandicapPartialReason = "weather"
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: actualReviews(3) + [review(source)])
        XCTAssertEqual(result.calculation.status, .blocked)
        XCTAssertEqual(result.calculation.effectiveCalculatedIndex, 16)
        XCTAssertEqual(result.history.count, 1)
        XCTAssertNil(result.scores.last?.differential)
        XCTAssertEqual(result.scores.last?.qualifyingHoles, 17)
    }

    func testExpectedModelBoundsExtremePlusInputsWithoutExtrapolation() throws {
        for index in [-6.0, -6.1, -10, -100, -Double.greatestFiniteMagnitude] {
            XCTAssertEqual(try PersonalHandicapNineHoleEstimation.modelIndex(index: index), -6)
            XCTAssertEqual(try PersonalHandicapNineHoleEstimation.expectedDifferential(index: index), -1.92, accuracy: 0.000001)
        }
        for index in [-5.9, 0, 15, 54] {
            XCTAssertEqual(try PersonalHandicapNineHoleEstimation.modelIndex(index: index), index)
        }
        for invalid in [Double.nan, .infinity, -.infinity, 54.1] {
            XCTAssertThrowsError(try PersonalHandicapNineHoleEstimation.expectedDifferential(index: invalid))
        }
    }

    func testBoundedEstimateRetainsActualHistoricalIndexAndPersistsBothInputs() throws {
        let (seed, verified) = pool([-10, -10, -10])
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: seed + [datedReview(10)], verified: verified)
        let score = try XCTUnwrap(result.scores.last)
        XCTAssertEqual(score.expectedScoreIndex, -12)
        XCTAssertEqual(score.expectedScoreModelIndex, -6)
        XCTAssertEqual(score.expectedNineDifferential!, -1.92, accuracy: 0.000001)
        XCTAssertEqual(score.differential, 7.1)
        XCTAssertEqual(score.differentialMethodVersion, PersonalHandicapNineHoleEstimation.expectedVersion)
        XCTAssertEqual(try JSONDecoder().decode(PersonalHandicapScoreRecord.self, from: JSONEncoder().encode(score)), score)
        XCTAssertEqual(result.history.first?.calculation.qualifiedIndex, -12)
    }

    func testDeletedPostingRebuildsPairsAndTrendIdempotently() {
        let cards = (0..<8).map { datedReview($0) }
        let time = Time(iso: "", unix: 1_800_000_000)
        let before = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards, asOf: time)
        let remaining = Array(cards.dropFirst())
        let removed = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: remaining, asOf: time)
        let repeated = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: remaining.reversed(), asOf: time)
        XCTAssertEqual(removed.calculation.qualifyingHoles, 63)
        XCTAssertFalse(removed.scores.contains { $0.id == "dated-0" })
        XCTAssertTrue(removed.scores.allSatisfy { $0.differentialRoundIDs?.contains("dated-0") != true })
        XCTAssertEqual(removed.scores.first?.differentialRoundIDs, ["dated-1", "dated-2"])
        XCTAssertNotEqual(removed.history.map(\.roundID), before.history.map(\.roundID))
        XCTAssertEqual(removed.calculation, repeated.calculation)
        XCTAssertEqual(removed.history, repeated.history)
        XCTAssertEqual(removed.scores, repeated.scores)
    }

    func testImportedOlderRoundReplaysHistoricalPairingAndExpectedInputs() {
        let cards = (0..<7).map { datedReview($0) }
        let time = Time(iso: "", unix: 1_800_000_000)
        let newerFirst = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: Array(cards.dropFirst()), asOf: time)
        XCTAssertEqual(newerFirst.history.first?.roundID, "dated-6")
        let imported = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: Array(cards.dropFirst()) + [cards[0]], asOf: time)
        XCTAssertEqual(imported.history.first?.roundID, "dated-5")
        XCTAssertEqual(imported.scores[0].differentialRoundIDs, ["dated-0", "dated-1"])
        XCTAssertEqual(imported.scores.last?.expectedScoreIndex, 16)
        XCTAssertEqual(imported.scores.last?.differentialMethod, .expectedNineEstimate)
        let chronological = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: cards, asOf: time)
        XCTAssertEqual(imported.calculation, chronological.calculation)
        XCTAssertEqual(imported.scores, chronological.scores)
    }

    func testAuditResavingSameManualIndexPreservesHistoricalLeagueDifferentials() throws {
        let base = 1_700_000_000.0
        let reviews = (0..<3).map { n -> PersonalHandicapRoundReview in
            var source = snapshot(id: "audit-league-\(n)")
            source.round.firstScoredAt = Time(iso: "", unix: base + Double(n) * 86400)
            source.participants[0].seriesMemberID = "league-member"
            for i in source.scoring.indices { source.scoring[i].strokes = 10 }
            return review(source)
        }
        let original = try ManualPersonalHandicap(value: 10, source: .manual, updatedAt: .init(iso: "", unix: base - 86400))
        var player = Player(id: "p1", userID: "u1", name: Name("Test", "Player"))
        player.personalHandicap = .init(manual: original)
        let now = Time(iso: "", unix: base + 3 * 86400)
        let savedAgain = try player.settingManualPersonalHandicap(.init(value: 10, source: .manual, updatedAt: now), as: "u1", at: now)
        let before = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, manual: original)
        let after = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, manual: savedAgain.personalHandicap?.manual)
        XCTAssertEqual(before.calculation.qualifiedIndex, 44)
        XCTAssertEqual(before.scores.first?.adjustedGrossScore, 118)
        XCTAssertEqual(after.scores.first?.personalIndexAtPlay, 10)
        XCTAssertEqual(after.scores.first?.adjustedGrossScore, before.scores.first?.adjustedGrossScore)
        XCTAssertEqual(after.calculation.qualifiedIndex, before.calculation.qualifiedIndex)
    }

    func testRealManualEditAndRemovalPreserveHistoricalLeagueHoleLimitsAndTrend() throws {
        let base = 1_700_000_000.0
        let reviews = (0..<3).map { n -> PersonalHandicapRoundReview in
            var source = snapshot(id: "historical-league-\(n)")
            source.round.firstScoredAt = .init(iso: "", unix: base + Double(n) * 86400)
            source.participants[0].seriesMemberID = "member"
            for i in source.scoring.indices { source.scoring[i].strokes = 10 }
            return review(source)
        }
        var player = Player(id: "p1", userID: "u1", name: Name("Test", "Player"))
        let manual = try ManualPersonalHandicap(value: 10, source: .manual, updatedAt: .init(iso: "", unix: base - 86400))
        player.personalHandicap = .init(manual: manual)
        let before = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, manual: manual)
        let edited = try player.settingManualPersonalHandicap(.init(value: 20, source: .external), as: "u1", at: .init(iso: "", unix: base + 4 * 86400))
        let cleared = try edited.settingManualPersonalHandicap(nil, as: "u1", at: .init(iso: "", unix: base + 5 * 86400))
        for profile in [edited.personalHandicap!, cleared.personalHandicap!] {
            let after = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, manual: profile.manual, manualHistory: profile.manualHistory ?? [])
            XCTAssertEqual(after.scores.first?.personalIndexAtPlay, 10)
            XCTAssertEqual(after.scores.first?.adjustedGrossScore, 118)
            XCTAssertEqual(after.calculation.qualifiedIndex, 44)
            XCTAssertEqual(after.calculation.qualifiedIndex, before.calculation.qualifiedIndex)
            XCTAssertTrue(PersonalHandicapPersistence.sameHistory(before.history[0], after.history[0]))
        }
    }

    func testDatedManualChangesOnlyAffectRoundsPlayedAfterTheirEffectiveDate() throws {
        let base = 1_700_000_000.0
        let reviews = [0, 2].map { day -> PersonalHandicapRoundReview in
            var source = snapshot(id: "between-\(day)")
            source.round.firstScoredAt = .init(iso: "", unix: base + Double(day) * 86400)
            for i in source.scoring.indices { source.scoring[i].strokes = 10 }
            return review(source)
        }
        let first = try ManualPersonalHandicap(value: 10, source: .manual, updatedAt: .init(iso: "", unix: base - 86400))
        var profile = PersonalHandicapProfile(manual: first)
        profile = try profile.settingManual(.init(value: 20, source: .external), at: .init(iso: "", unix: base + 86400))
        let result = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, manual: profile.manual, manualHistory: profile.manualHistory ?? [])
        XCTAssertEqual(result.scores.map(\.personalIndexAtPlay), [10, 20])
        XCTAssertEqual(result.scores.map(\.adjustedGrossScore), [118, 128])
        profile = try profile.settingManual(nil, at: .init(iso: "", unix: base + 86400))
        let cleared = PersonalHandicapEngine.rebuild(playerID: "p1", reviews: reviews, manual: nil, manualHistory: profile.manualHistory ?? [])
        XCTAssertEqual(cleared.scores.map(\.personalIndexAtPlay), [10, nil])
        XCTAssertEqual(cleared.scores.last?.adjustedGrossScore, 162)
    }

}
