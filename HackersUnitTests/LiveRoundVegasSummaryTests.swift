@testable import Hackers
import XCTest

@MainActor
final class LiveRoundVegasSummaryTests: XCTestCase {
    private let roundID = "vegas_live_round"
    private let groupID = "g1"
    private let segmentID = "seg1"

    private var courseSegment: CourseSegment {
        MockLiveRound2v2.round.configuration.courses.first!
    }

    private var teeBoxID: String {
        courseSegment.defaultTee ?? courseSegment.courseInfo.tees.first?.id ?? ""
    }

    private func makeParticipant(
        id: String,
        first: String,
        last: String,
        teamID: String,
        teeOrder: Int,
        handicap: Int = 0
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            playerID: "player_\(id)",
            name: Name(first, last),
            teeBoxID: teeBoxID,
            originalHandicap: handicap,
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID,
            teeOrder: teeOrder,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
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

    private func makeScore(participantID: String, holeNumber: Int, strokes: Int) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: participantID),
            holeNumber: holeNumber,
            segmentID: segmentID,
            groupID: groupID,
            scoringUnitID: participantID,
            participantIDs: [participantID],
            strokes: strokes,
            pickedUp: false,
            entryID: participantID,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private func makePartnership(id: String, teamID: String, members: [String]) -> RoundScoringGroup {
        RoundScoringGroup(
            id: id,
            teamID: teamID,
            teeGroupID: groupID,
            kind: .partnership,
            memberIDs: members,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private func makeVegasSnapshot(
        teams: [RoundTeam],
        participants: [RoundParticipant],
        scores: [ScoreEntry],
        scoringGroups: [RoundScoringGroup] = [],
        mode: RoundVegasMode = .exactPair,
        rule: RoundVegasSelectionRule = .best2,
        scope: AggregationScope = .perHole,
        basis: ScoreBasis = .gross
    ) -> RoundSnapshot {
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: basis,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false,
                    minPlayers: 4
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.vegas),
            courses: [courseSegment],
            competitionScope: .field,
            teamScoring: .init(),
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: .individual,
            matchupScoringStyle: .aggregateRoundTotal,
            vegasMode: mode,
            vegasSelectionRule: rule,
            vegasSelectionScope: scope
        )

        let round = Round(
            id: roundID,
            shareCode: "VEGAS1",
            createdBy: "host",
            status: .live,
            players: participants.compactMap(\.playerID),
            configuration: configuration,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )

        let teeGroup = TeeTimeGroup(
            id: groupID,
            index: 0,
            startingHole: 1,
            createdAt: .init(),
            parentID: roundID
        )

        let segment = RoundSegment(
            id: segmentID,
            roundID: roundID,
            holeRange: HoleRange(startHole: 1, endHole: 18),
            templateID: FormatTemplateRegistry.vegas.id,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )

        return RoundSnapshot(
            round: round,
            participants: participants,
            teams: teams,
            teeGroups: [teeGroup],
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: scores
        )
    }

    func testVegasSummaryAppearsOnlyForVegasAndSkipsLeaderboardChip() throws {
        let viewModel = LiveRoundViewModel()

        viewModel.set(snapshot: MockLiveRound2v2.snapshot)
        XCTAssertNil(viewModel.vegasLiveSummary)

        let teams = [
            makeTeam(id: "t1", name: "Team 1", color: "red", index: 0),
            makeTeam(id: "t2", name: "Team 2", color: "blue", index: 1)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Brooke", last: "Bennett", teamID: "t1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Casey", last: "Clark", teamID: "t2", teeOrder: 3),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t2", teeOrder: 4)
        ]
        let scores = [
            makeScore(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScore(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p4", holeNumber: 1, strokes: 6)
        ]

        viewModel.set(snapshot: makeVegasSnapshot(teams: teams, participants: participants, scores: scores))

        let summary = try XCTUnwrap(viewModel.vegasLiveSummary)
        XCTAssertEqual(summary.standings.map(\.total), [45, 56])
        XCTAssertEqual(summary.leaderText, "Team 1 leads by 11")
        XCTAssertEqual(viewModel.availableLeaderboardChips, [.strokes])
    }

    func testVegasSummaryRanksManyTeamsForSelectedPair() throws {
        let teams = [
            makeTeam(id: "t1", name: "Team 1", color: "red", index: 0),
            makeTeam(id: "t2", name: "Team 2", color: "blue", index: 1),
            makeTeam(id: "t3", name: "Team 3", color: "green", index: 2),
            makeTeam(id: "t4", name: "Team 4", color: "orange", index: 3)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Brooke", last: "Bennett", teamID: "t1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Cara", last: "Cole", teamID: "t1", teeOrder: 3),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t2", teeOrder: 4),
            makeParticipant(id: "p5", first: "Evan", last: "Ellis", teamID: "t2", teeOrder: 5),
            makeParticipant(id: "p6", first: "Finn", last: "Frost", teamID: "t2", teeOrder: 6),
            makeParticipant(id: "p7", first: "Gray", last: "Grant", teamID: "t3", teeOrder: 7),
            makeParticipant(id: "p8", first: "Harper", last: "Hughes", teamID: "t3", teeOrder: 8),
            makeParticipant(id: "p9", first: "Indy", last: "Irwin", teamID: "t3", teeOrder: 9),
            makeParticipant(id: "p10", first: "Jules", last: "James", teamID: "t4", teeOrder: 10),
            makeParticipant(id: "p11", first: "Kai", last: "Knight", teamID: "t4", teeOrder: 11),
            makeParticipant(id: "p12", first: "Lane", last: "Lewis", teamID: "t4", teeOrder: 12)
        ]
        let scores = [
            makeScore(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScore(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p3", holeNumber: 1, strokes: 7),
            makeScore(participantID: "p4", holeNumber: 1, strokes: 4),
            makeScore(participantID: "p5", holeNumber: 1, strokes: 6),
            makeScore(participantID: "p6", holeNumber: 1, strokes: 6),
            makeScore(participantID: "p7", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p8", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p9", holeNumber: 1, strokes: 7),
            makeScore(participantID: "p10", holeNumber: 1, strokes: 6),
            makeScore(participantID: "p11", holeNumber: 1, strokes: 6),
            makeScore(participantID: "p12", holeNumber: 1, strokes: 7)
        ]

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeVegasSnapshot(
            teams: teams,
            participants: participants,
            scores: scores,
            mode: .selectedPair,
            rule: .best2,
            scope: .perHole
        ))

        let summary = try XCTUnwrap(viewModel.vegasLiveSummary)
        XCTAssertEqual(summary.standings.map(\.teamName), ["Team 1", "Team 2", "Team 3", "Team 4"])
        XCTAssertEqual(summary.standings.map(\.total), [45, 46, 55, 66])
        XCTAssertEqual(summary.leaderText, "Team 1 leads by 1")
    }

    func testVegasSummaryIncludesPartnershipAggregateBreakdowns() throws {
        let teams = [
            makeTeam(id: "t1", name: "Team 1", color: "red", index: 0),
            makeTeam(id: "t2", name: "Team 2", color: "blue", index: 1)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Brooke", last: "Bennett", teamID: "t1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Cara", last: "Cole", teamID: "t1", teeOrder: 3),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t1", teeOrder: 4),
            makeParticipant(id: "p5", first: "Evan", last: "Ellis", teamID: "t2", teeOrder: 5),
            makeParticipant(id: "p6", first: "Finn", last: "Frost", teamID: "t2", teeOrder: 6),
            makeParticipant(id: "p7", first: "Gray", last: "Grant", teamID: "t2", teeOrder: 7),
            makeParticipant(id: "p8", first: "Harper", last: "Hughes", teamID: "t2", teeOrder: 8)
        ]
        let scoringGroups = [
            makePartnership(id: "pair1", teamID: "t1", members: ["p1", "p2"]),
            makePartnership(id: "pair2", teamID: "t1", members: ["p3", "p4"]),
            makePartnership(id: "pair3", teamID: "t2", members: ["p5", "p6"]),
            makePartnership(id: "pair4", teamID: "t2", members: ["p7", "p8"])
        ]
        let scores = [
            makeScore(participantID: "p1", holeNumber: 1, strokes: 4),
            makeScore(participantID: "p2", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p3", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p4", holeNumber: 1, strokes: 6),
            makeScore(participantID: "p5", holeNumber: 1, strokes: 4),
            makeScore(participantID: "p6", holeNumber: 1, strokes: 6),
            makeScore(participantID: "p7", holeNumber: 1, strokes: 5),
            makeScore(participantID: "p8", holeNumber: 1, strokes: 7)
        ]

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeVegasSnapshot(
            teams: teams,
            participants: participants,
            scores: scores,
            scoringGroups: scoringGroups,
            mode: .partnershipAggregate
        ))

        let summary = try XCTUnwrap(viewModel.vegasLiveSummary)
        let leader = try XCTUnwrap(summary.standings.first)

        XCTAssertEqual(summary.mode, .partnershipAggregate)
        XCTAssertEqual(summary.standings.map(\.total), [101, 103])
        XCTAssertEqual(summary.leaderText, "Team 1 leads by 2")
        XCTAssertEqual(leader.breakdowns.count, 2)
        XCTAssertEqual(leader.breakdowns.map(\.total).sorted(), [45, 56])
    }
}
