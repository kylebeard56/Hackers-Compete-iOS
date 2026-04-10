//
//  SeriesRoundCreationMappingTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundCreationMappingTests: XCTestCase {

    // MARK: - Fixtures

    private let t0 = Time(iso: "2023-11-15T12:00:00Z", unix: 1_700_000_000)

    private func makeHole(_ n: Int) -> Hole {
        Hole(number: n, par: 4, yardage: 400, handicap: n)
    }

    private func makeTee(id: String) -> Tee {
        let holes = (1...18).map { makeHole($0) }
        return Tee(
            id: id,
            name: "White",
            gender: "male",
            totalHoles: 18,
            holes: holes,
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
    }

    private func makeCourseSegment(defaultTee: String? = "tee_white") -> CourseSegment {
        let tee = makeTee(id: "tee_white")
        let info = CourseInfo(
            id: "course1",
            golfCourseApiID: nil,
            name: "Test Course",
            totalHoles: 18,
            location: nil,
            tees: [tee, makeTee(id: "tee_blue")]
        )
        return CourseSegment(
            courseInfo: info,
            holeRange: HoleRange(startHole: 1, endHole: 18),
            defaultTee: defaultTee
        )
    }

    private func makeMember(
        id: String,
        name: String,
        playerID: String? = nil,
        teamID: String? = nil,
        defaultTeeBoxID: String? = nil
    ) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: playerID,
            name: Name(name, "Player"),
            teamID: teamID,
            defaultTeeBoxID: defaultTeeBoxID,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
    }

    private func makeTeam(id: String, name: String, index: Int, color: String = "red") -> SeriesTeam {
        SeriesTeam(
            id: id,
            name: name,
            color: color,
            index: index,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
    }

    private func makePod(teamID: String, index: Int, memberIDs: [String], label: String = "") -> SeriesTeamPod {
        SeriesTeamPod(
            id: "pod_\(teamID)_\(index)",
            teamID: teamID,
            label: label,
            index: index,
            memberIDs: memberIDs,
            isActive: true,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
    }

    private func fieldSeriesRound() -> SeriesRound {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .field
        cfg.teamAssignmentMode = .manual
        return SeriesRound(id: "sr_field", roundConfig: cfg, parentID: "series1")
    }

    private func makeSeries(handicapsEnabled: Bool = false) -> Series {
        var settings = SeriesSettings()
        settings.handicapConfig = SeriesHandicapConfig(isEnabled: handicapsEnabled, config: .league2025)
        return Series(id: "series1", settings: settings)
    }

    // MARK: - Competition scope + round draft

    func testResolvedCompetitionScope_fieldUsesTemplateScope() {
        let sr = fieldSeriesRound()
        let scope = SeriesRoundCreationMapping.resolvedCompetitionScope(for: sr)
        XCTAssertEqual(scope, sr.roundConfig.resolvedCompetitionScope)
    }

    func testResolvedCompetitionScope_teamVsTeamForcesMatchup() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.teamAssignmentMode = .seriesTeams
        let sr = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        XCTAssertEqual(SeriesRoundCreationMapping.resolvedCompetitionScope(for: sr), .matchup)
    }

    func testRoundDraft_carriesPlayerIDsAndConfiguration() {
        let sr = fieldSeriesRound()
        let segment = makeCourseSegment()
        let members = [
            makeMember(id: "m1", name: "Alice", playerID: "p1"),
            makeMember(id: "m2", name: "Bob", playerID: "p2"),
        ]
        let draft = SeriesRoundCreationMapping.roundDraft(
            id: "round1",
            shareCode: "ABC12",
            createdBy: "user1",
            series: makeSeries(),
            members: members,
            seriesRound: sr,
            courseSegment: segment
        )
        XCTAssertEqual(draft.id, "round1")
        XCTAssertEqual(draft.shareCode, "ABC12")
        XCTAssertEqual(draft.createdBy, "user1")
        XCTAssertEqual(draft.status, .lobby)
        XCTAssertEqual(Set(draft.players), Set(["p1", "p2"]))
        XCTAssertEqual(draft.configuration.courses.count, 1)
        XCTAssertEqual(draft.configuration.courses.first?.holeRange, segment.holeRange)
    }

    func testRoundDraft_leagueHandicapsOn_defaultsPrimaryFormatToNet() {
        let sr = fieldSeriesRound()
        let segment = makeCourseSegment()
        let draft = SeriesRoundCreationMapping.roundDraft(
            id: "r",
            shareCode: "X",
            createdBy: "u",
            series: makeSeries(handicapsEnabled: true),
            members: [],
            seriesRound: sr,
            courseSegment: segment
        )
        XCTAssertTrue(draft.configuration.useHandicaps)
        XCTAssertEqual(draft.configuration.primaryFormat.configuration.basis, .net)
    }

    func testRoundDraft_explicitGrossOverride_keepsGrossWhenLeagueHandicapsOn() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .field
        cfg.teamAssignmentMode = .manual
        cfg.scoreBasisOverride = .gross
        let sr = SeriesRound(id: "sr", roundConfig: cfg, parentID: "series1")
        let draft = SeriesRoundCreationMapping.roundDraft(
            id: "r",
            shareCode: "X",
            createdBy: "u",
            series: makeSeries(handicapsEnabled: true),
            members: [],
            seriesRound: sr,
            courseSegment: makeCourseSegment()
        )
        XCTAssertFalse(draft.configuration.useHandicaps)
        XCTAssertEqual(draft.configuration.primaryFormat.configuration.basis, .gross)
    }

    // MARK: - Matchup plans

    func testResolvedMatchupPlans_teamVsTeam_pairsByIndex() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.teamAssignmentMode = .seriesTeams
        let sr = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        let teams = [
            makeTeam(id: "tA", name: "A", index: 2),
            makeTeam(id: "tB", name: "B", index: 0),
            makeTeam(id: "tC", name: "C", index: 1),
            makeTeam(id: "tD", name: "D", index: 3),
        ]
        let plans = SeriesRoundCreationMapping.resolvedMatchupPlans(
            seriesRound: sr,
            teams: teams,
            members: []
        )
        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].teamAID, "tB")
        XCTAssertEqual(plans[0].teamBID, "tC")
        XCTAssertEqual(plans[1].teamAID, "tA")
        XCTAssertEqual(plans[1].teamBID, "tD")
    }

    func testResolvedMatchupPlans_individual_sortsNamesCaseInsensitive() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .individualVsIndividual
        let sr = SeriesRound(id: "sr1", roundConfig: cfg, parentID: "series1")
        let members = [
            makeMember(id: "m2", name: "charlie"),
            makeMember(id: "m1", name: "Alice"),
            makeMember(id: "m3", name: "bob"),
            makeMember(id: "m4", name: "dave"),
        ]
        let plans = SeriesRoundCreationMapping.resolvedMatchupPlans(
            seriesRound: sr,
            teams: [],
            members: members
        )
        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].memberAID, "m1")
        XCTAssertEqual(plans[0].memberBID, "m3")
        XCTAssertEqual(plans[1].memberAID, "m2")
        XCTAssertEqual(plans[1].memberBID, "m4")
    }

    func testResolvedMatchupPlans_usesPresetPlansWhenPresent() {
        let plan = SeriesRoundMatchupPlan(
            id: "preset1",
            teamAID: "t1",
            teamBID: "t2",
            index: 1
        )
        var sr = fieldSeriesRound()
        sr.matchupPlans = [plan]
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        sr.roundConfig = cfg
        let plans = SeriesRoundCreationMapping.resolvedMatchupPlans(
            seriesRound: sr,
            teams: [],
            members: []
        )
        XCTAssertEqual(plans.map(\.id), ["preset1"])
    }

    // MARK: - Tee groups + assignments

    func testSequentialGroupPlans_chunksByFourAndSortsByTeamIndex() {
        let teams = [
            makeTeam(id: "tLate", name: "Late", index: 5),
            makeTeam(id: "tEarly", name: "Early", index: 1),
        ]
        let members = [
            makeMember(id: "m1", name: "Zed", teamID: "tLate"),
            makeMember(id: "m2", name: "Amy", teamID: "tEarly"),
            makeMember(id: "m3", name: "Ben", teamID: "tEarly"),
        ]
        let sr = fieldSeriesRound()
        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: [],
            matchupPlans: [],
            seriesRound: sr
        )
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].id, "group_0")
        // Early team (index 1) before late team (index 5); then name order within team
        XCTAssertEqual(plans[0].memberIDs, ["m2", "m3", "m1"])
    }

    func testBuildTeeGroupPlans_alignPairsKeepsSameIndexPodsTogether() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.podGroupingStrategy = .alignByIndex
        cfg.teeGroupMode = .podAligned
        let seriesRound = SeriesRound(id: "sr_pods", roundConfig: cfg, parentID: "series1")

        let teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        let members = [
            makeMember(id: "a1", name: "A1", teamID: "t1"),
            makeMember(id: "a2", name: "A2", teamID: "t1"),
            makeMember(id: "a3", name: "A3", teamID: "t1"),
            makeMember(id: "a4", name: "A4", teamID: "t1"),
            makeMember(id: "b1", name: "B1", teamID: "t2"),
            makeMember(id: "b2", name: "B2", teamID: "t2"),
            makeMember(id: "b3", name: "B3", teamID: "t2"),
            makeMember(id: "b4", name: "B4", teamID: "t2"),
        ]
        let pods = [
            makePod(teamID: "t1", index: 0, memberIDs: ["a1", "a2"], label: "A"),
            makePod(teamID: "t1", index: 1, memberIDs: ["a3", "a4"], label: "B"),
            makePod(teamID: "t2", index: 0, memberIDs: ["b1", "b2"], label: "A"),
            makePod(teamID: "t2", index: 1, memberIDs: ["b3", "b4"], label: "B"),
        ]
        let matchupPlans = [
            SeriesRoundMatchupPlan(
                id: "matchup_1",
                teamAID: "t1",
                teamBID: "t2",
                index: 0,
                podGroupingStrategy: .alignByIndex
            ),
        ]

        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: pods,
            matchupPlans: matchupPlans,
            seriesRound: seriesRound
        )

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].memberIDs, ["a1", "a2", "b1", "b2"])
        XCTAssertEqual(plans[1].memberIDs, ["a3", "a4", "b3", "b4"])
        XCTAssertEqual(plans[0].seats.map(\.teeOrder), [1, 2, 3, 4])
    }

    func testBuildTeeGroupPlans_swapPairsSwapsOpponentPodsWhenThereAreTwoPairs() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.podGroupingStrategy = .swapPairs
        cfg.teeGroupMode = .podAligned
        let seriesRound = SeriesRound(id: "sr_swap", roundConfig: cfg, parentID: "series1")

        let teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        let members = [
            makeMember(id: "a1", name: "A1", teamID: "t1"),
            makeMember(id: "a2", name: "A2", teamID: "t1"),
            makeMember(id: "a3", name: "A3", teamID: "t1"),
            makeMember(id: "a4", name: "A4", teamID: "t1"),
            makeMember(id: "b1", name: "B1", teamID: "t2"),
            makeMember(id: "b2", name: "B2", teamID: "t2"),
            makeMember(id: "b3", name: "B3", teamID: "t2"),
            makeMember(id: "b4", name: "B4", teamID: "t2"),
        ]
        let pods = [
            makePod(teamID: "t1", index: 0, memberIDs: ["a1", "a2"], label: "A"),
            makePod(teamID: "t1", index: 1, memberIDs: ["a3", "a4"], label: "B"),
            makePod(teamID: "t2", index: 0, memberIDs: ["b1", "b2"], label: "A"),
            makePod(teamID: "t2", index: 1, memberIDs: ["b3", "b4"], label: "B"),
        ]
        let matchupPlans = [
            SeriesRoundMatchupPlan(
                id: "matchup_1",
                teamAID: "t1",
                teamBID: "t2",
                index: 0,
                podGroupingStrategy: .swapPairs
            ),
        ]

        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: pods,
            matchupPlans: matchupPlans,
            seriesRound: seriesRound
        )

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].memberIDs, ["a1", "a2", "b3", "b4"])
        XCTAssertEqual(plans[1].memberIDs, ["a3", "a4", "b1", "b2"])
    }

    func testBuildTeeGroupPlans_swapPairsRotatesOpponentPodsWhenThereAreThreePairs() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.podGroupingStrategy = .swapPairs
        cfg.teeGroupMode = .podAligned
        let seriesRound = SeriesRound(id: "sr_rotate", roundConfig: cfg, parentID: "series1")

        let teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        let members = [
            makeMember(id: "a1", name: "A1", teamID: "t1"),
            makeMember(id: "a2", name: "A2", teamID: "t1"),
            makeMember(id: "a3", name: "A3", teamID: "t1"),
            makeMember(id: "a4", name: "A4", teamID: "t1"),
            makeMember(id: "a5", name: "A5", teamID: "t1"),
            makeMember(id: "a6", name: "A6", teamID: "t1"),
            makeMember(id: "b1", name: "B1", teamID: "t2"),
            makeMember(id: "b2", name: "B2", teamID: "t2"),
            makeMember(id: "b3", name: "B3", teamID: "t2"),
            makeMember(id: "b4", name: "B4", teamID: "t2"),
            makeMember(id: "b5", name: "B5", teamID: "t2"),
            makeMember(id: "b6", name: "B6", teamID: "t2"),
        ]
        let pods = [
            makePod(teamID: "t1", index: 0, memberIDs: ["a1", "a2"], label: "A"),
            makePod(teamID: "t1", index: 1, memberIDs: ["a3", "a4"], label: "B"),
            makePod(teamID: "t1", index: 2, memberIDs: ["a5", "a6"], label: "C"),
            makePod(teamID: "t2", index: 0, memberIDs: ["b1", "b2"], label: "A"),
            makePod(teamID: "t2", index: 1, memberIDs: ["b3", "b4"], label: "B"),
            makePod(teamID: "t2", index: 2, memberIDs: ["b5", "b6"], label: "C"),
        ]
        let matchupPlans = [
            SeriesRoundMatchupPlan(
                id: "matchup_1",
                teamAID: "t1",
                teamBID: "t2",
                index: 0,
                podGroupingStrategy: .swapPairs
            ),
        ]

        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: pods,
            matchupPlans: matchupPlans,
            seriesRound: seriesRound
        )

        XCTAssertEqual(plans.count, 3)
        XCTAssertEqual(plans[0].memberIDs, ["a1", "a2", "b3", "b4"])
        XCTAssertEqual(plans[1].memberIDs, ["a3", "a4", "b5", "b6"])
        XCTAssertEqual(plans[2].memberIDs, ["a5", "a6", "b1", "b2"])
    }

    func testBuildTeeGroupPlans_declinedPairMemberPreservesSeatGap() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.podGroupingStrategy = .alignByIndex
        cfg.teeGroupMode = .podAligned
        let seriesRound = SeriesRound(id: "sr_gap", roundConfig: cfg, parentID: "series1")

        let teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        let members = [
            makeMember(id: "a1", name: "A1", teamID: "t1"),
            makeMember(id: "a3", name: "A3", teamID: "t1"),
            makeMember(id: "a4", name: "A4", teamID: "t1"),
            makeMember(id: "b1", name: "B1", teamID: "t2"),
            makeMember(id: "b2", name: "B2", teamID: "t2"),
            makeMember(id: "b3", name: "B3", teamID: "t2"),
            makeMember(id: "b4", name: "B4", teamID: "t2"),
        ]
        let pods = [
            makePod(teamID: "t1", index: 0, memberIDs: ["a1", "a2"], label: "A"),
            makePod(teamID: "t1", index: 1, memberIDs: ["a3", "a4"], label: "B"),
            makePod(teamID: "t2", index: 0, memberIDs: ["b1", "b2"], label: "A"),
            makePod(teamID: "t2", index: 1, memberIDs: ["b3", "b4"], label: "B"),
        ]
        let matchupPlans = [
            SeriesRoundMatchupPlan(
                id: "matchup_1",
                teamAID: "t1",
                teamBID: "t2",
                index: 0,
                podGroupingStrategy: .alignByIndex
            ),
        ]

        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: pods,
            matchupPlans: matchupPlans,
            seriesRound: seriesRound
        )
        let assignments = SeriesRoundCreationMapping.buildMemberAssignments(
            groupPlans: plans,
            groupIDsByPlanID: Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0.id) })
        )

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].memberIDs, ["a1", "b1", "b2"])
        XCTAssertEqual(plans[0].seats.map(\.teeOrder), [1, 3, 4])
        XCTAssertEqual(assignments["a1"]?.teeOrder, 1)
        XCTAssertEqual(assignments["b1"]?.teeOrder, 3)
        XCTAssertEqual(assignments["b2"]?.teeOrder, 4)
    }

    func testBuildTeeGroupPlans_fallsBackToSequentialGroupingWhenPodCountsMismatch() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.podGroupingStrategy = .swapPairs
        cfg.teeGroupMode = .podAligned
        let seriesRound = SeriesRound(id: "sr_fallback", roundConfig: cfg, parentID: "series1")

        let teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        let members = [
            makeMember(id: "a1", name: "A1", teamID: "t1"),
            makeMember(id: "a2", name: "A2", teamID: "t1"),
            makeMember(id: "a3", name: "A3", teamID: "t1"),
            makeMember(id: "a4", name: "A4", teamID: "t1"),
            makeMember(id: "b1", name: "B1", teamID: "t2"),
            makeMember(id: "b2", name: "B2", teamID: "t2"),
        ]
        let pods = [
            makePod(teamID: "t1", index: 0, memberIDs: ["a1", "a2"], label: "A"),
            makePod(teamID: "t1", index: 1, memberIDs: ["a3", "a4"], label: "B"),
            makePod(teamID: "t2", index: 0, memberIDs: ["b1", "b2"], label: "A"),
        ]
        let matchupPlans = [
            SeriesRoundMatchupPlan(
                id: "matchup_1",
                teamAID: "t1",
                teamBID: "t2",
                index: 0,
                podGroupingStrategy: .swapPairs
            ),
        ]

        let plans = SeriesRoundCreationMapping.buildTeeGroupPlans(
            members: members,
            teams: teams,
            pods: pods,
            matchupPlans: matchupPlans,
            seriesRound: seriesRound
        )

        XCTAssertEqual(plans.map(\.memberIDs), [
            ["a1", "a2", "a3", "a4"],
            ["b1", "b2"],
        ])
    }

    func testBuildMemberAssignments_teeOrderStartsAtOne() {
        let groupPlans = [
            SeriesRoundCreationMapping.TeeGroupPlan(id: "g0", memberIDs: ["a", "b"]),
        ]
        let ids = ["g0": "firebase-group-99"]
        let map = SeriesRoundCreationMapping.buildMemberAssignments(
            groupPlans: groupPlans,
            groupIDsByPlanID: ids
        )
        XCTAssertEqual(map["a"]?.groupID, "firebase-group-99")
        XCTAssertEqual(map["a"]?.teeOrder, 1)
        XCTAssertEqual(map["b"]?.teeOrder, 2)
    }

    func testBuildMemberAssignments_preservesExplicitSeatOrder() {
        let groupPlans = [
            SeriesRoundCreationMapping.TeeGroupPlan(
                id: "g0",
                seats: [
                    .init(memberID: "a", teeOrder: 1),
                    .init(memberID: "b", teeOrder: 3),
                ]
            ),
        ]
        let map = SeriesRoundCreationMapping.buildMemberAssignments(
            groupPlans: groupPlans,
            groupIDsByPlanID: ["g0": "firebase-group-99"]
        )

        XCTAssertEqual(map["a"]?.teeOrder, 1)
        XCTAssertEqual(map["b"]?.teeOrder, 3)
    }

    // MARK: - Team mapping + participants

    func testTeamMappingsFromPosted_zipsSortedSeriesTeamsToRoundTeams() {
        let seriesTeams = [
            makeTeam(id: "st2", name: "B", index: 2),
            makeTeam(id: "st0", name: "A", index: 0),
        ]
        let t0 = self.t0
        let posted = [
            RoundTeam(id: "rt0", name: "A", color: "red", index: 0, createdAt: t0, parentID: "round1"),
            RoundTeam(id: "rt1", name: "B", color: "blue", index: 1, createdAt: t0, parentID: "round1"),
        ]
        let map = SeriesRoundCreationMapping.teamMappingsFromPosted(seriesTeams: seriesTeams, posted: posted)
        XCTAssertEqual(map["st0"]?.roundTeamID, "rt0")
        XCTAssertEqual(map["st2"]?.roundTeamID, "rt1")
    }

    func testResolvedTeeBoxID_precedenceMemberThenSegmentThenFirstTee() {
        let segment = makeCourseSegment(defaultTee: "tee_white")
        let m1 = makeMember(id: "m1", name: "A", defaultTeeBoxID: "tee_blue")
        XCTAssertEqual(SeriesRoundCreationMapping.resolvedTeeBoxID(for: m1, courseSegment: segment), "tee_blue")

        let m2 = makeMember(id: "m2", name: "B", defaultTeeBoxID: nil)
        XCTAssertEqual(SeriesRoundCreationMapping.resolvedTeeBoxID(for: m2, courseSegment: segment), "tee_white")

        let emptyDefault = CourseSegment(
            courseInfo: segment.courseInfo,
            holeRange: segment.holeRange,
            defaultTee: nil
        )
        XCTAssertEqual(
            SeriesRoundCreationMapping.resolvedTeeBoxID(for: m2, courseSegment: emptyDefault),
            "tee_white"
        )
    }

    func testBuildParticipantPayloads_teamHandicapHost() {
        let segment = makeCourseSegment()
        let members = [
            makeMember(id: "m1", name: "Host", playerID: "phost", teamID: "t1"),
            makeMember(id: "m2", name: "Guest", playerID: "pguest", teamID: "t1"),
        ]
        let links: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [
            "t1": .init(seriesTeamID: "t1", roundTeamID: "roundTeam99"),
        ]
        let assignments: [String: SeriesRoundCreationMapping.MemberAssignment] = [
            "m1": .init(groupID: "g1", teeOrder: 1),
            "m2": .init(groupID: "g1", teeOrder: 2),
        ]
        let handicaps: [String: SeriesMemberHandicap] = [
            "m2": SeriesMemberHandicap(memberID: "m2", computedIndex: 12.4),
        ]
        let payloads = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: members,
            roundID: "roundZ",
            teamMappings: links,
            memberAssignments: assignments,
            handicaps: handicaps,
            courseSegment: segment,
            hostPlayerID: "phost"
        )
        XCTAssertEqual(payloads.count, 2)
        XCTAssertEqual(payloads[0].parentID, "roundZ")
        XCTAssertTrue(payloads[0].isHost)
        XCTAssertEqual(payloads[0].teamID, "roundTeam99")
        XCTAssertEqual(payloads[0].groupID, "g1")
        XCTAssertEqual(payloads[0].teeOrder, 1)
        XCTAssertFalse(payloads[1].isHost)
        XCTAssertEqual(payloads[1].adjustedHandicap, 12)
        XCTAssertEqual(payloads[1].leagueHandicapStrokesAtCreation, 12)
        XCTAssertEqual(payloads[0].leagueHandicapStrokesAtCreation, 0)
    }

    func testBuildParticipantPayloads_preservesNonContiguousTeeOrder() {
        let payloads = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: [
                makeMember(id: "m1", name: "Host", playerID: "phost", teamID: "t1"),
                makeMember(id: "m2", name: "Guest", playerID: "pguest", teamID: "t1"),
            ],
            roundID: "roundZ",
            teamMappings: ["t1": .init(seriesTeamID: "t1", roundTeamID: "roundTeam99")],
            memberAssignments: [
                "m1": .init(groupID: "g1", teeOrder: 1),
                "m2": .init(groupID: "g1", teeOrder: 3),
            ],
            handicaps: [:],
            courseSegment: makeCourseSegment(),
            hostPlayerID: "phost"
        )

        XCTAssertEqual(payloads[0].teeOrder, 1)
        XCTAssertEqual(payloads[1].teeOrder, 3)
    }

    func testBuildParticipantPayloads_appliesPresenceStatusesByMember() {
        let payloads = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: [
                makeMember(id: "m1", name: "Host", playerID: "phost", teamID: "t1"),
                makeMember(id: "m2", name: "Guest", playerID: "pguest", teamID: "t1"),
            ],
            roundID: "roundZ",
            teamMappings: ["t1": .init(seriesTeamID: "t1", roundTeamID: "roundTeam99")],
            memberAssignments: [
                "m1": .init(groupID: "g1", teeOrder: 1),
                "m2": .init(groupID: "g1", teeOrder: 2),
            ],
            handicaps: [:],
            courseSegment: makeCourseSegment(),
            hostPlayerID: "phost",
            presenceStatusByMemberID: [
                "m2": .unconfirmed,
            ]
        )

        XCTAssertEqual(payloads[0].resolvedPresenceStatus, .active)
        XCTAssertEqual(payloads[1].resolvedPresenceStatus, .unconfirmed)
    }

    // MARK: - Segment matchups + Firestore mapping ids

    func testBuildRoundMatchups_teamAndIndividual() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        let srTeam = SeriesRound(id: "sr", roundConfig: cfg, parentID: "s")
        let teamPlans = [
            SeriesRoundMatchupPlan(id: "planT", teamAID: "ta", teamBID: "tb", index: 0),
        ]
        let teamMap: [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] = [
            "ta": .init(seriesTeamID: "ta", roundTeamID: "rta"),
            "tb": .init(seriesTeamID: "tb", roundTeamID: "rtb"),
        ]
        let teamMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: srTeam,
            matchupPlans: teamPlans,
            teamMappings: teamMap,
            participantIDsBySeriesMemberID: [:],
            scoringGroups: [],
            participants: []
        )
        XCTAssertEqual(teamMatchups.count, 1)
        XCTAssertEqual(teamMatchups[0].mode, MatchupMode.team)
        XCTAssertEqual(teamMatchups[0].teamIDs, ["rta", "rtb"])

        cfg.matchupMode = .individualVsIndividual
        let srInd = SeriesRound(id: "sr2", roundConfig: cfg, parentID: "s")
        let indPlans = [
            SeriesRoundMatchupPlan(id: "planI", memberAID: "ma", memberBID: "mb", index: 0),
        ]
        let partMap = ["ma": "pa", "mb": "pb"]
        let indMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: srInd,
            matchupPlans: indPlans,
            teamMappings: [:],
            participantIDsBySeriesMemberID: partMap,
            scoringGroups: [],
            participants: []
        )
        XCTAssertEqual(indMatchups.count, 1)
        XCTAssertEqual(indMatchups[0].mode, MatchupMode.individual)
        XCTAssertEqual(indMatchups[0].participantIDs, ["pa", "pb"])
    }

    func testBuildRoundSegment_includesTemplateAndHoleRange() {
        var cfg = SeriesRoundConfiguration()
        cfg.formatTemplateID = FormatTemplateRegistry.strokePlay.id
        let sr = SeriesRound(id: "srSeg", roundConfig: cfg, parentID: "s")
        let segment = makeCourseSegment()
        let matchups = [
            TeamMatchup(id: "m1", teamIDs: ["a", "b"], participantIDs: nil, mode: .team),
        ]
        let built = SeriesRoundCreationMapping.buildRoundSegment(
            roundID: "rSeg",
            series: makeSeries(),
            seriesRound: sr,
            courseSegment: segment,
            competitionScope: .matchup,
            matchups: matchups,
            scoringUnits: []
        )
        XCTAssertEqual(built.roundID, "rSeg")
        XCTAssertEqual(built.parentID, "rSeg")
        XCTAssertEqual(built.holeRange, segment.holeRange)
        XCTAssertEqual(built.templateID, FormatTemplateRegistry.strokePlay.id)
        XCTAssertEqual(built.competitionScope, CompetitionScope.matchup)
        XCTAssertEqual(built.matchups?.count, 1)
    }

    func testSeriesRoundMappingFactories_documentIDs() {
        let p = SeriesRoundCreationMapping.seriesRoundParticipantMapping(
            seriesRoundID: "sr99",
            seriesID: "s1",
            memberID: "mem1",
            participantID: "part1"
        )
        XCTAssertEqual(p.id, "sr99_participant_part1")
        XCTAssertEqual(p.seriesRoundID, "sr99")
        XCTAssertEqual(p.parentID, "s1")
        XCTAssertEqual(p.roundOwnerID, "part1")
        XCTAssertEqual(p.competitorID, "mem1")

        let link = SeriesRoundCreationMapping.SeriesToRoundTeamLink(seriesTeamID: "st", roundTeamID: "rt")
        let t = SeriesRoundCreationMapping.seriesRoundTeamMapping(
            seriesRoundID: "sr99",
            seriesID: "s1",
            link: link
        )
        XCTAssertEqual(t.id, "sr99_team_rt")
        XCTAssertEqual(t.roundOwnerID, "rt")
        XCTAssertEqual(t.competitorID, "st")
    }
}
