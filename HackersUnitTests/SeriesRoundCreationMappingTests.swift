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

    private func mirroredTeeGroupRound() -> SeriesRound {
        var cfg = SeriesRoundConfiguration()
        cfg.competitionScope = .matchup
        cfg.scoreOwnerScope = .partnership
        cfg.matchupMode = .teeGroupPartnerships
        cfg.teamAssignmentMode = .seriesTeams
        return SeriesRound(id: "sr_mirror", roundConfig: cfg, parentID: "series1")
    }

    private func mirrorTeamMappings() -> [String: SeriesRoundCreationMapping.SeriesToRoundTeamLink] {
        [
            "red": .init(seriesTeamID: "red", roundTeamID: "round_red"),
            "blue": .init(seriesTeamID: "blue", roundTeamID: "round_blue"),
        ]
    }

    private func makeSeries(handicapsEnabled: Bool = false, useTeams: Bool = true) -> Series {
        var settings = SeriesSettings()
        settings.handicapConfig = SeriesHandicapConfig(isEnabled: handicapsEnabled, config: .league2025)
        settings.useTeams = useTeams
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

    func testResolvedCompetitionScope_mirroredTeeGroupsForceMatchup() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teeGroupPartnerships
        cfg.scoreOwnerScope = .partnership
        cfg.teamAssignmentMode = .seriesTeams
        let sr = SeriesRound(id: "sr_mirror", roundConfig: cfg, parentID: "series1")
        let roundConfig = SeriesRoundCreationMapping.roundConfiguration(
            series: makeSeries(),
            seriesRound: sr,
            courseSegment: makeCourseSegment(),
            competitionScope: SeriesRoundCreationMapping.resolvedCompetitionScope(for: sr)
        )

        XCTAssertEqual(SeriesRoundCreationMapping.resolvedCompetitionScope(for: sr), .matchup)
        XCTAssertEqual(roundConfig.competitionScope, .matchup)
        XCTAssertEqual(roundConfig.scoreOwnerScope, .partnership)
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

    func testRoundConfigurationCopiesSharedScoreHandicapConfig() {
        var cfg = SeriesRoundConfiguration()
        cfg.sharedScoreHandicapConfig = HandicapConfiguration(
            percentage: 1.0,
            isTeamCombined: true,
            positionPercentages: [0.35, 0.15]
        )
        let seriesRound = SeriesRound(id: "sr_shared", roundConfig: cfg, parentID: "series1")

        let roundConfig = SeriesRoundCreationMapping.roundConfiguration(
            series: makeSeries(handicapsEnabled: true),
            seriesRound: seriesRound,
            courseSegment: makeCourseSegment(),
            competitionScope: .field
        )

        XCTAssertEqual(roundConfig.sharedScoreHandicapConfig, cfg.sharedScoreHandicapConfig)
    }

    func testTeeGroupPlansWithAdjacentPartnershipsKeepsPairsTogether() {
        let groupPlans = [
            SeriesRoundCreationMapping.TeeGroupPlan(
                id: "g1",
                seats: [
                    .init(memberID: "red_1", teeOrder: 1),
                    .init(memberID: "blue_1", teeOrder: 2),
                    .init(memberID: "red_2", teeOrder: 3),
                    .init(memberID: "blue_2", teeOrder: 4),
                ]
            ),
        ]
        let partnershipPlans = [
            SeriesRoundPartnershipPlan(id: "red_pair", teamID: "red", memberIDs: ["red_1", "red_2"]),
            SeriesRoundPartnershipPlan(id: "blue_pair", teamID: "blue", memberIDs: ["blue_1", "blue_2"]),
        ]

        let normalized = SeriesRoundCreationMapping.teeGroupPlansWithAdjacentPartnerships(
            groupPlans,
            partnershipPlans: partnershipPlans
        )

        XCTAssertEqual(
            normalized.first?.seats.map { "\($0.memberID):\($0.teeOrder)" },
            ["red_1:1", "red_2:2", "blue_1:3", "blue_2:4"]
        )
    }

    func testBuildTeeGroupsArray_shotgunUsesSameScheduledTeeTime() throws {
        let scheduled = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-01T14:00:00Z"))
        let groups = SeriesRoundCreationMapping.buildTeeGroupsArray(
            roundID: "round1",
            groupPlans: [
                .init(id: "g1", memberIDs: ["m1"]),
                .init(id: "g2", memberIDs: ["m2"]),
                .init(id: "g3", memberIDs: ["m3"]),
            ],
            holeRange: HoleRange(startHole: 1, endHole: 18),
            useSequentialStarts: true,
            scheduledTeeTime: scheduled
        )

        XCTAssertEqual(Set(groups.compactMap(\.teeTime)).count, 1)
        XCTAssertEqual(groups.map(\.startingHole), [1, 2, 3])
    }

    func testBuildTeeGroupsArray_nonShotgunStaggersScheduledTeeTime() throws {
        let scheduled = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-01T14:00:00Z"))
        let groups = SeriesRoundCreationMapping.buildTeeGroupsArray(
            roundID: "round1",
            groupPlans: [
                .init(id: "g1", memberIDs: ["m1"]),
                .init(id: "g2", memberIDs: ["m2"]),
            ],
            holeRange: HoleRange(startHole: 10, endHole: 18),
            useSequentialStarts: false,
            scheduledTeeTime: scheduled
        )

        let first = try XCTUnwrap(groups.first?.teeTime.flatMap(ISO8601DateFormatter().date(from:)))
        let second = try XCTUnwrap(groups.dropFirst().first?.teeTime.flatMap(ISO8601DateFormatter().date(from:)))
        XCTAssertEqual(second.timeIntervalSince(first), 8 * 60, accuracy: 0.1)
        XCTAssertEqual(groups.map(\.startingHole), [10, 10])
    }

    func testPlannedTeeGroupsWithSchedule_preservesManualSeatsAndUsesFirstTimeFallback() {
        let existing = [
            SeriesRoundPlannedTeeGroup(
                id: "g1",
                index: 0,
                teeTime: "2026-05-01T14:00:00Z",
                startingHole: 1,
                seats: [.init(id: "s1", memberID: "m1", teeOrder: 1, source: .manualOverride)],
                source: .manualOverride
            ),
            SeriesRoundPlannedTeeGroup(
                id: "g2",
                index: 1,
                teeTime: "2026-05-01T14:08:00Z",
                startingHole: 1,
                seats: [.init(id: "s2", memberID: "m2", teeOrder: 1, source: .manualOverride)],
                source: .manualOverride
            ),
        ]

        let shotgun = SeriesRoundCreationMapping.plannedTeeGroupsWithSchedule(
            existing,
            holeRange: HoleRange(startHole: 1, endHole: 18),
            useShotgunStart: true
        )

        XCTAssertEqual(Set(shotgun.compactMap(\.teeTime)), ["2026-05-01T14:00:00Z"])
        XCTAssertEqual(shotgun.map(\.startingHole), [1, 2])
        XCTAssertEqual(shotgun.flatMap(\.seats).map(\.source), [.manualOverride, .manualOverride])
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

    func testRoundDraft_carriesNineHoleHandicapBasisAndKeepsEnteredHCP() {
        var settings = SeriesSettings()
        settings.handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025, strokeBasis: .nineHole)
        let series = Series(id: "series1", settings: settings)
        let sr = fieldSeriesRound()
        let segment = makeCourseSegment()
        let member = makeMember(id: "m1", name: "Player", playerID: "p1")

        let draft = SeriesRoundCreationMapping.roundDraft(
            id: "r_nine",
            shareCode: "NINE",
            createdBy: "u",
            series: series,
            members: [member],
            seriesRound: sr,
            courseSegment: segment
        )
        let payloads = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: [member],
            roundID: draft.id,
            teamMappings: [:],
            memberAssignments: [:],
            handicaps: [
                "m1": SeriesMemberHandicap(id: "m1", memberID: "m1", computedIndex: 7),
            ],
            courseSegment: segment,
            hostPlayerID: nil
        )

        XCTAssertEqual(draft.configuration.handicapStrokeBasis, .nineHole)
        XCTAssertEqual(payloads.first?.adjustedHandicap, 7)
        XCTAssertEqual(payloads.first?.leagueHandicapStrokesAtCreation, 7)
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

    func testRoundDraft_fixedSeriesHandicapsAlsoDefaultPrimaryFormatToNet() {
        let sr = fieldSeriesRound()
        let segment = makeCourseSegment()
        var settings = SeriesSettings()
        settings.handicapConfig = SeriesHandicapConfig(mode: .fixed, config: .league2025)

        let draft = SeriesRoundCreationMapping.roundDraft(
            id: "r_fixed",
            shareCode: "Y",
            createdBy: "u",
            series: Series(id: "series1", settings: settings),
            members: [],
            seriesRound: sr,
            courseSegment: segment
        )

        XCTAssertTrue(draft.configuration.useHandicaps)
        XCTAssertEqual(draft.configuration.primaryFormat.configuration.basis, .net)
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

    func testBuildParticipantPayloads_capsSeriesHandicapForRoundStrokes() {
        let member = makeMember(id: "m1", name: "High", playerID: "p1")
        let payloads = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: [member],
            roundID: "roundZ",
            teamMappings: [:],
            memberAssignments: [:],
            handicaps: [
                "m1": SeriesMemberHandicap(memberID: "m1", computedIndex: 27.7),
            ],
            maximumHandicap: 18,
            courseSegment: makeCourseSegment(),
            hostPlayerID: nil
        )

        XCTAssertEqual(payloads.first?.originalHandicap, 18)
        XCTAssertEqual(payloads.first?.adjustedHandicap, 18)
        XCTAssertEqual(payloads.first?.leagueHandicapStrokesAtCreation, 18)
    }

    func testSeriesMemberHandicapCappedDisplayTextUsesAsteriskOnlyWhenCapped() {
        let capped = SeriesMemberHandicap(memberID: "m1", computedIndex: 27.7)
        let uncapped = SeriesMemberHandicap(memberID: "m2", computedIndex: 17.4)
        let missing = SeriesMemberHandicap(memberID: "m3")

        XCTAssertEqual(capped.cappedDisplayText(maximumHandicap: 18), "18*")
        XCTAssertEqual(uncapped.cappedDisplayText(maximumHandicap: 18), "17")
        XCTAssertNil(missing.cappedDisplayText(maximumHandicap: 18))
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

    func testBuildRoundMatchups_mirroredTeeGroupPartnershipsCreateScoreOwnerMatchup() {
        let seriesRound = mirroredTeeGroupRound()
        let scoringGroups = [
            RoundScoringGroup(id: "red_pair", teamID: "round_red", teeGroupID: "g1", kind: .partnership, memberIDs: ["p1", "p2"]),
            RoundScoringGroup(id: "blue_pair", teamID: "round_blue", teeGroupID: "g1", kind: .partnership, memberIDs: ["p3", "p4"]),
        ]

        let matchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: [],
            teamMappings: mirrorTeamMappings(),
            participantIDsBySeriesMemberID: [:],
            scoringGroups: scoringGroups,
            participants: []
        )

        XCTAssertEqual(matchups.count, 1)
        XCTAssertEqual(matchups.first?.mode, .scoreOwner)
        XCTAssertEqual(matchups.first?.scoreOwnerScope, .partnership)
        XCTAssertEqual(Set(matchups.first?.scoreOwnerIDs ?? []), Set(["red_pair", "blue_pair"]))
    }

    func testBuildRoundMatchups_mirroredTeeGroupsStillCreateScoreOwnerMatchupWhenScoreEntryIsIndividual() {
        var seriesRound = mirroredTeeGroupRound()
        seriesRound.roundConfig.scoreOwnerScope = .individual
        let scoringGroups = [
            RoundScoringGroup(id: "red_pair", teamID: "round_red", teeGroupID: "g1", kind: .partnership, memberIDs: ["p1", "p2"]),
            RoundScoringGroup(id: "blue_pair", teamID: "round_blue", teeGroupID: "g1", kind: .partnership, memberIDs: ["p3", "p4"]),
        ]

        let matchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: [],
            teamMappings: mirrorTeamMappings(),
            participantIDsBySeriesMemberID: [:],
            scoringGroups: scoringGroups,
            participants: []
        )

        XCTAssertEqual(matchups.count, 1)
        XCTAssertEqual(matchups.first?.mode, .scoreOwner)
        XCTAssertEqual(Set(matchups.first?.scoreOwnerIDs ?? []), Set(["red_pair", "blue_pair"]))
    }

    func testBuildRoundMatchups_pairPlansCreateExplicitScoreOwnerMatchups() {
        let seriesRound = mirroredTeeGroupRound()
        let scoringGroups = [
            RoundScoringGroup(id: "g1_red", teamID: "round_red", teeGroupID: "g1", kind: .partnership, memberIDs: ["p1", "p2"]),
            RoundScoringGroup(id: "g1_blue", teamID: "round_blue", teeGroupID: "g1", kind: .partnership, memberIDs: ["p3", "p4"]),
            RoundScoringGroup(id: "g2_red", teamID: "round_red", teeGroupID: "g2", kind: .partnership, memberIDs: ["p5", "p6"]),
            RoundScoringGroup(id: "g2_blue", teamID: "round_blue", teeGroupID: "g2", kind: .partnership, memberIDs: ["p7", "p8"]),
        ]
        let matchupPlans = [
            SeriesRoundMatchupPlan(id: "mx_1", pairAID: "g1_red", pairBID: "g2_blue", index: 0),
            SeriesRoundMatchupPlan(id: "mx_2", pairAID: "g2_red", pairBID: "g1_blue", index: 1),
        ]

        let matchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: matchupPlans,
            teamMappings: mirrorTeamMappings(),
            participantIDsBySeriesMemberID: [:],
            scoringGroups: scoringGroups,
            participants: []
        )

        XCTAssertEqual(matchups.map(\.id), ["mx_1", "mx_2"])
        XCTAssertEqual(Set(matchups[0].scoreOwnerIDs ?? []), Set(["g1_red", "g2_blue"]))
        XCTAssertEqual(Set(matchups[1].scoreOwnerIDs ?? []), Set(["g2_red", "g1_blue"]))
    }

    func testBuildRoundMatchups_mirroredTeeGroupsSkipSameTeamAndExtraPairs() {
        let seriesRound = mirroredTeeGroupRound()
        let sameTeamGroups = [
            RoundScoringGroup(id: "red_a", teamID: "round_red", teeGroupID: "g1", kind: .partnership, memberIDs: ["p1", "p2"]),
            RoundScoringGroup(id: "red_b", teamID: "round_red", teeGroupID: "g1", kind: .partnership, memberIDs: ["p3", "p4"]),
        ]
        let extraPairGroups = sameTeamGroups + [
            RoundScoringGroup(id: "blue_a", teamID: "round_blue", teeGroupID: "g1", kind: .partnership, memberIDs: ["p5", "p6"]),
        ]

        let sameTeamMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: [],
            teamMappings: mirrorTeamMappings(),
            participantIDsBySeriesMemberID: [:],
            scoringGroups: sameTeamGroups,
            participants: []
        )
        let extraPairMatchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: [],
            teamMappings: mirrorTeamMappings(),
            participantIDsBySeriesMemberID: [:],
            scoringGroups: extraPairGroups,
            participants: []
        )

        XCTAssertTrue(sameTeamMatchups.isEmpty)
        XCTAssertTrue(extraPairMatchups.isEmpty)
    }

    func testCaptainChoicePartnershipResolvedPlanPreservesSeriesTeamsTeeSheetMatchupsAndAllowances() throws {
        var cfg = SeriesRoundConfiguration()
        cfg.formatTemplateID = FormatTemplateRegistry.captainsChoice.id
        cfg.competitionScope = .matchup
        cfg.scoreOwnerScope = .partnership
        cfg.matchupMode = .teeGroupPartnerships
        cfg.teamAssignmentMode = .seriesTeams
        cfg.sharedScoreHandicapConfig = .scramble2Player

        let red = makeTeam(id: "red", name: "Red Team", index: 0, color: "red")
        let blue = makeTeam(id: "blue", name: "Blue Team", index: 1, color: "blue")
        let members = [
            makeMember(id: "r1", name: "Red 1", teamID: "red"),
            makeMember(id: "r2", name: "Red 2", teamID: "red"),
            makeMember(id: "b1", name: "Blue 1", teamID: "blue"),
            makeMember(id: "b2", name: "Blue 2", teamID: "blue"),
            makeMember(id: "r3", name: "Red 3", teamID: "red"),
            makeMember(id: "r4", name: "Red 4", teamID: "red"),
            makeMember(id: "b3", name: "Blue 3", teamID: "blue"),
            makeMember(id: "b4", name: "Blue 4", teamID: "blue"),
        ]
        let plannedTeeGroups = [
            SeriesRoundPlannedTeeGroup(
                id: "group_1",
                index: 0,
                seats: ["r1", "r2", "b1", "b2"].enumerated().map {
                    SeriesRoundPlannedSeat(id: $0.element, memberID: $0.element, teeOrder: $0.offset + 1)
                }
            ),
            SeriesRoundPlannedTeeGroup(
                id: "group_2",
                index: 1,
                seats: ["r3", "r4", "b3", "b4"].enumerated().map {
                    SeriesRoundPlannedSeat(id: $0.element, memberID: $0.element, teeOrder: $0.offset + 1)
                }
            ),
        ]
        let partnershipPlans = [
            SeriesRoundPartnershipPlan(id: "red_pair_1", teamID: "red", memberIDs: ["r1", "r2"]),
            SeriesRoundPartnershipPlan(id: "blue_pair_1", teamID: "blue", memberIDs: ["b1", "b2"]),
            SeriesRoundPartnershipPlan(id: "red_pair_2", teamID: "red", memberIDs: ["r3", "r4"]),
            SeriesRoundPartnershipPlan(id: "blue_pair_2", teamID: "blue", memberIDs: ["b3", "b4"]),
        ]
        let seriesRound = SeriesRound(
            id: "sr_captains",
            roundConfig: cfg,
            plannedTeeGroups: plannedTeeGroups,
            partnershipPlans: partnershipPlans,
            parentID: "series1"
        )
        let plan = SeriesRoundResolvedPlan(
            series: makeSeries(handicapsEnabled: true),
            seriesRound: seriesRound,
            members: members,
            teams: [red, blue],
            pods: [],
            courseSegment: makeCourseSegment()
        )

        XCTAssertEqual(plan.seriesTeamsForRound.map(\.id), ["red", "blue"])
        XCTAssertEqual(plan.teeGroupPlans.map(\.memberIDs), [
            ["r1", "r2", "b1", "b2"],
            ["r3", "r4", "b3", "b4"],
        ])

        let teamMappings = mirrorTeamMappings()
        let memberAssignments = SeriesRoundCreationMapping.buildMemberAssignments(
            groupPlans: plan.teeGroupPlans,
            groupIDsByPlanID: ["group_1": "round_group_1", "group_2": "round_group_2"]
        )
        let handicaps = Dictionary(uniqueKeysWithValues: members.enumerated().map { index, member in
            (member.id, SeriesMemberHandicap(id: member.id, memberID: member.id, computedIndex: Double(index + 10)))
        })
        let participants = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: members,
            roundID: "round1",
            teamMappings: teamMappings,
            memberAssignments: memberAssignments,
            handicaps: handicaps,
            courseSegment: makeCourseSegment(),
            hostPlayerID: nil
        )
        let teeGroups = [
            TeeTimeGroup(id: "round_group_1", index: 0, createdAt: t0, lastUpdatedAt: t0, parentID: "round1"),
            TeeTimeGroup(id: "round_group_2", index: 1, createdAt: t0, lastUpdatedAt: t0, parentID: "round1"),
        ]
        let scoringGroups = SeriesRoundCreationMapping.buildRoundScoringGroups(
            roundID: "round1",
            seriesRound: seriesRound,
            participants: participants,
            partnershipPlans: plan.partnershipPlans,
            teeGroups: teeGroups
        )
        let matchups = SeriesRoundCreationMapping.buildRoundMatchups(
            seriesRound: seriesRound,
            matchupPlans: plan.matchupPlans,
            teamMappings: teamMappings,
            participantIDsBySeriesMemberID: [:],
            scoringGroups: scoringGroups,
            participants: participants
        )
        let scoringUnits = SeriesRoundCreationMapping.buildScoringUnits(
            seriesRound: seriesRound,
            participants: participants,
            scoringGroups: scoringGroups,
            teamMappings: teamMappings
        )

        XCTAssertEqual(Set(participants.compactMap(\.teamID)), Set(["round_red", "round_blue"]))
        XCTAssertEqual(scoringGroups.count, 4)
        XCTAssertEqual(matchups.count, 2)
        XCTAssertTrue(matchups.allSatisfy { ($0.mode ?? .team) == .scoreOwner })
        XCTAssertEqual(scoringUnits.count, 4)
        XCTAssertTrue(scoringUnits.allSatisfy { $0.handicapAllowance != nil })
        let redPairUnitStrokes = try XCTUnwrap(scoringUnits.first { $0.id == "red_pair_1" }?.handicapAllowance?.unitStrokes)
        XCTAssertEqual(redPairUnitStrokes, 5.15, accuracy: 0.001)
        XCTAssertEqual(Int(redPairUnitStrokes.rounded(.toNearestOrAwayFromZero)), 5)
    }

    func testRoundSnapshotAutoMirrorsOnlyClassicSharedTeamRounds() {
        var classicConfig = SeriesRoundConfiguration(formatTemplateID: FormatTemplateRegistry.captainsChoice.id)
        classicConfig.teamAssignmentMode = .seriesTeams
        classicConfig.scoreOwnerScope = .individual
        let classicRoundConfig = SeriesRoundCreationMapping.roundConfiguration(
            series: makeSeries(),
            seriesRound: SeriesRound(id: "classic", roundConfig: classicConfig, parentID: "series1"),
            courseSegment: makeCourseSegment(),
            competitionScope: .field
        )
        XCTAssertTrue(RoundSnapshot(round: Round(configuration: classicRoundConfig)).shouldAutoMirrorTeeGroupsToTeams)

        var partnershipConfig = classicConfig
        partnershipConfig.scoreOwnerScope = .partnership
        partnershipConfig.matchupMode = .teeGroupPartnerships
        let partnershipRoundConfig = SeriesRoundCreationMapping.roundConfiguration(
            series: makeSeries(),
            seriesRound: SeriesRound(id: "partnership", roundConfig: partnershipConfig, parentID: "series1"),
            courseSegment: makeCourseSegment(),
            competitionScope: .matchup
        )
        XCTAssertFalse(RoundSnapshot(round: Round(configuration: partnershipRoundConfig)).shouldAutoMirrorTeeGroupsToTeams)
    }

    func testBuildRoundScoringGroups_materializesPartnershipsWithoutPartnershipScoreEntry() {
        var cfg = SeriesRoundConfiguration()
        cfg.scoreOwnerScope = .individual
        let seriesRound = SeriesRound(id: "sr_pairs", roundConfig: cfg, parentID: "series1")
        let participants = [
            RoundParticipant(
                id: "p1",
                name: Name("Alice", "Player"),
                seriesMemberID: "m1",
                teamID: "teamA",
                groupID: "g1",
                parentID: "round1"
            ),
            RoundParticipant(
                id: "p2",
                name: Name("Bob", "Player"),
                seriesMemberID: "m2",
                teamID: "teamA",
                groupID: "g1",
                parentID: "round1"
            ),
        ]
        let partnershipPlans = [
            SeriesRoundPartnershipPlan(id: "pair1", teamID: "tA", memberIDs: ["m1", "m2"])
        ]
        let teeGroups = [TeeTimeGroup(id: "g1", index: 0, createdAt: t0, lastUpdatedAt: t0, parentID: "round1")]

        let groups = SeriesRoundCreationMapping.buildRoundScoringGroups(
            roundID: "round1",
            seriesRound: seriesRound,
            participants: participants,
            partnershipPlans: partnershipPlans,
            teeGroups: teeGroups
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.kind, .partnership)
        XCTAssertEqual(groups.first?.memberIDs, ["p1", "p2"])
    }

    func testBuildRoundScoringGroups_dropsInvalidPartnershipWhenPlayersAreInDifferentTeeGroups() {
        var cfg = SeriesRoundConfiguration()
        cfg.scoreOwnerScope = .individual
        let seriesRound = SeriesRound(id: "sr_pairs", roundConfig: cfg, parentID: "series1")
        let participants = [
            RoundParticipant(
                id: "p1",
                name: Name("Alice", "Player"),
                seriesMemberID: "m1",
                teamID: "teamA",
                groupID: "g1",
                parentID: "round1"
            ),
            RoundParticipant(
                id: "p2",
                name: Name("Bob", "Player"),
                seriesMemberID: "m2",
                teamID: "teamA",
                groupID: "g2",
                parentID: "round1"
            ),
        ]

        let groups = SeriesRoundCreationMapping.buildRoundScoringGroups(
            roundID: "round1",
            seriesRound: seriesRound,
            participants: participants,
            partnershipPlans: [SeriesRoundPartnershipPlan(id: "pair1", teamID: "teamA", memberIDs: ["m1", "m2"])],
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, createdAt: t0, lastUpdatedAt: t0, parentID: "round1"),
                TeeTimeGroup(id: "g2", index: 1, createdAt: t0, lastUpdatedAt: t0, parentID: "round1"),
            ]
        )

        XCTAssertTrue(groups.isEmpty)
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

    func testNameNormalizedForStorageCollapsesDuplicatedFullName() {
        let name = Name("Scott Sternstein", "Scott Sternstein").normalizedForStorage

        XCTAssertEqual(name.givenName, "Scott")
        XCTAssertEqual(name.familyName, "Sternstein")
        XCTAssertEqual(name.fullName, "Scott Sternstein")
        XCTAssertEqual(name.initials, "SS")
    }

    @MainActor
    func testJoinSeriesMatchingOfflineMemberFindsNameMatchBeforeCreatingDuplicate() {
        let primary = Player(
            id: "player_scott",
            userID: "user_scott",
            name: Name("Scott Sternstein", "Scott Sternstein")
        )
        let offlineMember = SeriesMember(
            id: "member_scott",
            userID: nil,
            playerID: "offline_scott",
            name: Name("Scott", "Sternstein"),
            teamID: "red",
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let duplicateCandidate = SeriesMember(
            id: "member_other",
            userID: nil,
            playerID: "offline_other",
            name: Name("Sam", "Player"),
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )

        let match = JoinSeriesViewModel.matchingOfflineMember(
            for: primary,
            in: [duplicateCandidate, offlineMember]
        )

        XCTAssertEqual(match?.id, "member_scott")
        XCTAssertEqual(match?.teamID, "red")
        XCTAssertEqual(match?.defaultTeeBoxID, "tee_white")
    }

    @MainActor
    func testJoinRoundMatchingOfflineParticipantFindsNameMatchAndKeepsRoundFields() {
        let primary = Player(
            id: "player_scott",
            userID: "user_scott",
            name: Name("Scott Sternstein", "Scott Sternstein")
        )
        let participant = RoundParticipant(
            id: "participant_scott",
            userID: nil,
            playerID: "offline_scott",
            name: Name("Scott", "Sternstein"),
            teeBoxID: "tee_white",
            originalHandicap: 17,
            adjustedHandicap: 17,
            leagueHandicapStrokesAtCreation: 17,
            seriesMemberID: "member_scott",
            teamID: "round_red",
            groupID: "group_1",
            teeOrder: 3,
            isHost: false,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "round1"
        )

        let match = JoinRoundViewModel.matchingOfflineParticipant(
            for: primary,
            in: [participant]
        )

        XCTAssertEqual(match?.id, "participant_scott")
        XCTAssertEqual(match?.teamID, "round_red")
        XCTAssertEqual(match?.groupID, "group_1")
        XCTAssertEqual(match?.adjustedHandicap, 17)
    }

    func testBuildParticipantPayloadsNormalizesNameAndCarriesTeamAndHandicap() {
        let member = SeriesMember(
            id: "member_scott",
            userID: "user_scott",
            playerID: "player_scott",
            name: Name("Scott Sternstein", "Scott Sternstein"),
            teamID: "red",
            defaultTeeBoxID: "tee_white",
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let payloads = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: [member],
            roundID: "round1",
            teamMappings: ["red": .init(seriesTeamID: "red", roundTeamID: "round_red")],
            memberAssignments: ["member_scott": .init(groupID: "group_1", teeOrder: 2)],
            handicaps: [
                "member_scott": SeriesMemberHandicap(
                    id: "member_scott",
                    memberID: "member_scott",
                    computedIndex: 16.7
                ),
            ],
            courseSegment: makeCourseSegment(),
            hostPlayerID: nil
        )

        let payload = payloads.first
        XCTAssertEqual(payload?.name.givenName, "Scott")
        XCTAssertEqual(payload?.name.familyName, "Sternstein")
        XCTAssertEqual(payload?.teamID, "round_red")
        XCTAssertEqual(payload?.groupID, "group_1")
        XCTAssertEqual(payload?.teeOrder, 2)
        XCTAssertEqual(payload?.originalHandicap, 17)
        XCTAssertEqual(payload?.adjustedHandicap, 17)
        XCTAssertEqual(payload?.leagueHandicapStrokesAtCreation, 17)
    }

    func testMembersMissingEffectiveHandicapReportsOnlyMissingMembers() {
        let members = [
            makeMember(id: "m1", name: "Alice"),
            makeMember(id: "m2", name: "Bob"),
        ]
        let missing = SeriesRoundCreationMapping.membersMissingEffectiveHandicap(
            members: members,
            handicaps: [
                "m1": SeriesMemberHandicap(id: "m1", memberID: "m1", computedIndex: 8.2),
            ]
        )

        XCTAssertEqual(missing, ["m2"])
    }

    @MainActor
    func testSuggestedIndividualMatchupPlans_teamSeriesAvoidsTeammatePairings() {
        let viewModel = SeriesViewModel()
        viewModel.series = makeSeries(useTeams: true)
        viewModel.teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        viewModel.members = [
            makeMember(id: "a1", name: "Alice", teamID: "t1"),
            makeMember(id: "a2", name: "Annie", teamID: "t1"),
            makeMember(id: "b1", name: "Bob", teamID: "t2"),
            makeMember(id: "b2", name: "Ben", teamID: "t2"),
        ]

        let plans = viewModel.suggestedIndividualMatchupPlans()

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(Set(plans.flatMap { [$0.memberAID, $0.memberBID] }.compactMap { $0 }), Set(["a1", "a2", "b1", "b2"]))
        XCTAssertTrue(plans.allSatisfy { plan in
            let memberA = viewModel.members.first { $0.id == plan.memberAID }
            let memberB = viewModel.members.first { $0.id == plan.memberBID }
            return memberA?.teamID != memberB?.teamID
        })
    }

    @MainActor
    func testSuggestedIndividualMatchupPlans_unevenTeamSizesLeaveLeftoverUnmatched() {
        let viewModel = SeriesViewModel()
        viewModel.series = makeSeries(useTeams: true)
        viewModel.teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        viewModel.members = [
            makeMember(id: "a1", name: "Alice", teamID: "t1"),
            makeMember(id: "a2", name: "Annie", teamID: "t1"),
            makeMember(id: "a3", name: "Ava", teamID: "t1"),
            makeMember(id: "b1", name: "Bob", teamID: "t2"),
            makeMember(id: "b2", name: "Ben", teamID: "t2"),
        ]

        let plans = viewModel.suggestedIndividualMatchupPlans()

        XCTAssertEqual(plans.count, 2)
        let usedMemberIDs = Set(plans.flatMap { [$0.memberAID, $0.memberBID] }.compactMap { $0 })
        XCTAssertFalse(usedMemberIDs.contains("a3"))
        XCTAssertFalse(plans.contains { $0.memberAID?.hasPrefix("a") == true && $0.memberBID?.hasPrefix("a") == true })
    }

    @MainActor
    func testSuggestedIndividualMatchupPlans_teamSeriesUsesHandicapOrderWithinTeams() {
        let viewModel = SeriesViewModel()
        viewModel.series = makeSeries(handicapsEnabled: true, useTeams: true)
        viewModel.teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        viewModel.members = [
            makeMember(id: "aHigh", name: "Alice", teamID: "t1"),
            makeMember(id: "aLow", name: "Annie", teamID: "t1"),
            makeMember(id: "bLow", name: "Ben", teamID: "t2"),
            makeMember(id: "bHigh", name: "Bob", teamID: "t2"),
        ]
        viewModel.memberHandicaps = [
            "aHigh": SeriesMemberHandicap(id: "aHigh", memberID: "aHigh", computedIndex: 18.4),
            "aLow": SeriesMemberHandicap(id: "aLow", memberID: "aLow", computedIndex: 7.2),
            "bLow": SeriesMemberHandicap(id: "bLow", memberID: "bLow", computedIndex: 8.1),
            "bHigh": SeriesMemberHandicap(id: "bHigh", memberID: "bHigh", computedIndex: 20.0),
        ]

        let plans = viewModel.suggestedIndividualMatchupPlans()

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(Set([plans[0].memberAID, plans[0].memberBID]), Set(["aLow", "bLow"]))
        XCTAssertEqual(Set([plans[1].memberAID, plans[1].memberBID]), Set(["aHigh", "bHigh"]))
    }

    @MainActor
    func testSuggestedIndividualMatchupPlans_preservesExistingPairMetadata() {
        let viewModel = SeriesViewModel()
        viewModel.series = makeSeries(useTeams: true)
        viewModel.teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        viewModel.members = [
            makeMember(id: "a1", name: "Alice", teamID: "t1"),
            makeMember(id: "b1", name: "Bob", teamID: "t2"),
        ]
        let existing = SeriesRoundMatchupPlan(
            id: "existing-plan",
            memberAID: "a1",
            memberBID: "b1",
            index: 0,
            podGroupingStrategy: .disabled,
            notes: "keep me",
            isLocked: true,
            createdAt: t0,
            lastUpdatedAt: t0
        )

        let plans = viewModel.suggestedIndividualMatchupPlans(preserving: [existing])

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].id, "existing-plan")
        XCTAssertEqual(plans[0].notes, "keep me")
        XCTAssertTrue(plans[0].isLocked)
        XCTAssertEqual(plans[0].createdAt, t0)
    }

    func testMatchupMemberOptionSections_groupByTeamSortByHandicapAndFormatSubtitle() {
        let teams = [
            makeTeam(id: "t1", name: "Alpha", index: 0),
            makeTeam(id: "t2", name: "Beta", index: 1),
        ]
        let members = [
            makeMember(id: "aNoHcp", name: "Ava", teamID: "t1"),
            makeMember(id: "aLow", name: "Alice", teamID: "t1"),
            makeMember(id: "aHigh", name: "Annie", teamID: "t1"),
            makeMember(id: "b1", name: "Bob", teamID: "t2"),
        ]

        let sections = SeriesRoundMatchupMemberOptionBuilder.sections(
            members: members,
            teams: teams,
            usesTeams: true
        ) { memberID in
            switch memberID {
            case "aLow": return 7.2
            case "aHigh": return 15.5
            case "b1": return 9.0
            default: return nil
            }
        }

        XCTAssertEqual(sections.map(\.title), ["Alpha", "Beta"])
        XCTAssertEqual(sections[0].options.map(\.memberID), ["aLow", "aHigh", "aNoHcp"])
        XCTAssertEqual(sections[0].options[0].subtitle, "7.2 HCP")
        XCTAssertNil(sections[0].options[2].subtitle)
        XCTAssertEqual(sections[1].options[0].subtitle, "9.0 HCP")
    }
}
