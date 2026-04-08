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
