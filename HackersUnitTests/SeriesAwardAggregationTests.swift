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

    private func makeParticipant(id: String, memberID: String?, teamID: String, name: String) -> RoundParticipant {
        RoundParticipant(
            id: id,
            playerID: "p_\(memberID ?? id)",
            name: Name(name, "Player"),
            seriesMemberID: memberID,
            teamID: teamID,
            parentID: "round1"
        )
    }

    private func makeScoreEntry(participantID: String, holeNumber: Int, strokes: Int) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: "seg1", scoringUnit: participantID),
            holeNumber: holeNumber,
            segmentID: "seg1",
            scoringUnitID: participantID,
            participantIDs: [participantID],
            strokes: strokes,
            pickedUp: false,
            entryID: participantID,
            parentID: "round1"
        )
    }

    private func standingsSort(_ lhs: SeriesStanding, _ rhs: SeriesStanding) -> Bool {
        if lhs.totalPoints != rhs.totalPoints { return lhs.totalPoints > rhs.totalPoints }
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.bestPlacement != rhs.bestPlacement { return (lhs.bestPlacement ?? .max) < (rhs.bestPlacement ?? .max) }
        return lhs.competitorName < rhs.competitorName
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

    func testIndividualStandingsRebuildComputesOnlyIndividualRows() {
        let individualAwards = [
            SeriesPointAward(
                id: "round1_individual_m2",
                seriesRoundID: "round1",
                awardTrack: .individual,
                competitorType: .member,
                competitorID: "m2",
                competitorName: "Bailey",
                placement: 1,
                totalPoints: 8,
                parentID: "series1"
            ),
            SeriesPointAward(
                id: "round1_individual_m1",
                seriesRoundID: "round1",
                awardTrack: .individual,
                competitorType: .member,
                competitorID: "m1",
                competitorName: "Aaron",
                placement: 2,
                totalPoints: 7,
                parentID: "series1"
            ),
            SeriesPointAward(
                id: "round2_individual_m2",
                seriesRoundID: "round2",
                awardTrack: .individual,
                competitorType: .member,
                competitorID: "m2",
                competitorName: "Bailey",
                placement: 3,
                totalPoints: 6,
                parentID: "series1"
            ),
        ]

        let standings = SeriesViewModel.computedStandings(
            from: individualAwards,
            seriesID: "series1",
            sort: standingsSort
        )

        XCTAssertEqual(standings.count, 2)
        XCTAssertTrue(standings.allSatisfy { $0.awardTrack == .individual })
        XCTAssertEqual(standings.map(\.competitorID), ["m2", "m1"])
        XCTAssertEqual(standings.map(\.rank), [1, 2])
        XCTAssertEqual(standings.first?.totalPoints, 14)
        XCTAssertEqual(standings.first?.roundsCounted, 2)
        XCTAssertEqual(standings.first?.wins, 1)
        XCTAssertEqual(standings.first?.bestPlacement, 1)
    }

    func testIndividualPlacementAwardsUseParticipantScoresWhenTeamAggregateRowsAreTeamOwned() {
        let members = [
            makeMember(id: "m1", teamID: "t1", name: "Alice"),
            makeMember(id: "m2", teamID: "t2", name: "Bailey"),
            makeMember(id: "m3", teamID: "t2", name: "Charlie"),
        ]
        let participants = [
            makeParticipant(id: "p1", memberID: nil, teamID: "rt1", name: "Alice"),
            makeParticipant(id: "p2", memberID: "m2", teamID: "rt2", name: "Bailey"),
            makeParticipant(id: "p3", memberID: "m3", teamID: "rt2", name: "Charlie"),
        ]
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 2)
        )
        let round = Round(
            id: "round1",
            configuration: RoundConfiguration(
                primaryFormat: .strokePlay,
                teamScoring: .init(mode: .bestN, count: 1, scope: .perRound)
            )
        )
        let snapshot = RoundSnapshot(
            round: round,
            participants: participants,
            teams: [
                RoundTeam(id: "rt1", name: "Round Red", color: "red", index: 0, createdAt: .init(), parentID: "round1"),
                RoundTeam(id: "rt2", name: "Round Blue", color: "blue", index: 1, createdAt: .init(), parentID: "round1"),
            ],
            segments: [segment],
            scoring: [
                makeScoreEntry(participantID: "p1", holeNumber: 1, strokes: 4),
                makeScoreEntry(participantID: "p1", holeNumber: 2, strokes: 4),
                makeScoreEntry(participantID: "p2", holeNumber: 1, strokes: 5),
                makeScoreEntry(participantID: "p2", holeNumber: 2, strokes: 5),
            ]
        )
        let mainResult = SeriesViewModel.buildScoringResult(from: snapshot, segment: segment)
        XCTAssertTrue(mainResult.rows.allSatisfy { $0.owner == .team })

        let profile = SeriesScoringProfile(
            id: "individual_placement",
            name: "Individual Placement",
            outcomeSource: .roundIndividualLeaderboard,
            competitorType: .member,
            kind: .placement,
            placementRules: [
                .init(rankStart: 1, rankEnd: 1, points: 8),
                .init(rankStart: 2, rankEnd: 2, points: 7),
                .init(rankStart: 3, rankEnd: 3, points: 6),
            ],
            parentID: "series1"
        )
        let awards = SeriesViewModel.buildIndividualPlacementAwards(
            seriesRound: SeriesRound(id: "series_round1", roundID: "round1", parentID: "series1"),
            snapshot: snapshot,
            profile: profile,
            mappings: [
                SeriesRoundMapping(
                    id: "map_p1",
                    seriesRoundID: "series_round1",
                    roundOwnerType: .participant,
                    roundOwnerID: "p1",
                    competitorType: .member,
                    competitorID: "m1",
                    parentID: "series1"
                ),
            ],
            members: members,
            seriesID: "series1",
            awardedByMemberID: "commissioner1"
        )
        let standings = SeriesViewModel.computedStandings(
            from: awards,
            seriesID: "series1",
            sort: standingsSort
        )

        XCTAssertEqual(awards.map(\.competitorID), ["m1", "m2"])
        XCTAssertEqual(awards.map(\.placement), [1, 2])
        XCTAssertEqual(awards.map(\.totalPoints), [8, 7])
        XCTAssertFalse(awards.contains { $0.competitorID == "m3" })
        XCTAssertEqual(standings.map(\.competitorID), ["m1", "m2"])
        XCTAssertEqual(standings.map(\.rank), [1, 2])
    }

    func testIndividualStandingsRebuildLeavesExistingTeamRowsUnchanged() {
        let existingTeamStanding = SeriesStanding(
            id: SeriesStanding.standingID(for: .team, competitorID: "t1"),
            awardTrack: .team,
            competitorType: .team,
            competitorID: "t1",
            competitorName: "Team One",
            totalPoints: 3,
            roundsCounted: 2,
            wins: 2,
            topThrees: 2,
            lastPlacement: 1,
            bestPlacement: 1,
            rank: 1,
            parentID: "series1"
        )
        let individualAwards = [
            SeriesPointAward(
                id: "round1_individual_m1",
                seriesRoundID: "round1",
                awardTrack: .individual,
                competitorType: .member,
                competitorID: "m1",
                competitorName: "Aaron",
                placement: 1,
                totalPoints: 8,
                parentID: "series1"
            ),
        ]

        let rebuiltIndividualStandings = SeriesViewModel.computedStandings(
            from: individualAwards,
            seriesID: "series1",
            sort: standingsSort
        )
        let mergedStandings = [existingTeamStanding] + rebuiltIndividualStandings
        let teamStanding = mergedStandings.first { $0.awardTrack == .team }

        XCTAssertTrue(rebuiltIndividualStandings.allSatisfy { $0.awardTrack == .individual })
        XCTAssertNotNil(teamStanding)
        XCTAssertEqual(teamStanding?.id, existingTeamStanding.id)
        XCTAssertEqual(teamStanding?.competitorID, existingTeamStanding.competitorID)
        XCTAssertEqual(teamStanding?.competitorName, existingTeamStanding.competitorName)
        XCTAssertEqual(teamStanding?.totalPoints, existingTeamStanding.totalPoints)
        XCTAssertEqual(teamStanding?.roundsCounted, existingTeamStanding.roundsCounted)
        XCTAssertEqual(teamStanding?.wins, existingTeamStanding.wins)
        XCTAssertEqual(teamStanding?.topThrees, existingTeamStanding.topThrees)
        XCTAssertEqual(teamStanding?.lastPlacement, existingTeamStanding.lastPlacement)
        XCTAssertEqual(teamStanding?.bestPlacement, existingTeamStanding.bestPlacement)
        XCTAssertEqual(teamStanding?.rank, existingTeamStanding.rank)
    }

    func testTeamAndIndividualStandingsStayIsolatedWhenTeamWinnerDiffersFromIndividualWinner() {
        let teamAwards = [
            SeriesPointAward(
                id: "round1_team_t1",
                seriesRoundID: "round1",
                awardTrack: .team,
                competitorType: .team,
                competitorID: "t1",
                competitorName: "Team One",
                profileKind: .winTieLoss,
                placement: 1,
                totalPoints: 1,
                parentID: "series1"
            ),
            SeriesPointAward(
                id: "round1_team_t2",
                seriesRoundID: "round1",
                awardTrack: .team,
                competitorType: .team,
                competitorID: "t2",
                competitorName: "Team Two",
                profileKind: .winTieLoss,
                placement: 2,
                totalPoints: 0,
                parentID: "series1"
            ),
        ]
        let individualAwards = [
            SeriesPointAward(
                id: "round1_individual_m2",
                seriesRoundID: "round1",
                awardTrack: .individual,
                competitorType: .member,
                competitorID: "m2",
                competitorName: "Player On Team Two",
                placement: 1,
                totalPoints: 8,
                parentID: "series1"
            ),
            SeriesPointAward(
                id: "round1_individual_m1",
                seriesRoundID: "round1",
                awardTrack: .individual,
                competitorType: .member,
                competitorID: "m1",
                competitorName: "Player On Team One",
                placement: 2,
                totalPoints: 7,
                parentID: "series1"
            ),
        ]

        let standings = SeriesViewModel.computedStandings(
            from: teamAwards + individualAwards,
            seriesID: "series1",
            sort: standingsSort
        )
        let teamStandings = standings.filter { $0.awardTrack == .team }
        let individualStandings = standings.filter { $0.awardTrack == .individual }

        XCTAssertEqual(teamStandings.first?.competitorID, "t1")
        XCTAssertEqual(teamStandings.first?.totalPoints, 1)
        XCTAssertEqual(individualStandings.first?.competitorID, "m2")
        XCTAssertEqual(individualStandings.first?.totalPoints, 8)
    }
}
