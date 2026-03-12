//
//  PlayerHistoryEntry.swift
//  Hackers
//
//  Denormalized history of players this player has played rounds with.
//

import Foundation

// MARK: - RoundPlayedRef

struct RoundPlayedRef: Hashable, Codable {
    var roundID: String
    var playedAt: Time

    enum CodingKeys: String, CodingKey {
        case roundID = "round_id"
        case playedAt = "played_at"
    }

    init(roundID: String = "", playedAt: Time = .init()) {
        self.roundID = roundID
        self.playedAt = playedAt
    }
}

// MARK: - PlayerHistoryEntry

struct PlayerHistoryEntry: Hashable, Codable {
    var playerID: String
    var name: Name
    var rounds: [RoundPlayedRef]

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case name
        case rounds
    }

    init(playerID: String = "", name: Name = .init(), rounds: [RoundPlayedRef] = []) {
        self.playerID = playerID
        self.name = name
        self.rounds = rounds
    }

    var roundsPlayed: Int { rounds.count }
    var lastPlayedAt: Time? { rounds.map(\.playedAt).max(by: { $0.unix < $1.unix }) }
}

extension PlayerHistoryEntry: Identifiable {
    var id: String { playerID }
}
