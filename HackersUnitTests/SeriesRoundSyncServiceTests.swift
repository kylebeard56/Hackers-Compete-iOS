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
            preserveManualHandicapEdits: false
        )
        XCTAssertNotNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

        options.syncFormat = false
        options.syncOrganization = true
        XCTAssertNotNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))

        options.syncOrganization = false
        options.syncPlayerData = true
        XCTAssertNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .live))
    }

    func testValidateOptions_blocksAllWhenComplete() {
        let options = SeriesRoundSyncOptions(
            syncPlayerData: true,
            syncFormat: true,
            syncOrganization: true,
            preserveManualHandicapEdits: false
        )
        XCTAssertNotNil(SeriesRoundSyncPlanning.validateOptions(options, roundStatus: .complete))
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
        XCTAssertEqual(out.first?.teeBoxID, "tee_white")
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

        let plan = SeriesRoundResolvedPlan(
            series: series,
            seriesRound: SeriesRound(id: "sr1", parentID: "series1"),
            members: [member],
            teams: [],
            pods: [],
            courseSegment: courseSegment
        )

        XCTAssertEqual(plan.roundConfiguration.handicapStrokeBasis, .nineHole)
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
}
