@testable import Hackers
import XCTest

@MainActor
final class LiveRoundLeaderboardGroupingTests: XCTestCase {
    private let roundID = "leaderboard_grouping_round"
    private let segmentID = "leaderboard_grouping_segment"

    private var courseSegment: CourseSegment {
        MockLiveRound2v2.round.configuration.courses.first!
    }

    private var teeBoxID: String {
        courseSegment.defaultTee ?? courseSegment.courseInfo.tees.first?.id ?? ""
    }

    private func makeTeam(id: String, name: String, color: String, index: Int) -> RoundTeam {
        RoundTeam(
            id: id,
            name: name,
            color: color,
            index: index,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private func makeTeeGroup(id: String, index: Int) -> TeeTimeGroup {
        TeeTimeGroup(
            id: id,
            index: index,
            startingHole: 1,
            createdAt: .init(),
            parentID: roundID
        )
    }

    private func makeParticipant(
        id: String,
        first: String,
        last: String,
        teamID: String,
        groupID: String,
        teeOrder: Int
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            playerID: "player_\(id)",
            name: Name(first, last),
            teeBoxID: teeBoxID,
            originalHandicap: 0,
            adjustedHandicap: 0,
            teamID: teamID,
            groupID: groupID,
            teeOrder: teeOrder,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private func makePartnership(
        id: String,
        teamID: String,
        teeGroupID: String,
        members: [String]
    ) -> RoundScoringGroup {
        RoundScoringGroup(
            id: id,
            teamID: teamID,
            teeGroupID: teeGroupID,
            kind: .partnership,
            memberIDs: members,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private func makeSnapshot(
        scoreOwnerScope: RoundScoreOwnerScope,
        teams: [RoundTeam],
        teeGroups: [TeeTimeGroup],
        participants: [RoundParticipant],
        scoringGroups: [RoundScoringGroup] = []
    ) -> RoundSnapshot {
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .aggregate,
                    aggregation: .init(mode: .sumAll, scope: .perHole),
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false,
                    minPlayers: 2
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.captainsChoice),
            courses: [courseSegment],
            competitionScope: .field,
            teamScoring: .init(),
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: scoreOwnerScope,
            matchupScoringStyle: .aggregateRoundTotal
        )

        let round = Round(
            id: roundID,
            shareCode: "GROUPS",
            createdBy: "host",
            status: .live,
            players: participants.compactMap(\.playerID),
            configuration: configuration,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )

        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 18),
            templateID: FormatTemplateRegistry.captainsChoice.id,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: teams,
            teeGroups: teeGroups,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: []
        )
    }

    func testSharedPartnershipLeaderboardExposesPairTeamAndTeeGroupModes() {
        let teams = [
            makeTeam(id: "t1", name: "Red", color: "red", index: 0),
            makeTeam(id: "t2", name: "Blue", color: "blue", index: 1)
        ]
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0),
            makeTeeGroup(id: "g2", index: 1)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Bea", last: "Baker", teamID: "t1", groupID: "g1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Cara", last: "Cole", teamID: "t1", groupID: "g2", teeOrder: 3),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t1", groupID: "g2", teeOrder: 4),
            makeParticipant(id: "p5", first: "Evan", last: "Ellis", teamID: "t2", groupID: "g1", teeOrder: 5),
            makeParticipant(id: "p6", first: "Finn", last: "Frost", teamID: "t2", groupID: "g1", teeOrder: 6),
            makeParticipant(id: "p7", first: "Gray", last: "Grant", teamID: "t2", groupID: "g2", teeOrder: 7),
            makeParticipant(id: "p8", first: "Harper", last: "Hughes", teamID: "t2", groupID: "g2", teeOrder: 8)
        ]
        let scoringGroups = [
            makePartnership(id: "pair1", teamID: "t1", teeGroupID: "g1", members: ["p1", "p2"]),
            makePartnership(id: "pair2", teamID: "t1", teeGroupID: "g2", members: ["p3", "p4"]),
            makePartnership(id: "pair3", teamID: "t2", teeGroupID: "g1", members: ["p5", "p6"]),
            makePartnership(id: "pair4", teamID: "t2", teeGroupID: "g2", members: ["p7", "p8"])
        ]

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .partnership,
            teams: teams,
            teeGroups: teeGroups,
            participants: participants,
            scoringGroups: scoringGroups
        ))

        XCTAssertEqual(viewModel.leaderboardModeLabel(for: .individual), "Pairs")
        XCTAssertEqual(viewModel.availableLeaderboardModes, [.individual, .team, .teeGroup])
        XCTAssertEqual(viewModel.teamLeaderboardSections.map(\.rows.count), [2, 2])
        XCTAssertEqual(viewModel.teeGroupLeaderboardSections.map(\.rows.count), [2, 2])
    }

    func testSharedPartnershipLeaderboardHidesDuplicateTeeGroupModeWhenTeamsMirrorGroups() {
        let teams = [
            makeTeam(id: "t1", name: "Red", color: "red", index: 0),
            makeTeam(id: "t2", name: "Blue", color: "blue", index: 1)
        ]
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0),
            makeTeeGroup(id: "g2", index: 1)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Bea", last: "Baker", teamID: "t1", groupID: "g1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Cara", last: "Cole", teamID: "t1", groupID: "g1", teeOrder: 3),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t1", groupID: "g1", teeOrder: 4),
            makeParticipant(id: "p5", first: "Evan", last: "Ellis", teamID: "t2", groupID: "g2", teeOrder: 5),
            makeParticipant(id: "p6", first: "Finn", last: "Frost", teamID: "t2", groupID: "g2", teeOrder: 6),
            makeParticipant(id: "p7", first: "Gray", last: "Grant", teamID: "t2", groupID: "g2", teeOrder: 7),
            makeParticipant(id: "p8", first: "Harper", last: "Hughes", teamID: "t2", groupID: "g2", teeOrder: 8)
        ]
        let scoringGroups = [
            makePartnership(id: "pair1", teamID: "t1", teeGroupID: "g1", members: ["p1", "p2"]),
            makePartnership(id: "pair2", teamID: "t1", teeGroupID: "g1", members: ["p3", "p4"]),
            makePartnership(id: "pair3", teamID: "t2", teeGroupID: "g2", members: ["p5", "p6"]),
            makePartnership(id: "pair4", teamID: "t2", teeGroupID: "g2", members: ["p7", "p8"])
        ]

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .partnership,
            teams: teams,
            teeGroups: teeGroups,
            participants: participants,
            scoringGroups: scoringGroups
        ))

        XCTAssertEqual(viewModel.availableLeaderboardModes, [.individual, .team])
    }

    func testSharedTeamScoreUnitLeaderboardHidesRedundantGroupedModes() {
        let teams = [
            makeTeam(id: "t1", name: "Red", color: "red", index: 0),
            makeTeam(id: "t2", name: "Blue", color: "blue", index: 1)
        ]
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0),
            makeTeeGroup(id: "g2", index: 1)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Bea", last: "Baker", teamID: "t1", groupID: "g1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Cara", last: "Cole", teamID: "t2", groupID: "g2", teeOrder: 3),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t2", groupID: "g2", teeOrder: 4)
        ]

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .individual,
            teams: teams,
            teeGroups: teeGroups,
            participants: participants
        ))

        XCTAssertEqual(viewModel.leaderboardModeLabel(for: .individual), "Solo")
        XCTAssertEqual(viewModel.availableLeaderboardModes, [.individual])
    }
}
