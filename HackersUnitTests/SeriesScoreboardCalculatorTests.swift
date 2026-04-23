@testable import Hackers
import XCTest

final class SeriesScoreboardCalculatorTests: XCTestCase {
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
