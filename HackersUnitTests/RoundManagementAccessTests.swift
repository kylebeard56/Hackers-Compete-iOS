import XCTest
@testable import Hackers

final class RoundManagementAccessTests: XCTestCase {
    func testStandaloneHostIsRoundManagerAndCanTransferHost() {
        let access = RoundManagementAccess.resolve(
            snapshot: snapshot(),
            currentUserID: "host-user",
            currentPlayerID: nil
        )

        XCTAssertTrue(access.isHost)
        XCTAssertTrue(access.canManageRound)
        XCTAssertTrue(access.canTransferHost)
        XCTAssertTrue(access.canArchiveOrDelete)
    }

    func testPrimaryCommissionerIsManagerWithoutHostFlag() {
        let access = RoundManagementAccess.resolve(
            snapshot: snapshot(),
            currentUserID: "primary-commissioner",
            currentPlayerID: nil,
            series: Series(commissionerUserID: "primary-commissioner")
        )

        XCTAssertFalse(access.isHost)
        XCTAssertTrue(access.isSeriesCommissioner)
        XCTAssertTrue(access.canManageRound)
        XCTAssertFalse(access.canTransferHost)
        XCTAssertFalse(access.canArchiveOrDelete)
    }

    func testSecondaryCommissionerMatchesByUserID() {
        let member = SeriesMember(
            userID: "secondary-user",
            playerID: "different-player",
            role: .commissioner
        )
        let access = RoundManagementAccess.resolve(
            snapshot: snapshot(),
            currentUserID: "secondary-user",
            currentPlayerID: nil,
            members: [member]
        )

        XCTAssertTrue(access.isSeriesCommissioner)
        XCTAssertTrue(access.canManageRound)
    }

    func testSecondaryCommissionerMatchesByPlayerID() {
        let member = SeriesMember(
            userID: "different-user",
            playerID: "secondary-player",
            role: .commissioner
        )
        let access = RoundManagementAccess.resolve(
            snapshot: snapshot(),
            currentUserID: nil,
            currentPlayerID: "secondary-player",
            members: [member]
        )

        XCTAssertTrue(access.isSeriesCommissioner)
        XCTAssertTrue(access.canManageRound)
    }

    func testInactiveOrNonCommissionerMembersAreNotManagers() {
        let members = [
            SeriesMember(userID: "inactive", role: .commissioner, isActive: false),
            SeriesMember(userID: "captain", role: .captain),
            SeriesMember(userID: "member", role: .member),
            SeriesMember(userID: "substitute", role: .substitute),
            SeriesMember(userID: "spectator", role: .spectator),
        ]

        for member in members {
            let access = RoundManagementAccess.resolve(
                snapshot: snapshot(),
                currentUserID: member.userID,
                currentPlayerID: member.playerID,
                members: members
            )
            XCTAssertFalse(access.isSeriesCommissioner, member.role.rawValue)
            XCTAssertFalse(access.canManageRound, member.role.rawValue)
        }
    }

    private func snapshot() -> RoundSnapshot {
        let round = Round(
            id: "round-1",
            shareCode: "ROUND1",
            createdBy: "host-user"
        )
        let host = RoundParticipant(
            id: "host-participant",
            userID: "host-user",
            playerID: "host-player",
            isHost: true,
            parentID: round.id
        )
        return RoundSnapshot(round: round, participants: [host])
    }
}
