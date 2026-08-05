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

enum RoundParticipantHandicapSnapshotSource: String, Codable {
    case league
    case commissionerRepair = "commissioner_repair"
}

/// Immutable inputs used to seed a participant's handicap for one round.
/// Later score ingestion may change the member's projected handicap, but never this snapshot.
struct RoundParticipantHandicapSnapshot: Hashable, Codable {
    var authoritativeCourseHandicap: Int
    var handicapIndex: Double?
    var effectiveStrokes: Int
    var courseID: String
    var courseName: String
    var teeBoxID: String
    var teeName: String
    var teeGender: String
    var holeSegment: HoleSegment
    var courseRating: Double?
    var courseSlope: Int?
    var par: Int
    var handicapStrokeBasis: SeriesHandicapStrokeBasis
    var maximumHandicap: Int?
    var entryFormat: HandicapEntryFormat
    var calculatorFingerprint: String
    var selectedHandicapScoreIDs: [String]
    var calculatedAt: Time
    var source: RoundParticipantHandicapSnapshotSource

    enum CodingKeys: String, CodingKey {
        case par, source
        case authoritativeCourseHandicap = "authoritative_course_handicap"
        case handicapIndex = "handicap_index"
        case effectiveStrokes = "effective_strokes"
        case courseID = "course_id"
        case courseName = "course_name"
        case teeBoxID = "tee_box_id"
        case teeName = "tee_name"
        case teeGender = "tee_gender"
        case holeSegment = "hole_segment"
        case courseRating = "course_rating"
        case courseSlope = "course_slope"
        case handicapStrokeBasis = "handicap_stroke_basis"
        case maximumHandicap = "maximum_handicap"
        case entryFormat = "entry_format"
        case calculatorFingerprint = "calculator_fingerprint"
        case selectedHandicapScoreIDs = "selected_handicap_score_ids"
        case calculatedAt = "calculated_at"
    }
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
    var handicapIndex: Double?  // Optional decimal index used to compute adjustedHandicap
    /// Frozen scoring allowance for this historical round. Commissioner repair
    /// may replace it together with an auditable handicap snapshot.
    var leagueHandicapStrokesAtCreation: Int?
    var handicapSnapshot: RoundParticipantHandicapSnapshot?

    var seriesMemberID: String?
    var teamID: String?
    var groupID: String?
    var teeOrder: Int?
    var isHost: Bool
    var presenceStatus: RoundParticipantPresenceStatus?
    var isSubstitute: Bool
    var substituteForSeriesMemberID: String?
    var substituteForName: String?
    
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
        handicapIndex: Double? = nil,
        leagueHandicapStrokesAtCreation: Int? = nil,
        handicapSnapshot: RoundParticipantHandicapSnapshot? = nil,
        seriesMemberID: String? = nil,
        teamID: String? = nil,
        groupID: String? = nil,
        teeOrder: Int? = nil,
        isHost: Bool = false,
        presenceStatus: RoundParticipantPresenceStatus? = nil,
        isSubstitute: Bool = false,
        substituteForSeriesMemberID: String? = nil,
        substituteForName: String? = nil,
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
        self.handicapIndex = handicapIndex
        self.leagueHandicapStrokesAtCreation = leagueHandicapStrokesAtCreation
        self.handicapSnapshot = handicapSnapshot
        self.seriesMemberID = seriesMemberID
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.presenceStatus = presenceStatus
        self.isSubstitute = isSubstitute
        self.substituteForSeriesMemberID = substituteForSeriesMemberID
        self.substituteForName = substituteForName
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
        isSubstitute: Bool = false,
        substituteForSeriesMemberID: String? = nil,
        substituteForName: String? = nil,
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
        self.handicapIndex = nil
        self.leagueHandicapStrokesAtCreation = nil
        self.handicapSnapshot = nil
        self.seriesMemberID = nil
        self.teamID = teamID
        self.groupID = groupID
        self.teeOrder = teeOrder
        self.isHost = isHost
        self.presenceStatus = presenceStatus
        self.isSubstitute = isSubstitute
        self.substituteForSeriesMemberID = substituteForSeriesMemberID
        self.substituteForName = substituteForName
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
        case handicapIndex = "handicap_index"
        case leagueHandicapStrokesAtCreation = "league_handicap_strokes_at_creation"
        case handicapSnapshot = "handicap_snapshot"

        case seriesMemberID = "series_member_id"
        case teamID = "team_id"
        case groupID = "group_id"
        case teeOrder = "tee_order"
        case isHost = "is_host"
        case presenceStatus = "presence_status"
        case isSubstitute = "is_substitute"
        case substituteForSeriesMemberID = "substitute_for_series_member_id"
        case substituteForName = "substitute_for_name"
        
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
        handicapIndex = try c.decodeIfPresent(Double.self, forKey: .handicapIndex)
        leagueHandicapStrokesAtCreation = try c.decodeIfPresent(Int.self, forKey: .leagueHandicapStrokesAtCreation)
        handicapSnapshot = try c.decodeIfPresent(RoundParticipantHandicapSnapshot.self, forKey: .handicapSnapshot)

        seriesMemberID = try c.decodeIfPresent(String.self, forKey: .seriesMemberID)
        teamID = try c.decodeIfPresent(String.self, forKey: .teamID)
        groupID = try c.decodeIfPresent(String.self, forKey: .groupID)
        teeOrder = try c.decodeIfPresent(Int.self, forKey: .teeOrder)
        isHost = try c.decodeIfPresent(Bool.self, forKey: .isHost) ?? false
        presenceStatus = try c.decodeIfPresent(RoundParticipantPresenceStatus.self, forKey: .presenceStatus)
        isSubstitute = try c.decodeIfPresent(Bool.self, forKey: .isSubstitute) ?? false
        substituteForSeriesMemberID = try c.decodeIfPresent(String.self, forKey: .substituteForSeriesMemberID)
        substituteForName = try c.decodeIfPresent(String.self, forKey: .substituteForName)

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

    /// The allowance locked for this round. League handicap updates after activation
    /// must never alter live or historical scoring context.
    var lockedHandicapAllowance: Int {
        handicapSnapshot?.effectiveStrokes
            ?? leagueHandicapStrokesAtCreation
            ?? adjustedHandicap
    }

    var lockedHandicapProvenance: String {
        let strokes = lockedHandicapAllowance
        if let index = handicapSnapshot?.handicapIndex ?? handicapIndex {
            return "Index \(String(format: "%.1f", index)) → Course HCP \(strokes)"
        }
        return "Course HCP \(strokes)"
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
