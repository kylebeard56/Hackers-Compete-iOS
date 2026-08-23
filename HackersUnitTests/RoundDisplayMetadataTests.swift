//
//  RoundDisplayMetadataTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class RoundDisplayMetadataTests: XCTestCase {
    private let createdAt = Time(iso: "2026-06-01T12:00:00Z", unix: 1_748_780_000)
    private let updatedAt = Time(iso: "2026-06-29T12:00:00Z", unix: 1_751_199_200)
    private let firstScoredAt = Time(iso: "2026-06-24T12:00:00Z", unix: 1_750_767_200)

    func testRoundNameNormalizationTrimsCapsAndClearsEmptyValues() {
        XCTAssertEqual(Round.normalizedName("  Off Round  "), "Off Round")
        XCTAssertNil(Round.normalizedName("   "))

        let longName = String(repeating: "A", count: Round.nameCharacterLimit + 8)
        XCTAssertEqual(Round.normalizedName(longName)?.count, Round.nameCharacterLimit)
    }

    func testRoundCodableDefaultsNewOptionalMetadataWhenAbsent() throws {
        let round = Round(
            id: "round1",
            shareCode: "ABCD",
            createdBy: "user1",
            status: .complete,
            players: ["player1"],
            configuration: .init(),
            createdAt: createdAt,
            lastUpdatedAt: updatedAt
        )

        let data = try JSONEncoder().encode(round)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "name")
        object.removeValue(forKey: "first_scored_at")
        object.removeValue(forKey: "tee_group_display_names_by_player_id")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(Round.self, from: legacyData)

        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.firstScoredAt)
        XCTAssertEqual(decoded.teeGroupDisplayNamesByPlayerID, [:])
    }

    func testRoundDisplayDatePrefersFirstScoredAt() {
        let round = Round(
            firstScoredAt: firstScoredAt,
            createdAt: createdAt,
            lastUpdatedAt: updatedAt
        )

        XCTAssertEqual(round.displayDate, firstScoredAt)
    }

    func testTeeGroupDisplayNamesUseFirstNameAndLastInitial() {
        let participants = [
            RoundParticipant(id: "p1", playerID: "player1", name: Name("Sam", "Watson"), groupID: "g1", teeOrder: 1),
            RoundParticipant(id: "p2", playerID: "player2", name: Name("Andrew", "Miller"), groupID: "g1", teeOrder: 2),
            RoundParticipant(id: "p3", playerID: "player3", name: Name("Jason", "King"), groupID: "g1", teeOrder: 3),
            RoundParticipant(id: "p4", playerID: "player4", name: Name("Solo", "Player"), groupID: "g2", teeOrder: 1),
        ]

        let summaries = Round.teeGroupDisplayNamesByPlayerID(from: participants)

        XCTAssertEqual(summaries["player1"], ["Andrew M", "Jason K"])
        XCTAssertEqual(summaries["player2"], ["Sam W", "Jason K"])
        XCTAssertNil(summaries["player4"])
    }

    func testTeeGroupLineCandidatesIncludeCompactFallbacks() {
        let round = Round(
            teeGroupDisplayNamesByPlayerID: [
                "player1": ["Sam W", "Andrew M", "Jason K"]
            ]
        )

        XCTAssertEqual(
            round.teeGroupLineCandidates(for: "player1"),
            [
                "With Sam W, Andrew M, Jason K",
                "With Sam W, Andrew M, +1",
                "With Sam W, +2",
            ]
        )
    }

    func testRoundPartnershipEligibilityAllowsNoTeamLobbyPairs() {
        let sam = participant("p1", groupID: "g1")
        let andrew = participant("p2", groupID: "g1")
        let snapshot = snapshot(participants: [sam, andrew])

        XCTAssertFalse(snapshot.roundPartnershipsRequireTeamAssignment)
        XCTAssertTrue(snapshot.canCreateRoundPartnership(between: sam, and: andrew))
    }

    func testRoundPartnershipEligibilityRequiresConcreteSameTeamWhenTeamsExist() {
        let sam = participant("p1", groupID: "g1", teamID: "team1")
        let andrew = participant("p2", groupID: "g1", teamID: "team1")
        let unassigned = participant("p3", groupID: "g1")
        let snapshot = snapshot(participants: [sam, andrew, unassigned], teams: [team("team1")])

        XCTAssertTrue(snapshot.roundPartnershipsRequireTeamAssignment)
        XCTAssertTrue(snapshot.canCreateRoundPartnership(between: sam, and: andrew))
        XCTAssertFalse(snapshot.canCreateRoundPartnership(between: sam, and: unassigned))
    }

    func testRoundPartnershipEligibilityRejectsDifferentTeams() {
        let sam = participant("p1", groupID: "g1", teamID: "team1")
        let andrew = participant("p2", groupID: "g1", teamID: "team2")
        let snapshot = snapshot(participants: [sam, andrew], teams: [team("team1"), team("team2")])

        XCTAssertFalse(snapshot.canCreateRoundPartnership(between: sam, and: andrew))
    }

    private func snapshot(
        participants: [RoundParticipant],
        teams: [RoundTeam] = [],
        requiresTeams: Bool = false
    ) -> RoundSnapshot {
        var format = GameFormat.strokePlay
        format.configuration.requiresTeams = requiresTeams
        return RoundSnapshot(
            round: Round(configuration: RoundConfiguration(primaryFormat: format)),
            participants: participants,
            teams: teams
        )
    }

    private func participant(_ id: String, groupID: String, teamID: String? = nil) -> RoundParticipant {
        RoundParticipant(
            id: id,
            playerID: id,
            name: Name(id.capitalized, "Player"),
            teamID: teamID,
            groupID: groupID
        )
    }

    private func team(_ id: String) -> RoundTeam {
        RoundTeam(
            id: id,
            name: id.capitalized,
            color: TeamColor.none.rawValue,
            index: 1,
            createdAt: createdAt
        )
    }
}
