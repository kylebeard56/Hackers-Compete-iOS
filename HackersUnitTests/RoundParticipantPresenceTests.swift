//
//  RoundParticipantPresenceTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class RoundParticipantPresenceTests: XCTestCase {

    func testRoundParticipantDefaultsMissingPresenceStatusToActive() throws {
        let json = """
        {
          "id": "participant1",
          "user_id": "user1",
          "player_id": "player1",
          "name": {
            "given_name": "Alice",
            "family_name": "Player"
          },
          "tee_box_id": "tee_white",
          "original_handicap": 12,
          "adjusted_handicap": 12,
          "is_host": false,
          "created_at": {
            "iso": "2023-11-15T12:00:00Z",
            "unix": 1700000000
          },
          "last_updated_at": {
            "iso": "2023-11-15T12:00:00Z",
            "unix": 1700000000
          },
          "parent_id": "round1",
          "schema": 1
        }
        """

        let participant = try JSONDecoder().decode(
            RoundParticipant.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertNil(participant.presenceStatus)
        XCTAssertEqual(participant.resolvedPresenceStatus, .active)
        XCTAssertTrue(participant.isPresenceActive)
    }

    @MainActor
    func testLiveRoundPresenceStatusIsIgnoredWhenAttendanceConfirmationIsDisabled() async {
        let participant = RoundParticipant(
            id: "participant1",
            playerID: "player1",
            name: Name("Alice", "Player"),
            presenceStatus: .noShow,
            parentID: "round1"
        )
        var configuration = RoundConfiguration()
        configuration.attendanceConfirmationEnabled = false
        let viewModel = await boundLiveRoundViewModel(
            snapshot: RoundSnapshot(
                round: Round(id: "round1", configuration: configuration),
                participants: [participant]
            ),
            participantID: participant.id
        )

        XCTAssertEqual(viewModel.effectivePresenceStatus(for: participant), .active)
        XCTAssertTrue(viewModel.isPresenceActive(participant))
        XCTAssertFalse(viewModel.canEditPresence(participant: participant))
    }

    @MainActor
    func testLiveRoundPresenceStatusAppliesWhenAttendanceConfirmationIsEnabled() async {
        let participant = RoundParticipant(
            id: "participant1",
            playerID: "player1",
            name: Name("Alice", "Player"),
            presenceStatus: .noShow,
            parentID: "round1"
        )
        var configuration = RoundConfiguration()
        configuration.attendanceConfirmationEnabled = true
        let viewModel = await boundLiveRoundViewModel(
            snapshot: RoundSnapshot(
                round: Round(id: "round1", configuration: configuration),
                participants: [participant]
            ),
            participantID: participant.id
        )

        XCTAssertEqual(viewModel.effectivePresenceStatus(for: participant), .noShow)
        XCTAssertFalse(viewModel.isPresenceActive(participant))
    }

    @MainActor
    private func boundLiveRoundViewModel(
        snapshot: RoundSnapshot,
        participantID: String
    ) async -> LiveRoundViewModel {
        let appSession = AppSession()
        appSession.ephemeralParticipantID = participantID

        let roundSession = RoundSession()
        roundSession.snapshot = snapshot

        let viewModel = LiveRoundViewModel()
        viewModel.bind(appSession: appSession, roundSession: roundSession)
        await viewModel.ensureParticipantResolved()
        await Task.yield()
        return viewModel
    }
}
