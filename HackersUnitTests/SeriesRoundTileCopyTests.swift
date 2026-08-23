//
//  SeriesRoundTileCopyTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundTileCopyTests: XCTestCase {

    private let t0 = Time(iso: "2023-11-15T12:00:00Z", unix: 1_700_000_000)

    private func makeMember(
        id: String,
        given: String,
        family: String = "Player",
        teamID: String? = nil,
        role: SeriesMemberRole = .member
    ) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: "p_\(id)",
            name: Name(given, family),
            role: role,
            teamID: teamID,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
    }

    private func makeTeam(id: String, name: String, index: Int) -> SeriesTeam {
        SeriesTeam(
            id: id,
            name: name,
            color: "red",
            index: index,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
    }

    private func makeSeries(handicapsEnabled: Bool = false, useTeams: Bool = true) -> Series {
        var settings = SeriesSettings()
        settings.handicapConfig = SeriesHandicapConfig(isEnabled: handicapsEnabled, config: .league2025)
        settings.useTeams = useTeams
        return Series(id: "series1", settings: settings)
    }

    private func matchupRoundConfig() -> SeriesRoundConfiguration {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .teamVsTeam
        cfg.teamAssignmentMode = .seriesTeams
        cfg.competitionScope = .matchup
        cfg.teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
        return cfg
    }

    // MARK: - Format caption

    func testFormatCaption_fieldStrokePlay_grossOmitsNet() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .field
        cfg.teamAssignmentMode = .manual
        let caption = SeriesRoundTileCopy.formatCaption(config: cfg, series: makeSeries())
        XCTAssertEqual(caption, "Stroke Play")
    }

    func testFormatCaption_leagueHandicapsOn_appendsNet() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .field
        cfg.teamAssignmentMode = .manual
        let caption = SeriesRoundTileCopy.formatCaption(config: cfg, series: makeSeries(handicapsEnabled: true))
        XCTAssertEqual(caption, "Stroke Play \(kDot) Net")
    }

    func testFormatCaption_explicitGrossOverride_skipsHandicapNetImplied() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .field
        cfg.teamAssignmentMode = .manual
        cfg.scoreBasisOverride = .gross
        let caption = SeriesRoundTileCopy.formatCaption(config: cfg, series: makeSeries(handicapsEnabled: true))
        XCTAssertEqual(caption, "Stroke Play")
    }

    func testFormatCaption_teamScoring_appendsFragment() {
        let cfg = matchupRoundConfig()
        let caption = SeriesRoundTileCopy.formatCaption(config: cfg, series: makeSeries())
        XCTAssertEqual(caption, "Stroke Play \(kDot) Best 2 per round")
    }

    // MARK: - Opponent summary

    func testOpponentSummary_fieldCompetition_returnsNil() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .field
        cfg.teamAssignmentMode = .manual
        let sr = SeriesRound(
            id: "r1",
            roundConfig: cfg,
            matchupPlans: [
                SeriesRoundMatchupPlan(
                    id: "p1",
                    teamAID: "t1",
                    teamBID: "t2",
                    index: 0,
                    createdAt: t0,
                    lastUpdatedAt: t0
                ),
            ],
            parentID: "series1"
        )
        let members = [makeMember(id: "m1", given: "A", teamID: "t1")]
        let teams = [makeTeam(id: "t1", name: "Team 1", index: 0), makeTeam(id: "t2", name: "Team 2", index: 1)]
        let summary = SeriesRoundTileCopy.opponentSummary(
            seriesRound: sr,
            configuration: cfg,
            currentMemberID: "m1",
            members: members,
            teams: teams,
            pods: [],
            hasTeamsInLeague: true
        )
        XCTAssertNil(summary)
    }

    func testOpponentSummary_teamVsTeam_findsOpponentTeamAndNames() {
        let cfg = matchupRoundConfig()
        let plan = SeriesRoundMatchupPlan(
            id: "p1",
            teamAID: "t1",
            teamBID: "t2",
            index: 0,
            createdAt: t0,
            lastUpdatedAt: t0
        )
        let sr = SeriesRound(id: "r1", roundConfig: cfg, matchupPlans: [plan], parentID: "series1")
        let members = [
            makeMember(id: "m1", given: "Alice", teamID: "t1"),
            makeMember(id: "bo", given: "Bob", teamID: "t2"),
            makeMember(id: "ca", given: "Carol", teamID: "t2"),
        ]
        let teams = [
            makeTeam(id: "t1", name: "Team 1", index: 0),
            makeTeam(id: "t2", name: "Team 6", index: 1),
        ]
        let summary = SeriesRoundTileCopy.opponentSummary(
            seriesRound: sr,
            configuration: cfg,
            currentMemberID: "m1",
            members: members,
            teams: teams,
            pods: [],
            hasTeamsInLeague: true
        )
        XCTAssertEqual(summary?.primaryLine, "Team 6")
        XCTAssertEqual(summary?.secondaryLine, "Bob P, Carol P")
    }

    func testOpponentSummary_teamVsTeam_truncatesManyNames() {
        let cfg = matchupRoundConfig()
        let plan = SeriesRoundMatchupPlan(
            id: "p1",
            teamAID: "t1",
            teamBID: "t2",
            index: 0,
            createdAt: t0,
            lastUpdatedAt: t0
        )
        let sr = SeriesRound(id: "r1", roundConfig: cfg, matchupPlans: [plan], parentID: "series1")
        let members = [
            makeMember(id: "m1", given: "A", teamID: "t1"),
            makeMember(id: "b2", given: "B", teamID: "t2"),
            makeMember(id: "b3", given: "C", teamID: "t2"),
            makeMember(id: "b4", given: "D", teamID: "t2"),
            makeMember(id: "b5", given: "E", teamID: "t2"),
        ]
        let teams = [
            makeTeam(id: "t1", name: "Side A", index: 0),
            makeTeam(id: "t2", name: "Side B", index: 1),
        ]
        let summary = SeriesRoundTileCopy.opponentSummary(
            seriesRound: sr,
            configuration: cfg,
            currentMemberID: "m1",
            members: members,
            teams: teams,
            pods: [],
            hasTeamsInLeague: true
        )
        XCTAssertEqual(summary?.secondaryLine, "B P, C P, +2")
    }

    func testOpponentSummary_individual_includesTeamPodSubtitle() {
        var cfg = SeriesRoundConfiguration()
        cfg.matchupMode = .individualVsIndividual
        cfg.teamAssignmentMode = .seriesTeams
        cfg.competitionScope = .matchup
        let plan = SeriesRoundMatchupPlan(
            id: "p1",
            memberAID: "m1",
            memberBID: "m2",
            index: 0,
            createdAt: t0,
            lastUpdatedAt: t0
        )
        let sr = SeriesRound(id: "r1", roundConfig: cfg, matchupPlans: [plan], parentID: "series1")
        let members = [
            makeMember(id: "m1", given: "Self", teamID: "t1"),
            makeMember(id: "m2", given: "Opp", family: "Nent", teamID: "t2"),
        ]
        let teams = [
            makeTeam(id: "t1", name: "Team 1", index: 0),
            makeTeam(id: "t2", name: "Team 2", index: 1),
        ]
        let pod = SeriesTeamPod(
            id: "pod1",
            teamID: "t2",
            label: "A",
            index: 0,
            memberIDs: ["m2"],
            isActive: true,
            createdAt: t0,
            lastUpdatedAt: t0,
            parentID: "series1"
        )
        let summary = SeriesRoundTileCopy.opponentSummary(
            seriesRound: sr,
            configuration: cfg,
            currentMemberID: "m1",
            members: members,
            teams: teams,
            pods: [pod],
            hasTeamsInLeague: true
        )
        XCTAssertEqual(summary?.primaryLine, "Opp Nent")
        XCTAssertEqual(summary?.secondaryLine, "Team 2 \(kDot) A")
    }
}
