//
//  SeriesRoundHandicapAccrualTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class SeriesRoundHandicapAccrualTests: XCTestCase {

    func testSeriesRoundConfigurationDecodesHandicapDefaults() throws {
        let json = """
        {
          "format_template_id": "stroke_play",
          "team_scoring": {
            "mode": "all",
            "count": 1,
            "scope": "per_hole"
          },
          "matchup_resolution_style": "round_aggregate",
          "matchup_mode": "field",
          "pod_grouping_strategy": "disabled",
          "team_assignment_mode": "manual",
          "tee_group_mode": "auto",
          "allow_course_override": true,
          "allow_format_override": true,
          "allow_lobby_back_propagation": true
        }
        """

        let decoded = try JSONDecoder().decode(
            SeriesRoundConfiguration.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertTrue(decoded.countsTowardHandicapPool)
        XCTAssertEqual(decoded.normalizedExcludedHandicapMemberIDs, [])
    }

    func testSeriesRoundConfigurationNormalizesExcludedMemberIDs() {
        let config = SeriesRoundConfiguration(
            excludedHandicapMemberIDs: ["m2", "", "m1", "m2", "m3"]
        )

        XCTAssertEqual(config.normalizedExcludedHandicapMemberIDs, ["m1", "m2", "m3"])
    }

    func testTemplateHandicapAccrualEligibilityMatchesSupportedFormats() {
        XCTAssertTrue(FormatTemplateRegistry.strokePlay.supportsLeagueHandicapAccrual)
        XCTAssertTrue(FormatTemplateRegistry.stableford.supportsLeagueHandicapAccrual)
        XCTAssertTrue(FormatTemplateRegistry.strokePlayMatchupIndividual.supportsLeagueHandicapAccrual)
        XCTAssertFalse(FormatTemplateRegistry.matchPlayIndividual.supportsLeagueHandicapAccrual)
        XCTAssertFalse(FormatTemplateRegistry.alternateShot.supportsLeagueHandicapAccrual)
        XCTAssertFalse(FormatTemplateRegistry.captainsChoice.supportsLeagueHandicapAccrual)
    }

    @MainActor
    func testHandicapParticipationMembersUsesLinkedRoundPlayersWhenAvailable() {
        let viewModel = SeriesViewModel()
        viewModel.members = [
            makeMember(id: "m1", playerID: "p1", name: "Alice"),
            makeMember(id: "m2", playerID: "p2", name: "Bob"),
            makeMember(id: "m3", playerID: "p3", name: "Charlie", role: .spectator),
        ]

        let seriesRound = SeriesRound(
            id: "sr1",
            roundID: "round1",
            roundConfig: .init(),
            parentID: "series1"
        )
        viewModel.linkedRounds["round1"] = Round(
            id: "round1",
            players: ["p2"],
            configuration: .init(),
            createdAt: .init(),
            lastUpdatedAt: .init()
        )

        let resolvedMembers = viewModel.handicapParticipationMembers(for: seriesRound)
        XCTAssertEqual(resolvedMembers.map(\.id), ["m2"])
    }

    private func makeMember(
        id: String,
        playerID: String,
        name: String,
        role: SeriesMemberRole = .member
    ) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: playerID,
            name: Name(name, "Player"),
            role: role,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )
    }
}
