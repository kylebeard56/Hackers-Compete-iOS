import SwiftUI
import UIKit
import XCTest
@testable import Hackers

final class RoundHandicapEntryTests: XCTestCase {
    private func course(_ holes: HoleSegment = .full18, slope: Int = 143, estimated: Bool = false) -> CourseSegment {
        let tee = Tee(id: "black", name: "Black", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: 73.9, slopeFull: slope,
            ratingFront: estimated ? nil : 35.2, slopeFront: estimated ? nil : 118,
            ratingBack: estimated ? nil : 34.7, slopeBack: estimated ? nil : 124)
        return CourseSegment(courseInfo: .init(id: "course", name: "Course", totalHoles: 18, tees: [tee]),
            holeRange: holes.holeRange, defaultTee: tee.id)
    }

    private func indexed(_ segment: CourseSegment? = nil) -> RoundParticipant {
        HandicapCalculator.participant(RoundParticipant(id: "p", teeBoxID: "black"), applying: 22.6,
            format: .courseHandicap, courseSegment: segment ?? course(), maximumHandicap: 21,
            handicapStrokeBasis: .eighteenHole)
    }

    @MainActor
    func testMobileModePickerLabelsAndSelectionBinding() async throws {
        var selected: HandicapEntryFormat = .strokes
        let host = UIHostingController(rootView: HandicapEntryModePicker(selection: Binding(
            get: { selected }, set: { selected = $0 }
        )).padding().frame(width: 390))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        host.view.layoutIfNeeded()
        func segmentedControl(in view: UIView) -> UISegmentedControl? {
            if let control = view as? UISegmentedControl { return control }
            return view.subviews.lazy.compactMap { segmentedControl(in: $0) }.first
        }
        let control = try XCTUnwrap(segmentedControl(in: host.view))
        XCTAssertEqual(control.numberOfSegments, 2)
        XCTAssertEqual(control.titleForSegment(at: 0), "Handicap Index")
        XCTAssertEqual(control.titleForSegment(at: 1), "Strokes Received")
        XCTAssertEqual(control.selectedSegmentIndex, 1)
        control.selectedSegmentIndex = 0
        control.sendActions(for: .valueChanged)
        XCTAssertEqual(selected, .courseHandicap)
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { context in
            host.view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Handicap entry mode picker at mobile width"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testIndexModePreservesIndexRawCourseHandicapAndCappedStrokes() {
        var draft = RoundHandicapEntryDraft(participant: .init(teeBoxID: "black"), defaultFormat: .courseHandicap)
        draft.text = "22.67"
        let player = draft.applying(to: .init(teeBoxID: "black"), courseSegment: course(), indexBasis: .eighteenHole, maximum: 21)
        XCTAssertEqual(draft.text, "22.6")
        XCTAssertEqual(player.handicapIndex, 22.6)
        XCTAssertEqual(player.handicapResolution?.calculation?.courseHandicap, 31)
        XCTAssertEqual(player.handicapResolution?.effectiveStrokes, 21)
    }

    func testSwitchingDraftModesNeverReinterpretsIndexAsStrokes() {
        var draft = RoundHandicapEntryDraft(participant: indexed(), defaultFormat: .courseHandicap)
        draft.format = .strokes
        XCTAssertEqual(draft.text, "")
        XCTAssertNil(draft.value)
        draft.text = "14"
        draft.format = .courseHandicap
        XCTAssertEqual(draft.text, "22.6")
        draft.format = .strokes
        XCTAssertEqual(draft.text, "14")
    }

    func testStrokesAcceptOnlyWholeNumbersAndRetainUncappedManualInput() throws {
        var draft = RoundHandicapEntryDraft(participant: indexed(), defaultFormat: .courseHandicap)
        draft.format = .strokes
        draft.text = "40"
        let player = draft.applying(to: indexed(), courseSegment: nil, indexBasis: .eighteenHole, maximum: 21)
        XCTAssertEqual(player.adjustedHandicap, 21)
        XCTAssertEqual(player.handicapResolution?.manualStrokes, 40)
        XCTAssertEqual(player.handicapIndex, 22.6)
        let decoded = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(player))
        XCTAssertEqual(RoundHandicapEntryDraft(participant: decoded, defaultFormat: .courseHandicap).text, "40")
        draft.text = "12.3"
        XCTAssertEqual(draft.text, "40") // Reject decimal strokes rather than concatenating digits.
        draft.text = ""
        draft.text = "abc"
        XCTAssertNil(draft.value)
        XCTAssertEqual(draft.applying(to: player, courseSegment: nil, indexBasis: nil, maximum: 21), player)
    }

    func testRoundModeSwitchRestoresExplicitStrokesWithoutUsingCourseHandicap() {
        let initial = indexed()
        let manual = HandicapCalculator.participant(initial, applying: 12, format: .strokes, courseSegment: course())
        let indexMode = HandicapCalculator.recomputedParticipants([manual], format: .courseHandicap,
            courseSegment: course(), handicapStrokeBasis: .eighteenHole, changingEntryFormat: true)[0]
        XCTAssertEqual(indexMode.handicapIndex, 22.6)
        XCTAssertEqual(indexMode.handicapResolution?.manualStrokes, 12)
        let strokesMode = HandicapCalculator.recomputedParticipants([indexMode], format: .strokes,
            courseSegment: course(), changingEntryFormat: true)[0]
        XCTAssertEqual(strokesMode.adjustedHandicap, 12)
        XCTAssertEqual(strokesMode.handicapResolution?.effectiveStrokes, 12)
        XCTAssertEqual(strokesMode.handicapIndex, 22.6)
    }

    func testNewStrokesModeRequiresInputAndDisplaysPendingState() {
        let player = HandicapCalculator.recomputedParticipants([indexed()], format: .strokes,
            courseSegment: course(), changingEntryFormat: true)[0]
        XCTAssertNil(player.handicapResolution?.effectiveStrokes)
        XCTAssertEqual(RoundHandicapEntryDraft(participant: player, defaultFormat: .strokes).text, "")
        XCTAssertEqual(CourseHandicapRosterDisplay.label(participant: player, courseSegment: course(), handicapStrokeBasis: .eighteenHole,
            defaultTee: nil, tees: [], maximumHandicap: nil), "Enter strokes for this round")
    }

    func testEditedIndexSurvivesExplicitManualRecovery() {
        var draft = RoundHandicapEntryDraft(participant: .init(teeBoxID: "missing"), defaultFormat: .courseHandicap)
        draft.text = "23.0"
        draft.format = .strokes
        draft.text = "10"
        let result = draft.applying(to: .init(teeBoxID: "missing"), courseSegment: course(), indexBasis: .eighteenHole, maximum: 36)
        XCTAssertEqual(result.handicapIndex, 23)
        XCTAssertEqual(result.handicapResolution?.calculation?.status, .unavailable)
        XCTAssertEqual(result.handicapResolution?.entryFormat, .strokes)
        XCTAssertEqual(result.adjustedHandicap, 10)
        XCTAssertTrue(HandicapCalculator.isReady(result, format: .courseHandicap, courseSegment: course(), indexBasis: .eighteenHole))
    }

    func testMissingMetadataAffectsOnlyOnePlayerAndKeepsRoundInIndexMode() {
        let configuration = RoundConfiguration(courses: [course()], handicapIndexBasis: .eighteenHole, handicapEntryFormat: .courseHandicap)
        let good = indexed()
        var missing = good
        missing.id = "missing"
        missing.teeBoxID = "deleted"
        let result = HandicapCalculator.recomputedParticipants([good, missing], format: configuration.handicapEntryFormat,
            courseSegment: course(), maximumHandicap: 21, handicapStrokeBasis: .eighteenHole)
        XCTAssertEqual(result[0], good)
        XCTAssertEqual(result[1].handicapIndex, 22.6)
        XCTAssertNil(result[1].handicapResolution?.effectiveStrokes)
        XCTAssertEqual(configuration.handicapEntryFormat, .courseHandicap)
    }

    func testCourseAndSegmentChangesRecalculateIndexButPreserveManualStrokes() {
        let first = indexed()
        let manual = HandicapCalculator.participant(first, applying: 15, format: .strokes, courseSegment: course())
        let changed = HandicapCalculator.recomputedParticipants([first, manual], format: .courseHandicap,
            courseSegment: course(.back9), maximumHandicap: 21, handicapStrokeBasis: .eighteenHole)
        XCTAssertEqual(changed[0].handicapIndex, 22.6)
        XCTAssertEqual(changed[0].handicapResolution?.calculation?.calculationIndex, 11.3)
        XCTAssertNotEqual(changed[0].adjustedHandicap, first.adjustedHandicap)
        XCTAssertEqual(changed[1], manual)
    }

    func testEstimateApprovalSurvivesReopeningAndChangesOnlyWhenInputsChange() {
        let segment = course(.back9, estimated: true)
        var draft = RoundHandicapEntryDraft(participant: indexed(segment), defaultFormat: .courseHandicap)
        let pending = draft.applying(to: indexed(segment), courseSegment: segment, indexBasis: .eighteenHole, maximum: 36)
        XCTAssertNil(pending.handicapResolution?.effectiveStrokes)
        let approved = draft.applying(to: pending, courseSegment: segment, indexBasis: .eighteenHole, maximum: 36, approveEstimate: true, approvedBy: "host")
        draft = RoundHandicapEntryDraft(participant: approved, defaultFormat: .courseHandicap)
        let reopened = draft.applying(to: approved, courseSegment: segment, indexBasis: .eighteenHole, maximum: 36)
        XCTAssertEqual(reopened.handicapResolution?.estimateApprovedAt, approved.handicapResolution?.estimateApprovedAt)
        XCTAssertEqual(reopened.handicapResolution?.approvedBy, "host")
        let changed = draft.applying(to: approved, courseSegment: course(.back9, slope: 120, estimated: true), indexBasis: .eighteenHole, maximum: 36)
        XCTAssertNil(changed.handicapResolution?.estimateApprovedAt)
        XCTAssertNil(changed.handicapResolution?.effectiveStrokes)
    }

    func testPersonalPrefillWhenSelectingIndexAfterPlayersWereAdded() throws {
        var profile = Player(id: "profile", userID: "user", name: .init("Test", "Player"))
        profile.personalHandicap = .init(manual: try .init(value: 23, source: .manual))
        var player = RoundParticipant(player: profile, teeBoxID: "black")
        player = HandicapCalculator.participant(player, applying: 12, format: .strokes, courseSegment: nil)
        let configuration = RoundConfiguration(courses: [course(.back9)], handicapIndexBasis: .eighteenHole, handicapEntryFormat: .courseHandicap)
        let prefilled = PersonalHandicapRoundPrefill.participant(player, player: profile, configuration: configuration,
            isLeagueRound: false, selectingEntryFormat: true)
        XCTAssertEqual(prefilled.handicapIndex, 23)
        XCTAssertEqual(prefilled.personalHandicapInput?.basis, .eighteenHole)
        XCTAssertEqual(prefilled.handicapResolution?.calculation?.courseHandicap, 11)
        XCTAssertEqual(prefilled.handicapResolution?.manualStrokes, 12)
        XCTAssertEqual(RoundHandicapEntryPresentation.indexLabel(prefilled, basis: .eighteenHole), "Personal Handicap Index (18-hole)")
        XCTAssertEqual(profile.personalHandicap?.effectiveIndex, 23)
    }

    func testMissingPersonalIndexRemainsExplicitlyUnresolved() {
        let profile = Player(id: "profile", userID: nil, name: .init("Guest", "Player"))
        let result = PersonalHandicapRoundPrefill.participant(RoundParticipant(player: profile), player: profile,
            configuration: .init(courses: [course()], handicapIndexBasis: .eighteenHole, handicapEntryFormat: .courseHandicap),
            isLeagueRound: false, selectingEntryFormat: true)
        XCTAssertNil(result.handicapIndex)
        XCTAssertNil(result.handicapResolution?.effectiveStrokes)
    }

    func testLeagueIndexBasisAndFrozenSnapshotSurviveEditorAndModeChanges() throws {
        let segment = course(.back9)
        let resolution = SeriesCourseHandicapResolver.resolve(effectiveIndex: 8.5, memberID: "member", memberName: "Player",
            requestedTeeID: "black", tee: segment.tee(from: "black"), courseID: "course", courseName: "Course",
            holeSegment: .back9, entryFormat: .courseHandicap, handicapStrokeBasis: .nineHole, maximumHandicap: 21)
        var player = RoundParticipant(id: "p", teeBoxID: "black", handicapIndex: 8.5,
            handicapSnapshot: try XCTUnwrap(resolution.snapshot()))
        player.seriesMemberID = "member"
        XCTAssertEqual(player.handicapSnapshot?.calculation?.calculationIndex, 8.5)
        var draft = RoundHandicapEntryDraft(participant: player, defaultFormat: .courseHandicap)
        draft.text = "20"
        XCTAssertEqual(draft.applying(to: player, courseSegment: course(), indexBasis: .eighteenHole, maximum: 36), player)
        XCTAssertEqual(HandicapCalculator.recomputedParticipants([player], format: .strokes,
            courseSegment: course(), changingEntryFormat: true)[0], player)
        XCTAssertEqual(RoundHandicapEntryPresentation.indexLabel(player, basis: .nineHole), "League Handicap Index (9-hole)")
    }

    func testSavingIndexKeepsManualBufferForTheNextEdit() {
        let initial = indexed()
        var draft = RoundHandicapEntryDraft(participant: initial, defaultFormat: .courseHandicap)
        draft.format = .strokes
        draft.text = "13"
        draft.format = .courseHandicap
        let saved = draft.applying(to: initial, courseSegment: course(), indexBasis: .eighteenHole, maximum: 21)
        var reopened = RoundHandicapEntryDraft(participant: saved, defaultFormat: .courseHandicap)
        reopened.format = .strokes
        XCTAssertEqual(reopened.value, 13)
        XCTAssertEqual(saved.handicapIndex, 22.6)
    }

    func testExistingExplicitStrokesSurviveIndexSelectionWithoutNewProfileFields() {
        var player = indexed()
        player.handicapResolution = RoundHandicapResolution(entryFormat: .strokes, effectiveStrokes: 12)
        let indexMode = HandicapCalculator.recomputedParticipants([player], format: .courseHandicap,
            courseSegment: course(), handicapStrokeBasis: .eighteenHole, changingEntryFormat: true)[0]
        XCTAssertEqual(indexMode.handicapResolution?.manualStrokes, 12)
        let strokesMode = HandicapCalculator.recomputedParticipants([indexMode], format: .strokes,
            courseSegment: course(), changingEntryFormat: true)[0]
        XCTAssertEqual(strokesMode.handicapResolution?.effectiveStrokes, 12)
        XCTAssertEqual(strokesMode.handicapIndex, 22.6)
    }

    func testLegacyResolutionDecodesWithoutManualDraft() throws {
        let data = Data(#"{"entry_format":"strokes","effective_strokes":12}"#.utf8)
        let resolution = try JSONDecoder().decode(RoundHandicapResolution.self, from: data)
        XCTAssertNil(resolution.manualStrokes)
        let player = RoundParticipant(handicapResolution: resolution)
        XCTAssertEqual(RoundHandicapEntryDraft(participant: player, defaultFormat: .courseHandicap).text, "12")
    }

    func testEmptyAndSignedDecimalDraftValidationDoesNotInventZero() {
        var draft = RoundHandicapEntryDraft(participant: .init(), defaultFormat: .courseHandicap)
        for invalid in ["", "-", ".", "-."] {
            draft.text = invalid
            XCTAssertNil(draft.value)
        }
        draft.text = "-2,38"
        XCTAssertEqual(draft.value, -2.3)
        draft.text = "0.0"
        XCTAssertEqual(draft.value, 0)
    }
}
