import XCTest
@testable import Hackers

@MainActor
final class SeriesCourseHandicapValidationTests: XCTestCase {
    private let pars = [4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 3, 4, 4, 5, 3, 4, 4, 5]

    private func tee(id: String = "blue-original", rating: Double = 72.2, slope: Int = 137,
                     frontRating: Double? = 36.4, frontSlope: Int? = 130,
                     backRating: Double? = 35.8, backSlope: Int? = 143,
                     missingPar: Bool = false) -> Tee {
        Tee(id: id, name: "Blue", gender: "male", totalHoles: 18,
            holes: pars.enumerated().map { Hole(number: $0.offset + 1,
                par: missingPar && $0.offset == 17 ? 0 : $0.element, yardage: 400, handicap: $0.offset + 1) },
            ratingFull: rating, slopeFull: slope, ratingFront: frontRating, slopeFront: frontSlope,
            ratingBack: backRating, slopeBack: backSlope)
    }

    private func course(id: String = "selected-library-document", provider: GolfCourseID = 27322, tee: Tee? = nil) -> Course {
        Course(id: id, golfCourseApiID: provider, origin: .hackers,
            clubName: "The Preserve at Verdae", courseName: "The Preserve at Verdae", tees: [tee ?? self.tee()])
    }

    private func selection(_ course: Course, holes: HoleSegment = .full18) -> SeriesCourseSelection {
        SeriesRoundCourseHandicapAvailability.selection(from: segment(course, holes: holes))
    }

    private func segment(_ course: Course, holes: HoleSegment) -> CourseSegment {
        CourseSegment(courseInfo: CourseInfo(course: course, for: holes), holeRange: holes.holeRange,
            defaultTee: course.tees[0].id)
    }

    func testSelectedLibraryDocumentIsNotReplacedByProviderReference27322() {
        let course = course()
        let selected = selection(course)
        XCTAssertEqual(selected.courseID, course.id)
        XCTAssertNotEqual(selected.courseID, String(course.golfCourseApiID!))
        XCTAssertEqual(selected.defaultTeeBoxID, course.tees[0].id)
        XCTAssertEqual(selected.defaultTeeName, "Blue")
        XCTAssertEqual(selected.defaultTeeGender, "male")
    }

    func testVerdaeMensBlue18FrontAndBackUseExactIndependentData() throws {
        let course = course()
        for (holes, rating, slope, par, strokes) in [(HoleSegment.full18, 72.2, 137, 72, 22),
                (.front9, 36.4, 130, 36, 11), (.back9, 35.8, 143, 36, 11)] {
            let selected = selection(course, holes: holes)
            let checked = SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course)
            XCTAssertEqual(checked.status, .ready)
            XCTAssertEqual(checked.calculation?.rating, rating)
            XCTAssertEqual(checked.calculation?.slope, slope)
            XCTAssertEqual(checked.calculation?.par, par)
            let saved = HandicapCalculator.participant(RoundParticipant(teeBoxID: selected.defaultTeeBoxID),
                applying: 17.7, format: .courseHandicap, courseSegment: checked.courseSegment, handicapStrokeBasis: .eighteenHole)
            XCTAssertEqual(saved.handicapIndex, 17.7)
            XCTAssertEqual(saved.handicapResolution?.calculation?.rating, checked.calculation?.rating)
            XCTAssertEqual(saved.handicapResolution?.calculation?.slope, checked.calculation?.slope)
            XCTAssertEqual(saved.handicapResolution?.calculation?.par, checked.calculation?.par)
            XCTAssertEqual(saved.adjustedHandicap, strokes)
            XCTAssertEqual(saved.teeBoxID, selected.defaultTeeBoxID)
        }
    }

    func testBothProviderIDsPreserveTheirSelectedDocumentAndTee() {
        for provider in [GolfCourseID(24833), GolfCourseID(27322)] {
            let course = course(id: "library-\(provider)", provider: provider)
            for holes in [HoleSegment.full18, .front9, .back9] {
                let selected = selection(course, holes: holes)
                let checked = SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course)
                XCTAssertEqual(checked.status, .ready)
                XCTAssertEqual(checked.courseSegment?.courseInfo.id, course.id)
                XCTAssertEqual(checked.courseSegment?.courseInfo.golfCourseApiID, provider)
                XCTAssertEqual(checked.courseSegment?.defaultTee, course.tees[0].id)
            }
        }
    }

    func test24833CachedRecordWithoutNineHoleValuesIsEstimatedNotMissing() {
        let course = course(id: "24833", provider: 24833, tee: tee(id: "blue_male", frontRating: nil, frontSlope: nil, backRating: nil, backSlope: nil))
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selection(course), course: course).status, .ready)
        for holes in [HoleSegment.front9, .back9] {
            let checked = SeriesRoundCourseHandicapAvailability.evaluate(selection(course, holes: holes), course: course)
            XCTAssertEqual(checked.status, .estimated)
            XCTAssertTrue(checked.permitsConfiguration) // Existing planned-round policy.
            XCTAssertNil(checked.calculation?.allowedStrokes(maximum: nil))
            XCTAssertNotNil(checked.calculation?.allowedStrokes(maximum: nil, estimateApproved: true))
            XCTAssertTrue(checked.message.contains("approval"))
        }
    }

    func testMissingTeeNeverFallsBackToFirstEvenWhenBothHaveRatings() {
        let original = course()
        let refreshed = course(tee: tee(id: "blue-refreshed"))
        let checked = SeriesRoundCourseHandicapAvailability.evaluate(selection(original), course: refreshed)
        XCTAssertEqual(checked.status, .teeUnavailable)
        XCTAssertFalse(checked.permitsConfiguration)
        XCTAssertNil(checked.courseSegment)
    }

    func testEmptyTeeDoesNotSelectFirstTee() {
        let course = course()
        var selected = selection(course)
        selected.defaultTeeBoxID = ""
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course).status, .teeUnavailable)
    }

    func testReusedTeeIDWithDifferentIdentityRequiresReview() {
        let course = course()
        var selected = selection(course)
        selected.defaultTeeName = "White"
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course).status, .teeUnavailable)
        selected.defaultTeeName = "Blue"
        selected.defaultTeeGender = "female"
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course).status, .teeUnavailable)
    }

    func testLegacySelectionWithoutCachedNameOrGenderStillUsesItsExactTeeID() {
        let course = course()
        var selected = selection(course)
        selected.defaultTeeName = nil
        selected.defaultTeeGender = nil
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course).status, .ready)
    }

    func testDifferentCourseRecordCannotValidateSelectionEvenWithSameProviderReference() {
        let original = course(id: "selected")
        let other = course(id: "other")
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selection(original), course: other).status, .loadFailed)
    }

    func testGenuineMissingRatingSlopeAndParAreDistinguished() {
        for (tee, field) in [(tee(rating: 0), "Course Rating"), (tee(slope: 0), "Slope"), (tee(missingPar: true), "hole pars")] {
            let course = course(tee: tee)
            let checked = SeriesRoundCourseHandicapAvailability.evaluate(selection(course), course: course)
            XCTAssertEqual(checked.status, .missingData)
            XCTAssertFalse(checked.permitsConfiguration)
            XCTAssertTrue(checked.message.contains(field), checked.message)
            XCTAssertTrue(checked.message.contains("Blue"))
            XCTAssertFalse(checked.message.contains("Repair"))
        }
    }

    func testMissingBackNineParDoesNotInvalidateFrontNine() {
        let course = course(tee: tee(missingPar: true))
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selection(course, holes: .front9), course: course).status, .ready)
        XCTAssertEqual(SeriesRoundCourseHandicapAvailability.evaluate(selection(course, holes: .back9), course: course).status, .missingData)
    }

    func testZeroIndexIsCompleteForAllSegments() {
        let course = course()
        for holes in [HoleSegment.full18, .front9, .back9] {
            let selected = selection(course, holes: holes)
            let checked = SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course)
            let saved = HandicapCalculator.participant(RoundParticipant(teeBoxID: selected.defaultTeeBoxID),
                applying: 0, format: .courseHandicap, courseSegment: checked.courseSegment, handicapStrokeBasis: .eighteenHole)
            XCTAssertEqual(saved.handicapIndex, 0)
            XCTAssertEqual(saved.handicapResolution?.effectiveStrokes, 0)
        }
    }

    func testManualZeroDoesNotRequireCourseMetadataOrBecomeAnIndex() throws {
        var draft = SeriesRoundDraft(settings: .init(), suggestedCourse: nil, usesTeams: false)
        draft.handicapEntryFormat = .strokes
        XCTAssertNoThrow(try draft.persistedValues(usesTeams: false,
            courseValidation: .init(selection: nil, status: .loadFailed), fallbackTitle: "Manual"))
        let saved = HandicapCalculator.participant(RoundParticipant(), applying: 0, format: .strokes, courseSegment: nil)
        XCTAssertEqual(saved.handicapResolution?.effectiveStrokes, 0)
        XCTAssertNil(saved.handicapIndex)
    }

    func testSavedCourseAndReopenedDraftRetainExactIdentityAndConfiguration() throws {
        let course = course()
        let selected = selection(course, holes: .back9)
        let checked = SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course)
        var config = SeriesRoundConfiguration()
        config.handicapEntryFormat = .courseHandicap
        config.scoreBasisOverride = .net
        config.handicapNormalizationMode = .matchup
        let round = SeriesRound(id: "planned", courseOverride: selected, roundConfig: config, parentID: "series")
        let draft = SeriesRoundDraft(seriesRound: round, fallbackCourse: nil, usesTeams: false)
        let values = try draft.persistedValues(usesTeams: false, courseValidation: checked, fallbackTitle: "Round")
        XCTAssertEqual(values.courseOverride, selected)
        XCTAssertEqual(values.roundConfig.scoreBasisOverride, .net)
        XCTAssertEqual(values.roundConfig.handicapEntryFormat, .courseHandicap)
        XCTAssertEqual(draft.selectedCourse, selected)
    }

    func testNewlySelectedCourseIsPersistedUsingTheValidatedDocument() throws {
        let course = course()
        let selected = selection(course)
        var draft = SeriesRoundDraft(settings: .init(), suggestedCourse: nil, usesTeams: false)
        draft.selectedCourse = selected
        draft.handicapEntryFormat = .courseHandicap
        let checked = SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course)
        let values = try draft.persistedValues(usesTeams: false, courseValidation: checked, fallbackTitle: "Round")
        XCTAssertEqual(values.courseOverride, selected)
        XCTAssertEqual(values.courseOverride?.courseID, course.id)
    }

    func testFailedValidationLeavesTitleCourseScoringAndDraftInputsUntouched() {
        let course = course()
        var draft = SeriesRoundDraft(settings: .init(), suggestedCourse: selection(course), usesTeams: false)
        draft.title = "My unchanged round"
        draft.notes = "Keep my notes"
        draft.handicapEntryFormat = .courseHandicap
        let original = draft
        XCTAssertThrowsError(try draft.persistedValues(usesTeams: false,
            courseValidation: .init(selection: selection(course), status: .loadFailed), fallbackTitle: "Round"))
        XCTAssertEqual(draft, original)
    }

    func testValidationForPreviousCourseOrSegmentCannotAuthorizeSaving() {
        let course = course()
        let old = SeriesRoundCourseHandicapAvailability.evaluate(selection(course), course: course)
        var draft = SeriesRoundDraft(settings: .init(), suggestedCourse: selection(course, holes: .back9), usesTeams: false)
        draft.handicapEntryFormat = .courseHandicap
        XCTAssertThrowsError(try draft.persistedValues(usesTeams: false, courseValidation: old, fallbackTitle: "Round"))
    }

    func testCheckingIsNotReportedAsMissingRatingOrSlope() {
        let checked = SeriesCourseHandicapValidation(selection: selection(course()), status: .checking)
        XCTAssertEqual(checked.message, "Checking course data…")
        XCTAssertFalse(checked.permitsConfiguration)
        XCTAssertFalse(checked.message.contains("missing"))
    }

    func testNetworkFailureAndRetry() async {
        let course = course()
        var fails = true
        let store = SeriesCourseHandicapValidationStore { _ in
            if fails { throw URLError(.notConnectedToInternet) }
            return course
        }
        await store.refresh(selection(course))
        XCTAssertEqual(store.result.status, .loadFailed)
        XCTAssertFalse(store.result.message.contains("rating"))
        fails = false
        await store.refresh(selection(course))
        XCTAssertEqual(store.result.status, .ready)
    }

    func testLateOldCourseResponseCannotReplaceNewSelection() async {
        let old = course(id: "old")
        let new = course(id: "new")
        var suspended: CheckedContinuation<Course, Error>?
        let store = SeriesCourseHandicapValidationStore { selected in
            if selected.courseID == old.id { return try await withCheckedThrowingContinuation { suspended = $0 } }
            return new
        }
        let pending = Task { await store.refresh(selection(old)) }
        while suspended == nil { await Task.yield() }
        await store.refresh(selection(new, holes: .back9))
        suspended?.resume(returning: old)
        await pending.value
        XCTAssertEqual(store.result.selection, selection(new, holes: .back9))
        XCTAssertEqual(store.result.status, .ready)
    }

    func testLateOldTeeFailureCannotReplaceReadyCurrentTee() async {
        let course = course()
        let selected = selection(course)
        var old = selected
        old.defaultTeeBoxID = "old-tee"
        var suspended: CheckedContinuation<Course, Error>?
        let store = SeriesCourseHandicapValidationStore { value in
            if value.defaultTeeBoxID == "old-tee" { return try await withCheckedThrowingContinuation { suspended = $0 } }
            return course
        }
        let pending = Task { await store.refresh(old) }
        while suspended == nil { await Task.yield() }
        await store.refresh(selected)
        suspended?.resume(throwing: URLError(.timedOut))
        await pending.value
        XCTAssertEqual(store.result.selection, selected)
        XCTAssertEqual(store.result.status, .ready)
    }

    func testCommitRevalidatesRatherThanTrustingAnEarlierReadyResult() async {
        let good = course()
        let bad = course(tee: tee(slope: 0))
        var current = good
        let store = SeriesCourseHandicapValidationStore { _ in current }
        await store.refresh(selection(good))
        XCTAssertEqual(store.result.status, .ready)
        current = bad
        let checked = await store.revalidate(selection(good))
        XCTAssertEqual(checked.status, .missingData)
        XCTAssertFalse(checked.permitsConfiguration)
    }
    func testLiveRoundPayloadUsesTheValidatedCourseAndFrozenIndexResolution() throws {
        let course = course()
        let member = SeriesMember(id: "member", playerID: "player", name: Name("Fixture"), parentID: "series")
        for holes in [HoleSegment.full18, .front9, .back9] {
            let selected = selection(course, holes: holes)
            let checked = SeriesRoundCourseHandicapAvailability.evaluate(selected, course: course)
            let segment = try XCTUnwrap(checked.courseSegment)
            for basis in [ScoreBasis.gross, .net] {
                var config = SeriesRoundConfiguration()
                config.handicapEntryFormat = .courseHandicap
                config.scoreBasisOverride = basis
                let series = Series(id: "series", settings: SeriesSettings(useTeams: false))
                let planned = SeriesRound(id: "planned", courseOverride: selected, roundConfig: config, parentID: series.id)
                let round = SeriesRoundCreationMapping.roundDraft(id: "live", shareCode: "FIXTURE", createdBy: "owner",
                    series: series, members: [member], seriesRound: planned, courseSegment: segment)
                XCTAssertEqual(round.configuration.courses.first, segment)
                let players = SeriesRoundCreationMapping.buildParticipantPayloads(members: [member], roundID: round.id,
                    teamMappings: [:], memberAssignments: [:], handicaps: [:], maximumHandicap: nil,
                    courseSegment: segment, handicapEntryFormat: .courseHandicap, handicapStrokeBasis: .eighteenHole,
                    roundHandicapInputs: [member.id: .init(method: .personalIndex, value: 17.7, teeBoxID: selected.defaultTeeBoxID)],
                    hostPlayerID: nil)
                let player = try XCTUnwrap(players.first)
                XCTAssertEqual(player.handicapIndex, 17.7)
                XCTAssertEqual(player.teeBoxID, selected.defaultTeeBoxID)
                XCTAssertEqual(player.handicapSnapshot?.calculation?.rating, checked.calculation?.rating)
                XCTAssertEqual(player.handicapSnapshot?.calculation?.slope, checked.calculation?.slope)
                XCTAssertEqual(player.handicapSnapshot?.calculation?.par, checked.calculation?.par)
                XCTAssertEqual(player.handicapSnapshot?.effectiveStrokes, holes == .full18 ? 22 : 11)
            }
        }
    }

    func testCancelledRequestCannotPublishAfterAReplacementSelection() async {
        let old = course(id: "old")
        let new = course(id: "new")
        var suspended: CheckedContinuation<Course, Error>?
        let store = SeriesCourseHandicapValidationStore { selected in
            if selected.courseID == old.id { return try await withCheckedThrowingContinuation { suspended = $0 } }
            return new
        }
        let pending = Task { await store.refresh(selection(old)) }
        while suspended == nil { await Task.yield() }
        pending.cancel()
        await store.refresh(selection(new))
        suspended?.resume(returning: old)
        await pending.value
        XCTAssertEqual(store.result.selection, selection(new))
        XCTAssertEqual(store.result.status, .ready)
    }

    func testSavedCoursePrefillWorksForFreshModelWhoseDefaultCourseAlreadyHasAnID() async {
        let course = course()
        let model = CourseSelectionViewModel()
        XCTAssertFalse(model.selectedCourse.id.isEmpty)
        let checked = await SeriesRoundCoursePickerSheet.prefillSelection(selection(course, holes: .back9), model: model, load: { _ in course })
        XCTAssertEqual(checked?.status, .ready)
        XCTAssertEqual(model.selectedCourse.id, course.id)
        XCTAssertEqual(model.selectedTee?.id, course.tees[0].id)
        XCTAssertEqual(model.holeSegment, .back9)
        XCTAssertTrue(model.showConfirmation)
    }

    func testLateSavedCoursePrefillCannotReplaceANewUserSelection() async {
        let saved = course(id: "saved")
        let chosen = course(id: "chosen")
        let model = CourseSelectionViewModel()
        var suspended: CheckedContinuation<Course, Error>?
        let pending = Task {
            await SeriesRoundCoursePickerSheet.prefillSelection(selection(saved), model: model,
                load: { _ in try await withCheckedThrowingContinuation { suspended = $0 } })
        }
        while suspended == nil { await Task.yield() }
        model.select(course: chosen, source: .search, trackEvent: false)
        model.selectedTee = chosen.tees[0]
        suspended?.resume(returning: saved)
        let result = await pending.value
        XCTAssertNil(result)
        XCTAssertEqual(model.selectedCourse.id, chosen.id)
        XCTAssertEqual(model.selectedTee?.id, chosen.tees[0].id)
    }

    func testLateSavedCoursePrefillPreservesUserTeeAndHoleEdits() async {
        let saved = course()
        for changeTee in [true, false] {
            let model = CourseSelectionViewModel()
            var suspended: CheckedContinuation<Course, Error>?
            let pending = Task {
                await SeriesRoundCoursePickerSheet.prefillSelection(selection(saved), model: model,
                    load: { _ in try await withCheckedThrowingContinuation { suspended = $0 } })
            }
            while suspended == nil { await Task.yield() }
            if changeTee { model.selectedTee = tee(id: "user-tee") }
            else { model.holeSegment = .back9 }
            suspended?.resume(returning: saved)
            let result = await pending.value
            XCTAssertNil(result)
            if changeTee { XCTAssertEqual(model.selectedTee?.id, "user-tee") }
            else { XCTAssertEqual(model.holeSegment, .back9) }
        }
    }

}
