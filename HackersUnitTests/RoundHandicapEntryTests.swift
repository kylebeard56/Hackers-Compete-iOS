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
        XCTAssertEqual(RoundHandicapEntryPresentation.indexLabel(prefilled, basis: .eighteenHole), "Handicap Index")
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

    func testRosterIndexPreviewUsesSelectedNineBeforeParticipantRecalculationFinishes() {
        let player = indexed(course(.full18))
        let front = course(.front9)
        let expected = HandicapCalculator.calculation(index: 22.6, participant: player,
            courseSegment: front, indexBasis: .eighteenHole).courseHandicap!
        XCTAssertNotEqual(expected, player.handicapResolution?.calculation?.courseHandicap)
        let label = CourseHandicapRosterDisplay.label(participant: player, courseSegment: front,
            handicapStrokeBasis: .eighteenHole, defaultTee: nil, tees: [], maximumHandicap: 21,
            previewCurrentSelection: true)
        XCTAssertEqual(label, "Course HCP: \(expected) · Strokes Received: \(min(expected, 21))")
        XCTAssertEqual(player.handicapIndex, 22.6)
    }

    func testOfflineTemporaryIndexCalculatesFromRoundDefaultTee() {
        let segment = course(.front9)
        let guest = RoundParticipant(id: "guest", name: Name("Guest", "Player"), teeBoxID: "")
        let resolved = HandicapCalculator.participant(guest, applying: 17.7, format: .courseHandicap,
            courseSegment: segment, handicapStrokeBasis: .eighteenHole)
        XCTAssertTrue(resolved.isOffline)
        XCTAssertEqual(resolved.handicapIndex, 17.7)
        XCTAssertEqual(resolved.handicapResolution?.calculation?.status, .exact)
        XCTAssertNotNil(resolved.handicapResolution?.effectiveStrokes)
        let label = CourseHandicapRosterDisplay.label(participant: resolved, courseSegment: segment,
            handicapStrokeBasis: .eighteenHole, defaultTee: segment.tee(from: "black"),
            tees: segment.courseInfo.tees, maximumHandicap: nil)
        XCTAssertTrue(label?.contains("Course HCP:") == true)
        XCTAssertFalse(label?.contains("Unavailable") == true)
    }

    func testMixedRosterEntryUsesPerPlayerModeInsteadOfRoundWideIndex() throws {
        let indexPlayer = indexed()
        let manualPlayer = HandicapCalculator.participant(indexPlayer, applying: 12, format: .strokes, courseSegment: course())
        let restored = try JSONDecoder().decode(RoundParticipant.self, from: JSONEncoder().encode(manualPlayer))
        XCTAssertEqual(CourseHandicapRosterDisplay.entryFormat(for: indexPlayer, defaultFormat: .strokes), .courseHandicap)
        XCTAssertEqual(CourseHandicapRosterDisplay.entryFormat(for: restored, defaultFormat: .courseHandicap), .strokes)
        XCTAssertEqual(restored.handicapIndex, 22.6)
        let draft = RoundHandicapEntryDraft(participant: restored, defaultFormat: .courseHandicap)
        XCTAssertEqual(draft.format, .strokes)
        XCTAssertEqual(draft.text, "12")
        XCTAssertEqual(draft.indexText, "22.6")
        XCTAssertEqual(CourseHandicapRosterDisplay.label(participant: restored, courseSegment: course(.front9),
            handicapStrokeBasis: .eighteenHole, defaultTee: nil, tees: [], maximumHandicap: nil,
            previewCurrentSelection: true), "Strokes Received: 12 (manual)")
    }

    func testRosterPreviewRequiresNewEstimateApprovalWhenSelectionChanges() throws {
        let segment = course(.front9, estimated: true)
        let approved = HandicapCalculator.participant(indexed(), applying: 22.6, format: .courseHandicap,
            courseSegment: segment, maximumHandicap: 21, approveEstimate: true, approvedBy: "host")
        let strokes = try XCTUnwrap(approved.handicapResolution?.effectiveStrokes)
        let unchanged = CourseHandicapRosterDisplay.label(participant: approved, courseSegment: segment,
            handicapStrokeBasis: .eighteenHole, defaultTee: nil, tees: [], maximumHandicap: 21,
            previewCurrentSelection: true)
        XCTAssertTrue(unchanged?.contains("Strokes Received: \(strokes)") == true)
        let changed = CourseHandicapRosterDisplay.label(participant: approved,
            courseSegment: course(.back9, slope: 120, estimated: true), handicapStrokeBasis: .eighteenHole,
            defaultTee: nil, tees: [], maximumHandicap: 21, previewCurrentSelection: true)
        XCTAssertTrue(changed?.contains("Estimated Course HCP:") == true)
        XCTAssertTrue(changed?.contains("Confirmation required") == true)
        XCTAssertFalse(changed?.contains("Strokes Received:") == true)
        XCTAssertNotNil(approved.handicapResolution?.estimateApprovedAt)
        XCTAssertEqual(approved.handicapResolution?.effectiveStrokes, strokes)
    }

    func testClearedIndexAndMissingCurrentCourseNeverPreviewOldAllowance() {
        let original = indexed()
        var cleared = original
        cleared.handicapIndex = nil
        for (player, segment) in [(cleared, course()), (original, nil)] {
            XCTAssertEqual(CourseHandicapRosterDisplay.label(participant: player, courseSegment: segment,
                handicapStrokeBasis: .eighteenHole, defaultTee: nil, tees: [], maximumHandicap: 21,
                previewCurrentSelection: true), "Course HCP: Unavailable")
        }
        XCTAssertEqual(original.handicapIndex, 22.6)
        XCTAssertEqual(original.handicapResolution?.effectiveStrokes, 21)
    }

    func testSavedHistoricalCalculationAndFrozenLeagueSeedKeepStoredAllowance() {
        var player = indexed()
        let saved = "Course HCP: 31 · Strokes Received: 21"
        XCTAssertEqual(CourseHandicapRosterDisplay.label(participant: player, courseSegment: course(.front9),
            handicapStrokeBasis: .nineHole, defaultTee: nil, tees: [], maximumHandicap: 21), saved)
        player.leagueHandicapStrokesAtCreation = 21
        XCTAssertEqual(CourseHandicapRosterDisplay.label(participant: player, courseSegment: course(.front9),
            handicapStrokeBasis: .nineHole, defaultTee: nil, tees: [], maximumHandicap: 21,
            previewCurrentSelection: true), saved)
        XCTAssertEqual(player.handicapResolution?.calculation?.indexBasis, .eighteenHole)
    }

    func testMixedRegisteredOfflineAndManualEntriesKeepAllowancesThroughNavigationAndReload() throws {
        var segment = course()
        let alternate = Tee(id: "red", name: "Red", gender: "female", totalHoles: 18,
            holes: segment.courseInfo.tees[0].holes, ratingFull: 70, slopeFull: 115,
            ratingFront: 34, slopeFront: 112, ratingBack: 36, slopeBack: 119)
        segment.courseInfo.tees.append(alternate)
        let profiles = [Player(id: "registered", userID: "user", name: .init("Registered", "Player")),
                        Player(id: "guest", userID: nil, name: .init("Offline", "Player"))]
        var players = profiles.enumerated().map { offset, profile in
            HandicapCalculator.participant(RoundParticipant(player: profile, teeBoxID: offset == 0 ? "black" : "red"),
                applying: 22.6, format: .courseHandicap, courseSegment: segment, maximumHandicap: 21)
        }
        var manual = HandicapCalculator.participant(players[1], applying: 15, format: .strokes, courseSegment: segment)
        manual.id = "manual"
        players.append(manual)
        let frozenOriginal = players
        for holes in [HoleSegment.full18, .front9, .back9, .full18] {
            segment.holeRange = holes.holeRange
            let configuration = HandicapCalculator.personalConfiguration(
                .init(courses: [segment], handicapEntryFormat: .courseHandicap), playedHoleCount: holes.holeCount)
            players = HandicapCalculator.recomputedParticipants(players, format: .courseHandicap,
                courseSegment: segment, maximumHandicap: 21, handicapStrokeBasis: configuration.handicapIndexBasis)
            players = try JSONDecoder().decode([RoundParticipant].self, from: JSONEncoder().encode(players))
            for player in players.prefix(2) {
                let expected = HandicapCalculator.calculation(index: 22.6, participant: player,
                    courseSegment: segment, indexBasis: .eighteenHole)
                XCTAssertEqual(player.handicapResolution?.calculation, expected)
                XCTAssertEqual(player.adjustedHandicap, expected.allowedStrokes(maximum: 21))
                XCTAssertTrue(HandicapCalculator.isReady(player, format: .courseHandicap,
                    courseSegment: segment, indexBasis: .eighteenHole))
            }
            for player in players {
                let tee = try XCTUnwrap(segment.tee(from: player.teeBoxID))
                let allocated = holes.holeRange.holeNumbers.reduce(0) { total, hole in
                    total + ScoringEngine.strokesReceived(handicap: player.adjustedHandicap, holeNumber: hole,
                        holes: tee.holes, playedHoleNumbers: holes.holeRange.holeNumbers, useHandicaps: true,
                        handicapStrokeBasis: configuration.resolvedHandicapStrokeBasis(holeCount: holes.holeCount))
                }
                XCTAssertEqual(allocated, player.adjustedHandicap)
                XCTAssertEqual(player.handicapIndex, 22.6)
            }
            XCTAssertEqual(players[2], manual)
        }
        XCTAssertEqual(frozenOriginal[0].handicapResolution?.calculation?.segment, .full18)
        XCTAssertEqual(frozenOriginal[2], manual)
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
