//
//  SeriesRoundSyncServiceTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundSyncServiceTests: XCTestCase {

    private let t0 = Time(iso: "2023-11-15T12:00:00Z", unix: 1_700_000_000)

    func testValidateOptions_blocksFormatAndOrgWhenLive() {
        var options = SeriesRoundSyncOptions(
            syncPlayerData: false,
            syncFormat: true,
            syncOrganization: false,
            syncPairs: false,
            syncMatchups: false,
            preserveManualHandicapEdits: false
        )
        XCTAssertNotNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

        options.syncFormat = false
        options.syncOrganization = true
        XCTAssertNotNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

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
    func testRoundTileLinkedActionCopyAndRSVPEligibility() {
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
        XCTAssertTrue(viewModel.isRSVPEligible(for: lobby))
        XCTAssertFalse(viewModel.isRSVPEligible(for: live))
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

    @MainActor
    func testEffectiveRoundConfig_respectsBackPropagationFlag() {
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
            allowLobbyBackPropagation: false
        )
        var seriesRound = SeriesRound(
            id: "series_round1",
            roundID: "round1",
            roundConfig: seriesConfig,
            parentID: "series1"
        )

        XCTAssertEqual(viewModel.effectiveRoundConfig(for: seriesRound).formatTemplateID, "series_template")

        seriesConfig.allowLobbyBackPropagation = true
        seriesRound.roundConfig = seriesConfig

        XCTAssertEqual(viewModel.effectiveRoundConfig(for: seriesRound).formatTemplateID, "linked_template")
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
        settings.handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025, strokeBasis: .nineHole)
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

    func testLobbyAttendancePlan_removesDeclinedMemberAndBlocksScoredLobby() throws {
        var settings = SeriesSettings()
        settings.useTeams = false
        let series = Series(id: "series1", settings: settings)
        let member1 = testMember(id: "m1", playerID: "p1")
        let member2 = testMember(id: "m2", playerID: "p2")
        let segment = testCourseSegment()
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
                RoundParticipant(id: "part2", playerID: "p2", name: member2.name, seriesMemberID: "m2", groupID: "g1", teeOrder: 2, createdAt: t0, parentID: "round1"),
            ],
            teeGroups: [TeeTimeGroup(id: "g1", index: 0, createdAt: t0, parentID: "round1")],
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
        XCTAssertEqual(plan.round.players, ["p1"])

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

    func testCSVExporter_addsGroupingAndHandicapColumnsInSortedOrder() {
        let segment = testCourseSegment(holeRange: HoleRange(startHole: 10, endHole: 11))
        let teamA = RoundTeam(id: "teamA", name: "Team A", color: "red", index: 0, createdAt: t0, parentID: "round1")
        let teamB = RoundTeam(id: "teamB", name: "Team B", color: "blue", index: 1, createdAt: t0, parentID: "round1")
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

        let doc = SeriesRoundCSVExporter.document(
            seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
            snapshot: snapshot,
            members: []
        )

        XCTAssertTrue(doc.header.contains("handicap_strokes"))
        XCTAssertTrue(doc.header.contains("hole_10_to_par"))
        XCTAssertFalse(doc.header.contains("hole_1_to_par"))
        XCTAssertTrue(doc.rows[0].contains("\"Bob B\""))
        XCTAssertTrue(doc.rows[0].contains("\"Team B\""))
        XCTAssertTrue(doc.rows[0].contains("\"match1\""))
        XCTAssertTrue(doc.rows[1].contains("\"Alice A\""))
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

    private func testMember(id: String, playerID: String, teamID: String? = nil) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: playerID,
            name: Name(id.uppercased(), "Player"),
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
