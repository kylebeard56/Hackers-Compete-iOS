//
//  Round+Scoring.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

enum ScoreBasis: String, Codable {
    case gross, net
}

// MARK: - ScoreEntry (idempotent subcollection under Round)
struct ScoreEntry: FirebaseSubcollectable {
    var id: String                  // Deterministic: h{number}_s{segment}_u{unit}
    
    var holeNumber: Int
    var segmentID: String
    var groupID: String
    
    var scoringUnitID: String       // ID of the scoring unit to reference
    var participantIDs: [String]    // Denormalization for who this score belongs to

    var strokes: Int?               // Gross strokes where nil == unscored
    var value: String?              // Non-stroke scoring value (if it applies)
    var pickedUp: Bool              // Skipped hole, opted to not score
    
    var entryID: String             // ID of the player who entered this score
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var parentCollection: String { Collections.rounds.name }
    var subcollectionName: String { RoundSubcollection.scores.rawValue }
    
    init(
        id: String = "",
        holeNumber: Int = 0,
        segmentID: String = "",
        groupID: String = "",
        scoringUnitID: String = "",
        participantIDs: [String] = [],
        strokes: Int? = nil,
        value: String? = nil,
        pickedUp: Bool = false,
        entryID: String = "",
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = "",
    ) {
        self.id = id
        self.holeNumber = holeNumber
        self.segmentID = segmentID
        self.groupID = groupID
        self.scoringUnitID = scoringUnitID
        self.participantIDs = participantIDs
        self.strokes = strokes
        self.value = value
        self.pickedUp = pickedUp
        self.entryID = entryID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, strokes, value
        case holeNumber = "hole_number"
        case segmentID = "segment_id"
        case groupID = "group_id"
        case scoringUnitID = "scoring_unit_id"
        case participantIDs = "participant_ids"
        case pickedUp = "picked_up"
        case entryID = "entry_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}

extension ScoreEntry {
    static func makeID(hole: Int, segment: String, scoringUnit: String) -> String {
        "h\(hole)_s\(segment)_u\(scoringUnit)"
    }
}

// MARK: - Scoring Unit (linked to RoundSegment)
struct ScoringUnit: Hashable, Codable, Identifiable {
    var id: String                                      // Unique ID for this scoring unit
    var owner: ScoringOwner                             // Whether a participant or team owns this score
    var ownerIDs: [String]                              // Who shares this score (1+ players)
    var scoringMethod: ScoringMethod                    // Individual scoring or aggregate of multiple participants
    var aggregation: Aggregation?                       // How scores are reflected (if participants.count > 1)
    var handicapAdjustments: [String: Double]?          // Adjusted HCP per player based on game format fairness

    init(
        id: String = "",
        owner: ScoringOwner = .participant,
        ownerIDs: [String] = [],
        scoringMethod: ScoringMethod = .individual,
        aggregation: Aggregation? = nil,
        handicapAdjustments: [String : Double]? = nil
    ) {
        self.id = id
        self.owner = owner
        self.ownerIDs = ownerIDs
        self.scoringMethod = scoringMethod
        self.aggregation = aggregation
        self.handicapAdjustments = handicapAdjustments
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, participants, aggregation
        case teamID = "team_id"
        case scoringMethod = "scoring_method"
        case handicapAdjustments = "handicap_adjustments"
    }
    
    var teamID: String? {
        guard owner == .team else { return nil }
        return ownerIDs.first
    }
}

enum ScoringOwner: String, Codable { case participant, team }

enum ScoringMethod: String, Codable {
    case individual           // one participant per unit
    case aggregate            // team aggregate (sum or best-N per hole/round)
}
