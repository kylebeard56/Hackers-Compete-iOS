@testable import Hackers
import XCTest

@MainActor
final class VegasRoundActivationTests: XCTestCase {
    private func makeParticipant(
        id: String,
        teamID: String,
        groupID: String? = "g1"
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            name: Name(id, "Player"),
            adjustedHandicap: 0,
            teamID: teamID,
            groupID: groupID
        )
    }

    private func makeVegasSession(
        participants: [RoundParticipant],
        teams: [RoundTeam],
        scoringGroups: [RoundScoringGroup] = [],
        mode: RoundVegasMode,
        includeTeeGroup: Bool = true
    ) -> RoundSession {
        let session = RoundSession()
        let round = Round(
            id: "round1",
            shareCode: "VEGAS",
            createdBy: "host",
            status: .lobby,
            players: [],
            configuration: RoundConfiguration(
                primaryFormat: GameFormat(
                    type: .strokePlay,
                    configuration: GameConfiguration(
                        method: .individual,
                        aggregation: nil,
                        basis: .gross,
                        handicap: .individualStrokePlay,
                        requiresTeams: true
                    )
                ),
                formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.vegas),
                courses: [],
                competitionScope: .field,
                teamScoring: .init(),
                matchupResolutionStyle: .roundAggregate,
                scoreOwnerScope: .individual,
                matchupScoringStyle: .aggregateRoundTotal,
                vegasMode: mode,
                vegasSelectionRule: .best2,
                vegasSelectionScope: .perHole
            )
        )
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            templateID: FormatTemplateRegistry.vegas.id
        )
        let teeGroups: [TeeTimeGroup] = includeTeeGroup ? [.init(id: "g1", index: 0, createdAt: .init())] : []
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

    private func makePartnership(id: String, teamID: String, members: [String]) -> RoundScoringGroup {
        RoundScoringGroup(
            id: id,
            teamID: teamID,
            teeGroupID: "g1",
            kind: .partnership,
            memberIDs: members,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "round1"
        )
    }

    func testVegasExactPairBlocksOversizedTeams() async {
        let participants = [
            makeParticipant(id: "p1", teamID: "t1"),
            makeParticipant(id: "p2", teamID: "t1"),
            makeParticipant(id: "p3", teamID: "t1"),
            makeParticipant(id: "p4", teamID: "t2"),
            makeParticipant(id: "p5", teamID: "t2"),
            makeParticipant(id: "p6", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init())
        ]
        let session = makeVegasSession(participants: participants, teams: teams, mode: .exactPair)

        let started = await session.activateLiveRound()
        XCTAssertFalse(started)
        XCTAssertTrue(session.roundActivationErrors.contains(.vegasConfigurationInvalid))
    }

    func testVegasPartnershipAggregateAcceptsValidPairCoverage() async {
        let participants = [
            makeParticipant(id: "p1", teamID: "t1", groupID: nil),
            makeParticipant(id: "p2", teamID: "t1"),
            makeParticipant(id: "p3", teamID: "t1"),
            makeParticipant(id: "p4", teamID: "t1"),
            makeParticipant(id: "p5", teamID: "t2"),
            makeParticipant(id: "p6", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init())
        ]
        let scoringGroups = [
            makePartnership(id: "pair1", teamID: "t1", members: ["p1", "p2"]),
            makePartnership(id: "pair2", teamID: "t1", members: ["p3", "p4"])
        ]
        let session = makeVegasSession(
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            mode: .partnershipAggregate
        )

        let started = await session.activateLiveRound()
        XCTAssertFalse(started)
        XCTAssertFalse(session.roundActivationErrors.contains(.vegasConfigurationInvalid))
        XCTAssertTrue(session.roundActivationErrors.contains(.playerMissingFromTeeGroup))
    }

    func testVegasSelectedPairAllowsOversizedTeamsWhenConfigured() async {
        let participants = [
            makeParticipant(id: "p1", teamID: "t1", groupID: nil),
            makeParticipant(id: "p2", teamID: "t1"),
            makeParticipant(id: "p3", teamID: "t1"),
            makeParticipant(id: "p4", teamID: "t2"),
            makeParticipant(id: "p5", teamID: "t2"),
            makeParticipant(id: "p6", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init())
        ]
        let session = makeVegasSession(participants: participants, teams: teams, mode: .selectedPair)

        let started = await session.activateLiveRound()
        XCTAssertFalse(started)
        XCTAssertFalse(session.roundActivationErrors.contains(.vegasConfigurationInvalid))
        XCTAssertTrue(session.roundActivationErrors.contains(.playerMissingFromTeeGroup))
    }
}
