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

        XCTAssertEqual(summary.example, "Andrew + Chris shoot 71. Henry + Justin shoot 69. Blue wins 40.")
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
