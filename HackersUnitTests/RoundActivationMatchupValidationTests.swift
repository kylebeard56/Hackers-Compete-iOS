@testable import Hackers
import XCTest

@MainActor
final class RoundActivationMatchupValidationTests: XCTestCase {
    private func makeParticipant(
        id: String,
        teamID: String? = nil,
        groupID: String? = "g1",
        teeOrder: Int? = nil
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            name: Name(id, "Player"),
            adjustedHandicap: 0,
            teamID: teamID,
            groupID: groupID,
            teeOrder: teeOrder
        )
    }

    private func makeTeam(_ id: String, index: Int) -> RoundTeam {
        RoundTeam(
            id: id,
            name: "Team \(index + 1)",
            color: index == 0 ? "red" : "blue",
            index: index,
            createdAt: .init()
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
            parentID: "round1"
        )
    }

    private func makeSession(
        requiresTeams: Bool,
        scoreOwnerScope: RoundScoreOwnerScope = .individual,
        selectionDomain: ScoringSelectionDomain? = nil,
        participants: [RoundParticipant],
        teams: [RoundTeam],
        teeGroups: [TeeTimeGroup],
        scoringGroups: [RoundScoringGroup] = [],
        matchups: [TeamMatchup]
    ) -> RoundSession {
        let session = RoundSession()
        let round = Round(
            id: "round1",
            shareCode: "TEST",
            createdBy: "host",
            status: .lobby,
            players: [],
            configuration: RoundConfiguration(
                primaryFormat: GameFormat(
                    type: .strokePlay,
                    configuration: GameConfiguration(
                        method: requiresTeams ? .aggregate : .individual,
                        aggregation: requiresTeams ? .init(mode: .countBest, scope: .perHole, bestN: 1) : nil,
                        basis: .net,
                        handicap: .individualStrokePlay,
                        requiresTeams: requiresTeams
                    )
                ),
                formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlay),
                courses: [],
                competitionScope: .matchup,
                teamScoring: .init(mode: .bestN, count: 1, scope: .perHole),
                matchupResolutionStyle: .roundAggregate,
                scoreOwnerScope: scoreOwnerScope,
                matchupScoringStyle: .aggregateRoundTotal,
                selectionDomain: selectionDomain
            )
        )
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            matchups: matchups,
            competitionScope: .matchup
        )
        session.snapshot = RoundSnapshot(
            round: round,
            participants: participants,
            teams: teams,
            teeGroups: teeGroups,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: []
        )
        return session
    }

    func testActivationAcceptsExplicitPartnershipScoreOwnerMatchupsWithIndividualScoreOwners() async {
        let participants = [
            makeParticipant(id: "p1", teamID: "t1", groupID: "g1", teeOrder: 1),
            makeParticipant(id: "p2", teamID: "t1", groupID: "g1", teeOrder: 2),
            makeParticipant(id: "p3", teamID: "t2", groupID: "g1", teeOrder: 3),
            makeParticipant(id: "p4", teamID: "t2", groupID: "g1", teeOrder: 4),
            makeParticipant(id: "p5", teamID: "t1", groupID: "g2", teeOrder: 1),
            makeParticipant(id: "p6", teamID: "t1", groupID: "g2", teeOrder: 2),
            makeParticipant(id: "p7", teamID: "t2", groupID: "g2", teeOrder: 3),
            makeParticipant(id: "p8", teamID: "t2", groupID: "g2", teeOrder: 4),
            makeParticipant(id: "p9", teamID: "t1", groupID: nil)
        ]
        let scoringGroups = [
            makePartnership(id: "pair1", teamID: "t1", teeGroupID: "g1", members: ["p1", "p2"]),
            makePartnership(id: "pair2", teamID: "t2", teeGroupID: "g1", members: ["p3", "p4"]),
            makePartnership(id: "pair3", teamID: "t1", teeGroupID: "g2", members: ["p5", "p6"]),
            makePartnership(id: "pair4", teamID: "t2", teeGroupID: "g2", members: ["p7", "p8"])
        ]
        let matchups = [
            TeamMatchup(
                id: "m1",
                teamIDs: [],
                participantIDs: nil,
                scoreOwnerIDs: ["pair1", "pair2"],
                scoreOwnerScope: .partnership,
                mode: .scoreOwner
            ),
            TeamMatchup(
                id: "m2",
                teamIDs: [],
                participantIDs: nil,
                scoreOwnerIDs: ["pair3", "pair4"],
                scoreOwnerScope: .partnership,
                mode: .scoreOwner
            )
        ]
        let session = makeSession(
            requiresTeams: true,
            selectionDomain: .partnership,
            participants: participants,
            teams: [makeTeam("t1", index: 0), makeTeam("t2", index: 1)],
            teeGroups: [
                TeeTimeGroup(id: "g1", index: 0, createdAt: .init()),
                TeeTimeGroup(id: "g2", index: 1, createdAt: .init())
            ],
            scoringGroups: scoringGroups,
            matchups: matchups
        )

        let started = await session.activateLiveRound()

        XCTAssertFalse(started)
        XCTAssertEqual(session.snapshot.expectedMatchupMode, .scoreOwner)
        XCTAssertTrue(session.roundActivationErrors.contains(.playerMissingFromTeeGroup))
        XCTAssertFalse(session.roundActivationErrors.contains(.matchupsIncomplete))
        XCTAssertFalse(session.roundActivationErrors.contains(.matchupInvalidReferences))
        XCTAssertFalse(session.roundActivationErrors.contains(.scoringGroupsInvalidReferences))
    }

    func testActivationStillAcceptsTeamMatchupsForTeamRounds() async {
        let participants = [
            makeParticipant(id: "p1", teamID: "t1", groupID: "g1"),
            makeParticipant(id: "p2", teamID: "t2", groupID: "g1"),
            makeParticipant(id: "p3", teamID: "t1", groupID: nil)
        ]
        let session = makeSession(
            requiresTeams: true,
            participants: participants,
            teams: [makeTeam("t1", index: 0), makeTeam("t2", index: 1)],
            teeGroups: [TeeTimeGroup(id: "g1", index: 0, createdAt: .init())],
            matchups: [
                TeamMatchup(id: "m1", teamIDs: ["t1", "t2"], participantIDs: nil, mode: .team)
            ]
        )

        let started = await session.activateLiveRound()

        XCTAssertFalse(started)
        XCTAssertEqual(session.snapshot.expectedMatchupMode, .team)
        XCTAssertTrue(session.roundActivationErrors.contains(.playerMissingFromTeeGroup))
        XCTAssertFalse(session.roundActivationErrors.contains(.matchupsIncomplete))
        XCTAssertFalse(session.roundActivationErrors.contains(.matchupInvalidReferences))
    }

    func testActivationStillAcceptsIndividualMatchupsForIndividualRounds() async {
        let participants = [
            makeParticipant(id: "p1", groupID: "g1"),
            makeParticipant(id: "p2", groupID: "g1"),
            makeParticipant(id: "p3", groupID: nil)
        ]
        let session = makeSession(
            requiresTeams: false,
            participants: participants,
            teams: [],
            teeGroups: [TeeTimeGroup(id: "g1", index: 0, createdAt: .init())],
            matchups: [
                TeamMatchup(id: "m1", teamIDs: [], participantIDs: ["p1", "p2"], mode: .individual)
            ]
        )

        let started = await session.activateLiveRound()

        XCTAssertFalse(started)
        XCTAssertEqual(session.snapshot.expectedMatchupMode, .individual)
        XCTAssertTrue(session.roundActivationErrors.contains(.playerMissingFromTeeGroup))
        XCTAssertFalse(session.roundActivationErrors.contains(.matchupsIncomplete))
        XCTAssertFalse(session.roundActivationErrors.contains(.matchupInvalidReferences))
    }
}
