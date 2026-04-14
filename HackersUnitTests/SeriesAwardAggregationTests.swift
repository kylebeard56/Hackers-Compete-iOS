@testable import Hackers
import XCTest

@MainActor
final class SeriesAwardAggregationTests: XCTestCase {

    private func makeMember(id: String, teamID: String?, name: String) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: "p_\(id)",
            name: Name(name, "Player"),
            teamID: teamID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )
    }

    private func makeTeam(id: String, name: String, index: Int) -> SeriesTeam {
        SeriesTeam(
            id: id,
            name: name,
            color: "red",
            index: index,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )
    }

    func testBuildAccruedTeamAwards_sumsIndividualPointsByTeamAndRanksDescending() {
        let profile = SeriesScoringProfile(
            id: "team_accrue",
            name: "Accrue from Individual",
            outcomeSource: .individualAwardsAggregateToTeam,
            competitorType: .team,
            kind: .accrueFromIndividual,
            parentID: "series1"
        )
        let awards = SeriesViewModel.buildAccruedTeamAwards(
            seriesRoundID: "round1",
            profile: profile,
            individualAwards: [
                SeriesPointAward(seriesRoundID: "round1", competitorID: "m1", totalPoints: 3),
                SeriesPointAward(seriesRoundID: "round1", competitorID: "m2", totalPoints: 0),
                SeriesPointAward(seriesRoundID: "round1", competitorID: "m3", totalPoints: 2),
                SeriesPointAward(seriesRoundID: "round1", competitorID: "m4", totalPoints: 2),
            ],
            members: [
                makeMember(id: "m1", teamID: "t1", name: "Alice"),
                makeMember(id: "m2", teamID: "t1", name: "Bob"),
                makeMember(id: "m3", teamID: "t2", name: "Charlie"),
                makeMember(id: "m4", teamID: "t2", name: "Dylan"),
            ],
            teams: [
                makeTeam(id: "t1", name: "Red", index: 0),
                makeTeam(id: "t2", name: "Blue", index: 1),
            ],
            seriesID: "series1",
            awardedByMemberID: "commissioner1"
        )

        XCTAssertEqual(awards.count, 2)
        XCTAssertEqual(awards[0].competitorID, "t2")
        XCTAssertEqual(awards[0].placement, 1)
        XCTAssertEqual(awards[0].totalPoints, 4)
        XCTAssertEqual(awards[1].competitorID, "t1")
        XCTAssertEqual(awards[1].placement, 2)
        XCTAssertEqual(awards[1].totalPoints, 3)
    }

    func testBuildAccruedTeamAwards_skipsPlayersWithoutTeams() {
        let profile = SeriesScoringProfile(
            id: "team_accrue",
            name: "Accrue from Individual",
            outcomeSource: .individualAwardsAggregateToTeam,
            competitorType: .team,
            kind: .accrueFromIndividual,
            parentID: "series1"
        )

        let awards = SeriesViewModel.buildAccruedTeamAwards(
            seriesRoundID: "round1",
            profile: profile,
            individualAwards: [
                SeriesPointAward(seriesRoundID: "round1", competitorID: "m1", totalPoints: 3),
                SeriesPointAward(seriesRoundID: "round1", competitorID: "m2", totalPoints: 1),
            ],
            members: [
                makeMember(id: "m1", teamID: "t1", name: "Alice"),
                makeMember(id: "m2", teamID: nil, name: "Bob"),
            ],
            teams: [makeTeam(id: "t1", name: "Red", index: 0)],
            seriesID: "series1",
            awardedByMemberID: "commissioner1"
        )

        XCTAssertEqual(awards.count, 1)
        XCTAssertEqual(awards[0].competitorID, "t1")
        XCTAssertEqual(awards[0].totalPoints, 3)
    }
}
