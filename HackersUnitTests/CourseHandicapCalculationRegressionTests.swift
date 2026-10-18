import XCTest
@testable import Hackers

final class CourseHandicapCalculationRegressionTests: XCTestCase {
    private func tee(
        id: String = "white", rating: Double = 73.9, slope: Int = 143,
        frontRating: Double? = 35.2, frontSlope: Int? = 118,
        backRating: Double? = 34.7, backSlope: Int? = 124,
        holeCount: Int = 18
    ) -> Tee {
        Tee(id: id, name: id, gender: "male", totalHoles: holeCount,
            holes: (1...holeCount).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: rating, slopeFull: slope, ratingFront: frontRating, slopeFront: frontSlope,
            ratingBack: backRating, slopeBack: backSlope)
    }

    private func segment(_ tee: Tee, _ holes: HoleSegment = .back9) -> CourseSegment {
        CourseSegment(courseInfo: CourseInfo(id: "verdae", name: "The Preserve at Verdae", totalHoles: tee.totalHoles, tees: [tee]),
                      holeRange: holes.holeRange, defaultTee: tee.id)
    }

    private func participant(_ tee: Tee) -> RoundParticipant {
        RoundParticipant(id: "player", name: Name("Test", "Player"), teeBoxID: tee.id, originalHandicap: 7, adjustedHandicap: 7)
    }

    func testRequiredPersonalIndexBackNineExamplePreservesOriginalIndex() {
        let tee = tee()
        let result = HandicapCalculator.calculation(index: 23, tee: tee, segment: .back9, indexBasis: .eighteenHole)
        XCTAssertEqual(result.status, .exact)
        XCTAssertEqual(result.handicapIndex, 23)
        XCTAssertEqual(result.calculationIndex, 11.5)
        XCTAssertEqual(result.courseHandicap, 11)
        XCTAssertEqual(result.rating, 34.7)
        XCTAssertEqual(result.slope, 124)
        XCTAssertEqual(result.par, 36)
        let saved = HandicapCalculator.participant(participant(tee), applying: 23, format: .courseHandicap,
            courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)
        XCTAssertEqual(saved.handicapIndex, 23)
        XCTAssertEqual(saved.adjustedHandicap, 11)
        XCTAssertEqual(saved.handicapResolution?.calculation, result)
    }

    func testAllFourSourceBasisAndRoundLengthCombinations() {
        let tee = tee(rating: 72, slope: 113, frontRating: 36, frontSlope: 113, backRating: 36, backSlope: 113)
        let cases: [(SeriesHandicapStrokeBasis, HoleSegment, Double, Int)] = [
            (.eighteenHole, .front9, 4.3, 4), (.nineHole, .front9, 8.5, 9),
            (.eighteenHole, .full18, 8.5, 9), (.nineHole, .full18, 17, 17)
        ]
        for (basis, segment, calculationIndex, expected) in cases {
            let result = HandicapCalculator.calculation(index: 8.5, tee: tee, segment: segment, indexBasis: basis)
            XCTAssertEqual(result.handicapIndex, 8.5)
            XCTAssertEqual(result.calculationIndex, calculationIndex)
            XCTAssertEqual(result.courseHandicap, expected)
            XCTAssertEqual(result.status, .exact)
        }
    }

    func testFrontBackAndFullUseTheirOwnRatingSlopeAndPar() {
        let tee = tee()
        for (segment, rating, slope, par) in [(HoleSegment.front9, 35.2, 118, 36), (.back9, 34.7, 124, 36), (.full18, 73.9, 143, 72)] {
            let result = HandicapCalculator.calculation(index: 22.6, tee: tee, segment: segment, indexBasis: .eighteenHole)
            XCTAssertEqual(result.rating, rating)
            XCTAssertEqual(result.slope, slope)
            XCTAssertEqual(result.par, par)
            XCTAssertEqual(result.status, .exact)
        }
    }

    func testRawFullCourseHandicapIsCalculatedBeforeLeagueCap() throws {
        let tee = tee()
        let result = HandicapCalculator.calculation(index: 22.6, tee: tee, segment: .full18, indexBasis: .eighteenHole)
        XCTAssertEqual(result.courseHandicap, 31)
        XCTAssertEqual(result.allowedStrokes(maximum: 21), 21)
        XCTAssertEqual(result.handicapIndex, 22.6)
        let resolved = SeriesCourseHandicapResolver.resolve(effectiveIndex: 22.6, memberID: "m", memberName: "Player",
            requestedTeeID: tee.id, tee: tee, courseID: "c", courseName: "Course", holeSegment: .full18,
            entryFormat: .courseHandicap, handicapStrokeBasis: .eighteenHole, maximumHandicap: 21)
        let snapshot = try XCTUnwrap(resolved.snapshot())
        XCTAssertEqual(snapshot.authoritativeCourseHandicap, 31)
        XCTAssertEqual(snapshot.effectiveStrokes, 21)
        XCTAssertEqual(snapshot.handicapIndex, 22.6)
        XCTAssertEqual(snapshot.calculation, result)
    }

    func testExactSegmentValuesWinAndPartialFallbackPreservesEveryExactInput() {
        let fullOnly = tee(frontRating: nil, frontSlope: nil, backRating: nil, backSlope: nil)
        for segment in [HoleSegment.front9, .back9] {
            let result = HandicapCalculator.calculation(index: 23, tee: fullOnly, segment: segment, indexBasis: .eighteenHole)
            XCTAssertEqual(result.status, .estimated)
            XCTAssertEqual(result.rating, 73.9 / 2)
            XCTAssertEqual(result.slope, 143)
            XCTAssertEqual(result.ratingProvenance, .estimatedFromFullCourse)
            XCTAssertEqual(result.slopeProvenance, .estimatedFromFullCourse)
        }
        let missingFrontRating = tee(frontRating: nil)
        let front = HandicapCalculator.calculation(index: 23, tee: missingFrontRating, segment: .front9, indexBasis: .eighteenHole)
        XCTAssertEqual(front.status, .estimated)
        XCTAssertEqual(front.rating, 73.9 / 2)
        XCTAssertEqual(front.slope, 118)
        XCTAssertEqual(front.slopeProvenance, .segment)
        let missingBackSlope = tee(backSlope: nil)
        let back = HandicapCalculator.calculation(index: 23, tee: missingBackSlope, segment: .back9, indexBasis: .eighteenHole)
        XCTAssertEqual(back.status, .estimated)
        XCTAssertEqual(back.rating, 34.7)
        XCTAssertEqual(back.ratingProvenance, .segment)
        XCTAssertEqual(back.slope, 143)
        XCTAssertEqual(HandicapCalculator.calculation(index: 23, tee: tee(), segment: .back9, indexBasis: .eighteenHole).status, .exact)
    }

    func testEstimateRequiresExplicitConsentAndTeeChangesInvalidateConsent() throws {
        let tee = tee(frontRating: nil, frontSlope: nil, backRating: nil, backSlope: nil)
        let course = segment(tee)
        let pending = HandicapCalculator.participant(participant(tee), applying: 23, format: .courseHandicap,
            courseSegment: course, handicapStrokeBasis: .eighteenHole)
        XCTAssertNil(pending.handicapResolution?.effectiveStrokes)
        XCTAssertEqual(pending.adjustedHandicap, 7) // unresolved drafts don't invent a new allowance
        XCTAssertFalse(HandicapCalculator.isReady(pending, format: .courseHandicap, courseSegment: course, indexBasis: .eighteenHole))
        let approved = HandicapCalculator.participant(pending, applying: 23, format: .courseHandicap,
            courseSegment: course, handicapStrokeBasis: .eighteenHole, approveEstimate: true, approvedBy: "host")
        XCTAssertNotNil(approved.handicapResolution?.estimateApprovedAt)
        XCTAssertEqual(approved.handicapResolution?.approvedBy, "host")
        XCTAssertTrue(HandicapCalculator.isReady(approved, format: .courseHandicap, courseSegment: course, indexBasis: .eighteenHole))
        let decoded = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(approved))
        XCTAssertEqual(decoded.handicapResolution, approved.handicapResolution)
        let changed = self.tee(rating: 70, slope: 120, frontRating: nil, frontSlope: nil, backRating: nil, backSlope: nil)
        let recalculated = HandicapCalculator.recomputedParticipants([decoded], format: .courseHandicap,
            courseSegment: segment(changed), handicapStrokeBasis: .eighteenHole)[0]
        XCTAssertNil(recalculated.handicapResolution?.estimateApprovedAt)
        XCTAssertNil(recalculated.handicapResolution?.effectiveStrokes)
        XCTAssertEqual(recalculated.handicapIndex, 23)
    }

    func testSelectedTeeWithoutSlopeNeverBorrowsAnotherTeesDataOrConvertsIndexToStrokes() {
        let invalid = tee(id: "selected", slope: 0, frontSlope: nil, backSlope: nil)
        let valid = tee(id: "default")
        let course = CourseSegment(courseInfo: CourseInfo(id: "c", name: "Course", totalHoles: 18, tees: [invalid, valid]),
                                  holeRange: HoleSegment.back9.holeRange, defaultTee: valid.id)
        let player = participant(invalid)
        let result = HandicapCalculator.calculation(index: 23, participant: player, courseSegment: course, indexBasis: .eighteenHole)
        XCTAssertEqual(result.status, .unavailable)
        XCTAssertNil(result.courseHandicap)
        XCTAssertNil(HandicapCalculator.strokes(for: 23, format: .courseHandicap, participant: player, courseSegment: course))
        let saved = HandicapCalculator.participant(player, applying: 23, format: .courseHandicap, courseSegment: course)
        XCTAssertEqual(saved.handicapIndex, 23)
        XCTAssertNil(saved.handicapResolution?.effectiveStrokes)
        XCTAssertEqual(saved.adjustedHandicap, player.adjustedHandicap)
        XCTAssertNil(HandicapCalculator.calculation(index: 23, participant: RoundParticipant(teeBoxID: "deleted"),
            courseSegment: course, indexBasis: .eighteenHole).courseHandicap)
    }

    func testMissingTeeParAndAmbiguousLegacyBasisAreUnavailable() throws {
        let tee = tee()
        XCTAssertEqual(HandicapCalculator.calculation(index: 23, tee: nil, segment: .back9, indexBasis: .eighteenHole).status, .unavailable)
        XCTAssertEqual(HandicapCalculator.calculation(index: 23, tee: tee, segment: .back9, indexBasis: nil).status, .unavailable)
        let incomplete = self.tee(holeCount: 9)
        XCTAssertEqual(HandicapCalculator.calculation(index: 23, tee: incomplete, segment: .full18, indexBasis: .eighteenHole).status, .unavailable)
        let legacy = RoundParticipant(id: "legacy", originalHandicap: 23, adjustedHandicap: 11)
        let decoded = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(decoded.handicapIndex)
        XCTAssertNil(decoded.handicapResolution)
        XCTAssertEqual(decoded.adjustedHandicap, 11)
        let recomputed = HandicapCalculator.recomputedParticipants([decoded], format: .courseHandicap,
            courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)[0]
        XCTAssertNil(recomputed.handicapIndex)
        XCTAssertEqual(recomputed.handicapResolution?.calculation?.status, .unavailable)
        XCTAssertEqual(recomputed.adjustedHandicap, 11)
    }

    func testNativeNineHoleRatingIsExactAndIsNotHalved() {
        let tee = tee(rating: 35.4, slope: 121, frontRating: nil, frontSlope: nil, holeCount: 9)
        let result = HandicapCalculator.calculation(index: 23, tee: tee, segment: .front9, indexBasis: .eighteenHole)
        XCTAssertEqual(result.status, .exact)
        XCTAssertEqual(result.rating, 35.4)
        XCTAssertEqual(result.calculationIndex, 11.5)
    }

    func testChangingTeeRecalculatesCourseHandicapAndPreservesIndex() {
        let first = tee()
        let player = HandicapCalculator.participant(participant(first), applying: 23, format: .courseHandicap,
            courseSegment: segment(first), handicapStrokeBasis: .eighteenHole)
        let second = tee(backRating: 37, backSlope: 140)
        let updated = HandicapCalculator.recomputedParticipants([player], format: .courseHandicap,
            courseSegment: segment(second), handicapStrokeBasis: .eighteenHole)[0]
        XCTAssertEqual(player.adjustedHandicap, 11)
        XCTAssertEqual(updated.adjustedHandicap, 15)
        XCTAssertEqual(updated.handicapIndex, 23)
    }

    func testManualStrokesPreserveIndexAndDoNotChangeWithTeesForOnlineAndOfflinePlayers() {
        let tee = tee()
        for userID in [nil, "registered-user"] as [String?] {
            var player = participant(tee)
            player.userID = userID
            let indexed = HandicapCalculator.participant(player, applying: 23, format: .courseHandicap,
                courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)
            let manual = HandicapCalculator.participant(indexed, applying: 15, format: .strokes,
                courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)
            XCTAssertEqual(manual.handicapIndex, 23)
            XCTAssertEqual(manual.adjustedHandicap, 15)
            XCTAssertEqual(manual.handicapResolution?.entryFormat, .strokes)
            XCTAssertEqual(HandicapCalculator.recomputedParticipants([manual], format: .courseHandicap,
                courseSegment: segment(self.tee(backSlope: 140)), handicapStrokeBasis: .eighteenHole)[0], manual)
        }
    }

    func testLeagueValidationRejectsUnconfirmedEstimatesAndMissingData() {
        for tee in [tee(frontRating: nil), tee(slope: 0, frontSlope: nil)] {
            let resolved = SeriesCourseHandicapResolver.resolve(effectiveIndex: 8.5, memberID: "m", memberName: "Member",
                requestedTeeID: tee.id, tee: tee, courseID: "c", courseName: "Course", holeSegment: .front9,
                entryFormat: .courseHandicap, handicapStrokeBasis: .nineHole, maximumHandicap: 21)
            XCTAssertNil(resolved.effectiveStrokes)
            XCTAssertNotNil(resolved.validationIssue)
            XCTAssertNil(resolved.snapshot())
        }
    }

    func testHistoricalLeagueSnapshotAndCommissionerOverrideRemainFrozen() throws {
        let tee = tee()
        let resolved = SeriesCourseHandicapResolver.resolve(effectiveIndex: 8.5, memberID: "m", memberName: "Member",
            requestedTeeID: tee.id, tee: tee, courseID: "c", courseName: "Course", holeSegment: .back9,
            entryFormat: .courseHandicap, handicapStrokeBasis: .nineHole, maximumHandicap: 21)
        var frozen = participant(tee)
        frozen.handicapIndex = 8.5
        frozen.handicapSnapshot = try XCTUnwrap(resolved.snapshot())
        frozen.leagueHandicapStrokesAtCreation = resolved.effectiveStrokes
        frozen.adjustedHandicap = try XCTUnwrap(resolved.effectiveStrokes)
        let overridden = frozen.applyingLeagueHandicapOverride(17, maximum: 21)
        XCTAssertEqual(overridden.lockedHandicapAllowance, 17)
        XCTAssertEqual(overridden.handicapSnapshot, frozen.handicapSnapshot)
        XCTAssertEqual(HandicapCalculator.participant(overridden, applying: 30, format: .courseHandicap,
            courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole, approveEstimate: true), overridden)
        XCTAssertEqual(HandicapCalculator.recomputedParticipants([overridden], format: .courseHandicap,
            courseSegment: segment(self.tee(backSlope: 140)), handicapStrokeBasis: .eighteenHole)[0], overridden)
        XCTAssertEqual(overridden.restoringLeagueHandicapComputedBaseline()?.lockedHandicapAllowance, frozen.lockedHandicapAllowance)
        let decoded = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(overridden))
        XCTAssertEqual(decoded.handicapSnapshot, frozen.handicapSnapshot)
        XCTAssertEqual(decoded.lockedHandicapAllowance, 17)
    }

    func testResolvedCourseHandicapAllocatesItsFullAllowanceOverThePlayedNine() {
        let tee = tee()
        let courseHandicap = HandicapCalculator.calculation(index: 23, tee: tee, segment: .back9, indexBasis: .eighteenHole).courseHandicap!
        let received = (10...18).map {
            ScoringEngine.strokesReceived(handicap: courseHandicap, holeNumber: $0, holes: tee.holes,
                playedHoleNumbers: Array(10...18), useHandicaps: true, handicapStrokeBasis: .nineHole)
        }
        XCTAssertEqual(received.reduce(0, +), 11)
        XCTAssertEqual(received.filter { $0 == 2 }.count, 2)
        XCTAssertEqual(received.filter { $0 == 1 }.count, 7)
    }
    func testExplicitLegacyBasisIsReadableButUnknownBasisIsNeverInferredFromRoundLength() {
        var configuration = RoundConfiguration(courses: [segment(tee())], handicapEntryFormat: .courseHandicap)
        let unknown = RoundSnapshot(round: Round(configuration: configuration))
        XCTAssertEqual(unknown.handicapStrokeBasis, .nineHole)
        XCTAssertNil(unknown.handicapIndexBasis)
        configuration.handicapStrokeBasis = .eighteenHole
        XCTAssertEqual(RoundSnapshot(round: Round(configuration: configuration)).handicapIndexBasis, .eighteenHole)
    }

    func testSwitchingIndexToStrokesRequiresAnExplicitNewRoundAllowance() {
        let tee = tee()
        let indexed = HandicapCalculator.participant(participant(tee), applying: 23, format: .courseHandicap,
            courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)
        let pending = HandicapCalculator.recomputedParticipants([indexed], format: .strokes,
            courseSegment: segment(tee), changingEntryFormat: true)[0]
        XCTAssertEqual(pending.handicapIndex, 23)
        XCTAssertNil(pending.handicapResolution?.effectiveStrokes)
        XCTAssertFalse(HandicapCalculator.isReady(pending, format: .strokes, courseSegment: segment(tee), indexBasis: .eighteenHole))
        let manual = HandicapCalculator.participant(pending, applying: 10, format: .strokes, courseSegment: segment(tee))
        XCTAssertEqual(manual.handicapIndex, 23)
        XCTAssertEqual(manual.adjustedHandicap, 10)
        XCTAssertTrue(HandicapCalculator.isReady(manual, format: .strokes, courseSegment: segment(tee), indexBasis: .eighteenHole))
    }

    func testPersistedLegacyNineLobbyReconcilesAllocationWhenSourceBasisChanges() throws {
        let tee = tee(rating: 72, slope: 113, frontRating: 36, frontSlope: 113, backRating: 36, backSlope: 113)
        let legacy = RoundConfiguration(courses: [segment(tee, .front9)], handicapStrokeBasis: .eighteenHole,
            handicapIndexBasis: nil, handicapEntryFormat: .courseHandicap)
        let persisted = try JSONDecoder().decode(RoundConfiguration.self, from: JSONEncoder().encode(legacy))
        let updated = HandicapCalculator.configuration(persisted, settingHandicapBasis: .nineHole, playedHoleCount: 9)
        XCTAssertEqual(updated.handicapIndexBasis, .nineHole)
        XCTAssertEqual(updated.handicapStrokeBasis, .nineHole)
        let p = HandicapCalculator.participant(participant(tee), applying: 8.5, format: .courseHandicap,
            courseSegment: segment(tee, .front9), handicapStrokeBasis: updated.handicapIndexBasis)
        XCTAssertEqual(p.handicapResolution?.calculation?.courseHandicap, 9)
        XCTAssertEqual(ScoringEngine.handicapStrokesForPlayedHoles(handicap: p.adjustedHandicap,
            basis: updated.handicapStrokeBasis!, holesInPlay: 9), 9)
        XCTAssertEqual(persisted.handicapStrokeBasis, .eighteenHole)
    }

    func testBlankIndexDraftSavesOtherFieldsWithoutInventingAHandicap() {
        XCTAssertTrue(HandicapCalculator.isValidDraft("", format: .courseHandicap))
        XCTAssertFalse(HandicapCalculator.isValidDraft("", format: .strokes))
        for invalid in ["-", "NaN", "infinity", "1.2.3"] {
            XCTAssertFalse(HandicapCalculator.isValidDraft(invalid, format: .courseHandicap))
        }
        let tee = tee()
        var edited = participant(tee)
        edited.name = Name("Edited", "Name")
        edited.groupID = "new-group"
        let saved = HandicapCalculator.participant(edited, applying: nil, format: .courseHandicap,
            courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)
        XCTAssertEqual(saved.name, edited.name)
        XCTAssertEqual(saved.groupID, "new-group")
        XCTAssertNil(saved.handicapIndex)
        XCTAssertNil(saved.handicapResolution?.effectiveStrokes)
        XCTAssertFalse(HandicapCalculator.isReady(saved, format: .courseHandicap, courseSegment: segment(tee), indexBasis: .eighteenHole))
        XCTAssertEqual(saved.adjustedHandicap, edited.adjustedHandicap, "Unrelated legacy strokes are not silently changed to zero")
    }

    @MainActor
    func testLiveAndPausedCourseHandicapSettersKeepFrozenSetup() async {
        let tee = tee()
        XCTAssertTrue(RoundStatus.lobby.allowsCourseHandicapSetupEdits)
        for status: RoundStatus in [.live, .paused, .complete, .archived] {
            XCTAssertFalse(status.allowsCourseHandicapSetupEdits)
            let session = RoundSession()
            let configuration = RoundConfiguration(courses: [segment(tee)], handicapStrokeBasis: .nineHole,
                handicapIndexBasis: .eighteenHole, handicapEntryFormat: .courseHandicap)
            let frozen = HandicapCalculator.participant(participant(tee), applying: 23, format: .courseHandicap,
                courseSegment: segment(tee), handicapStrokeBasis: .eighteenHole)
            session.snapshot = .init(round: Round(id: "frozen", status: status, configuration: configuration), participants: [frozen])
            await session.setHandicapStrokeBasis(.nineHole)
            await session.setHandicapEntryFormat(.strokes)
            await session.setDefaultTee(to: "another-tee")
            await session.setCourseSegment(to: segment(tee, .full18))
            XCTAssertEqual(session.snapshot.configuration, configuration)
            XCTAssertEqual(session.snapshot.participants, [frozen])
        }
    }

}
