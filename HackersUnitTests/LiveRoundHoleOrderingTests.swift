//
//  LiveRoundHoleOrderingTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

// MARK: - Pure ordering (LiveRoundHoleOrdering)

final class LiveRoundHoleOrderingTests: XCTestCase {

    func testCourseHoleNumbers_nilRange_defaultsThrough18() {
        let holes = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: nil)
        XCTAssertEqual(holes, Array(1...18))
    }

    func testCourseHoleNumbers_frontNine() {
        let holes = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: HoleRange(startHole: 1, endHole: 9))
        XCTAssertEqual(holes, Array(1...9))
    }

    func testCourseHoleNumbers_endHoleZeroUses18() {
        let holes = LiveRoundHoleOrdering.courseHoleNumbers(holeRange: HoleRange(startHole: 1, endHole: 0))
        XCTAssertEqual(holes.last, 18)
    }

    func testPlayOrdered_startingHole7_rotatesFrontNine() {
        let course = Array(1...9)
        let ordered = LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 7)
        XCTAssertEqual(ordered, [7, 8, 9, 1, 2, 3, 4, 5, 6])
    }

    func testPlayOrdered_startingHole9_wrapsToFront() {
        let course = Array(1...9)
        let ordered = LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 9)
        XCTAssertEqual(ordered, [9, 1, 2, 3, 4, 5, 6, 7, 8])
    }

    func testPlayOrdered_startingHoleZero_returnsCourseOrder() {
        let course = Array(1...9)
        XCTAssertEqual(
            LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 0),
            course
        )
    }

    func testPlayOrdered_startingHoleNotInCourse_returnsCourseOrder() {
        let course = Array(1...9)
        XCTAssertEqual(
            LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 99),
            course
        )
    }

    func testPlayOrdered_firstHole_isIdentity() {
        let course = Array(1...9)
        XCTAssertEqual(
            LiveRoundHoleOrdering.playOrderedHoleNumbers(course: course, startingHole: 1),
            course
        )
    }

    func testPlayOrderHoleNumbers_resolvesTeeGroup() {
        let group = TeeTimeGroup(
            id: "g1",
            index: 0,
            startingHole: 7,
            createdAt: .init(),
            parentID: "r1"
        )
        let ordered = LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: HoleRange(startHole: 1, endHole: 9),
            teeGroupID: "g1",
            teeGroups: [group]
        )
        XCTAssertEqual(ordered, [7, 8, 9, 1, 2, 3, 4, 5, 6])
    }

    func testPlayOrderHoleNumbers_nilGroupID_isCourseOrder() {
        let group = TeeTimeGroup(
            id: "g1",
            index: 0,
            startingHole: 7,
            createdAt: .init(),
            parentID: "r1"
        )
        let ordered = LiveRoundHoleOrdering.playOrderHoleNumbers(
            holeRange: HoleRange(startHole: 1, endHole: 9),
            teeGroupID: nil,
            teeGroups: [group]
        )
        XCTAssertEqual(ordered, Array(1...9))
    }

    func testPrimarySegmentHoleRangeMismatchReportsScoresOutsideSegment() throws {
        let snapshot = makeRangeMismatchSnapshot(
            courseRange: HoleRange(startHole: 10, endHole: 18),
            segmentRange: HoleRange(startHole: 1, endHole: 9),
            scoreHoles: [10, 11, 12]
        )

        let mismatch = try XCTUnwrap(snapshot.primarySegmentHoleRangeMismatch)

        XCTAssertEqual(mismatch.roundHoleRange, HoleRange(startHole: 10, endHole: 18))
        XCTAssertEqual(mismatch.segmentHoleRange, HoleRange(startHole: 1, endHole: 9))
        XCTAssertEqual(mismatch.observedScoreHoleNumbers, [10, 11, 12])
        XCTAssertEqual(mismatch.scoredOutsideSegmentHoleNumbers, [10, 11, 12])
        XCTAssertTrue(mismatch.diagnosticDetail.contains("Course holes are 10-18"))
    }

    func testPrimarySegmentHoleRangeMismatchNilWhenRangesAlign() {
        let snapshot = makeRangeMismatchSnapshot(
            courseRange: HoleRange(startHole: 10, endHole: 18),
            segmentRange: HoleRange(startHole: 10, endHole: 18),
            scoreHoles: [10, 11, 12]
        )

        XCTAssertNil(snapshot.primarySegmentHoleRangeMismatch)
    }

    private func makeRangeMismatchSnapshot(
        courseRange: HoleRange,
        segmentRange: HoleRange,
        scoreHoles: [Int]
    ) -> RoundSnapshot {
        let roundID = "range_mismatch_round"
        let segmentID = "range_mismatch_segment"
        let round = Round(
            id: roundID,
            configuration: RoundConfiguration(
                courses: [
                    CourseSegment(
                        courseInfo: CourseInfo(),
                        holeRange: courseRange
                    ),
                ]
            )
        )
        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: segmentRange,
            parentID: roundID
        )
        let scores = scoreHoles.map { hole in
            ScoreEntry(
                id: ScoreEntry.makeID(hole: hole, segment: segmentID, scoringUnit: "p1"),
                holeNumber: hole,
                segmentID: segmentID,
                scoringUnitID: "p1",
                participantIDs: ["p1"],
                strokes: 4,
                entryID: "p1",
                parentID: roundID
            )
        }

        return RoundSnapshot(round: round, segments: [segment], scoring: scores)
    }

    // MARK: - Past / future in play order (error styling)

    func testIncompletePast_startOn9_current9_hole1IsFuture() {
        let play = [9, 1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertFalse(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 1, currentHole: 9)
        )
    }

    func testIncompletePast_startOn9_current3_hole1IsPast() {
        let play = [9, 1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 1, currentHole: 3)
        )
    }

    func testIncompletePast_startOn9_onHole2_hole9WasSkippedIncomplete() {
        let play = [9, 1, 2, 3, 4, 5, 6, 7, 8]
        XCTAssertTrue(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 9, currentHole: 1)
        )
    }

    func testIncompletePast_startOn7_current7_hole1IsFuture() {
        let play = [7, 8, 9, 1, 2, 3, 4, 5, 6]
        XCTAssertFalse(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 1, currentHole: 7)
        )
    }

    func testIncompletePast_unknownHole_returnsFalse() {
        let play = [1, 2, 3]
        XCTAssertFalse(
            LiveRoundHoleOrdering.isIncompletePastInPlayOrder(playOrder: play, holeNumber: 99, currentHole: 2)
        )
    }
}

// MARK: - LiveRoundViewModel integration

@MainActor
final class LiveRoundViewModelHoleOrderingTests: XCTestCase {

    private func boundViewModel(
        snapshot: RoundSnapshot,
        participantID: String? = nil,
        useFirstParticipantIfMissing: Bool = true,
        seriesID: String? = nil,
        isCommissioner: Bool = false
    ) async -> LiveRoundViewModel {
        let appSession = AppSession()
        if let participantID {
            appSession.ephemeralParticipantID = participantID
        } else if useFirstParticipantIfMissing, let id = snapshot.participants.first?.id {
            appSession.ephemeralParticipantID = id
        }
        appSession.activeSeriesID = seriesID
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        let vm = LiveRoundViewModel()
        if seriesID != nil || isCommissioner {
            vm.seriesAccessOverride = .init(seriesID: seriesID, isCommissioner: isCommissioner)
        }
        vm.bind(appSession: appSession, roundSession: roundSession)
        await vm.ensureParticipantResolved()
        await Task.yield()
        await Task.yield()
        return vm
    }

    func testHoleNumbers_clampsExtremeCurrentHoleIndex_noCrash() async {
        let vm = await boundViewModel(snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 1))
        vm.currentHoleIndex = 10_000
        XCTAssertEqual(vm.currentHoleNumber, 9)
        vm.currentHoleIndex = -50
        XCTAssertEqual(vm.currentHoleNumber, 1)
    }

    func testHoleNumbers_startOnNine_orderAndFutureHolesNotError() async {
        let vm = await boundViewModel(snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 9))
        vm.currentHoleIndex = 0

        XCTAssertEqual(vm.holeNumbers, [9, 1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(vm.holeState(for: 9), .current)
        XCTAssertEqual(vm.holeState(for: 1), .unscored)
        XCTAssertEqual(vm.holeState(for: 2), .unscored)
        XCTAssertEqual(vm.holeState(for: 8), .unscored)
    }

    /// Past hole in play order, still unscored → error styling (skipped).
    func testHoleState_onHole1_withoutScoringHole9_hole9IsError() async {
        let vm = await boundViewModel(snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 9))
        vm.selectHole(1)

        XCTAssertEqual(vm.holeState(for: 1), .current)
        XCTAssertEqual(vm.holeState(for: 9), .error)
    }

    func testHoleCompletion_allHolesScored_progressComplete() async {
        let vm = await boundViewModel(
            snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 7, scoreAllHoles: true)
        )

        for h in 1...9 {
            XCTAssertEqual(vm.holeCompletionProgress(holeNumber: h), 1.0, "hole \(h)")
        }
        XCTAssertNil(vm.nextUnscoredHoleNumber)
    }

    func testHoleState_allScored_currentHole7_restCompleted() async {
        let vm = await boundViewModel(
            snapshot: Self.makeSnapshotNineHolesStarting(groupStartingHole: 7, scoreAllHoles: true)
        )
        vm.selectHole(7)

        XCTAssertEqual(vm.holeState(for: 7), .current)
        for h in 1...9 where h != 7 {
            XCTAssertEqual(vm.holeState(for: h), .completed, "hole \(h)")
        }
    }

    func testSelectVisibleTeeGroup_targetsSelectedGroupStartingHole_andChangesVisibleParticipants() async {
        let snapshot = Self.makeMultiGroupSnapshot()
        let vm = await boundViewModel(
            snapshot: snapshot,
            participantID: "p1",
            seriesID: "series_test",
            isCommissioner: true
        )

        vm.selectHole(2)
        XCTAssertEqual(vm.currentHoleNumber, 2)

        vm.selectVisibleTeeGroup("g2")

        XCTAssertEqual(vm.currentHoleNumber, 1)
        XCTAssertEqual(vm.holeNumbers, Array(1...9))
        XCTAssertEqual(vm.actualTeeGroupParticipants.map(\.id), ["p1", "p2"])
        XCTAssertEqual(vm.visibleTeeGroupParticipants.map(\.id), ["p3", "p4"])
        XCTAssertEqual(vm.visibleGroupSwitchRequest?.groupID, "g2")
        XCTAssertEqual(vm.visibleGroupSwitchRequest?.targetHoleNumber, 1)
    }

    func testSelectVisibleTeeGroup_invalidStartingHole_fallsBackToFirstPlayOrderHole() async {
        let snapshot = Self.makeMultiGroupSnapshot(groupTwoStartingHole: 99)
        let vm = await boundViewModel(
            snapshot: snapshot,
            participantID: "p1",
            seriesID: "series_test",
            isCommissioner: true
        )

        vm.selectVisibleTeeGroup("g2")

        XCTAssertEqual(vm.currentHoleNumber, 1)
        XCTAssertEqual(vm.visibleGroupSwitchRequest?.targetHoleNumber, 1)
        XCTAssertEqual(vm.visibleTeeGroupParticipants.map(\.id), ["p3", "p4"])
    }

    func testSelectVisibleTeeGroup_emitsFreshRequestWhenTargetHoleMatchesPreviousSelection() async {
        let snapshot = Self.makeMultiGroupSnapshot(groupOneStartingHole: 1, groupTwoStartingHole: 1)
        let vm = await boundViewModel(
            snapshot: snapshot,
            participantID: "p1",
            seriesID: "series_test",
            isCommissioner: true
        )

        let firstRevision = vm.visibleGroupSwitchRequest?.revisionID

        vm.selectVisibleTeeGroup("g2")
        let secondRequest = vm.visibleGroupSwitchRequest

        vm.selectVisibleTeeGroup("g1")
        let thirdRequest = vm.visibleGroupSwitchRequest

        XCTAssertEqual(secondRequest?.targetHoleNumber, 1)
        XCTAssertEqual(thirdRequest?.targetHoleNumber, 1)
        XCTAssertNotEqual(firstRevision, secondRequest?.revisionID)
        XCTAssertNotEqual(secondRequest?.revisionID, thirdRequest?.revisionID)
    }

    func testCanCompleteActualGroup_falseWhenViewingAlternateGroup() async {
        let vm = await boundViewModel(
            snapshot: Self.makeMultiGroupSnapshot(),
            participantID: "p1",
            seriesID: "series_test",
            isCommissioner: true
        )

        XCTAssertTrue(vm.canCompleteActualGroup)

        vm.selectVisibleTeeGroup("g2")

        XCTAssertFalse(vm.canCompleteActualGroup)
    }

    func testNonPlayingCommissioner_defaultsVisibleGroupToFirstTeeGroup() async {
        let vm = await boundViewModel(
            snapshot: Self.makeMultiGroupSnapshot(),
            participantID: nil,
            useFirstParticipantIfMissing: false,
            seriesID: "series_test",
            isCommissioner: true
        )

        XCTAssertNil(vm.actualParticipant)
        XCTAssertEqual(vm.visibleTeeGroupID, "g1")
        XCTAssertEqual(vm.visibleTeeGroupParticipants.map(\.id), ["p1", "p2"])
        XCTAssertTrue(vm.canScoreVisibleGroup)
        XCTAssertFalse(vm.canCompleteActualGroup)
    }

    func testScorecardEditPermissions_onlyActualGroupCanEdit() async {
        let snapshot = Self.makeMultiGroupSnapshot()
        let vm = await boundViewModel(
            snapshot: snapshot,
            participantID: "p1",
            seriesID: "series_test",
            isCommissioner: true
        )

        let actualGroupPlayer = snapshot.participants.first(where: { $0.id == "p2" })!
        let alternateGroupPlayer = snapshot.participants.first(where: { $0.id == "p3" })!

        XCTAssertTrue(vm.canEditScorecard(participant: actualGroupPlayer))
        XCTAssertFalse(vm.canEditScorecard(participant: alternateGroupPlayer))

        vm.selectVisibleTeeGroup("g2")

        XCTAssertTrue(vm.canEditScorecard(participant: actualGroupPlayer))
        XCTAssertFalse(vm.canEditScorecard(participant: alternateGroupPlayer))
    }

    func testScorecardEditPermissions_nonPlayingCommissionerIsReadOnly() async {
        let snapshot = Self.makeMultiGroupSnapshot()
        let vm = await boundViewModel(
            snapshot: snapshot,
            participantID: nil,
            useFirstParticipantIfMissing: false,
            seriesID: "series_test",
            isCommissioner: true
        )

        for participant in snapshot.participants {
            XCTAssertFalse(vm.canEditScorecard(participant: participant), participant.id)
        }
    }

    func testOutcomeResolvedPlayedTee_prefersParticipantTeeOverDefault() async throws {
        let vm = await boundViewModel(
            snapshot: Self.makeOutcomeSnapshot(participantTeeID: "tee_alt", defaultTeeID: "tee_default"),
            participantID: "p1"
        )

        let participant = try XCTUnwrap(vm.outcomeParticipant)
        XCTAssertEqual(vm.resolvedPlayedTee(for: participant)?.id, "tee_alt")
        XCTAssertEqual(vm.outcomePersonalSummary?.tee.id, "tee_alt")
    }

    func testOutcomeResolvedPlayedTee_fallsBackToDefaultThenFirstAvailable() async throws {
        let defaultVM = await boundViewModel(
            snapshot: Self.makeOutcomeSnapshot(participantTeeID: "", defaultTeeID: "tee_default"),
            participantID: "p1"
        )
        let defaultParticipant = try XCTUnwrap(defaultVM.outcomeParticipant)
        XCTAssertEqual(defaultVM.resolvedPlayedTee(for: defaultParticipant)?.id, "tee_default")

        let firstAvailableVM = await boundViewModel(
            snapshot: Self.makeOutcomeSnapshot(participantTeeID: "", defaultTeeID: nil),
            participantID: "p1"
        )
        let firstAvailableParticipant = try XCTUnwrap(firstAvailableVM.outcomeParticipant)
        XCTAssertEqual(firstAvailableVM.resolvedPlayedTee(for: firstAvailableParticipant)?.id, "tee_default")
    }

    func testOutcomePersonalSummary_reportsGrossNetAndAdjustedIndex() async throws {
        let vm = await boundViewModel(
            snapshot: Self.makeOutcomeSnapshot(participantTeeID: "tee_alt", defaultTeeID: "tee_default"),
            participantID: "p1"
        )

        let summary = try XCTUnwrap(vm.outcomePersonalSummary)
        XCTAssertEqual(summary.grossScoreToPar, 9)
        XCTAssertEqual(summary.netScoreToPar, 0)
        XCTAssertEqual(summary.adjustedIndex ?? -1, 9.3, accuracy: 0.01)

        let subtitle = vm.outcomeAdjustedIndexSubtitle(for: summary.participant)
        XCTAssertEqual(subtitle, "Blue \(kDot) CR 35.1 \(kDot) Slope 120")
    }

    func testOutcomeGroupedSectionSets_suppressAggregateFormatsWhenBestBallChipSelected() async {
        let vm = await boundViewModel(
            snapshot: Self.makeBestBallOutcomeSnapshot(),
            participantID: "bb_p1"
        )

        XCTAssertTrue(vm.availableLeaderboardChips.contains(.bestBall))

        vm.selectedLeaderboardChip = .bestBall

        XCTAssertEqual(vm.effectiveLeaderboardChip, .bestBall)
        XCTAssertTrue(vm.outcomeGroupedSectionSets.isEmpty)
    }

    func testOutcomeMatchupStatus_formatsWinnerAndTie() async throws {
        let vm = await boundViewModel(
            snapshot: MockLiveRoundBest2of4Matchup.snapshot,
            participantID: "p01"
        )

        let section = try XCTUnwrap(vm.matchupSections.first)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertEqual(status.title, "Red Team wins")
        XCTAssertEqual(status.detail, "Won by 1 stroke")
        XCTAssertEqual(status.winningScoringUnitID, "team_red")

        let fallbackTieMatchup = TeamMatchup(
            id: "fallback_tie",
            teamIDs: ["fallback_red", "fallback_blue"],
            mode: .team
        )
        let tieSection = MatchupLeaderboardSection(
            id: "tie",
            matchup: fallbackTieMatchup,
            name: "Tie",
            rows: [
                LeaderboardRow(
                    scoringUnitID: "fallback_red",
                    participantIDs: ["p01", "p02"],
                    owner: .team,
                    total: 0,
                    holesPlayed: 18,
                    placeLabel: "T1",
                    isPinned: false
                ),
                LeaderboardRow(
                    scoringUnitID: "fallback_blue",
                    participantIDs: ["p03", "p04"],
                    owner: .team,
                    total: 0,
                    holesPlayed: 18,
                    placeLabel: "T1",
                    isPinned: false
                ),
            ]
        )

        let tieStatus = vm.outcomeMatchupStatus(for: tieSection)
        XCTAssertFalse(tieStatus.isTie)
        XCTAssertEqual(tieStatus.title, "Matchup pending")
        XCTAssertEqual(tieStatus.detail, "Waiting for both sides to post scores")
        XCTAssertNil(tieStatus.winningScoringUnitID)
    }

    func testOutcomeMatchupStatusUsesEngineAggregateWhenSectionRowsDrift() async throws {
        let vm = await boundViewModel(
            snapshot: MockLiveRoundBest2of4Matchup.snapshot,
            participantID: "p01"
        )
        let section = try XCTUnwrap(vm.matchupSections.first)
        let staleTieSection = MatchupLeaderboardSection(
            id: section.id,
            matchup: section.matchup,
            name: section.name,
            rows: [
                LeaderboardRow(
                    scoringUnitID: "team_red",
                    participantIDs: ["p01", "p02"],
                    owner: .team,
                    total: 0,
                    holesPlayed: 18,
                    placeLabel: "T1",
                    isPinned: false
                ),
                LeaderboardRow(
                    scoringUnitID: "team_blue",
                    participantIDs: ["p03", "p04"],
                    owner: .team,
                    total: 0,
                    holesPlayed: 18,
                    placeLabel: "T1",
                    isPinned: false
                ),
            ]
        )

        let status = vm.outcomeMatchupStatus(for: staleTieSection)

        XCTAssertEqual(status.title, "Red Team wins")
        XCTAssertEqual(status.detail, "Won by 1 stroke")
        XCTAssertEqual(status.winningScoringUnitID, "team_red")
    }

    func testMatchupParticipantDisplaySortUsesNetWhenHandicapsAreEnabled() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.primaryFormat.configuration.basis = .net
        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let participants = presentation.sides.flatMap(\.participants)

        let sorted = participants.sorted {
            vm.matchupParticipantDisplaySort(lhs: $0, rhs: $1, isPointsFormat: false)
        }
        let netScores = sorted.map { vm.scoreToPar(for: $0, basis: .net) }

        XCTAssertEqual(netScores, netScores.sorted())
    }

    func testMatchupParticipantDisplaySortUsesGrossWhenHandicapsAreDisabled() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.primaryFormat.configuration.basis = .gross
        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let participants = presentation.sides.flatMap(\.participants)

        let sorted = participants.sorted {
            vm.matchupParticipantDisplaySort(lhs: $0, rhs: $1, isPointsFormat: false)
        }
        let grossScores = sorted.map { vm.scoreToPar(for: $0, basis: .gross) }

        XCTAssertEqual(grossScores, grossScores.sorted())
    }

    func testMatchupParticipantDisplaySortFallsBackToStableParticipantOrderForTies() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.scoring = []
        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let participants = presentation.sides.flatMap(\.participants)

        let sortedIDs = participants
            .sorted { vm.matchupParticipantDisplaySort(lhs: $0, rhs: $1, isPointsFormat: false) }
            .map(\.id)

        XCTAssertEqual(sortedIDs, ["p01", "p05", "p06", "p02", "p03", "p07", "p08", "p04"])
    }

    func testTeamMatchupBestNUsesTeamAggregatesWhenPrimaryFormatIsIndividual() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.primaryFormat.configuration.requiresTeams = false
        snapshot.segments[0].gameFormat.configuration.requiresTeams = false

        XCTAssertFalse(snapshot.requiresTeams)
        XCTAssertEqual(snapshot.expectedMatchupMode, .team)
        XCTAssertTrue(snapshot.usesTeamScoringAggregates)

        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let result = vm.engineResult
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })

        XCTAssertNotNil(rowMap["team_red"])
        XCTAssertNotNil(rowMap["team_blue"])

        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertTrue(presentation.hasCompleteSides)
        XCTAssertFalse(presentation.isTie)
        XCTAssertEqual(status.title, "Red Team wins")
        XCTAssertEqual(status.detail, "Won by 1 stroke")
        XCTAssertEqual(status.winningScoringUnitID, "team_red")
        XCTAssertEqual(presentation.side(id: "team_red")?.scoreLabel, "+1")
        XCTAssertEqual(presentation.side(id: "team_blue")?.scoreLabel, "+2")
    }

    func testTeamMatchupHoleByHolePointsPresentationUsesPointTotals() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.round.configuration.teamScoring = .init(mode: .bestN, count: 1, scope: .perHole)
        snapshot.round.configuration.matchupScoringStyle = .holeByHolePoints
        snapshot.scoring = snapshot.scoring.map { entry in
            guard entry.holeNumber == 3,
                  ["p03", "p04", "p07", "p08"].contains(entry.scoringUnitID) else {
                return entry
            }
            var updated = entry
            updated.strokes = 5
            return updated
        }

        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let result = vm.engineResult
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })

        XCTAssertEqual(matchupResult.isPointsFormat, true)
        XCTAssertEqual(rowMap["team_red"]?.total, 2.5)
        XCTAssertEqual(rowMap["team_blue"]?.total, 1.5)

        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertTrue(presentation.isPointsFormat)
        XCTAssertEqual(presentation.side(id: "team_red")?.scoreLabel, "2.5")
        XCTAssertEqual(presentation.side(id: "team_blue")?.scoreLabel, "1.5")
        XCTAssertEqual(status.title, "Red Team wins")
        XCTAssertEqual(status.detail, "Won by 1 pt")
        XCTAssertEqual(status.winningScoringUnitID, "team_red")
    }

    func testTeamMatchupBestNUsesTeamAggregatesWhenScoringGroupsExist() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.scoringGroups = Self.best2ScoringGroups()
        snapshot.segments[0].matchups = [
            TeamMatchup(id: "m1", teamIDs: ["team_red", "team_blue"], mode: .team),
        ]

        XCTAssertFalse(snapshot.usesTeamScoringAggregates)
        XCTAssertTrue(ScoringEngine.shouldUseTeamAggregateScoring(snapshot: snapshot, segment: snapshot.segments[0]))

        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let result = vm.engineResult
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
        let red = try XCTUnwrap(rowMap["team_red"])
        let blue = try XCTUnwrap(rowMap["team_blue"])

        XCTAssertEqual(red.total, 1, accuracy: 0.01)
        XCTAssertEqual(blue.total, 2, accuracy: 0.01)
        XCTAssertEqual(red.countingParticipantIDs, ["p05", "p01"])
        XCTAssertEqual(blue.countingParticipantIDs, ["p03", "p07"])

        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertTrue(presentation.hasCompleteSides)
        XCTAssertEqual(presentation.winningSideID, "team_red")
        XCTAssertEqual(status.title, "Red Team wins")
        XCTAssertEqual(status.detail, "Won by 1 stroke")
        XCTAssertEqual(status.winningScoringUnitID, "team_red")
        XCTAssertEqual(presentation.side(id: "team_red")?.scoreLabel, "+1")
        XCTAssertEqual(presentation.side(id: "team_blue")?.scoreLabel, "+2")
    }

    func testTeamMatchupBestNProjectsPartialStandingsWhenScoringGroupsExist() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.scoringGroups = Self.best2ScoringGroups()
        snapshot.scoring = snapshot.scoring.filter { $0.holeNumber == 1 }
        snapshot.segments[0].matchups = [
            TeamMatchup(id: "m1", teamIDs: ["team_red", "team_blue"], mode: .team),
        ]

        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertTrue(presentation.hasCompleteSides)
        XCTAssertTrue(presentation.isTie)
        XCTAssertEqual(status.title, "Match tied")
        XCTAssertEqual(status.detail, "Tied at E")
        XCTAssertNil(status.winningScoringUnitID)
        XCTAssertEqual(presentation.side(id: "team_red")?.scoreLabel, "E")
        XCTAssertEqual(presentation.side(id: "team_blue")?.scoreLabel, "E")
        XCTAssertTrue(presentation.side(id: "team_red")?.isParticipantActive(snapshot.participants[0]) == true)
        XCTAssertTrue(presentation.side(id: "team_red")?.isParticipantActive(snapshot.participants[4]) == true)
        XCTAssertTrue(presentation.side(id: "team_red")?.isParticipantActive(snapshot.participants[1]) == false)
        XCTAssertTrue(presentation.side(id: "team_blue")?.isParticipantActive(snapshot.participants[2]) == true)
        XCTAssertTrue(presentation.side(id: "team_blue")?.isParticipantActive(snapshot.participants[6]) == true)
        XCTAssertTrue(presentation.side(id: "team_blue")?.isParticipantActive(snapshot.participants[7]) == false)
    }

    func testOutcomeMatchupsResolveScoresSavedUnderObservedSegmentID() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.scoringGroups = Self.best2ScoringGroups()
        snapshot.segments[0].matchups = [
            TeamMatchup(id: "m1", teamIDs: ["team_red", "team_blue"], mode: .team),
        ]
        snapshot.scoring = snapshot.scoring.map { entry in
            var updated = entry
            updated.segmentID = "persisted_score_segment"
            return updated
        }

        XCTAssertTrue(snapshot.segmentScoreLookupSegmentIDs.contains("persisted_score_segment"))

        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let section = try XCTUnwrap(vm.matchupSections.first)
        let presentation = vm.matchupPresentation(in: section)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertTrue(presentation.hasCompleteSides)
        XCTAssertEqual(status.title, "Red Team wins")
        XCTAssertEqual(status.detail, "Won by 1 stroke")
        XCTAssertEqual(status.winningScoringUnitID, "team_red")
        XCTAssertEqual(presentation.side(id: "team_red")?.scoreLabel, "+1")
        XCTAssertEqual(presentation.side(id: "team_blue")?.scoreLabel, "+2")
        XCTAssertTrue(presentation.side(id: "team_red")?.isParticipantActive(snapshot.participants[4]) == true)
        XCTAssertTrue(presentation.side(id: "team_blue")?.isParticipantActive(snapshot.participants[6]) == true)
    }

    func testOutcomeMatchupStatusReportsRangeMismatchInsteadOfResult() async throws {
        var snapshot = MockLiveRoundBest2of4Matchup.snapshot
        snapshot.scoringGroups = Self.best2ScoringGroups()
        snapshot.segments[0].holeRange = HoleRange(startHole: 1, endHole: 9)
        snapshot.segments[0].matchups = [
            TeamMatchup(id: "m1", teamIDs: ["team_red", "team_blue"], mode: .team),
        ]
        if snapshot.round.configuration.courses.isEmpty {
            snapshot.round.configuration.courses = [
                CourseSegment(courseInfo: CourseInfo(), holeRange: HoleRange(startHole: 10, endHole: 18)),
            ]
        } else {
            snapshot.round.configuration.courses[0].holeRange = HoleRange(startHole: 10, endHole: 18)
        }
        snapshot.scoring = snapshot.scoring.map { entry in
            var updated = entry
            updated.holeNumber += 9
            updated.id = ScoreEntry.makeID(
                hole: updated.holeNumber,
                segment: updated.segmentID,
                scoringUnit: updated.scoringUnitID
            )
            return updated
        }

        let vm = await boundViewModel(snapshot: snapshot, participantID: "p01")
        let section = try XCTUnwrap(vm.matchupSections.first)
        let status = vm.outcomeMatchupStatus(for: section)

        XCTAssertEqual(status.title, "Setup needs repair")
        XCTAssertTrue(status.detail.contains("Course holes are 10-18"))
        XCTAssertNil(status.winningScoringUnitID)
        XCTAssertFalse(status.isTie)
    }

    // MARK: - Snapshot factory

    private static func best2ScoringGroups() -> [RoundScoringGroup] {
        [
            RoundScoringGroup(
                id: "red_group_1",
                teamID: "team_red",
                teeGroupID: "group_1",
                kind: .partnership,
                memberIDs: ["p01", "p02"],
                parentID: MockLiveRoundBest2of4Matchup.roundID
            ),
            RoundScoringGroup(
                id: "red_group_2",
                teamID: "team_red",
                teeGroupID: "group_2",
                kind: .partnership,
                memberIDs: ["p05", "p06"],
                parentID: MockLiveRoundBest2of4Matchup.roundID
            ),
            RoundScoringGroup(
                id: "blue_group_1",
                teamID: "team_blue",
                teeGroupID: "group_1",
                kind: .partnership,
                memberIDs: ["p03", "p04"],
                parentID: MockLiveRoundBest2of4Matchup.roundID
            ),
            RoundScoringGroup(
                id: "blue_group_2",
                teamID: "team_blue",
                teeGroupID: "group_2",
                kind: .partnership,
                memberIDs: ["p07", "p08"],
                parentID: MockLiveRoundBest2of4Matchup.roundID
            ),
        ]
    }

    private static func makeSnapshotNineHolesStarting(
        groupStartingHole: Int,
        scoreAllHoles: Bool = false
    ) -> RoundSnapshot {
        let roundID = "lr_order_test"
        let groupID = "g_order"
        let segmentID = "seg_order"

        let participant = RoundParticipant(
            id: "p1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Test", "Player"),
            teeBoxID: "tee1",
            groupID: groupID,
            teeOrder: 1,
            isHost: true,
            parentID: roundID
        )

        let teeGroup = TeeTimeGroup(
            id: groupID,
            index: 0,
            startingHole: groupStartingHole,
            createdAt: .init(),
            parentID: roundID
        )

        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 9),
            scoringUnits: [
                ScoringUnit(
                    id: "su_p1",
                    owner: .participant,
                    ownerIDs: ["p1"],
                    scoringMethod: .individual
                ),
            ],
            parentID: roundID
        )

        let round = Round(
            id: roundID,
            shareCode: "TST",
            createdBy: "u1",
            status: .live,
            players: ["pl1"],
            configuration: RoundConfiguration(
                primaryFormat: .strokePlay,
                courses: [
                    CourseSegment(
                        courseInfo: CourseInfo(),
                        holeRange: HoleRange(startHole: 1, endHole: 9),
                        defaultTee: "tee1"
                    ),
                ]
            )
        )

        var scoring: [ScoreEntry] = []
        if scoreAllHoles {
            for hole in 1...9 {
                scoring.append(
                    ScoreEntry(
                        id: ScoreEntry.makeID(hole: hole, segment: segmentID, scoringUnit: "su_p1"),
                        holeNumber: hole,
                        segmentID: segmentID,
                        groupID: groupID,
                        scoringUnitID: "su_p1",
                        participantIDs: ["p1"],
                        strokes: 4,
                        pickedUp: false,
                        entryID: "p1",
                        parentID: roundID
                    )
                )
            }
        }

        return RoundSnapshot(
            round: round,
            participants: [participant],
            teams: [],
            teeGroups: [teeGroup],
            segments: [segment],
            scoring: scoring
        )
    }

    private static func makeMultiGroupSnapshot(
        groupOneStartingHole: Int = 7,
        groupTwoStartingHole: Int = 1
    ) -> RoundSnapshot {
        let roundID = "lr_multi_group_test"
        let segmentID = "seg_multi"

        let participants = [
            RoundParticipant(
                id: "p1",
                userID: "u1",
                playerID: "pl1",
                name: Name("Alex", "One"),
                teeBoxID: "tee1",
                seriesMemberID: "sm1",
                groupID: "g1",
                teeOrder: 1,
                isHost: true,
                parentID: roundID
            ),
            RoundParticipant(
                id: "p2",
                userID: "u2",
                playerID: "pl2",
                name: Name("Blair", "Two"),
                teeBoxID: "tee1",
                seriesMemberID: "sm2",
                groupID: "g1",
                teeOrder: 2,
                parentID: roundID
            ),
            RoundParticipant(
                id: "p3",
                userID: "u3",
                playerID: "pl3",
                name: Name("Casey", "Three"),
                teeBoxID: "tee2",
                seriesMemberID: "sm3",
                groupID: "g2",
                teeOrder: 1,
                parentID: roundID
            ),
            RoundParticipant(
                id: "p4",
                userID: "u4",
                playerID: "pl4",
                name: Name("Drew", "Four"),
                teeBoxID: "tee2",
                seriesMemberID: "sm4",
                groupID: "g2",
                teeOrder: 2,
                parentID: roundID
            ),
        ]

        let teeGroups = [
            TeeTimeGroup(
                id: "g1",
                index: 0,
                startingHole: groupOneStartingHole,
                createdAt: .init(),
                parentID: roundID
            ),
            TeeTimeGroup(
                id: "g2",
                index: 1,
                startingHole: groupTwoStartingHole,
                createdAt: .init(),
                parentID: roundID
            ),
        ]

        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 9),
            scoringUnits: participants.map { participant in
                ScoringUnit(
                    id: "su_\(participant.id)",
                    owner: .participant,
                    ownerIDs: [participant.id],
                    scoringMethod: .individual
                )
            },
            parentID: roundID
        )

        let round = Round(
            id: roundID,
            shareCode: "MUL",
            createdBy: "u1",
            status: .live,
            players: participants.compactMap(\.playerID),
            configuration: RoundConfiguration(
                primaryFormat: .strokePlay,
                courses: [
                    CourseSegment(
                        courseInfo: CourseInfo(),
                        holeRange: HoleRange(startHole: 1, endHole: 9),
                        defaultTee: "tee1"
                    ),
                ]
            )
        )

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: [],
            teeGroups: teeGroups,
            segments: [segment],
            scoring: []
        )
    }

    private static func makeOutcomeSnapshot(
        participantTeeID: String,
        defaultTeeID: String?
    ) -> RoundSnapshot {
        let roundID = "outcome_snapshot_test"
        let segmentID = "outcome_segment"
        let holes = (1...9).map { holeNumber in
            Hole(number: holeNumber, par: 4, yardage: 360 + (holeNumber * 5), handicap: holeNumber)
        }
        let defaultTee = Tee(
            id: "tee_default",
            name: "White",
            gender: Gender.male.rawValue,
            totalHoles: 9,
            holes: holes,
            ratingFull: 36.0,
            slopeFull: 113,
            ratingFront: 36.0,
            slopeFront: 113,
            ratingBack: nil,
            slopeBack: nil
        )
        let altTee = Tee(
            id: "tee_alt",
            name: "Blue",
            gender: Gender.male.rawValue,
            totalHoles: 9,
            holes: holes,
            ratingFull: 35.1,
            slopeFull: 120,
            ratingFront: 35.1,
            slopeFront: 120,
            ratingBack: nil,
            slopeBack: nil
        )
        let participant = RoundParticipant(
            id: "p1",
            userID: "u1",
            playerID: "player_1",
            name: Name("Pat", "Player"),
            teeBoxID: participantTeeID,
            originalHandicap: 9,
            adjustedHandicap: 9,
            teeOrder: 1,
            isHost: true,
            parentID: roundID
        )
        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 9),
            gameFormat: .init(
                type: .strokePlay,
                configuration: .init(
                    method: .individual,
                    aggregation: nil,
                    basis: .net,
                    handicap: .individualStrokePlay,
                    requiresTeams: false,
                    teeGroupOnly: false
                )
            ),
            templateID: FormatTemplateRegistry.strokePlay.id,
            scoringUnits: [
                ScoringUnit(id: "p1", owner: .participant, ownerIDs: ["p1"], scoringMethod: .individual),
            ],
            parentID: roundID
        )
        let round = Round(
            id: roundID,
            shareCode: "OUTCOME",
            createdBy: "u1",
            status: .complete,
            players: ["player_1"],
            configuration: RoundConfiguration(
                primaryFormat: .init(
                    type: .strokePlay,
                    configuration: .init(
                        method: .individual,
                        aggregation: nil,
                        basis: .net,
                        handicap: .individualStrokePlay,
                        requiresTeams: false,
                        teeGroupOnly: false
                    )
                ),
                formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlay),
                courses: [
                    CourseSegment(
                        courseInfo: CourseInfo(
                            id: "course_1",
                            name: "Outcome Hills",
                            totalHoles: 9,
                            location: CourseLocation(
                                address: nil,
                                city: "Auburn",
                                state: "AL",
                                country: "USA",
                                latitude: 0,
                                longitude: 0
                            ),
                            tees: [defaultTee, altTee]
                        ),
                        holeRange: HoleRange(startHole: 1, endHole: 9),
                        defaultTee: defaultTeeID
                    ),
                ]
            ),
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
        let scoring = (1...9).map { holeNumber in
            ScoreEntry(
                id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: "p1"),
                holeNumber: holeNumber,
                segmentID: segmentID,
                groupID: "",
                scoringUnitID: "p1",
                participantIDs: ["p1"],
                strokes: 5,
                entryID: "p1",
                parentID: roundID
            )
        }

        return RoundSnapshot(
            round: round,
            participants: [participant],
            teams: [],
            teeGroups: [],
            segments: [segment],
            scoring: scoring
        )
    }

    private static func makeBestBallOutcomeSnapshot() -> RoundSnapshot {
        let roundID = "best_ball_outcome_test"
        let segmentID = "best_ball_segment"
        let holes = [
            Hole(number: 1, par: 4, yardage: 360, handicap: 1),
            Hole(number: 2, par: 4, yardage: 370, handicap: 2),
            Hole(number: 3, par: 3, yardage: 180, handicap: 3),
            Hole(number: 4, par: 4, yardage: 390, handicap: 4),
        ]
        let tee = Tee(
            id: "tee1",
            name: "Gold",
            gender: Gender.male.rawValue,
            totalHoles: 4,
            holes: holes,
            ratingFull: 15.2,
            slopeFull: 118,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        let participants = [
            RoundParticipant(
                id: "bb_p1",
                userID: "bb_u1",
                playerID: "bb_player_1",
                name: Name("Alice", "One"),
                teeBoxID: tee.id,
                teamID: "t1",
                teeOrder: 1,
                isHost: true,
                parentID: roundID
            ),
            RoundParticipant(
                id: "bb_p2",
                userID: "bb_u2",
                playerID: "bb_player_2",
                name: Name("Bob", "Two"),
                teeBoxID: tee.id,
                teamID: "t1",
                teeOrder: 2,
                parentID: roundID
            ),
            RoundParticipant(
                id: "bb_p3",
                userID: "bb_u3",
                playerID: "bb_player_3",
                name: Name("Cara", "Three"),
                teeBoxID: tee.id,
                teamID: "t2",
                teeOrder: 3,
                parentID: roundID
            ),
            RoundParticipant(
                id: "bb_p4",
                userID: "bb_u4",
                playerID: "bb_player_4",
                name: Name("Drew", "Four"),
                teeBoxID: tee.id,
                teamID: "t2",
                teeOrder: 4,
                parentID: roundID
            ),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init(), parentID: roundID),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init(), parentID: roundID),
        ]
        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 4),
            gameFormat: .init(
                type: .strokePlay,
                configuration: .init(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            templateID: FormatTemplateRegistry.bestBall.id,
            scoringUnits: participants.map {
                ScoringUnit(id: $0.id, owner: .participant, ownerIDs: [$0.id], scoringMethod: .individual)
            },
            parentID: roundID
        )
        let round = Round(
            id: roundID,
            shareCode: "BESTBALL",
            createdBy: "bb_u1",
            status: .complete,
            players: participants.compactMap(\.playerID),
            configuration: RoundConfiguration(
                primaryFormat: .init(
                    type: .strokePlay,
                    configuration: .init(
                        method: .individual,
                        aggregation: nil,
                        basis: .gross,
                        handicap: .individualStrokePlay,
                        requiresTeams: true,
                        teeGroupOnly: false
                    )
                ),
                formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.bestBall),
                courses: [
                    CourseSegment(
                        courseInfo: CourseInfo(id: "best_ball_course", name: "Best Ball Club", totalHoles: 4, tees: [tee]),
                        holeRange: HoleRange(startHole: 1, endHole: 4),
                        defaultTee: tee.id
                    ),
                ]
            ),
            createdAt: .init(),
            lastUpdatedAt: .init()
        )

        let rawScores: [(String, [Int])] = [
            ("bb_p1", [3, 4, 3, 4]),
            ("bb_p2", [5, 5, 4, 5]),
            ("bb_p3", [4, 3, 2, 5]),
            ("bb_p4", [5, 4, 3, 4]),
        ]
        let scoring = rawScores.flatMap { participantID, strokes in
            strokes.enumerated().map { index, strokeCount in
                let holeNumber = index + 1
                return ScoreEntry(
                    id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: participantID),
                    holeNumber: holeNumber,
                    segmentID: segmentID,
                    groupID: "",
                    scoringUnitID: participantID,
                    participantIDs: [participantID],
                    strokes: strokeCount,
                    entryID: participantID,
                    parentID: roundID
                )
            }
        }

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: teams,
            teeGroups: [],
            segments: [segment],
            scoring: scoring
        )
    }
}
