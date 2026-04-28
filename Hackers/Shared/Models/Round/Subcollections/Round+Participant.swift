//
//  Round+Participant.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

enum RoundParticipantPresenceStatus: String, Codable, CaseIterable {
    case active
    case unconfirmed
    case noShow = "no_show"
}

// MARK: - RoundParticipant
struct RoundParticipant: FirebaseSubcollectable, Playable {
    var id: String              // unique participant ID for subcollection
    var userID: String?         // the id of the authenticated user (upstream of player profiles)
    var playerID: String?       // the id of the specific user's player profile
    
    var name: Name              // Name or value to dislay in UI
    var teeBoxID: String
    var originalHandicap: Int   // Starting, inputted handicap from user
    var adjustedHandicap: Int   // Handicap adjustment based on course and slope adjustment
    /// Strokes seeded from the series league handicap when the participant was created from a series round; immutable for commissioner override UI.
    var leagueHandicapStrokesAtCreation: Int?

    var seriesMemberID: String?
    var teamID: String?
    var groupID: String?
    var teeOrder: Int?
    var isHost: Bool
    var presenceStatus: RoundParticipantPresenceStatus?
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.participants.rawValue }
    
    init(
        id: String = "",
        userID: String? = nil,
        playerID: String? = nil,
        name: Name = .init(),
        teeBoxID: String = "",
        originalHandicap: Int = 0,
        adjustedHandicap: Int = 0,
        leagueHandicapStrokesAtCreation: Int? = nil,
        seriesMemberID: String? = nil,
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        presenceStatus: RoundParticipantPresenceStatus? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.userID = userID
        self.playerID = playerID
        self.name = name
        self.teeBoxID = teeBoxID
        self.originalHandicap = originalHandicap
        self.adjustedHandicap = adjustedHandicap
        self.leagueHandicapStrokesAtCreation = leagueHandicapStrokesAtCreation
        self.seriesMemberID = seriesMemberID
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.presenceStatus = presenceStatus
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    init(
        player: Player,
        teeBoxID: String = "",
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        presenceStatus: RoundParticipantPresenceStatus? = nil,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        let handicap = player.handicaps.first?.value ?? 0
        
        self.id = HackersID.string()
        self.userID = player.userID
        self.playerID = player.id
        self.name = player.name
        
        self.teeBoxID = teeBoxID
        self.originalHandicap = handicap
        self.adjustedHandicap = handicap
        self.leagueHandicapStrokesAtCreation = nil
        self.seriesMemberID = nil
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.presenceStatus = presenceStatus
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case playerID = "player_id"
        
        case name
        case teeBoxID = "tee_box_id"
        case originalHandicap = "original_handicap"
        case adjustedHandicap = "adjusted_handicap"
        case leagueHandicapStrokesAtCreation = "league_handicap_strokes_at_creation"

        case seriesMemberID = "series_member_id"
        case teamID = "team_id"
        case groupID = "group_id"
        case teeOrder = "tee_order"
        case isHost = "is_host"
        case presenceStatus = "presence_status"
        
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
        case schema
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        userID = try c.decodeIfPresent(String.self, forKey: .userID)
        playerID = try c.decodeIfPresent(String.self, forKey: .playerID)

        name = try c.decodeIfPresent(Name.self, forKey: .name) ?? .init()
        teeBoxID = try c.decodeIfPresent(String.self, forKey: .teeBoxID) ?? ""
        originalHandicap = try c.decodeIfPresent(Int.self, forKey: .originalHandicap) ?? 0
        adjustedHandicap = try c.decodeIfPresent(Int.self, forKey: .adjustedHandicap) ?? 0
        leagueHandicapStrokesAtCreation = try c.decodeIfPresent(Int.self, forKey: .leagueHandicapStrokesAtCreation)

        seriesMemberID = try c.decodeIfPresent(String.self, forKey: .seriesMemberID)
        teamID = try c.decodeIfPresent(String.self, forKey: .teamID)
        groupID = try c.decodeIfPresent(String.self, forKey: .groupID)
        teeOrder = try c.decodeIfPresent(Int.self, forKey: .teeOrder)
        isHost = try c.decodeIfPresent(Bool.self, forKey: .isHost) ?? false
        presenceStatus = try c.decodeIfPresent(RoundParticipantPresenceStatus.self, forKey: .presenceStatus)

        createdAt = try c.decodeIfPresent(Time.self, forKey: .createdAt) ?? .init()
        lastUpdatedAt = try c.decodeIfPresent(Time.self, forKey: .lastUpdatedAt) ?? .init()
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID) ?? ""
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
    }
}

extension RoundParticipant {
    var isOnline: Bool { userID != nil }
    var isOffline: Bool { userID == nil }
    var resolvedPresenceStatus: RoundParticipantPresenceStatus { presenceStatus ?? .active }
    var isPresenceActive: Bool { resolvedPresenceStatus != .noShow }

    /// True when commissioner changed strokes vs series seed (commissioner-only orange hint).
    var isLeagueHandicapModifiedFromCreation: Bool {
        guard let baseline = leagueHandicapStrokesAtCreation else { return false }
        return adjustedHandicap != baseline
    }
}

extension RoundParticipant {
    var alphabeticName: String {
        name.fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    func toPlayer() -> Player {
        .init(playable: self)
    }
}
