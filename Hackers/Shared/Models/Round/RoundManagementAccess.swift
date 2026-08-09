//
//  RoundManagementAccess.swift
//  Hackers
//
//  Created by Codex on 8/5/26.
//

import Foundation

/// Operational round authority derived from the current identity and live Series membership.
/// The persisted `isHost` flag remains a singular ownership marker.
struct RoundManagementAccess: Equatable, Sendable {
    var isHost: Bool
    var isSeriesCommissioner: Bool
    var isRoundCreator: Bool

    var canManageRound: Bool { isHost || isSeriesCommissioner }
    var canTransferHost: Bool { isHost }
    var canArchiveOrDelete: Bool { isRoundCreator }

    static let none = RoundManagementAccess(
        isHost: false,
        isSeriesCommissioner: false,
        isRoundCreator: false
    )

    static func resolve(
        snapshot: RoundSnapshot,
        currentUserID: String?,
        currentPlayerID: String?,
        series: Series? = nil,
        members: [SeriesMember] = []
    ) -> RoundManagementAccess {
        let isHost = snapshot.participants.contains { participant in
            participant.isHost && identityMatches(
                userID: participant.userID,
                playerID: participant.playerID,
                currentUserID: currentUserID,
                currentPlayerID: currentPlayerID
            )
        }

        let isPrimaryCommissioner = series.map { series in
            populatedValuesMatch(series.commissionerUserID, currentUserID)
                || populatedValuesMatch(series.commissionerPlayerID, currentPlayerID)
        } ?? false

        let isActiveMemberCommissioner = members.contains { member in
            member.isActive
                && member.role == .commissioner
                && identityMatches(
                    userID: member.userID,
                    playerID: member.playerID,
                    currentUserID: currentUserID,
                    currentPlayerID: currentPlayerID
                )
        }

        return RoundManagementAccess(
            isHost: isHost,
            isSeriesCommissioner: isPrimaryCommissioner || isActiveMemberCommissioner,
            isRoundCreator: populatedValuesMatch(snapshot.round.createdBy, currentUserID)
        )
    }

    private static func identityMatches(
        userID: String?,
        playerID: String?,
        currentUserID: String?,
        currentPlayerID: String?
    ) -> Bool {
        populatedValuesMatch(userID, currentUserID)
            || populatedValuesMatch(playerID, currentPlayerID)
    }

    private static func populatedValuesMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, lhs.isPopulated, let rhs, rhs.isPopulated else { return false }
        return lhs == rhs
    }
}
