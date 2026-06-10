@testable import Hackers
import XCTest

final class SeriesScoreboardCalculatorTests: XCTestCase {
    func testScoreboardEligibilityRequiresExactlyTwoTeams() {
        XCTAssertFalse(SeriesScoreboardEligibility.isEligible(teams: []))
        XCTAssertFalse(SeriesScoreboardEligibility.isEligible(teams: [
            SeriesTeam(id: "one", name: "One", color: "red", index: 0),
        ]))
        XCTAssertTrue(SeriesScoreboardEligibility.isEligible(teams: [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1),
        ]))
        XCTAssertFalse(SeriesScoreboardEligibility.isEligible(teams: [
            SeriesTeam(id: "one", name: "One", color: "red", index: 0),
            SeriesTeam(id: "two", name: "Two", color: "blue", index: 1),
            SeriesTeam(id: "three", name: "Three", color: "green", index: 2),
        ]))
        XCTAssertFalse(SeriesScoreboardEligibility.isEligible(teams: (0..<10).map {
            SeriesTeam(id: "team_\($0)", name: "Team \($0)", color: TeamColor.teamValue(for: $0).0.rawValue, index: $0)
        }))
    }

    func testTeamInsightRosterSubtitleUsesFirstNameLastInitial() {
        let members = [
            SeriesMember(id: "ada", name: Name("Ada", "Lovelace"), teamID: "red"),
            SeriesMember(id: "grace", name: Name("Grace", "Hopper"), teamID: "red"),
            SeriesMember(id: "inactive", name: Name("Inactive", "Player"), teamID: "red", isActive: false),
        ]

        let subtitle = SeriesTeamInsightBuilder.rosterSubtitle(for: members.filter(\.isActive))

        XCTAssertEqual(subtitle, "Ada L, Grace H")
        XCTAssertNil(SeriesTeamInsightBuilder.rosterSubtitle(for: []))
    }

    func testTeamInsightBuildsScheduleRowsForWinLossTieAndPlacement() {
        let teams = [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1),
        ]
        let rounds = [
            teamMatchupRound(id: "win", index: 0),
            teamMatchupRound(id: "tie", index: 1),
            teamMatchupRound(id: "loss", index: 2),
            SeriesRound(id: "placement", title: "Placement", index: 3, status: .complete),
            SeriesRound(id: "planned", title: "Planned", index: 4, status: .planned),
        ]
        let awards = [
            teamAward(roundID: "win", teamID: "red", name: "Red", points: 3, placement: 1),
            teamAward(roundID: "win", teamID: "blue", name: "Blue", points: 1, placement: 2),
            teamAward(roundID: "tie", teamID: "red", name: "Red", points: 2, placement: 1),
            teamAward(roundID: "tie", teamID: "blue", name: "Blue", points: 2, placement: 1),
            teamAward(roundID: "loss", teamID: "red", name: "Red", points: 0, placement: 2),
            teamAward(roundID: "loss", teamID: "blue", name: "Blue", points: 3, placement: 1),
            teamAward(roundID: "placement", teamID: "red", name: "Red", points: 5, placement: 1),
        ]

        let insight = SeriesTeamInsightBuilder.build(
            team: teams[0],
            standing: nil,
            teams: teams,
            members: [],
            rounds: rounds,
            pointAwards: awards,
            snapshotsBySeriesRoundID: [:]
        )

        XCTAssertEqual(insight.record, SeriesTeamRecord(wins: 1, losses: 1, ties: 1))
        XCTAssertEqual(insight.scheduleRows.map(\.outcomeLabel), ["Win", "Tie", "Loss", "#1", "Planned"])
        XCTAssertEqual(insight.scheduleRows.map(\.opponentName), ["Blue", "Blue", "Blue", "Field", "Field"])
    }

    func testTeamInsightUsesLinkedRoundMatchupBeforePlannedOpponent() {
        let teams = [
            SeriesTeam(id: "team2", name: "Team 2", color: "red", index: 1),
            SeriesTeam(id: "team4", name: "Team 4", color: "yellow", index: 3),
            SeriesTeam(id: "team6", name: "Team 6", color: "green", index: 5),
        ]
        let round = SeriesRound(
            id: "week2",
            title: "Week 2",
            index: 1,
            status: .complete,
            roundID: "linked_week2",
            roundConfig: SeriesRoundConfiguration(competitionScope: .matchup, matchupMode: .teamVsTeam),
            matchupPlans: [
                SeriesRoundMatchupPlan(id: "stale_plan", teamAID: "team4", teamBID: "team6", index: 0),
            ]
        )
        let awards = [
            teamAward(roundID: "week2", teamID: "team4", name: "Team 4", points: 1, placement: 1, roundOwnerID: "round_team4"),
            teamAward(roundID: "week2", teamID: "team2", name: "Team 2", points: 0, placement: 2, roundOwnerID: "round_team2"),
            teamAward(roundID: "week2", teamID: "team6", name: "Team 6", points: 1, placement: 1, roundOwnerID: "round_team6"),
        ]
        let snapshots = [
            "week2": RoundSnapshot(
                round: Round(id: "linked_week2", status: .complete),
                segments: [
                    RoundSegment(
                        id: "seg",
                        matchups: [
                            TeamMatchup(id: "actual_match", teamIDs: ["round_team2", "round_team4"], mode: .team),
                        ]
                    ),
                ]
            ),
        ]

        let insight = SeriesTeamInsightBuilder.build(
            team: teams[1],
            standing: nil,
            teams: teams,
            members: [],
            rounds: [round],
            pointAwards: awards,
            snapshotsBySeriesRoundID: snapshots
        )

        XCTAssertEqual(insight.scheduleRows.first?.opponentName, "Team 2")
        XCTAssertEqual(insight.scheduleRows.first?.outcomeLabel, "Win")
        XCTAssertEqual(insight.record, SeriesTeamRecord(wins: 1, losses: 0, ties: 0))
    }

    func testTeamInsightTreatsTieMetadataAsTieBeforeAwardPoints() {
        let teams = [
            SeriesTeam(id: "team4", name: "Team 4", color: "yellow", index: 3),
            SeriesTeam(id: "team6", name: "Team 6", color: "green", index: 5),
        ]
        let round = SeriesRound(
            id: "week3",
            title: "Week 3",
            index: 2,
            status: .complete,
            roundConfig: SeriesRoundConfiguration(competitionScope: .matchup, matchupMode: .teamVsTeam),
            matchupPlans: [
                SeriesRoundMatchupPlan(id: "match4", teamAID: "team4", teamBID: "team6", index: 0),
            ]
        )
        let awards = [
            teamAward(roundID: "week3", teamID: "team4", name: "Team 4", points: 0, placement: 1, tieGroupSize: 2),
            teamAward(roundID: "week3", teamID: "team6", name: "Team 6", points: 1, placement: 1, tieGroupSize: 2),
        ]

        let insight = SeriesTeamInsightBuilder.build(
            team: teams[0],
            standing: nil,
            teams: teams,
            members: [],
            rounds: [round],
            pointAwards: awards,
            snapshotsBySeriesRoundID: [:]
        )

        XCTAssertEqual(insight.scheduleRows.first?.opponentName, "Team 6")
        XCTAssertEqual(insight.scheduleRows.first?.outcomeLabel, "Tie")
        XCTAssertEqual(insight.scheduleRows.first?.outcomeKind, .tie)
        XCTAssertEqual(insight.record, SeriesTeamRecord(wins: 0, losses: 0, ties: 1))
    }

    func testTeamInsightUsesPointsFirstForAveragesAndTopContributor() {
        let team = SeriesTeam(id: "red", name: "Red", color: "red", index: 0)
        let members = [
            SeriesMember(id: "m1", name: Name("Ada", "Lovelace"), teamID: "red"),
            SeriesMember(id: "m2", name: Name("Grace", "Hopper"), teamID: "red"),
        ]
        let rounds = [
            SeriesRound(id: "r1", title: "One", index: 0, status: .complete),
            SeriesRound(id: "r2", title: "Two", index: 1, status: .complete),
        ]
        let awards = [
            teamAward(roundID: "r1", teamID: "red", name: "Red", points: 4, placement: 1),
            teamAward(roundID: "r2", teamID: "red", name: "Red", points: 2, placement: 2),
            individualAward(roundID: "r1", memberID: "m1", name: "Ada Lovelace", points: 3),
            individualAward(roundID: "r2", memberID: "m1", name: "Ada Lovelace", points: 1),
            individualAward(roundID: "r1", memberID: "m2", name: "Grace Hopper", points: 2),
        ]

        let insight = SeriesTeamInsightBuilder.build(
            team: team,
            standing: nil,
            teams: [team],
            members: members,
            rounds: rounds,
            pointAwards: awards,
            snapshotsBySeriesRoundID: [:]
        )

        XCTAssertEqual(insight.totalPoints, 6)
        XCTAssertEqual(insight.averagePoints, 3)
        XCTAssertEqual(insight.topContributorName, "Ada Lovelace")
        XCTAssertEqual(insight.topContributorDetail, "4 player pts")
        XCTAssertEqual(insight.playerPerformances.first { $0.memberID == "m1" }?.roundsPlayed, 2)
    }

    func testTeamInsightBuildsScoreAveragesBestScoresAndSpread() {
        let team = SeriesTeam(id: "red", name: "Red", color: "red", index: 0)
        let members = [
            SeriesMember(id: "m1", name: Name("Ada", "Lovelace"), teamID: "red"),
            SeriesMember(id: "m2", name: Name("Grace", "Hopper"), teamID: "red"),
        ]
        let rounds = [
            SeriesRound(id: "r1", title: "One", index: 0, status: .complete, roundID: "linked1"),
            SeriesRound(id: "r2", title: "Two", index: 1, status: .complete, roundID: "linked2"),
        ]
        let snapshots = [
            "r1": scoreSnapshot(roundID: "linked1", grossByMemberID: ["m1": 40, "m2": 45], members: members),
            "r2": scoreSnapshot(roundID: "linked2", grossByMemberID: ["m1": 37, "m2": 43], members: members),
        ]

        let insight = SeriesTeamInsightBuilder.build(
            team: team,
            standing: nil,
            teams: [team],
            members: members,
            rounds: rounds,
            pointAwards: [],
            snapshotsBySeriesRoundID: snapshots
        )

        XCTAssertEqual(insight.averageGrossScore ?? 0, 41.25, accuracy: 0.001)
        XCTAssertEqual(insight.scoreSpread ?? 0, 3.031, accuracy: 0.001)

        let ada = insight.playerPerformances.first { $0.memberID == "m1" }
        XCTAssertEqual(ada?.averageGross ?? 0, 38.5, accuracy: 0.001)
        XCTAssertEqual(ada?.bestGross, 37)
        XCTAssertEqual(ada?.trendLabel, "Gross -3 vs prev")
        XCTAssertEqual(ada?.trendKind, .improved)
    }

    func testRTJStyleTripDerivesSixHundredFortyAvailablePoints() {
        let teams = [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0, isLocked: true),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1, isLocked: true),
        ]
        let members = (0..<16).map { index in
            SeriesMember(
                id: "m\(index)",
                name: Name("Player", "\(index)"),
                teamID: index < 8 ? "red" : "blue",
                isActive: true
            )
        }
        var settings = SeriesSettings.seeded(for: .trip)
        settings.useTeams = true
        settings.useTeamStandings = true
        let series = Series(id: "series", name: "RTJ 2026", settings: settings)
        let teamWLT = SeriesScoringProfile(
            id: "team_wlt",
            outcomeSource: .roundMatchResult,
            competitorType: .team,
            kind: .winTieLoss,
            resultPoints: .init(winPoints: 40, tiePoints: 20, lossPoints: 0)
        )
        let singles = SeriesScoringProfile(
            id: "singles",
            outcomeSource: .roundMatchResult,
            competitorType: .member,
            kind: .winTieLoss,
            resultPoints: .init(winPoints: 1, tiePoints: 0.5, lossPoints: 0)
        )
        let accrue = SeriesScoringProfile(
            id: "accrue",
            outcomeSource: .individualAwardsAggregateToTeam,
            competitorType: .team,
            kind: .accrueFromIndividual
        )
        let rounds = [
            partnershipRound(id: "r1", index: 0, profileID: "team_wlt"),
            partnershipRound(id: "r2", index: 1, profileID: "team_wlt"),
            partnershipRound(id: "r3", index: 2, profileID: "team_wlt"),
            singlesRound(id: "r4", index: 3, teamProfileID: "accrue", individualProfileID: "singles"),
        ]

        let snapshot = SeriesScoreboardCalculator.snapshot(
            series: series,
            rounds: rounds,
            scoringProfiles: [teamWLT, singles, accrue],
            pointAwards: [],
            teams: teams,
            members: members
        )

        XCTAssertEqual(snapshot?.totalAvailablePoints, 640)
        XCTAssertEqual(snapshot?.winThreshold, 320.5)
        XCTAssertEqual(snapshot?.roundSummaries.map(\.availablePoints), [160, 160, 160, 160])
    }

    func testScoreboardDoesNotAssumeSixHundredFortyPoints() {
        let teams = [
            SeriesTeam(id: "a", name: "A", color: "red", index: 0),
            SeriesTeam(id: "b", name: "B", color: "blue", index: 1),
        ]
        var settings = SeriesSettings.seeded(for: .trip)
        settings.useTeams = true
        settings.useTeamStandings = true
        let series = Series(id: "series", name: "Weekend", settings: settings)
        let profile = SeriesScoringProfile(
            id: "profile",
            outcomeSource: .roundTeamLeaderboard,
            competitorType: .team,
            kind: .placement,
            placementRules: [
                .init(rankStart: 1, rankEnd: 1, points: 7),
                .init(rankStart: 2, rankEnd: 2, points: 3),
            ]
        )
        let rounds = [
            SeriesRound(id: "one", title: "One", index: 0, teamScoringProfileID: "profile"),
            SeriesRound(id: "two", title: "Two", index: 1, teamScoringProfileID: "profile"),
        ]

        let snapshot = SeriesScoreboardCalculator.snapshot(
            series: series,
            rounds: rounds,
            scoringProfiles: [profile],
            pointAwards: [],
            teams: teams,
            members: []
        )

        XCTAssertEqual(snapshot?.totalAvailablePoints, 20)
        XCTAssertEqual(snapshot?.winThreshold, 10.5)
    }

    func testSharedScoreScoringUnitsApplyAllowanceByHandicapRank() {
        let participants = [
            RoundParticipant(id: "low", name: Name("Low"), adjustedHandicap: 10, teamID: "red"),
            RoundParticipant(id: "high", name: Name("High"), adjustedHandicap: 20, teamID: "red"),
        ]
        let scoringGroups = [
            RoundScoringGroup(
                id: "pair",
                teamID: "red",
                teeGroupID: "g1",
                kind: .partnership,
                memberIDs: ["high", "low"]
            )
        ]
        let round = SeriesRound(
            id: "round",
            roundConfig: SeriesRoundConfiguration(
                formatTemplateID: FormatTemplateRegistry.captainsChoice.id,
                scoreOwnerScope: .partnership
            )
        )

        let units = SeriesRoundCreationMapping.buildScoringUnits(
            seriesRound: round,
            participants: participants,
            scoringGroups: scoringGroups
        )

        XCTAssertEqual(units.first?.handicapAdjustments?["low"], 3.5)
        XCTAssertEqual(units.first?.handicapAdjustments?["high"], 3.0)
    }

    func testMirroredTeeGroupMatchupsYieldOneHundredSixtyAvailablePoints() {
        let teams = [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1),
        ]
        let members = (0..<16).map { index in
            SeriesMember(
                id: "m\(index)",
                name: Name("Player", "\(index)"),
                teamID: index % 4 < 2 ? "red" : "blue",
                isActive: true
            )
        }
        var settings = SeriesSettings.seeded(for: .trip)
        settings.useTeams = true
        settings.useTeamStandings = true
        let series = Series(id: "series", settings: settings)
        let profile = SeriesScoringProfile(
            id: "team_wlt_40",
            outcomeSource: .roundMatchResult,
            competitorType: .team,
            kind: .winTieLoss,
            resultPoints: .init(winPoints: 40, tiePoints: 20, lossPoints: 0)
        )
        let round = mirroredRound(id: "mirror", profileID: profile.id)

        let snapshot = SeriesScoreboardCalculator.snapshot(
            series: series,
            rounds: [round],
            scoringProfiles: [profile],
            pointAwards: [],
            teams: teams,
            members: members
        )

        XCTAssertEqual(snapshot?.totalAvailablePoints, 160)
        XCTAssertEqual(snapshot?.roundSummaries.first?.availablePoints, 160)
    }

    func testMirroredTeeGroupMatchupsCountAvailablePointsWithoutPartnershipScoreEntry() {
        let teams = [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1),
        ]
        let members = (0..<16).map { index in
            SeriesMember(
                id: "m\(index)",
                name: Name("Player", "\(index)"),
                teamID: index % 4 < 2 ? "red" : "blue",
                isActive: true
            )
        }
        var settings = SeriesSettings.seeded(for: .trip)
        settings.useTeams = true
        settings.useTeamStandings = true
        let series = Series(id: "series", settings: settings)
        let profile = SeriesScoringProfile(
            id: "team_wlt_40",
            outcomeSource: .roundMatchResult,
            competitorType: .team,
            kind: .winTieLoss,
            resultPoints: .init(winPoints: 40, tiePoints: 20, lossPoints: 0)
        )
        let round = mirroredRound(id: "mirror_individual_entry", profileID: profile.id, scoreOwnerScope: .individual)

        let snapshot = SeriesScoreboardCalculator.snapshot(
            series: series,
            rounds: [round],
            scoringProfiles: [profile],
            pointAwards: [],
            teams: teams,
            members: members
        )

        XCTAssertEqual(snapshot?.totalAvailablePoints, 160)
        XCTAssertEqual(snapshot?.roundSummaries.first?.availablePoints, 160)
    }

    func testExplicitPairMatchupsDriveAvailablePoints() {
        let teams = [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1),
        ]
        let members = (0..<8).map { index in
            SeriesMember(
                id: "m\(index)",
                name: Name("Player", "\(index)"),
                teamID: index % 4 < 2 ? "red" : "blue",
                isActive: true
            )
        }
        var settings = SeriesSettings.seeded(for: .trip)
        settings.useTeams = true
        settings.useTeamStandings = true
        let series = Series(id: "series", settings: settings)
        let profile = SeriesScoringProfile(
            id: "team_wlt_40",
            outcomeSource: .roundMatchResult,
            competitorType: .team,
            kind: .winTieLoss,
            resultPoints: .init(winPoints: 40, tiePoints: 20, lossPoints: 0)
        )
        var round = mirroredRound(id: "explicit_pairs", profileID: profile.id)
        round.matchupPlans = [
            SeriesRoundMatchupPlan(id: "mx_1", pairAID: "g0_red", pairBID: "g1_blue", index: 0),
            SeriesRoundMatchupPlan(id: "mx_2", pairAID: "g1_red", pairBID: "g0_blue", index: 1),
        ]

        let snapshot = SeriesScoreboardCalculator.snapshot(
            series: series,
            rounds: [round],
            scoringProfiles: [profile],
            pointAwards: [],
            teams: teams,
            members: members
        )

        XCTAssertEqual(snapshot?.totalAvailablePoints, 80)
        XCTAssertEqual(snapshot?.roundSummaries.first?.availablePoints, 80)
    }

    func testConfidenceSummaryUsesRealTeeGroupNames() {
        let teams = [
            SeriesTeam(id: "red", name: "Red", color: "red", index: 0),
            SeriesTeam(id: "blue", name: "Blue", color: "blue", index: 1),
        ]
        let members = [
            SeriesMember(id: "andrew", name: Name("Andrew", "McCartney"), teamID: "red", isActive: true),
            SeriesMember(id: "chris", name: Name("Chris", "Robinson"), teamID: "red", isActive: true),
            SeriesMember(id: "henry", name: Name("Henry", "Scarlato"), teamID: "blue", isActive: true),
            SeriesMember(id: "justin", name: Name("Justin", "Allen"), teamID: "blue", isActive: true),
        ]
        let group = SeriesRoundPlannedTeeGroup(
            id: "g1",
            index: 0,
            seats: members.enumerated().map {
                SeriesRoundPlannedSeat(id: $0.element.id, memberID: $0.element.id, teeOrder: $0.offset + 1)
            }
        )
        let pairs = [
            SeriesRoundPartnershipPlan(id: "red_pair", teamID: "red", memberIDs: ["andrew", "chris"]),
            SeriesRoundPartnershipPlan(id: "blue_pair", teamID: "blue", memberIDs: ["henry", "justin"]),
        ]
        let profile = SeriesScoringProfile(
            id: "team_wlt_40",
            outcomeSource: .roundMatchResult,
            competitorType: .team,
            kind: .winTieLoss,
            resultPoints: .init(winPoints: 40, tiePoints: 20, lossPoints: 0)
        )

        let summary = SeriesRoundPointsConfidenceBuilder.summary(
            roundConfig: SeriesRoundConfiguration(
                competitionScope: .matchup,
                scoreOwnerScope: .partnership,
                matchupMode: .teeGroupPartnerships
            ),
            teamProfile: profile,
            individualProfile: nil,
            plannedTeeGroups: [group],
            partnershipPlans: pairs,
            members: members,
            teams: teams,
            courseSelection: nil
        )

        XCTAssertEqual(summary.example, "If Andrew + Chris beat Henry + Justin, Red earn 40 team points and Blue earn 0.")
    }

    func testIndividualStatsRowsSortByAverageDifferentialAndFallbackToGrossToPar() {
        let members = [
            SeriesMember(id: "alice", name: Name("Alice", "Able")),
            SeriesMember(id: "bob", name: Name("Bob", "Baker")),
            SeriesMember(id: "charlie", name: Name("Charlie", "Clear")),
        ]
        let rounds = [
            SeriesRound(id: "week1", status: .complete, roundID: "round1"),
            SeriesRound(id: "week2", status: .complete, roundID: "round2"),
            SeriesRound(id: "planned", status: .planned, roundID: "round3"),
        ]
        let scores = [
            handicapRoundScore(id: "alice1", memberID: "alice", roundID: "round1", score: 45, par: 36, rating: 34, slope: 113),
            handicapRoundScore(id: "alice2", memberID: "alice", roundID: "round2", score: 45, par: 36),
            handicapRoundScore(id: "bob1", memberID: "bob", roundID: "round1", score: 40, par: 36),
            handicapRoundScore(id: "ignored", memberID: "bob", roundID: "round3", score: 30, par: 36),
        ]
        let handicaps = [
            "alice": SeriesMemberHandicap(id: "alice", memberID: "alice", computedIndex: 8.2),
            "bob": SeriesMemberHandicap(id: "bob", memberID: "bob", computedIndex: 12.4, overrideIndex: 9.7, isOverridden: true),
        ]

        let rows = SeriesViewModel.individualStatsRows(
            members: members,
            handicapScores: scores,
            completedRounds: rounds.filter { $0.status == .complete },
            handicaps: handicaps
        )

        XCTAssertEqual(rows.map(\.memberID), ["bob", "alice", "charlie"])
        XCTAssertEqual(rows[0].averageDifferential, 4)
        XCTAssertEqual(rows[0].currentHandicap, 9.7)
        XCTAssertEqual(rows[0].roundsPlayed, 1)
        XCTAssertEqual(rows[1].averageDifferential, 10)
        XCTAssertEqual(rows[1].currentHandicap, 8.2)
        XCTAssertEqual(rows[1].roundsPlayed, 2)
        XCTAssertNil(rows[2].averageDifferential)
        XCTAssertEqual(rows[2].roundsPlayed, 0)
    }

    private func teamMatchupRound(id: String, index: Int) -> SeriesRound {
        SeriesRound(
            id: id,
            title: id.capitalized,
            index: index,
            status: .complete,
            roundConfig: SeriesRoundConfiguration(competitionScope: .matchup, matchupMode: .teamVsTeam),
            matchupPlans: [
                SeriesRoundMatchupPlan(id: "\(id)_match", teamAID: "red", teamBID: "blue", index: 0),
            ]
        )
    }

    private func teamAward(
        roundID: String,
        teamID: String,
        name: String,
        points: Double,
        placement: Int,
        roundOwnerID: String? = nil,
        tieGroupSize: Int? = nil
    ) -> SeriesPointAward {
        SeriesPointAward(
            id: "\(roundID)_team_\(teamID)",
            seriesRoundID: roundID,
            awardTrack: .team,
            competitorType: .team,
            competitorID: teamID,
            competitorName: name,
            placement: placement,
            tieGroupSize: tieGroupSize,
            totalPoints: points,
            roundOwnerID: roundOwnerID
        )
    }

    private func individualAward(
        roundID: String,
        memberID: String,
        name: String,
        points: Double
    ) -> SeriesPointAward {
        SeriesPointAward(
            id: "\(roundID)_individual_\(memberID)",
            seriesRoundID: roundID,
            awardTrack: .individual,
            competitorType: .member,
            competitorID: memberID,
            competitorName: name,
            placement: 1,
            totalPoints: points
        )
    }

    private func handicapRoundScore(
        id: String,
        memberID: String,
        roundID: String,
        score: Double,
        par: Double,
        rating: Double? = nil,
        slope: Int? = nil
    ) -> SeriesHandicapScore {
        SeriesHandicapScore(
            id: id,
            memberID: memberID,
            score: score,
            par: par,
            courseRating: rating,
            courseSlope: slope,
            source: .round,
            sourceRoundID: roundID
        )
    }

    private func scoreSnapshot(
        roundID: String,
        grossByMemberID: [String: Int],
        members: [SeriesMember]
    ) -> RoundSnapshot {
        let participants = members.map { member in
            RoundParticipant(
                id: "participant_\(member.id)",
                playerID: member.playerID,
                name: member.name,
                seriesMemberID: member.id,
                teamID: member.teamID
            )
        }
        let scoring = participants.compactMap { participant -> ScoreEntry? in
            guard let memberID = participant.seriesMemberID,
                  let gross = grossByMemberID[memberID] else { return nil }
            return ScoreEntry(
                id: "\(roundID)_\(participant.id)",
                holeNumber: 1,
                scoringUnitID: participant.id,
                participantIDs: [participant.id],
                strokes: gross
            )
        }

        return RoundSnapshot(
            round: Round(id: roundID, status: .complete),
            participants: participants,
            scoring: scoring
        )
    }

    private func partnershipRound(id: String, index: Int, profileID: String) -> SeriesRound {
        SeriesRound(
            id: id,
            title: id.uppercased(),
            index: index,
            roundConfig: SeriesRoundConfiguration(
                competitionScope: .matchup,
                scoreOwnerScope: .partnership,
                matchupMode: .teamVsTeam
            ),
            teamScoringProfileID: profileID,
            partnershipPlans: (0..<8).map { pairIndex in
                SeriesRoundPartnershipPlan(
                    id: "\(id)_p\(pairIndex)",
                    teamID: pairIndex < 4 ? "red" : "blue",
                    memberIDs: ["m\(pairIndex)", "m\(pairIndex + 8)"]
                )
            }
        )
    }

    private func mirroredRound(
        id: String,
        profileID: String,
        scoreOwnerScope: RoundScoreOwnerScope = .partnership
    ) -> SeriesRound {
        let groups = (0..<4).map { groupIndex in
            let start = groupIndex * 4
            return SeriesRoundPlannedTeeGroup(
                id: "g\(groupIndex)",
                index: groupIndex,
                seats: (0..<4).map { offset in
                    let memberID = "m\(start + offset)"
                    return SeriesRoundPlannedSeat(id: memberID, memberID: memberID, teeOrder: offset + 1)
                }
            )
        }
        let partnerships = (0..<4).flatMap { groupIndex in
            let start = groupIndex * 4
            return [
                SeriesRoundPartnershipPlan(id: "g\(groupIndex)_red", teamID: "red", memberIDs: ["m\(start)", "m\(start + 1)"]),
                SeriesRoundPartnershipPlan(id: "g\(groupIndex)_blue", teamID: "blue", memberIDs: ["m\(start + 2)", "m\(start + 3)"]),
            ]
        }
        return SeriesRound(
            id: id,
            title: id.uppercased(),
            index: 0,
            roundConfig: SeriesRoundConfiguration(
                competitionScope: .matchup,
                scoreOwnerScope: scoreOwnerScope,
                matchupMode: .teeGroupPartnerships
            ),
            teamScoringProfileID: profileID,
            plannedTeeGroups: groups,
            partnershipPlans: partnerships
        )
    }

    private func singlesRound(
        id: String,
        index: Int,
        teamProfileID: String,
        individualProfileID: String
    ) -> SeriesRound {
        SeriesRound(
            id: id,
            title: id.uppercased(),
            index: index,
            roundConfig: SeriesRoundConfiguration(
                competitionScope: .matchup,
                scoreOwnerScope: .individual,
                matchupScoringStyle: .holeByHolePoints,
                holeWinPoints: 1,
                matchWinnerBonusPoints: 2,
                matchupMode: .individualVsIndividual
            ),
            teamScoringProfileID: teamProfileID,
            individualScoringProfileID: individualProfileID
        )
    }
}
