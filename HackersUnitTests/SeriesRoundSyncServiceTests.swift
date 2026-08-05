//
//  SeriesRoundSyncServiceTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundSyncServiceTests: XCTestCase {

    private let t0 = Time(iso: "2023-11-15T12:00:00Z", unix: 1_700_000_000)

    func testValidateOptions_allowsSyncOptionsWhenLiveOrPaused() {
        var options = SeriesRoundSyncOptions(
            syncPlayerData: false,
            syncFormat: true,
            syncOrganization: false,
            syncPairs: false,
            syncMatchups: false,
            preserveManualHandicapEdits: false
        )
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

        options.syncFormat = false
        options.syncOrganization = true
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

        options.syncOrganization = false
        options.syncPlayerData = true
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

        options.syncPlayerData = false
        options.syncPairs = true
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .paused))

        options.syncPairs = false
        options.syncMatchups = true
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .paused))
    }

    func testValidateOptions_blocksAllWhenComplete() {
        let options = SeriesRoundSyncOptions(
            syncPlayerData: true,
            syncFormat: true,
            syncOrganization: true,
            syncPairs: true,
            syncMatchups: true,
            preserveManualHandicapEdits: false
        )
        XCTAssertNotNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .complete))
    }

    func testRoundStatusPreservationPreventsLobbyDowngrade() {
        XCTAssertTrue(SeriesRoundSyncService.shouldPreserveCurrentRoundStatus(candidate: .lobby, current: .live))
        XCTAssertTrue(SeriesRoundSyncService.shouldPreserveCurrentRoundStatus(candidate: .lobby, current: .paused))
        XCTAssertTrue(SeriesRoundSyncService.shouldPreserveCurrentRoundStatus(candidate: .lobby, current: .complete))
        XCTAssertFalse(SeriesRoundSyncService.shouldPreserveCurrentRoundStatus(candidate: .live, current: .lobby))
        XCTAssertFalse(SeriesRoundSyncService.shouldPreserveCurrentRoundStatus(candidate: .lobby, current: .lobby))
    }

    func testPartnershipScoringGroupPatchRebuildsPairsOnly() {
        var cfg = SeriesRoundConfiguration()
        cfg.scoreOwnerScope = .partnership
        let seriesRound = SeriesRound(
            id: "sr1",
            roundConfig: cfg,
            partnershipPlans: [
                SeriesRoundPartnershipPlan(id: "pair_red", teamID: "series_red", memberIDs: ["m1", "m2"], label: "Red Pair"),
                SeriesRoundPartnershipPlan(id: "pair_blue", teamID: "series_blue", memberIDs: ["m3", "m4"], label: "Blue Pair"),
            ],
            parentID: "series1"
        )
        let participants = [
            RoundParticipant(id: "p1", seriesMemberID: "m1", teamID: "round_red", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p2", seriesMemberID: "m2", teamID: "round_red", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p3", seriesMemberID: "m3", teamID: "round_blue", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p4", seriesMemberID: "m4", teamID: "round_blue", groupID: "g1", createdAt: t0, parentID: "round1"),
        ]
        let teeGroups = [
            TeeTimeGroup(id: "g1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 7, createdAt: t0, parentID: "round1"),
        ]
        let teeGroupOwner = RoundScoringGroup(
            id: "tee_group_g1",
            kind: .teeGroup,
            memberIDs: ["p1", "p2", "p3", "p4"],
            createdAt: t0,
            parentID: "round1"
        )
        let oldPair = RoundScoringGroup(
            id: "old_pair",
            kind: .partnership,
            memberIDs: ["p1", "p3"],
            createdAt: t0,
            parentID: "round1"
        )

        let patch = SeriesRoundSyncPlanning.partnershipScoringGroupPatch(
            roundID: "round1",
            seriesRound: seriesRound,
            participants: participants,
            partnershipPlans: seriesRound.partnershipPlans,
            teeGroups: teeGroups,
            existingScoringGroups: [teeGroupOwner, oldPair]
        )

        XCTAssertEqual(Set(patch.scoringGroupsToPut.map(\.id)), ["pair_red", "pair_blue"])
        XCTAssertEqual(patch.scoringGroupsToDelete.map(\.id), ["old_pair"])
        XCTAssertTrue(patch.mergedScoringGroups.contains(where: { $0.id == "tee_group_g1" && $0.kind == .teeGroup }))
        XCTAssertEqual(teeGroups.first?.startingHole, 7)
    }

    func testTeeGroupScoringGroupPatchRebuildsTeeOwnersOnly() {
        var cfg = SeriesRoundConfiguration()
        cfg.scoreOwnerScope = .teeGroup
        let seriesRound = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        let participants = [
            RoundParticipant(id: "p1", seriesMemberID: "m1", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p2", seriesMemberID: "m2", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p3", seriesMemberID: "m3", groupID: "g2", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p4", seriesMemberID: "m4", groupID: "g2", createdAt: t0, parentID: "round1"),
        ]
        let teeGroups = [
            TeeTimeGroup(id: "g1", index: 0, startingHole: 4, createdAt: t0, parentID: "round1"),
            TeeTimeGroup(id: "g2", index: 1, startingHole: 8, createdAt: t0, parentID: "round1"),
        ]
        let oldTeeGroup = RoundScoringGroup(
            id: "tee_group_old",
            kind: .teeGroup,
            memberIDs: ["old"],
            createdAt: t0,
            parentID: "round1"
        )
        let existingPair = RoundScoringGroup(
            id: "pair_existing",
            kind: .partnership,
            memberIDs: ["p1", "p2"],
            createdAt: t0,
            parentID: "round1"
        )

        let patch = SeriesRoundSyncPlanning.teeGroupScoringGroupPatch(
            roundID: "round1",
            seriesRound: seriesRound,
            participants: participants,
            partnershipPlans: [],
            teeGroups: teeGroups,
            existingScoringGroups: [oldTeeGroup, existingPair]
        )

        XCTAssertEqual(Set(patch.scoringGroupsToPut.map(\.id)), ["tee_group_g1", "tee_group_g2"])
        XCTAssertEqual(patch.scoringGroupsToDelete.map(\.id), ["tee_group_old"])
        XCTAssertTrue(patch.mergedScoringGroups.contains(where: { $0.id == "pair_existing" && $0.kind == .partnership }))
        XCTAssertEqual(
            patch.scoringGroupsToPut.first { $0.id == "tee_group_g1" }?.memberIDs,
            ["p1", "p2"]
        )
    }

    func testBuildUpdatedSegment_matchupsOnlyPreservesFormatAndScoringUnits() {
        let context = pairMatchupContext()
        let existingUnit = ScoringUnit(id: "existing_unit", owner: .participant, ownerIDs: ["p1"])
        let existingSegment = RoundSegment(
            id: "seg1",
            holeRange: HoleRange(startHole: 10, endHole: 18),
            templateID: "old_template",
            scoringUnits: [existingUnit],
            matchups: [TeamMatchup(id: "old_matchup", teamIDs: ["old_a", "old_b"], mode: .team)],
            competitionScope: .field,
            parentID: "round1"
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: context.scoringGroups,
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: false,
            updateMatchups: true
        )

        XCTAssertEqual(updated.templateID, "old_template")
        XCTAssertEqual(updated.holeRange, HoleRange(startHole: 10, endHole: 18))
        XCTAssertEqual(updated.competitionScope, .field)
        XCTAssertEqual(updated.scoringUnits, [existingUnit])
        XCTAssertEqual(updated.matchups?.map(\.id), ["pair_match"])
        XCTAssertEqual(updated.matchups?.first?.scoreOwnerIDs, ["pair_red", "pair_blue"])
    }

    func testBuildUpdatedSegment_pairsAndMatchupsSupportPairVsPairScoreOwnerMatchups() {
        let context = pairMatchupContext()
        let existingSegment = RoundSegment(id: "seg1", parentID: "round1")

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: context.scoringGroups,
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: true,
            updateMatchups: true
        )

        XCTAssertEqual(updated.matchups?.count, 1)
        XCTAssertEqual(updated.matchups?.first?.mode, .partnership)
        XCTAssertNil(updated.matchups?.first?.scoreOwnerScope)
        XCTAssertEqual(updated.matchups?.first?.scoreOwnerIDs, ["pair_red", "pair_blue"])
    }

    func testBuildUpdatedSegment_matchupsOnlyPairSyncPreservesIndividualScoreEntry() {
        var context = pairMatchupContext()
        context.seriesRound.roundConfig.scoreOwnerScope = .individual
        let existingUnit = ScoringUnit(id: "p1", owner: .participant, ownerIDs: ["p1"])
        let existingSegment = RoundSegment(
            id: "seg1",
            scoringUnits: [existingUnit],
            matchups: [],
            parentID: "round1"
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: context.scoringGroups,
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: false,
            updateMatchups: true
        )

        XCTAssertEqual(context.seriesRound.roundConfig.scoreOwnerScope, .individual)
        XCTAssertEqual(updated.scoringUnits, [existingUnit])
        XCTAssertEqual(updated.matchups?.first?.mode, .partnership)
        XCTAssertNil(updated.matchups?.first?.scoreOwnerScope)
        XCTAssertEqual(updated.matchups?.first?.scoreOwnerIDs, ["pair_red", "pair_blue"])
    }

    func testBuildUpdatedSegment_matchupsOnlyUsesExistingRoundMatchupMode() {
        let context = pairMatchupContext()
        let existingSegment = RoundSegment(
            id: "seg1",
            gameFormat: context.seriesRound.roundConfig.legacyGameFormat,
            scoringUnits: [
                ScoringUnit(id: "p1", owner: .participant, ownerIDs: ["p1"]),
                ScoringUnit(id: "p2", owner: .participant, ownerIDs: ["p2"]),
            ],
            matchups: [],
            competitionScope: .matchup,
            parentID: "round1"
        )
        let existingRoundConfiguration = RoundConfiguration(
            primaryFormat: context.seriesRound.roundConfig.legacyGameFormat,
            competitionScope: .matchup,
            scoreOwnerScope: .individual
        )
        let scoringSeriesRound = SeriesRoundSyncPlanning.scoringSeriesRoundForExistingRound(
            context.seriesRound,
            roundConfiguration: existingRoundConfiguration,
            existingSegment: existingSegment
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            scoringSeriesRound: scoringSeriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: context.scoringGroups,
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: false,
            updateMatchups: true
        )

        XCTAssertEqual(scoringSeriesRound.roundConfig.scoreOwnerScope, .individual)
        XCTAssertEqual(scoringSeriesRound.roundConfig.matchupMode, .teamVsTeam)
        XCTAssertEqual(updated.matchups?.count, 1)
        XCTAssertEqual(updated.matchups?.first?.mode, .team)
        XCTAssertEqual(updated.matchups?.first?.teamIDs, ["round_red", "round_blue"])
        XCTAssertNil(updated.matchups?.first?.scoreOwnerIDs)
    }

    func testBuildUpdatedSegment_matchupsOnlyDoesNotClearExistingMatchupsWhenLeagueRebuildIsEmpty() {
        var context = teamVsTeamMatchupContext()
        context.teamLinks = [:]
        let existingMatchup = TeamMatchup(id: "existing_match", teamIDs: ["round_red", "round_blue"], mode: .team)
        let existingSegment = RoundSegment(
            id: "seg1",
            matchups: [existingMatchup],
            competitionScope: .matchup,
            parentID: "round1"
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: [],
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: false,
            updateMatchups: true
        )

        XCTAssertEqual(updated.competitionScope, .matchup)
        XCTAssertEqual(updated.matchups, [existingMatchup])
    }

    func testBuildUpdatedSegment_matchupsOnlyUsesSeriesMatchupPlansWhenLinkedRoundWasBackPropagatedToField() {
        let context = teamVsTeamMatchupContext()
        let existingSegment = RoundSegment(
            id: "seg1",
            matchups: nil,
            competitionScope: .field,
            parentID: "round1"
        )
        let linkedRoundConfiguration = RoundConfiguration(
            primaryFormat: context.seriesRound.roundConfig.legacyGameFormat,
            competitionScope: .field,
            teamScoring: .init(mode: .bestN, count: 2, scope: .perRound),
            matchupScoringStyle: .aggregateRoundTotal,
            selectionDomain: .team
        )
        let scoringSeriesRound = SeriesRoundSyncPlanning.scoringSeriesRoundForExistingRound(
            context.seriesRound,
            roundConfiguration: linkedRoundConfiguration,
            existingSegment: existingSegment
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            scoringSeriesRound: scoringSeriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: [],
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: false,
            updateMatchups: true
        )

        XCTAssertEqual(scoringSeriesRound.roundConfig.resolvedCompetitionScope, .matchup)
        XCTAssertEqual(scoringSeriesRound.roundConfig.matchupMode, .teamVsTeam)
        XCTAssertEqual(updated.matchups?.map(\.id), ["team_match"])
        XCTAssertEqual(updated.matchups?.first?.teamIDs, ["round_red", "round_blue"])
    }

    func testBuildUpdatedSegment_matchupsOnlyPreservesManualMaxScoreWhenFormatIsNotSynced() {
        let context = teamVsTeamMatchupContext()
        var existingFormat = context.seriesRound.roundConfig.legacyGameFormat
        existingFormat.configuration.maxScoreOverPar = .double
        let existingSegment = RoundSegment(
            id: "seg1",
            gameFormat: existingFormat,
            matchups: [TeamMatchup(id: "old_match", teamIDs: ["round_red", "round_blue"], mode: .team)],
            competitionScope: .matchup,
            parentID: "round1"
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: context.seriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: [],
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: false,
            updateScoringUnits: false,
            updateMatchups: true
        )

        XCTAssertEqual(updated.gameFormat.configuration.maxScoreOverPar, .double)
    }

    func testScoringSeriesRoundForExistingRoundCopiesSelectionDomain() {
        var roundConfiguration = RoundConfiguration(selectionDomain: .partnership)
        roundConfiguration.competitionScope = .matchup
        var teamFormat = GameFormat.strokePlay
        teamFormat.configuration.requiresTeams = true
        roundConfiguration.primaryFormat = teamFormat
        roundConfiguration.teamScoring = .init(mode: .bestN, count: 1, scope: .perHole)
        let seriesRound = SeriesRound(id: "sr1", parentID: "series1")
        let existingSegment = RoundSegment(id: "seg1", templateID: FormatTemplateRegistry.strokePlay.id)

        let updated = SeriesRoundSyncPlanning.scoringSeriesRoundForExistingRound(
            seriesRound,
            roundConfiguration: roundConfiguration,
            existingSegment: existingSegment
        )

        XCTAssertEqual(updated.roundConfig.selectionDomain, .partnership)
        XCTAssertEqual(updated.roundConfig.teamScoring, roundConfiguration.teamScoring)
        XCTAssertEqual(updated.roundConfig.matchupMode, .teamVsTeam)
    }

    @MainActor
    func testRoundTileLinkedActionCopyAndRSVPAttendancePreloadEligibility() {
        let viewModel = SeriesViewModel()
        var settings = SeriesSettings()
        settings.isAttendanceEnabled = true
        viewModel.series = Series(id: "series1", settings: settings)

        let planned = SeriesRound(id: "planned", status: .planned, parentID: "series1")
        let lobby = SeriesRound(id: "lobby", status: .lobby, roundID: "round_lobby", parentID: "series1")
        let live = SeriesRound(id: "live", status: .live, roundID: "round_live", parentID: "series1")
        viewModel.rounds = [planned, lobby, live]
        viewModel.linkedRounds = [
            "round_lobby": Round(id: "round_lobby", status: .lobby),
            "round_live": Round(id: "round_live", status: .live),
        ]

        XCTAssertEqual(viewModel.openLinkedRoundButtonTitle(for: lobby), "Open lobby")
        XCTAssertEqual(viewModel.openLinkedRoundButtonTitle(for: live), "Continue playing")
        XCTAssertTrue(viewModel.isRSVPEligible(for: planned))
        XCTAssertFalse(viewModel.isRSVPEligible(for: lobby))
        XCTAssertFalse(viewModel.isRSVPEligible(for: live))
        XCTAssertTrue(viewModel.shouldPreloadAttendance(for: planned))
        XCTAssertFalse(viewModel.shouldPreloadAttendance(for: lobby))
        XCTAssertFalse(viewModel.shouldPreloadAttendance(for: live))
    }

    func testTeamLinks_filtersMappings() {
        let sid = "sr1"
        let mappings = [
            SeriesRoundMapping(
                id: "m1",
                seriesRoundID: sid,
                roundOwnerType: .team,
                roundOwnerID: "rt_a",
                competitorType: .team,
                competitorID: "st_a",
                createdAt: t0,
                lastUpdatedAt: t0,
                parentID: "series1"
            ),
            SeriesRoundMapping(
                id: "m2",
                seriesRoundID: "other",
                roundOwnerType: .team,
                roundOwnerID: "x",
                competitorType: .team,
                competitorID: "y",
                createdAt: t0,
                lastUpdatedAt: t0,
                parentID: "series1"
            ),
        ]
        let links = SeriesRoundSyncPlanning.teamLinks(mappings: mappings, seriesRoundID: sid)
        XCTAssertEqual(links["st_a"]?.roundTeamID, "rt_a")
        XCTAssertNil(links["y"])
    }

    func testTeamLinksForSync_createsMissingRoundTeamLinks() {
        let teamA = SeriesTeam(id: "series_a", name: "A", color: "red", index: 0, createdAt: t0, parentID: "series1")
        let teamB = SeriesTeam(id: "series_b", name: "B", color: "blue", index: 1, createdAt: t0, parentID: "series1")

        let links = SeriesRoundSyncPlanning.teamLinksForSync(
            seriesTeamsForRound: [teamA, teamB],
            existingLinks: [
                "series_a": .init(seriesTeamID: "series_a", roundTeamID: "round_a")
            ],
            roundID: "round1"
        )

        XCTAssertEqual(links["series_a"]?.roundTeamID, "round_a")
        XCTAssertEqual(links["series_b"]?.roundTeamID, "round1_series_team_series_b")
    }

    func testRoundTeamsPatch_createsMissingRoundTeamFromSeries() throws {
        let team = SeriesTeam(id: "series_b", name: "Blue", color: "blue", index: 1, createdAt: t0, parentID: "series1")
        let patched = try SeriesRoundSyncPlanning.roundTeamsPatch(
            seriesTeamsForRound: [team],
            teamLinks: [
                "series_b": .init(seriesTeamID: "series_b", roundTeamID: "round1_series_team_series_b")
            ],
            snapshot: RoundSnapshot(round: Round(id: "round1"))
        )

        XCTAssertEqual(patched.first?.id, "round1_series_team_series_b")
        XCTAssertEqual(patched.first?.name, "Blue")
        XCTAssertEqual(patched.first?.parentID, "round1")
    }

    @MainActor
    func testEffectiveRoundConfig_usesSeriesConfigEvenWhenBackPropagationFlagIsEnabled() {
        let viewModel = SeriesViewModel()
        let linkedRound = Round(
            id: "round1",
            status: .lobby,
            configuration: RoundConfiguration(
                formatSummary: RoundFormatSummary(templateID: "linked_template")
            )
        )
        viewModel.linkedRounds = ["round1": linkedRound]

        var seriesConfig = SeriesRoundConfiguration(
            formatTemplateID: "series_template",
            allowLobbyBackPropagation: true
        )
        let seriesRound = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: seriesConfig,
            parentID: "series1"
        )

        XCTAssertEqual(viewModel.effectiveRoundConfig(for: seriesRound).formatTemplateID, "series_template")

        seriesConfig.allowLobbyBackPropagation = false
        let disabledSeriesRound = SeriesRound(
            id: "series_round2",
            roundID: "round1",
            roundConfig: seriesConfig,
            parentID: "series1"
        )

        XCTAssertEqual(viewModel.effectiveRoundConfig(for: disabledSeriesRound).formatTemplateID, "series_template")
    }

    @MainActor
    func testShouldSyncLinkedLobbyAfterSeriesRoundUpdate_detectsPlannedTeeStartChange() {
        let viewModel = SeriesViewModel()
        let previousGroup = SeriesRoundPlannedTeeGroup(id: "group1", index: 0, startingHole: 1)
        let updatedGroup = SeriesRoundPlannedTeeGroup(id: "group1", index: 0, startingHole: 4)
        let previous = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            plannedTeeGroups: [previousGroup],
            notes: "same",
            parentID: "series1"
        )
        let updated = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            plannedTeeGroups: [updatedGroup],
            notes: "same",
            parentID: "series1"
        )

        XCTAssertTrue(viewModel.shouldSyncLinkedLobbyAfterSeriesRoundUpdate(previous: previous, updated: updated))
    }

    @MainActor
    func testShouldSyncLinkedLobbyAfterSeriesRoundUpdate_ignoresNotesOnlyChangeAndUnlinkedRound() {
        let viewModel = SeriesViewModel()
        let linkedPrevious = SeriesRound(id: "series_round1", roundID: "round1", notes: "old", parentID: "series1")
        let linkedUpdated = SeriesRound(id: "series_round1", roundID: "round1", notes: "new", parentID: "series1")
        let unlinkedPrevious = SeriesRound(id: "series_round2", notes: "old", parentID: "series1")
        var unlinkedUpdated = unlinkedPrevious
        unlinkedUpdated.plannedTeeGroups = [SeriesRoundPlannedTeeGroup(id: "group1", index: 0, startingHole: 4)]

        XCTAssertFalse(viewModel.shouldSyncLinkedLobbyAfterSeriesRoundUpdate(previous: linkedPrevious, updated: linkedUpdated))
        XCTAssertFalse(viewModel.shouldSyncLinkedLobbyAfterSeriesRoundUpdate(previous: unlinkedPrevious, updated: unlinkedUpdated))
    }

    @MainActor
    func testCachedSourceSeriesRoundForSyncUsesFreshViewModelRoundInsteadOfCapturedSheetValue() {
        let viewModel = SeriesViewModel()
        let staleConfig = SeriesRoundConfiguration(maxScoreOverPar: .quad)
        let freshConfig = SeriesRoundConfiguration(maxScoreOverPar: .twoTimesParPlusOne)
        let stale = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: staleConfig,
            plannedTeeGroups: [SeriesRoundPlannedTeeGroup(id: "group1", index: 0, startingHole: 1)],
            parentID: "series1"
        )
        let fresh = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: freshConfig,
            plannedTeeGroups: [SeriesRoundPlannedTeeGroup(id: "group1", index: 0, startingHole: 4)],
            parentID: "series1"
        )
        viewModel.rounds = [fresh]

        let source = viewModel.cachedSourceSeriesRoundForSync(stale)

        XCTAssertEqual(source.roundConfig.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertEqual(source.plannedTeeGroups.first?.startingHole, 4)
    }

    @MainActor
    func testSeriesRoundForSyncPreservesStoredMaxScoreWhenLeagueDefaultChanges() {
        let viewModel = SeriesViewModel()
        var settings = SeriesSettings()
        settings.defaultRoundConfig.maxScoreOverPar = .twoTimesParPlusOne
        viewModel.series = Series(id: "series1", settings: settings)
        let seriesRound = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: SeriesRoundConfiguration(maxScoreOverPar: .quad),
            plannedTeeGroups: [SeriesRoundPlannedTeeGroup(id: "group1", index: 0, startingHole: 4)],
            parentID: "series1"
        )

        let source = viewModel.seriesRoundForSyncPreservingAuthoredConfiguration(seriesRound)

        XCTAssertEqual(source.roundConfig.maxScoreOverPar, .quad)
        XCTAssertEqual(source.plannedTeeGroups.first?.startingHole, 4)
    }

    @MainActor
    func testSeriesRoundForSyncPreservesRoundMaxScoreWhenLeagueDefaultMissing() {
        let viewModel = SeriesViewModel()
        viewModel.series = Series(id: "series1")
        let seriesRound = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: SeriesRoundConfiguration(maxScoreOverPar: .double),
            parentID: "series1"
        )

        let source = viewModel.seriesRoundForSyncPreservingAuthoredConfiguration(seriesRound)

        XCTAssertEqual(source.roundConfig.maxScoreOverPar, .double)
    }

    @MainActor
    func testEffectiveRoundConfig_doesNotDowngradeSeriesMatchupRoundWhenLinkedRoundIsFieldButPlansExist() {
        let viewModel = SeriesViewModel()
        let linkedRound = Round(
            id: "round1",
            status: .live,
            configuration: RoundConfiguration(
                primaryFormat: GameFormat.strokePlay,
                competitionScope: .field,
                matchupScoringStyle: .aggregateRoundTotal,
                selectionDomain: .team
            )
        )
        viewModel.linkedRounds = ["round1": linkedRound]

        var seriesConfig = SeriesRoundConfiguration(
            formatTemplateID: FormatTemplateRegistry.bestBall.id,
            competitionScope: .matchup,
            matchupMode: .teamVsTeam,
            teamAssignmentMode: .seriesTeams,
            allowLobbyBackPropagation: true
        )
        seriesConfig.teamScoring = .init(mode: .bestN, count: 2, scope: .perRound)
        let seriesRound = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: seriesConfig,
            matchupPlans: [
                SeriesRoundMatchupPlan(id: "team_match", teamAID: "series_red", teamBID: "series_blue")
            ],
            parentID: "series1"
        )

        let effective = viewModel.effectiveRoundConfig(for: seriesRound)

        XCTAssertEqual(effective.resolvedCompetitionScope, .matchup)
        XCTAssertEqual(effective.matchupMode, .teamVsTeam)
    }

    func testOrganizationTeamMappingPreflight_reportsMissingTeamIDs() {
        let seriesTeams = [
            SeriesTeam(
                id: "series_team1",
                name: "Team 1",
                color: "red",
                index: 0,
                createdAt: t0,
                lastUpdatedAt: t0,
                parentID: "series1"
            ),
            SeriesTeam(
                id: "series_team2",
                name: "Team 2",
                color: "blue",
                index: 1,
                createdAt: t0,
                lastUpdatedAt: t0,
                parentID: "series1"
            ),
        ]
        let teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [
            "series_team1": .init(seriesTeamID: "series_team1", roundTeamID: "round_team1"),
        ]
        let snapshot = RoundSnapshot(
            teams: [
                RoundTeam(
                    id: "round_team1",
                    name: "Team 1",
                    color: "red",
                    index: 0,
                    createdAt: t0,
                    lastUpdatedAt: t0,
                    parentID: "round1"
                ),
            ]
        )

        let error = SeriesRoundSyncPlanning.organizationTeamMappingPreflightError(
            seriesTeamsForRound: seriesTeams,
            teamLinks: teamLinks,
            snapshot: snapshot
        )

        guard case .preflightFailed(let message) = error else {
            return XCTFail("Expected preflightFailed")
        }
        XCTAssertTrue(message.contains("Expected 2, found 1"))
        XCTAssertTrue(message.contains("series_team2"))
    }

    func testOrganizationPrunePlanRemovesEmptyArtifactsAndInvalidMatchups() {
        let participants = [
            RoundParticipant(
                id: "p1",
                name: Name("Alice", "One"),
                teamID: "team_active",
                groupID: "group_active",
                createdAt: t0,
                parentID: "round1"
            ),
            RoundParticipant(
                id: "p2",
                name: Name("Bob", "Two"),
                teamID: "team_other",
                groupID: "group_active",
                createdAt: t0,
                parentID: "round1"
            ),
        ]
        let snapshot = RoundSnapshot(
            participants: participants,
            teams: [
                RoundTeam(id: "team_active", name: "Team 1", color: "red", index: 0, createdAt: t0, parentID: "round1"),
                RoundTeam(id: "team_other", name: "Team 2", color: "blue", index: 1, createdAt: t0, parentID: "round1"),
                RoundTeam(id: "team_empty", name: "Team 3", color: "green", index: 2, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [
                TeeTimeGroup(id: "group_active", index: 0, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "group_empty", index: 1, createdAt: t0, parentID: "round1"),
            ],
            scoringGroups: [
                RoundScoringGroup(id: "pair_active", kind: .partnership, memberIDs: ["p1", "p2"], createdAt: t0, parentID: "round1"),
                RoundScoringGroup(id: "pair_empty", kind: .partnership, memberIDs: ["ghost"], createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(
                    id: "segment1",
                    matchups: [
                        TeamMatchup(id: "valid_team", teamIDs: ["team_active", "team_other"], mode: .team),
                        TeamMatchup(id: "empty_team", teamIDs: ["team_active", "team_empty"], mode: .team),
                        TeamMatchup(id: "ghost_participant", participantIDs: ["p1", "ghost"], mode: .individual),
                        TeamMatchup(id: "bad_score_owner", scoreOwnerIDs: ["pair_active", "pair_empty"], scoreOwnerScope: .partnership, mode: .scoreOwner),
                    ]
                ),
            ]
        )

        let plan = SeriesRoundSyncPlanning.organizationPrunePlan(snapshot: snapshot)

        XCTAssertEqual(plan.teeGroupsToDelete.map(\.id), ["group_empty"])
        XCTAssertEqual(plan.teamsToDelete.map(\.id), ["team_empty"])
        XCTAssertEqual(plan.scoringGroupsToDelete.map(\.id), ["pair_empty"])
        XCTAssertEqual(plan.retainedMatchups.map(\.id), ["valid_team"])
        XCTAssertTrue(plan.didPruneMatchups)
    }

    func testParticipantsWithPlayerDataSync_preservesManualHandicap() {
        let p = RoundParticipant(
            id: "part1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Old", "Name"),
            teeBoxID: "tee_old",
            originalHandicap: 12,
            adjustedHandicap: 14,
            handicapIndex: 12.9,
            leagueHandicapStrokesAtCreation: 12,
            seriesMemberID: "mem1",
            teamID: "team_round",
            groupID: "g1",
            teeOrder: 1,
            isHost: true,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )
        let member = SeriesMember(
            id: "mem1",
            userID: "u1",
            playerID: "pl1",
            name: Name("New", "Name"),
            teamID: nil,
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let membersByHandicap: [String: SeriesMemberHandicap] = [
            "mem1": SeriesMemberHandicap(
                id: "mem1",
                memberID: "mem1",
                computedIndex: 8,
                overrideIndex: nil,
                isOverridden: false
            ),
        ]
        let assignment = SeriesRoundCreationMapping.MemberAssignment(groupID: "g1", teeOrder: 1)

        let out = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
            participants: [p],
            roundID: "round1",
            participatingMembers: [member],
            teamLinks: [:],
            memberAssignments: ["mem1": assignment],
            handicaps: membersByHandicap,
            courseSegment: CourseSegment(
                courseInfo: CourseInfo(
                    id: "c1",
                    golfCourseApiID: nil,
                    name: "C",
                    totalHoles: 18,
                    location: nil,
                    tees: []
                ),
                holeRange: HoleRange(startHole: 1, endHole: 18),
                defaultTee: "tee_white"
            ),
            hostPlayerID: "pl1",
            preserveManualHandicapEdits: true
        )

        XCTAssertEqual(out.first?.name.fullName, "New Name")
        XCTAssertEqual(out.first?.adjustedHandicap, 14)
        XCTAssertEqual(out.first?.handicapIndex, 12.9)
        XCTAssertEqual(out.first?.teeBoxID, "tee_white")
    }

    func testParticipantsWithPlayerDataSyncPreserveManualFillsMissingCourseHandicapIndex() {
        let p = RoundParticipant(
            id: "part1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Old", "Name"),
            teeBoxID: "tee_white",
            originalHandicap: 12,
            adjustedHandicap: 14,
            handicapIndex: nil,
            leagueHandicapStrokesAtCreation: 12,
            seriesMemberID: "mem1",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )
        let member = SeriesMember(
            id: "mem1",
            userID: "u1",
            playerID: "pl1",
            name: Name("New", "Name"),
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )

        let out = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
            participants: [p],
            roundID: "round1",
            participatingMembers: [member],
            teamLinks: [:],
            memberAssignments: [:],
            handicaps: [
                "mem1": SeriesMemberHandicap(id: "mem1", memberID: "mem1", computedIndex: 6.2),
            ],
            courseSegment: testCourseSegment(),
            handicapEntryFormat: .courseHandicap,
            hostPlayerID: nil,
            preserveManualHandicapEdits: true
        )

        XCTAssertEqual(out.first?.adjustedHandicap, 14)
        XCTAssertEqual(out.first?.originalHandicap, 12)
        XCTAssertEqual(out.first?.handicapIndex, 6.2)
        XCTAssertEqual(out.first?.leagueHandicapStrokesAtCreation, 12)
    }

    func testParticipantsWithPlayerDataSyncPreservesDecimalIndexForCourseHandicap() {
        let p = RoundParticipant(
            id: "part1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Old", "Name"),
            teeBoxID: "tee_white",
            originalHandicap: 4,
            adjustedHandicap: 4,
            leagueHandicapStrokesAtCreation: 4,
            seriesMemberID: "mem1",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )
        let member = SeriesMember(
            id: "mem1",
            userID: "u1",
            playerID: "pl1",
            name: Name("New", "Name"),
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )

        let out = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
            participants: [p],
            roundID: "round1",
            participatingMembers: [member],
            teamLinks: [:],
            memberAssignments: [:],
            handicaps: [
                "mem1": SeriesMemberHandicap(id: "mem1", memberID: "mem1", computedIndex: 6.2),
            ],
            courseSegment: testCourseSegment(),
            handicapEntryFormat: .courseHandicap,
            hostPlayerID: nil,
            preserveManualHandicapEdits: false
        )

        XCTAssertEqual(out.first?.handicapIndex, 6.2)
        XCTAssertEqual(out.first?.originalHandicap, 6)
        XCTAssertEqual(out.first?.adjustedHandicap, 6)
        XCTAssertEqual(out.first?.leagueHandicapStrokesAtCreation, 6)
    }

    func testParticipantsWithPlayerDataSync_capsSeriesHandicapWhenNotPreservingManualEdit() {
        let p = RoundParticipant(
            id: "part1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Old", "Name"),
            teeBoxID: "tee_old",
            originalHandicap: 12,
            adjustedHandicap: 12,
            leagueHandicapStrokesAtCreation: 12,
            seriesMemberID: "mem1",
            isHost: true,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )
        let member = SeriesMember(
            id: "mem1",
            userID: "u1",
            playerID: "pl1",
            name: Name("New", "Name"),
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )

        let out = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
            participants: [p],
            roundID: "round1",
            participatingMembers: [member],
            teamLinks: [:],
            memberAssignments: ["mem1": .init(groupID: "g1", teeOrder: 1)],
            handicaps: [
                "mem1": SeriesMemberHandicap(id: "mem1", memberID: "mem1", computedIndex: 27.7),
            ],
            maximumHandicap: 18,
            courseSegment: CourseSegment(
                courseInfo: CourseInfo(
                    id: "c1",
                    golfCourseApiID: nil,
                    name: "C",
                    totalHoles: 18,
                    location: nil,
                    tees: []
                ),
                holeRange: HoleRange(startHole: 1, endHole: 18),
                defaultTee: "tee_white"
            ),
            hostPlayerID: "pl1",
            preserveManualHandicapEdits: false
        )

        XCTAssertEqual(out.first?.originalHandicap, 18)
        XCTAssertEqual(out.first?.adjustedHandicap, 18)
        XCTAssertEqual(out.first?.leagueHandicapStrokesAtCreation, 18)
    }

    func testResolvedPlanCarriesSeriesHandicapBasisForSync() {
        var settings = SeriesSettings()
        var handicapConfig = HandicapComputationConfig.league2025
        handicapConfig.maximumHandicap = 18
        settings.handicapConfig = SeriesHandicapConfig(
            isEnabled: true,
            config: HandicapComputationConfigDTO(from: handicapConfig),
            strokeBasis: .nineHole
        )
        let series = Series(id: "series1", settings: settings)
        let member = SeriesMember(
            id: "mem1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Player", "One"),
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let courseSegment = CourseSegment(
            courseInfo: CourseInfo(
                id: "c1",
                golfCourseApiID: nil,
                name: "C",
                totalHoles: 18,
                location: nil,
                tees: []
            ),
            holeRange: HoleRange(startHole: 1, endHole: 9),
            defaultTee: "tee_white"
        )

        var cfg = SeriesRoundConfiguration()
        cfg.handicapStrokeBasis = .nineHole
        let plan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1"),
            members: [member],
            teams: [],
            pods: [],
            courseSegment: courseSegment
        )

        XCTAssertEqual(plan.roundConfiguration.handicapStrokeBasis, .nineHole)
        XCTAssertEqual(plan.roundConfiguration.leagueHandicapMaximum, 18)
        XCTAssertTrue(plan.roundConfiguration.useHandicaps)
        XCTAssertEqual(plan.roundConfiguration.handicapsEnabled, true)
    }

    func testTeeGroupsWithLeagueSchedule_usesExistingFirstTimeWhenNoScheduledDate() throws {
        var cfg = SeriesRoundConfiguration()
        cfg.sequentialTeeStartsEnabled = true
        let seriesRound = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", status: .lobby),
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 1, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, teeTime: "2026-05-01T14:08:00Z", startingHole: 1, createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(id: "seg1", parentID: "round1")
            ]
        )
        var snap = snapshot
        snap.round.configuration.courses = [
            testCourseSegment()
        ]

        let updated = try SeriesRoundSyncPlanning.teeGroupsWithLeagueSchedule(
            snapshot: snap,
            groupPlans: [
                .init(id: "p1", memberIDs: ["m1"]),
                .init(id: "p2", memberIDs: ["m2"]),
            ],
            seriesRound: seriesRound
        )

        XCTAssertEqual(Set(updated.compactMap(\.teeTime)), ["2026-05-01T14:00:00Z"])
        XCTAssertEqual(updated.map(\.startingHole), [1, 2])
    }

    func testTeeGroupsWithLeagueSchedule_preservesSavedPlannedStartingHoles() throws {
        var cfg = SeriesRoundConfiguration()
        cfg.sequentialTeeStartsEnabled = true
        let seriesRound = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        var snapshot = RoundSnapshot(
            round: Round(id: "round1", status: .lobby),
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 1, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, teeTime: "2026-05-01T14:08:00Z", startingHole: 2, createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(id: "seg1", parentID: "round1")
            ]
        )
        snapshot.round.configuration.courses = [
            testCourseSegment()
        ]

        let updated = try SeriesRoundSyncPlanning.teeGroupsWithLeagueSchedule(
            snapshot: snapshot,
            groupPlans: [
                .init(id: "planned_1", memberIDs: ["m1"]),
                .init(id: "planned_2", memberIDs: ["m2"]),
            ],
            plannedTeeGroups: [
                SeriesRoundPlannedTeeGroup(id: "planned_1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 4),
                SeriesRoundPlannedTeeGroup(id: "planned_2", index: 1, teeTime: "2026-05-01T14:00:00Z", startingHole: 8),
            ],
            seriesRound: seriesRound
        )

        XCTAssertEqual(updated.map(\.id), ["g1", "g2"])
        XCTAssertEqual(updated.map(\.startingHole), [4, 8])
        XCTAssertEqual(Set(updated.compactMap(\.teeTime)), ["2026-05-01T14:00:00Z"])
    }

    func testTeeGroupsWithLeagueSchedule_preservesExistingLiveStartingHoles() throws {
        var cfg = SeriesRoundConfiguration()
        cfg.sequentialTeeStartsEnabled = true
        let seriesRound = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        var snapshot = RoundSnapshot(
            round: Round(id: "round1", status: .live),
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 4, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, teeTime: "2026-05-01T14:08:00Z", startingHole: 8, createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(id: "seg1", parentID: "round1")
            ]
        )
        snapshot.round.configuration.courses = [
            testCourseSegment()
        ]

        let updated = try SeriesRoundSyncPlanning.teeGroupsWithLeagueSchedule(
            snapshot: snapshot,
            groupPlans: [
                .init(id: "planned_1", memberIDs: ["m1"]),
                .init(id: "planned_2", memberIDs: ["m2"]),
            ],
            seriesRound: seriesRound
        )

        XCTAssertEqual(updated.map(\.id), ["g1", "g2"])
        XCTAssertEqual(updated.map(\.startingHole), [4, 8])
        XCTAssertEqual(Set(updated.compactMap(\.teeTime)), ["2026-05-01T14:00:00Z"])
    }

    func testTeeGroupsWithLeagueSchedule_addsMissingRoundGroupsFromSeriesPlan() throws {
        var cfg = SeriesRoundConfiguration()
        cfg.sequentialTeeStartsEnabled = true
        let seriesRound = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        var snapshot = RoundSnapshot(
            round: Round(id: "round1", status: .live),
            teeGroups: [
                TeeTimeGroup(id: "existing_g1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 1, createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(id: "seg1", parentID: "round1")
            ]
        )
        snapshot.round.configuration.courses = [
            testCourseSegment()
        ]

        let updated = try SeriesRoundSyncPlanning.teeGroupsWithLeagueSchedule(
            snapshot: snapshot,
            groupPlans: [
                .init(id: "planned_1", memberIDs: ["m1"]),
                .init(id: "planned_2", memberIDs: ["m2"]),
            ],
            plannedTeeGroups: [
                SeriesRoundPlannedTeeGroup(id: "planned_1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 4),
                SeriesRoundPlannedTeeGroup(id: "planned_2", index: 1, teeTime: "2026-05-01T14:00:00Z", startingHole: 8),
            ],
            seriesRound: seriesRound
        )

        XCTAssertEqual(updated.map(\.id), ["existing_g1", "round1_series_tee_group_planned_2"])
        XCTAssertEqual(updated.map(\.startingHole), [4, 8])
    }

    func testBuildMemberAssignmentsForSync_allowsSeriesTeeGroupCountToGrow() throws {
        let member1 = testMember(id: "m1", playerID: "p1")
        let member2 = testMember(id: "m2", playerID: "p2")
        let plannedGroups = [
            SeriesRoundPlannedTeeGroup(
                id: "planned_1",
                index: 0,
                seats: [SeriesRoundPlannedSeat(id: "m1", memberID: "m1", teeOrder: 1)]
            ),
            SeriesRoundPlannedTeeGroup(
                id: "planned_2",
                index: 1,
                seats: [SeriesRoundPlannedSeat(id: "m2", memberID: "m2", teeOrder: 1)]
            ),
        ]
        let seriesRound = SeriesRound(id: "sr1", plannedTeeGroups: plannedGroups, parentID: "series1")
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", configuration: RoundConfiguration(courses: [testCourseSegment()])),
            teeGroups: [TeeTimeGroup(id: "existing_g1", index: 0, startingHole: 1, createdAt: t0, parentID: "round1")],
            segments: [RoundSegment(id: "seg1", parentID: "round1")]
        )

        let built = try SeriesRoundSyncPlanning.buildMemberAssignmentsForSync(
            series: Series(id: "series1"),
            snapshot: snapshot,
            seriesRound: seriesRound,
            participatingMembers: [member1, member2],
            teams: [],
            pods: []
        )

        XCTAssertEqual(built.0["m1"]?.groupID, "existing_g1")
        XCTAssertEqual(built.0["m2"]?.groupID, "round1_series_tee_group_planned_2")
    }

    func testParticipantsWithOrganizationSync_preservesNonContiguousTeeOrder() {
        let participant = RoundParticipant(
            id: "part1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Player", "One"),
            teeBoxID: "tee_old",
            originalHandicap: 12,
            adjustedHandicap: 12,
            leagueHandicapStrokesAtCreation: 12,
            seriesMemberID: "mem1",
            teamID: "team_round_old",
            groupID: "g_old",
            teeOrder: 1,
            isHost: true,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )
        let member = SeriesMember(
            id: "mem1",
            userID: "u1",
            playerID: "pl1",
            name: Name("Player", "One"),
            teamID: "team_series",
            defaultTeeBoxID: nil,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let out = SeriesRoundSyncPlanning.participantsWithOrganizationSync(
            participants: [participant],
            participatingMembers: [member],
            teamLinks: [
                "team_series": .init(seriesTeamID: "team_series", roundTeamID: "team_round_new"),
            ],
            memberAssignments: [
                "mem1": .init(groupID: "g_new", teeOrder: 3),
            ],
            usesSeriesTeams: true
        )

        XCTAssertEqual(out.first?.groupID, "g_new")
        XCTAssertEqual(out.first?.teeOrder, 3)
        XCTAssertEqual(out.first?.teamID, "team_round_new")
    }

    func testParticipantsWithOrganizationSync_repairsSubstituteMetadataAndRoundTeam() {
        let substituteParticipant = RoundParticipant(
            id: "part_sub",
            userID: "u_sub",
            playerID: "p_sub",
            name: Name("Sub", "Player"),
            teeBoxID: "tee_old",
            originalHandicap: 12,
            adjustedHandicap: 12,
            seriesMemberID: "sub",
            teamID: nil,
            groupID: "g_old",
            teeOrder: 1,
            isSubstitute: false,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )
        let originalMember = SeriesMember(
            id: "regular",
            userID: "u_regular",
            playerID: "p_regular",
            name: Name("Regular", "Player"),
            teamID: "team_series",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let substituteMember = SeriesMember(
            id: "sub",
            userID: "u_sub",
            playerID: "p_sub",
            name: Name("Sub", "Player"),
            role: .substitute,
            teamID: nil,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let plannedSeat = SeriesRoundPlannedSeat(
            id: "sub",
            memberID: "sub",
            teeOrder: 2,
            isSubstitute: true,
            substituteForSeriesMemberID: "regular",
            substituteForName: "Regular Player",
            representedTeamID: "team_series"
        )

        let out = SeriesRoundSyncPlanning.participantsWithOrganizationSync(
            participants: [substituteParticipant],
            participatingMembers: [originalMember, substituteMember],
            teamLinks: [
                "team_series": .init(seriesTeamID: "team_series", roundTeamID: "team_round"),
            ],
            memberAssignments: [
                "sub": .init(groupID: "g_new", teeOrder: 2),
            ],
            plannedSeatsByMemberID: ["sub": plannedSeat],
            usesSeriesTeams: true
        )

        let repaired = out.first
        XCTAssertNil(substituteMember.teamID)
        XCTAssertEqual(repaired?.groupID, "g_new")
        XCTAssertEqual(repaired?.teeOrder, 2)
        XCTAssertEqual(repaired?.teamID, "team_round")
        XCTAssertTrue(repaired?.isSubstitute == true)
        XCTAssertEqual(repaired?.substituteForSeriesMemberID, "regular")
        XCTAssertEqual(repaired?.substituteForName, "Regular Player")
    }

    func testParticipantsWithPlayerDataSync_updatesLinkedPlayerIdentityFromSeriesMember() {
        let existing = RoundParticipant(
            id: "part1",
            userID: "old_user",
            playerID: "old_player",
            name: Name("Old", "Name"),
            teeBoxID: "tee_old",
            originalHandicap: 12,
            adjustedHandicap: 12,
            seriesMemberID: "mem1",
            groupID: "g1",
            teeOrder: 1,
            createdAt: t0,
            parentID: "round1"
        )
        let member = SeriesMember(
            id: "mem1",
            userID: "new_user",
            playerID: "new_player",
            name: Name("New", "Name"),
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            parentID: "series1"
        )

        let out = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
            participants: [existing],
            roundID: "round1",
            participatingMembers: [member],
            teamLinks: [:],
            memberAssignments: ["mem1": .init(groupID: "g1", teeOrder: 1)],
            handicaps: [:],
            courseSegment: testCourseSegment(),
            hostPlayerID: nil,
            preserveManualHandicapEdits: false
        )

        XCTAssertEqual(out.first?.id, "part1")
        XCTAssertEqual(out.first?.userID, "new_user")
        XCTAssertEqual(out.first?.playerID, "new_player")
        XCTAssertEqual(out.first?.groupID, "g1")
    }

    func testLobbyAttendancePlan_removesDeclinedMemberAndBlocksScoredLobby() throws {
        var settings = SeriesSettings()
        settings.useTeams = false
        settings.substitutesScore = false
        let series = Series(id: "series1", settings: settings)
        let member1 = testMember(id: "m1", playerID: "p1")
        let member2 = testMember(id: "m2", playerID: "p2")
        let segment = testCourseSegment()
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                status: .lobby,
                configuration: RoundConfiguration(
                    courses: [segment],
                    substitutesScore: true
                )
            ),
            participants: [
                RoundParticipant(id: "part1", playerID: "p1", name: member1.name, seriesMemberID: "m1", groupID: "g1", teeOrder: 1, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part2", playerID: "p2", name: member2.name, seriesMemberID: "m2", groupID: "g1", teeOrder: 2, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [TeeTimeGroup(id: "g1", index: 0, startingHole: 7, createdAt: t0, parentID: "round1")],
            segments: [RoundSegment(id: "seg1", parentID: "round1")]
        )

        let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
            series: series,
            seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
            participatingMembers: [member1],
            teams: [],
            pods: [],
            handicaps: [:],
            seriesMappings: [],
            snapshot: snapshot,
            hostPlayerID: nil,
            presenceStatusByMemberID: ["m1": .active]
        )

        XCTAssertEqual(plan.participantsToDelete.map(\.id), ["part2"])
        XCTAssertEqual(plan.participantsToPut.map(\.seriesMemberID), ["m1"])
        XCTAssertEqual(plan.teeGroupsToPut.first?.startingHole, 7)
        XCTAssertEqual(plan.round.players, ["p1"])
        XCTAssertFalse(plan.round.configuration.substitutesScore)

        var scored = snapshot
        scored.scoring = [
            ScoreEntry(id: "score1", holeNumber: 1, scoringUnitID: "part1", strokes: 4, parentID: "round1")
        ]
        XCTAssertThrowsError(
            try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
                series: series,
                seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
                participatingMembers: [member1],
                teams: [],
                pods: [],
                handicaps: [:],
                seriesMappings: [],
                snapshot: scored,
                hostPlayerID: nil,
                presenceStatusByMemberID: ["m1": .active]
            )
        )
    }

    func testLobbyAttendancePlan_repairsSubstitutionOneForOneAndPreservesManualParticipant() throws {
        let series = Series(id: "series1")
        let original = testMember(id: "original", playerID: "player_original", teamID: "red")
        let other = testMember(id: "other", playerID: "player_other", teamID: "red")
        let substitute = testMember(id: "sub", playerID: "player_sub", role: .substitute)
        let unusedSubstitute = testMember(id: "unused_sub", playerID: "player_unused", role: .substitute)
        let plannedGroups = [
            SeriesRoundPlannedTeeGroup(
                id: "planned_1",
                index: 0,
                seats: [
                    SeriesRoundPlannedSeat(
                        memberID: "sub",
                        teeOrder: 1,
                        source: .manualOverride,
                        isSubstitute: true,
                        substituteForSeriesMemberID: "original",
                        substituteForName: "ORIGINAL Player",
                        representedTeamID: "red"
                    ),
                    SeriesRoundPlannedSeat(memberID: "other", teeOrder: 2),
                ],
                source: .manualOverride
            ),
        ]
        let seriesRound = SeriesRound(
            id: "sr1",
            roundID: "round1",
            plannedTeeGroups: plannedGroups,
            parentID: "series1"
        )
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                status: .lobby,
                players: ["player_original", "player_other", "player_unused", "walk_on"],
                configuration: RoundConfiguration(courses: [testCourseSegment()])
            ),
            participants: [
                RoundParticipant(id: "part_original", playerID: "player_original", seriesMemberID: "original", groupID: "g1", teeOrder: 1, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part_other", playerID: "player_other", seriesMemberID: "other", groupID: "g1", teeOrder: 2, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part_unused", playerID: "player_unused", seriesMemberID: "unused_sub", groupID: "g1", teeOrder: 3, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "walk_on", playerID: "walk_on", name: Name("Walk", "On"), groupID: "manual_group", teeOrder: 1, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, startingHole: 1, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "manual_group", index: 1, startingHole: 10, createdAt: t0, parentID: "round1"),
            ],
            segments: [RoundSegment(id: "seg1", parentID: "round1")]
        )

        let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
            series: series,
            seriesRound: seriesRound,
            participatingMembers: [original, other, substitute, unusedSubstitute],
            teams: [],
            pods: [],
            handicaps: [:],
            seriesMappings: [],
            snapshot: snapshot,
            hostPlayerID: nil,
            presenceStatusByMemberID: ["sub": .active, "other": .active],
            pruneNonSeriesParticipants: false
        )

        XCTAssertEqual(Set(plan.participantsToPut.compactMap(\.seriesMemberID)), ["sub", "other"])
        XCTAssertEqual(Set(plan.participantsToDelete.map(\.id)), ["part_original", "part_unused"])
        XCTAssertTrue(plan.participantsToPut.contains { $0.seriesMemberID == "sub" && $0.substituteForSeriesMemberID == "original" })
        XCTAssertFalse(plan.participantsToDelete.contains { $0.id == "walk_on" })
        XCTAssertFalse(plan.teeGroupsToDelete.contains { $0.id == "manual_group" })
        XCTAssertEqual(Set(plan.round.players), ["player_sub", "player_other", "walk_on"])
    }

    func testLobbyAttendancePlan_usesSavedPlannedStartingHoleWhenSeriesHasTeePlan() throws {
        var settings = SeriesSettings()
        settings.useTeams = false
        let series = Series(id: "series1", settings: settings)
        let member1 = testMember(id: "m1", playerID: "p1")
        let segment = testCourseSegment()
        let plannedGroup = SeriesRoundPlannedTeeGroup(
            id: "planned_1",
            index: 0,
            startingHole: 4,
            seats: [
                SeriesRoundPlannedSeat(id: "m1", memberID: "m1", teeOrder: 1)
            ],
            source: .manualOverride
        )
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                status: .lobby,
                configuration: RoundConfiguration(
                    courses: [segment]
                )
            ),
            participants: [
                RoundParticipant(id: "part1", playerID: "p1", name: member1.name, seriesMemberID: "m1", groupID: "g1", teeOrder: 1, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [TeeTimeGroup(id: "g1", index: 0, startingHole: 1, createdAt: t0, parentID: "round1")],
            segments: [RoundSegment(id: "seg1", parentID: "round1")]
        )

        let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
            series: series,
            seriesRound: SeriesRound(id: "sr1", plannedTeeGroups: [plannedGroup], parentID: "series1"),
            participatingMembers: [member1],
            teams: [],
            pods: [],
            handicaps: [:],
            seriesMappings: [],
            snapshot: snapshot,
            hostPlayerID: nil,
            presenceStatusByMemberID: ["m1": .active]
        )

        XCTAssertEqual(plan.teeGroupsToPut.first?.id, "g1")
        XCTAssertEqual(plan.teeGroupsToPut.first?.startingHole, 4)
    }

    func testLobbyAttendancePlan_fullSyncReconcilesStaleLobbyFromSeriesSource() throws {
        var settings = SeriesSettings()
        settings.useTeams = false
        let series = Series(id: "series1", settings: settings)
        let members = [
            testMember(id: "m1", playerID: "p1"),
            testMember(id: "m2", playerID: "p2"),
            testMember(id: "m3", playerID: "p3"),
            testMember(id: "m4", playerID: "p4"),
        ]
        let segment = testCourseSegment()
        var sourceConfig = SeriesRoundConfiguration(maxScoreOverPar: .twoTimesParPlusOne)
        sourceConfig.sequentialTeeStartsEnabled = true
        let plannedGroups = [
            SeriesRoundPlannedTeeGroup(
                id: "planned_1",
                index: 0,
                teeTime: "2026-05-01T16:30:00Z",
                startingHole: 4,
                seats: [
                    SeriesRoundPlannedSeat(id: "m1", memberID: "m1", teeOrder: 1),
                    SeriesRoundPlannedSeat(id: "m2", memberID: "m2", teeOrder: 2),
                ],
                source: .manualOverride
            ),
            SeriesRoundPlannedTeeGroup(
                id: "planned_2",
                index: 1,
                teeTime: "2026-05-01T16:30:00Z",
                startingHole: 3,
                seats: [
                    SeriesRoundPlannedSeat(id: "m3", memberID: "m3", teeOrder: 1),
                    SeriesRoundPlannedSeat(id: "m4", memberID: "m4", teeOrder: 2),
                ],
                source: .manualOverride
            ),
        ]
        let seriesRound = SeriesRound(
            id: "sr1",
            roundID: "round1",
            roundConfig: sourceConfig,
            plannedTeeGroups: plannedGroups,
            parentID: "series1"
        )
        var staleFormat = GameFormat.strokePlay
        staleFormat.configuration.maxScoreOverPar = .quad
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                status: .lobby,
                players: ["p1", "p2", "p3", "p4", "walk_on"],
                configuration: RoundConfiguration(
                    primaryFormat: staleFormat,
                    courses: [segment]
                )
            ),
            participants: [
                RoundParticipant(id: "part1", playerID: "p1", name: members[0].name, seriesMemberID: "m1", groupID: "g1", teeOrder: 1, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part2", playerID: "p2", name: members[1].name, seriesMemberID: "m2", groupID: "g1", teeOrder: 2, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part3", playerID: "p3", name: members[2].name, seriesMemberID: "m3", groupID: "g2", teeOrder: 1, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part4", playerID: "p4", name: members[3].name, seriesMemberID: "m4", groupID: "g2", teeOrder: 2, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "walk_on", playerID: "walk_on", name: Name("Walk", "On"), groupID: "g1", teeOrder: 3, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, teeTime: "2026-05-01T16:30:00Z", startingHole: 1, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, teeTime: "2026-05-01T16:30:00Z", startingHole: 2, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "stale_g3", index: 2, teeTime: "2026-05-01T16:30:00Z", startingHole: 9, createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(id: "seg1", roundID: "round1", gameFormat: staleFormat, parentID: "round1")
            ]
        )

        let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
            series: series,
            seriesRound: seriesRound,
            participatingMembers: members,
            teams: [],
            pods: [],
            handicaps: [:],
            seriesMappings: [],
            snapshot: snapshot,
            hostPlayerID: nil,
            presenceStatusByMemberID: Dictionary(uniqueKeysWithValues: members.map { ($0.id, .active) }),
            updateFormat: true,
            pruneNonSeriesParticipants: true
        )

        XCTAssertEqual(plan.round.configuration.primaryFormat.configuration.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertFalse(plan.round.configuration.usesSequentialTeeStarts)
        XCTAssertEqual(plan.segment.gameFormat.configuration.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertEqual(plan.teeGroupsToPut.map(\.id), ["g1", "g2"])
        XCTAssertEqual(plan.teeGroupsToPut.map(\.startingHole), [4, 3])
        XCTAssertEqual(Set(plan.participantsToDelete.map(\.id)), ["walk_on"])
        XCTAssertEqual(plan.teeGroupsToDelete.map(\.id), ["stale_g3"])
        XCTAssertEqual(plan.round.players, ["p1", "p2", "p3", "p4"])

        let participantsByMemberID = Dictionary(uniqueKeysWithValues: plan.participantsToPut.compactMap { participant -> (String, RoundParticipant)? in
            guard let memberID = participant.seriesMemberID else { return nil }
            return (memberID, participant)
        })
        XCTAssertEqual(participantsByMemberID["m1"]?.groupID, "g1")
        XCTAssertEqual(participantsByMemberID["m2"]?.groupID, "g1")
        XCTAssertEqual(participantsByMemberID["m3"]?.groupID, "g2")
        XCTAssertEqual(participantsByMemberID["m4"]?.groupID, "g2")
        XCTAssertEqual(participantsByMemberID["m1"]?.teeOrder, 1)
        XCTAssertEqual(participantsByMemberID["m4"]?.teeOrder, 2)
    }

    func testLobbyAttendancePlan_fullSyncRebuildsTeamsGroupsMatchupsAttendanceAndPrunesStaleArtifacts() throws {
        var settings = SeriesSettings()
        settings.useTeams = true
        settings.isAttendanceEnabled = true
        let series = Series(id: "series1", settings: settings)
        let members = [
            testMember(id: "m1", playerID: "p1", teamID: "series_red"),
            testMember(id: "m2", playerID: "p2", teamID: "series_red"),
            testMember(id: "m3", playerID: "p3", teamID: "series_green"),
            testMember(id: "m4", playerID: "p4", teamID: "series_green"),
        ]
        let teams = [
            SeriesTeam(id: "series_red", name: "Scarlet", color: "red", index: 0, createdAt: t0, parentID: "series1"),
            SeriesTeam(id: "series_green", name: "Green", color: "green", index: 1, createdAt: t0, parentID: "series1"),
        ]
        let segment = testCourseSegment()
        var sourceConfig = SeriesRoundConfiguration(maxScoreOverPar: .twoTimesParPlusOne)
        sourceConfig.competitionScope = .matchup
        sourceConfig.matchupMode = .teamVsTeam
        sourceConfig.teamAssignmentMode = .seriesTeams
        sourceConfig.selectionDomain = .team
        sourceConfig.sequentialTeeStartsEnabled = true
        let plannedGroups = [
            SeriesRoundPlannedTeeGroup(
                id: "planned_1",
                index: 0,
                teeTime: "2026-05-01T16:30:00Z",
                startingHole: 8,
                seats: [
                    SeriesRoundPlannedSeat(id: "m3", memberID: "m3", teeOrder: 1),
                    SeriesRoundPlannedSeat(id: "m1", memberID: "m1", teeOrder: 2),
                ],
                source: .manualOverride
            ),
            SeriesRoundPlannedTeeGroup(
                id: "planned_2",
                index: 1,
                teeTime: "2026-05-01T16:38:00Z",
                startingHole: 12,
                seats: [
                    SeriesRoundPlannedSeat(id: "m2", memberID: "m2", teeOrder: 1),
                    SeriesRoundPlannedSeat(id: "m4", memberID: "m4", teeOrder: 2),
                ],
                source: .manualOverride
            ),
        ]
        let seriesRound = SeriesRound(
            id: "sr1",
            roundID: "round1",
            roundConfig: sourceConfig,
            matchupPlans: [SeriesRoundMatchupPlan(id: "match_red_green", teamAID: "series_red", teamBID: "series_green")],
            plannedTeeGroups: plannedGroups,
            parentID: "series1"
        )
        var staleFormat = GameFormat.strokePlay
        staleFormat.configuration.maxScoreOverPar = .quad
        let mappings = [
            SeriesRoundCreationMapping.seriesRoundTeamMapping(
                seriesRoundID: "sr1",
                seriesID: "series1",
                link: .init(seriesTeamID: "series_red", roundTeamID: "round_red")
            ),
            SeriesRoundCreationMapping.seriesRoundTeamMapping(
                seriesRoundID: "sr1",
                seriesID: "series1",
                link: .init(seriesTeamID: "series_blue", roundTeamID: "round_blue")
            ),
        ]
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                status: .lobby,
                players: ["p1", "p2", "p3", "p4", "walk_on"],
                configuration: RoundConfiguration(primaryFormat: staleFormat, courses: [segment])
            ),
            participants: [
                RoundParticipant(id: "part1", playerID: "p1", name: members[0].name, seriesMemberID: "m1", teamID: "round_red", groupID: "g1", teeOrder: 1, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part2", playerID: "p2", name: members[1].name, seriesMemberID: "m2", teamID: "round_red", groupID: "g1", teeOrder: 2, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part3", playerID: "p3", name: members[2].name, seriesMemberID: "m3", teamID: "round_blue", groupID: "g2", teeOrder: 1, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part4", playerID: "p4", name: members[3].name, seriesMemberID: "m4", teamID: "round_blue", groupID: "g2", teeOrder: 2, createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "walk_on", playerID: "walk_on", name: Name("Walk", "On"), teamID: "round_blue", groupID: "stale_g3", teeOrder: 1, createdAt: t0, parentID: "round1"),
            ],
            teams: [
                RoundTeam(id: "round_red", name: "Old Red", color: "red", index: 0, createdAt: t0, parentID: "round1"),
                RoundTeam(id: "round_blue", name: "Blue", color: "blue", index: 1, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, teeTime: "2026-05-01T15:00:00Z", startingHole: 1, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, teeTime: "2026-05-01T15:08:00Z", startingHole: 2, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "stale_g3", index: 2, teeTime: "2026-05-01T15:16:00Z", startingHole: 9, createdAt: t0, parentID: "round1"),
            ],
            scoringGroups: [
                RoundScoringGroup(id: "stale_pair", teamID: "round_blue", teeGroupID: "stale_g3", kind: .partnership, memberIDs: ["walk_on"], createdAt: t0, parentID: "round1"),
            ],
            segments: [
                RoundSegment(
                    id: "seg1",
                    roundID: "round1",
                    gameFormat: staleFormat,
                    matchups: [TeamMatchup(id: "old_match", teamIDs: ["round_red", "round_blue"], mode: .team)],
                    parentID: "round1"
                ),
            ]
        )

        let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
            series: series,
            seriesRound: seriesRound,
            participatingMembers: members,
            teams: teams,
            pods: [],
            handicaps: [:],
            seriesMappings: mappings,
            snapshot: snapshot,
            hostPlayerID: nil,
            presenceStatusByMemberID: [
                "m1": .active,
                "m2": .unconfirmed,
                "m3": .active,
                "m4": .active,
            ],
            updateFormat: true,
            pruneNonSeriesParticipants: true
        )

        let greenTeam = try XCTUnwrap(plan.teamsToPut.first { $0.name == "Green" })
        XCTAssertEqual(plan.round.configuration.primaryFormat.configuration.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertEqual(plan.segment.gameFormat.configuration.maxScoreOverPar, .twoTimesParPlusOne)
        XCTAssertEqual(plan.teamsToPut.map(\.name), ["Scarlet", "Green"])
        XCTAssertEqual(plan.teamsToPut.first { $0.id == "round_red" }?.name, "Scarlet")
        XCTAssertEqual(plan.teamsToDelete.map(\.id), ["round_blue"])
        XCTAssertEqual(plan.teeGroupsToPut.map(\.id), ["g1", "g2"])
        XCTAssertEqual(plan.teeGroupsToPut.map(\.startingHole), [8, 12])
        XCTAssertEqual(plan.teeGroupsToDelete.map(\.id), ["stale_g3"])
        XCTAssertEqual(plan.participantsToDelete.map(\.id), ["walk_on"])
        XCTAssertEqual(plan.scoringGroupsToDelete.map(\.id), ["stale_pair"])
        XCTAssertTrue(plan.mappingsToDelete.contains { $0.competitorID == "series_blue" })
        XCTAssertEqual(plan.round.players, ["p1", "p2", "p3", "p4"])

        let participantsByMemberID = Dictionary(uniqueKeysWithValues: plan.participantsToPut.compactMap { participant -> (String, RoundParticipant)? in
            guard let memberID = participant.seriesMemberID else { return nil }
            return (memberID, participant)
        })
        XCTAssertEqual(participantsByMemberID["m1"]?.id, "part1")
        XCTAssertEqual(participantsByMemberID["m1"]?.groupID, "g1")
        XCTAssertEqual(participantsByMemberID["m1"]?.teeOrder, 2)
        XCTAssertEqual(participantsByMemberID["m2"]?.groupID, "g2")
        XCTAssertEqual(participantsByMemberID["m2"]?.teeOrder, 1)
        XCTAssertEqual(participantsByMemberID["m2"]?.presenceStatus, .unconfirmed)
        XCTAssertEqual(participantsByMemberID["m3"]?.teamID, greenTeam.id)
        XCTAssertEqual(participantsByMemberID["m4"]?.teamID, greenTeam.id)

        let matchup = try XCTUnwrap(plan.segment.matchups?.first)
        XCTAssertEqual(plan.segment.matchups?.count, 1)
        XCTAssertEqual(matchup.id, "match_red_green")
        XCTAssertEqual(matchup.teamIDs, ["round_red", greenTeam.id])
    }

    func testLobbyAttendancePlan_addsTeeGroupsWhenSeriesSourceGrows() throws {
        let series = Series(id: "series1")
        let members = [
            testMember(id: "m1", playerID: "p1"),
            testMember(id: "m2", playerID: "p2"),
            testMember(id: "m3", playerID: "p3"),
            testMember(id: "m4", playerID: "p4"),
            testMember(id: "m5", playerID: "p5"),
            testMember(id: "m6", playerID: "p6"),
        ]
        let plannedGroups = [
            SeriesRoundPlannedTeeGroup(id: "planned_1", index: 0, startingHole: 1, seats: [
                SeriesRoundPlannedSeat(id: "m1", memberID: "m1", teeOrder: 1),
                SeriesRoundPlannedSeat(id: "m2", memberID: "m2", teeOrder: 2),
            ]),
            SeriesRoundPlannedTeeGroup(id: "planned_2", index: 1, startingHole: 4, seats: [
                SeriesRoundPlannedSeat(id: "m3", memberID: "m3", teeOrder: 1),
                SeriesRoundPlannedSeat(id: "m4", memberID: "m4", teeOrder: 2),
            ]),
            SeriesRoundPlannedTeeGroup(id: "planned_3", index: 2, startingHole: 7, seats: [
                SeriesRoundPlannedSeat(id: "m5", memberID: "m5", teeOrder: 1),
                SeriesRoundPlannedSeat(id: "m6", memberID: "m6", teeOrder: 2),
            ]),
        ]
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", status: .lobby, configuration: RoundConfiguration(courses: [testCourseSegment()])),
            participants: [
                RoundParticipant(id: "part1", playerID: "p1", seriesMemberID: "m1", groupID: "g1", createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part2", playerID: "p2", seriesMemberID: "m2", groupID: "g1", createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part3", playerID: "p3", seriesMemberID: "m3", groupID: "g2", createdAt: t0, parentID: "round1"),
                RoundParticipant(id: "part4", playerID: "p4", seriesMemberID: "m4", groupID: "g2", createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, startingHole: 1, createdAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, startingHole: 2, createdAt: t0, parentID: "round1"),
            ],
            segments: [RoundSegment(id: "seg1", parentID: "round1")]
        )

        let plan = try SeriesRoundSyncPlanning.buildLobbyAttendancePlan(
            series: series,
            seriesRound: SeriesRound(id: "sr1", plannedTeeGroups: plannedGroups, parentID: "series1"),
            participatingMembers: members,
            teams: [],
            pods: [],
            handicaps: [:],
            seriesMappings: [],
            snapshot: snapshot,
            hostPlayerID: nil,
            presenceStatusByMemberID: [:]
        )

        XCTAssertEqual(plan.teeGroupsToPut.count, 3)
        XCTAssertEqual(plan.teeGroupsToPut.prefix(2).map(\.id), ["g1", "g2"])
        XCTAssertEqual(plan.teeGroupsToPut.map(\.startingHole), [1, 4, 7])
        XCTAssertTrue(plan.teeGroupsToDelete.isEmpty)
        XCTAssertEqual(plan.participantsToPut.count, 6)
        XCTAssertEqual(plan.participantsToPut.first { $0.seriesMemberID == "m5" }?.groupID, plan.teeGroupsToPut[2].id)
    }

    func testBuildUpdatedSegment_clearsExistingMatchupsWhenSourceChangesToField() {
        let context = teamVsTeamMatchupContext()
        var fieldConfig = SeriesRoundConfiguration()
        fieldConfig.competitionScope = .field
        fieldConfig.matchupMode = .field
        fieldConfig.teamAssignmentMode = .seriesTeams
        let fieldSeriesRound = SeriesRound(id: "sr_field", roundConfig: fieldConfig, parentID: "series1")
        let existingSegment = RoundSegment(
            id: "seg1",
            matchups: [TeamMatchup(id: "stale_match", teamIDs: ["round_red", "round_blue"], mode: .team)]
        )

        let updated = SeriesRoundSyncPlanning.buildUpdatedSegment(
            series: context.series,
            seriesRound: fieldSeriesRound,
            courseSegment: testCourseSegment(),
            participants: context.participants,
            scoringGroups: [],
            existingSegment: existingSegment,
            teams: context.teams,
            pods: [],
            participatingMembers: context.members,
            teamLinks: context.teamLinks,
            updateFormat: true,
            updateScoringUnits: true,
            updateMatchups: true
        )

        XCTAssertNil(updated.matchups)
        XCTAssertEqual(updated.competitionScope, .field)
    }

    func testCSVExporter_addsSelectableSectionsAndFixedColumnsInSortedOrder() {
        let segment = testCourseSegment(holeRange: HoleRange(startHole: 10, endHole: 11))
        let teamA = RoundTeam(id: "teamA", name: "Team A", color: "red", index: 0, createdAt: t0, parentID: "round1")
        let teamB = RoundTeam(id: "teamB", name: "Team B", color: "blue", index: 1, createdAt: t0, parentID: "round1")
        let seriesTeamA = SeriesTeam(id: "seriesTeamA", name: "Team A", color: "red", index: 0, createdAt: t0, parentID: "series1")
        let seriesTeamB = SeriesTeam(id: "seriesTeamB", name: "Team B", color: "blue", index: 1, createdAt: t0, parentID: "series1")
        let memberA = testMember(id: "ma", playerID: "player_a", teamID: "seriesTeamA")
        let memberB = testMember(id: "mb", playerID: "player_b", teamID: "seriesTeamB")
        let group1 = TeeTimeGroup(id: "group1", index: 0, teeTime: "2026-05-01T14:00:00Z", startingHole: 10, createdAt: t0, parentID: "round1")
        let group2 = TeeTimeGroup(id: "group2", index: 1, teeTime: "2026-05-01T14:08:00Z", startingHole: 11, createdAt: t0, parentID: "round1")
        let alice = RoundParticipant(id: "pa", playerID: "player_a", name: Name("Alice", "A"), teeBoxID: "tee_white", adjustedHandicap: 5, seriesMemberID: "ma", teamID: "teamA", groupID: "group2", teeOrder: 2, createdAt: t0, parentID: "round1")
        let bob = RoundParticipant(id: "pb", playerID: "player_b", name: Name("Bob", "B"), teeBoxID: "tee_white", adjustedHandicap: 7, seriesMemberID: "mb", teamID: "teamB", groupID: "group1", teeOrder: 1, createdAt: t0, parentID: "round1")
        var netFormat = GameFormat.strokePlay
        netFormat.configuration.basis = .net
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                configuration: RoundConfiguration(
                    primaryFormat: netFormat,
                    courses: [segment]
                )
            ),
            participants: [alice, bob],
            teams: [teamA, teamB],
            teeGroups: [group2, group1],
            segments: [
                RoundSegment(
                    id: "seg1",
                    matchups: [TeamMatchup(id: "match1", teamIDs: ["teamB", "teamA"], mode: .team)],
                    parentID: "round1"
                )
            ],
            scoring: [
                ScoreEntry(id: ScoreEntry.makeID(hole: 10, segment: "seg1", scoringUnit: "pa"), holeNumber: 10, segmentID: "seg1", scoringUnitID: "pa", strokes: 5, parentID: "round1"),
                ScoreEntry(id: ScoreEntry.makeID(hole: 10, segment: "seg1", scoringUnit: "pb"), holeNumber: 10, segmentID: "seg1", scoringUnitID: "pb", strokes: 4, parentID: "round1"),
            ]
        )

        let doc = SeriesCSVExporter.document(
            series: Series(id: "series1"),
            seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
            snapshot: snapshot,
            members: [memberA, memberB],
            teams: [seriesTeamA, seriesTeamB]
        )
        let content = doc.content

        XCTAssertEqual(doc.header, SeriesCSVExporter.headerColumns.joined(separator: ","))
        XCTAssertTrue(doc.header.contains("actual_strokes_used"))
        XCTAssertTrue(doc.header.contains("handicap_strokes_used"))
        XCTAssertTrue(content.contains("\"leaderboard\""))
        XCTAssertTrue(content.contains("\"hole_score\""))
        XCTAssertTrue(content.contains("\"tee_group\""))
        XCTAssertTrue(content.contains("\"tee_group_player\""))
        XCTAssertTrue(content.contains("\"Bob B\""))
        XCTAssertTrue(content.contains("\"Team B\""))
        XCTAssertTrue(content.contains("\"match1\""))
        let bobOffset = content.distance(from: content.startIndex, to: content.range(of: "\"Bob B\"")!.lowerBound)
        let aliceOffset = content.distance(from: content.startIndex, to: content.range(of: "\"Alice A\"")!.lowerBound)
        XCTAssertLessThan(bobOffset, aliceOffset)
    }

    func testCSVExporter_filtersBySeriesTeamAndPlayer() {
        let segment = testCourseSegment(holeRange: HoleRange(startHole: 10, endHole: 11))
        let teamA = RoundTeam(id: "teamA", name: "Team A", color: "red", index: 0, createdAt: t0, parentID: "round1")
        let teamB = RoundTeam(id: "teamB", name: "Team B", color: "blue", index: 1, createdAt: t0, parentID: "round1")
        let memberA = testMember(id: "ma", playerID: "player_a", teamID: "seriesTeamA")
        let memberB = testMember(id: "mb", playerID: "player_b", teamID: "seriesTeamB")
        let alice = RoundParticipant(id: "pa", playerID: "player_a", name: Name("Alice", "A"), teeBoxID: "tee_white", adjustedHandicap: 5, seriesMemberID: "ma", teamID: "teamA", groupID: "group1", teeOrder: 1, createdAt: t0, parentID: "round1")
        let bob = RoundParticipant(id: "pb", playerID: "player_b", name: Name("Bob", "B"), teeBoxID: "tee_white", adjustedHandicap: 7, seriesMemberID: "mb", teamID: "teamB", groupID: "group1", teeOrder: 2, createdAt: t0, parentID: "round1")
        let snapshot = RoundSnapshot(
            round: Round(
                id: "round1",
                configuration: RoundConfiguration(
                    primaryFormat: GameFormat.strokePlay,
                    courses: [segment]
                )
            ),
            participants: [alice, bob],
            teams: [teamA, teamB],
            teeGroups: [TeeTimeGroup(id: "group1", index: 0, startingHole: 10, createdAt: t0, parentID: "round1")],
            segments: [RoundSegment(id: "seg1", parentID: "round1")],
            scoring: [
                ScoreEntry(id: ScoreEntry.makeID(hole: 10, segment: "seg1", scoringUnit: "pa"), holeNumber: 10, segmentID: "seg1", scoringUnitID: "pa", strokes: 5, parentID: "round1"),
                ScoreEntry(id: ScoreEntry.makeID(hole: 10, segment: "seg1", scoringUnit: "pb"), holeNumber: 10, segmentID: "seg1", scoringUnitID: "pb", strokes: 4, parentID: "round1"),
            ]
        )

        let teamDoc = SeriesCSVExporter.document(
            seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
            snapshot: snapshot,
            members: [memberA, memberB],
            options: SeriesCSVExportOptions(
                selectedRoundIDs: ["sr1"],
                selectedTeamIDs: ["seriesTeamB"],
                selectedMemberIDs: [],
                selectedSections: [.holeScores]
            )
        )

        XCTAssertTrue(teamDoc.content.contains("\"Bob B\""))
        XCTAssertFalse(teamDoc.content.contains("\"Alice A\""))

        let playerDoc = SeriesCSVExporter.document(
            seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
            snapshot: snapshot,
            members: [memberA, memberB],
            options: SeriesCSVExportOptions(
                selectedRoundIDs: ["sr1"],
                selectedTeamIDs: [],
                selectedMemberIDs: ["ma"],
                selectedSections: [.holeScores]
            )
        )

        XCTAssertTrue(playerDoc.content.contains("\"Alice A\""))
        XCTAssertFalse(playerDoc.content.contains("\"Bob B\""))
    }

    func testCSVExporter_defaultsAndEscaping() {
        let linked = SeriesRound(id: "linked", roundID: "round1", parentID: "series1")
        let planned = SeriesRound(id: "planned", roundID: nil, parentID: "series1")
        let options = SeriesCSVExportOptions.defaults(for: [linked, planned])

        XCTAssertEqual(options.selectedRoundIDs, ["linked"])
        XCTAssertEqual(options.selectedSections, Set(SeriesCSVExportSection.allCases))
        XCTAssertEqual(SeriesCSVExporter.escapedCSV("A \"B\", C"), "\"A \"\"B\"\", C\"")
    }

    private func pairMatchupContext() -> (
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink]
    ) {
        var settings = SeriesSettings()
        settings.useTeams = true
        let series = Series(id: "series1", settings: settings)
        let members = [
            testMember(id: "m1", playerID: "player1", teamID: "series_red"),
            testMember(id: "m2", playerID: "player2", teamID: "series_red"),
            testMember(id: "m3", playerID: "player3", teamID: "series_blue"),
            testMember(id: "m4", playerID: "player4", teamID: "series_blue"),
        ]
        let teams = [
            SeriesTeam(id: "series_red", name: "Red", color: "red", index: 0, createdAt: t0, parentID: "series1"),
            SeriesTeam(id: "series_blue", name: "Blue", color: "blue", index: 1, createdAt: t0, parentID: "series1"),
        ]
        let participants = [
            RoundParticipant(id: "p1", playerID: "player1", seriesMemberID: "m1", teamID: "round_red", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p2", playerID: "player2", seriesMemberID: "m2", teamID: "round_red", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p3", playerID: "player3", seriesMemberID: "m3", teamID: "round_blue", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p4", playerID: "player4", seriesMemberID: "m4", teamID: "round_blue", groupID: "g1", createdAt: t0, parentID: "round1"),
        ]
        let scoringGroups = [
            RoundScoringGroup(
                id: "pair_red",
                teamID: "round_red",
                teeGroupID: "g1",
                kind: .partnership,
                memberIDs: ["p1", "p2"],
                label: "Red Pair",
                createdAt: t0,
                parentID: "round1"
            ),
            RoundScoringGroup(
                id: "pair_blue",
                teamID: "round_blue",
                teeGroupID: "g1",
                kind: .partnership,
                memberIDs: ["p3", "p4"],
                label: "Blue Pair",
                createdAt: t0,
                parentID: "round1"
            ),
        ]
        var cfg = SeriesRoundConfiguration()
        cfg.competitionScope = .matchup
        cfg.scoreOwnerScope = .partnership
        cfg.matchupMode = .teeGroupPartnerships
        cfg.teamAssignmentMode = .seriesTeams
        let seriesRound = SeriesRound(
            id: "sr_pair_match",
            roundConfig: cfg,
            matchupPlans: [
                SeriesRoundMatchupPlan(
                    id: "pair_match",
                    teamAID: "series_red",
                    teamBID: "series_blue",
                    pairAID: "pair_red",
                    pairBID: "pair_blue"
                ),
            ],
            partnershipPlans: [
                SeriesRoundPartnershipPlan(id: "pair_red", teamID: "series_red", memberIDs: ["m1", "m2"]),
                SeriesRoundPartnershipPlan(id: "pair_blue", teamID: "series_blue", memberIDs: ["m3", "m4"]),
            ],
            parentID: "series1"
        )
        let teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [
            "series_red": .init(seriesTeamID: "series_red", roundTeamID: "round_red"),
            "series_blue": .init(seriesTeamID: "series_blue", roundTeamID: "round_blue"),
        ]

        return (series, seriesRound, members, teams, participants, scoringGroups, teamLinks)
    }

    private func teamVsTeamMatchupContext() -> (
        series: Series,
        seriesRound: SeriesRound,
        members: [SeriesMember],
        teams: [SeriesTeam],
        participants: [RoundParticipant],
        teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink]
    ) {
        var settings = SeriesSettings()
        settings.useTeams = true
        let series = Series(id: "series1", settings: settings)
        let members = [
            testMember(id: "m1", playerID: "player1", teamID: "series_red"),
            testMember(id: "m2", playerID: "player2", teamID: "series_red"),
            testMember(id: "m3", playerID: "player3", teamID: "series_blue"),
            testMember(id: "m4", playerID: "player4", teamID: "series_blue"),
        ]
        let teams = [
            SeriesTeam(id: "series_red", name: "Red", color: "red", index: 0, createdAt: t0, parentID: "series1"),
            SeriesTeam(id: "series_blue", name: "Blue", color: "blue", index: 1, createdAt: t0, parentID: "series1"),
        ]
        let participants = [
            RoundParticipant(id: "p1", playerID: "player1", seriesMemberID: "m1", teamID: "round_red", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p2", playerID: "player2", seriesMemberID: "m2", teamID: "round_red", groupID: "g1", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p3", playerID: "player3", seriesMemberID: "m3", teamID: "round_blue", groupID: "g2", createdAt: t0, parentID: "round1"),
            RoundParticipant(id: "p4", playerID: "player4", seriesMemberID: "m4", teamID: "round_blue", groupID: "g2", createdAt: t0, parentID: "round1"),
        ]
        var cfg = SeriesRoundConfiguration()
        cfg.formatTemplateID = FormatTemplateRegistry.bestBall.id
        cfg.competitionScope = .matchup
        cfg.matchupMode = .teamVsTeam
        cfg.teamAssignmentMode = .seriesTeams
        cfg.selectionDomain = .team
        cfg.teamScoring = .init(mode: .bestN, count: 2, scope: .perRound)
        let seriesRound = SeriesRound(
            id: "sr_team_match",
            roundConfig: cfg,
            matchupPlans: [
                SeriesRoundMatchupPlan(id: "team_match", teamAID: "series_red", teamBID: "series_blue")
            ],
            parentID: "series1"
        )
        let teamLinks: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [
            "series_red": .init(seriesTeamID: "series_red", roundTeamID: "round_red"),
            "series_blue": .init(seriesTeamID: "series_blue", roundTeamID: "round_blue"),
        ]

        return (series, seriesRound, members, teams, participants, teamLinks)
    }

    private func testMember(
        id: String,
        playerID: String,
        teamID: String? = nil,
        role: SeriesMemberRole = .member
    ) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: playerID,
            name: Name(id.uppercased(), "Player"),
            role: role,
            teamID: teamID,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
    }

    private func testCourseSegment(holeRange: HoleRange = HoleRange(startHole: 1, endHole: 18)) -> CourseSegment {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) }
        let tee = Tee(
            id: "tee_white",
            name: "White",
            gender: "male",
            totalHoles: 18,
            holes: holes,
            ratingFull: 72,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        return CourseSegment(
            courseInfo: CourseInfo(id: "course1", golfCourseApiID: nil, name: "Test Course", totalHoles: 18, location: nil, tees: [tee]),
            holeRange: holeRange,
            defaultTee: "tee_white"
        )
    }
}
