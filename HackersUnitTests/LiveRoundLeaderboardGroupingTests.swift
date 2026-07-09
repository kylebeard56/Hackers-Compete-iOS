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
        scoringGroups: [RoundScoringGroup] = [],
        scoring: [ScoreEntry] = [],
        template: GameTemplate = FormatTemplateRegistry.captainsChoice,
        gameConfiguration: GameConfiguration? = nil,
        teamScoring: RoundTeamScoringConfiguration = .init()
    ) -> RoundSnapshot {
        let resolvedGameConfiguration = gameConfiguration ?? GameConfiguration(
            method: .aggregate,
            aggregation: .init(mode: .sumAll, scope: .perHole),
            basis: .gross,
            handicap: .individualStrokePlay,
            requiresTeams: true,
            teeGroupOnly: false,
            minPlayers: 2
        )
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: resolvedGameConfiguration
            ),
            formatSummary: RoundFormatSummary(from: template),
            courses: [courseSegment],
            competitionScope: .field,
            teamScoring: teamScoring,
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
            templateID: template.id,
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
            scoring: scoring
        )
    }

    private func makeScore(participantID: String, holeNumber: Int, strokes: Int) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: holeNumber, segment: segmentID, scoringUnit: participantID),
            holeNumber: holeNumber,
            segmentID: segmentID,
            scoringUnitID: participantID,
            participantIDs: [participantID],
            strokes: strokes,
            pickedUp: false,
            entryID: participantID,
            parentID: roundID
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

    func testDisplayLeaderboardRowsCanHideScorelessRowsAndAverageUsesScoredRows() {
        let teams = [
            makeTeam(id: "t1", name: "Red", color: "red", index: 0)
        ]
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Bea", last: "Baker", teamID: "t1", groupID: "g1", teeOrder: 2)
        ]
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .individual,
            teams: teams,
            teeGroups: teeGroups,
            participants: participants,
            scoring: [makeScore(participantID: "p1", holeNumber: 1, strokes: 5)],
            template: FormatTemplateRegistry.strokePlay,
            gameConfiguration: .strokePlay
        ))

        XCTAssertEqual(viewModel.displayLeaderboardRows.map(\.id), ["p2", "p1"])

        viewModel.showScorelessLeaderboardRows = false

        XCTAssertEqual(viewModel.displayLeaderboardRows.map(\.id), ["p1"])
        XCTAssertEqual(viewModel.rowsEligibleForAverageDisplay.map(\.id), ["p1"])
        XCTAssertEqual(viewModel.averageForDisplay(rows: viewModel.rowsEligibleForAverageDisplay) ?? .nan, 1, accuracy: 0.01)
    }

    func testEngineLeaderboardRowsRecomputeImmediatelyWhenScoreBasisChanges() {
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "", groupID: "g1", teeOrder: 1, handicap: 18),
            makeParticipant(id: "p2", first: "Bea", last: "Baker", teamID: "", groupID: "g1", teeOrder: 2)
        ]
        let par = courseSegment.tee(from: teeBoxID)?.holes.first(where: { $0.number == 1 })?.par ?? 4
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .individual,
            teams: [],
            teeGroups: teeGroups,
            participants: participants,
            scoring: [
                makeScore(participantID: "p1", holeNumber: 1, strokes: par),
                makeScore(participantID: "p2", holeNumber: 1, strokes: par)
            ],
            template: FormatTemplateRegistry.stableford,
            gameConfiguration: GameConfiguration(
                method: .individual,
                basis: .net,
                handicap: .individualStrokePlay,
                requiresTeams: false
            )
        ))
        viewModel.selectedLeaderboardChip = .stableford
        viewModel.scoreBasis = .gross

        let grossRows = Dictionary(uniqueKeysWithValues: viewModel.effectiveLeaderboardRows.map { ($0.id, $0) })

        viewModel.scoreBasis = .net
        let netRows = Dictionary(uniqueKeysWithValues: viewModel.effectiveLeaderboardRows.map { ($0.id, $0) })

        XCTAssertEqual(grossRows["p1"]?.totalPoints, 2)
        XCTAssertEqual(netRows["p1"]?.totalPoints, 3)
        XCTAssertEqual(netRows["p2"]?.totalPoints, 2)
    }

    func testStablefordSoloDisplayShowsIndividualPointContributionsInTeamRound() {
        let teams = [
            makeTeam(id: "t1", name: "Red", color: "red", index: 0),
            makeTeam(id: "t2", name: "Blue", color: "blue", index: 1)
        ]
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0)
        ]
        let participants = [
            makeParticipant(id: "p1", first: "Alice", last: "Adams", teamID: "t1", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "p2", first: "Bea", last: "Baker", teamID: "t1", groupID: "g1", teeOrder: 2),
            makeParticipant(id: "p3", first: "Cara", last: "Cole", teamID: "t2", groupID: "g1", teeOrder: 3, handicap: 18),
            makeParticipant(id: "p4", first: "Drew", last: "Diaz", teamID: "t2", groupID: "g1", teeOrder: 4, handicap: 18),
            makeParticipant(id: "p5", first: "Evan", last: "Ellis", teamID: "t2", groupID: "g1", teeOrder: 5)
        ]
        let par = courseSegment.tee(from: teeBoxID)?.holes.first(where: { $0.number == 1 })?.par ?? 4
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .individual,
            teams: teams,
            teeGroups: teeGroups,
            participants: participants,
            scoring: [
                makeScore(participantID: "p1", holeNumber: 1, strokes: par - 1),
                makeScore(participantID: "p2", holeNumber: 1, strokes: par),
                makeScore(participantID: "p3", holeNumber: 1, strokes: par + 1),
                makeScore(participantID: "p4", holeNumber: 1, strokes: par + 2)
            ],
            template: FormatTemplateRegistry.stableford,
            gameConfiguration: GameConfiguration(
                method: .aggregate,
                basis: .gross,
                handicap: .individualStrokePlay,
                requiresTeams: true
            ),
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 1, scope: .perHole)
        ))

        viewModel.selectedLeaderboardChip = .stableford
        viewModel.leaderboardMode = .individual

        XCTAssertEqual(viewModel.effectiveLeaderboardRows.map(\.id), ["t1", "t2"])
        XCTAssertEqual(viewModel.displayLeaderboardRows.map(\.id), ["p1", "p2", "p3", "p4", "p5"])
        XCTAssertEqual(viewModel.displayLeaderboardRows.map(\.totalPoints), [3.0, 2.0, 1.0, 0.0, 0.0])
        XCTAssertEqual(viewModel.displayLeaderboardRows.map(\.thru), [1, 1, 1, 1, 0])

        viewModel.scoreBasis = .net

        let netRowsByID = Dictionary(uniqueKeysWithValues: viewModel.displayLeaderboardRows.map { ($0.id, $0) })
        XCTAssertEqual(netRowsByID["p1"]?.totalPoints, 3)
        XCTAssertEqual(netRowsByID["p2"]?.totalPoints, 2)
        XCTAssertEqual(netRowsByID["p3"]?.totalPoints, 2)
        XCTAssertEqual(netRowsByID["p4"]?.totalPoints, 1)
        XCTAssertEqual(netRowsByID["p5"]?.totalPoints, 0)
        XCTAssertEqual(netRowsByID["p4"]?.thru, 1)
    }

    func testScoringParticipantsFollowTeeGroupScoringRowOrderAcrossTeams() {
        let teams = [
            makeTeam(id: "t1", name: "Red", color: "red", index: 0),
            makeTeam(id: "t2", name: "Blue", color: "blue", index: 1)
        ]
        let teeGroups = [
            makeTeeGroup(id: "g1", index: 0)
        ]
        let participants = [
            makeParticipant(id: "mike", first: "Mike", last: "Arnett", teamID: "t2", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "kyle", first: "Kyle", last: "Beard", teamID: "t1", groupID: "g1", teeOrder: 2),
            makeParticipant(id: "andrew", first: "Andrew", last: "McCartney", teamID: "t1", groupID: "g1", teeOrder: 3)
        ]
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeSnapshot(
            scoreOwnerScope: .individual,
            teams: teams,
            teeGroups: teeGroups,
            participants: participants
        ))
        let session = ScoringSession(
            participant: participants[0],
            participants: participants,
            holeNumber: 1
        )

        XCTAssertEqual(viewModel.teeGroupTeamSections.flatMap(\.participants).map(\.id), ["mike", "kyle", "andrew"])
        XCTAssertEqual(viewModel.scoringParticipants(for: session).map(\.id), ["mike", "kyle", "andrew"])
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
