//
//  Round+Scoring.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

enum ScoreBasis: String, Codable, Sendable {
    case gross, net
}

enum ScoreEntryMode: String, Codable {
    case strokes
    case relativeToPar = "relative_to_par"
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
    var relativeToPar: Int?         // Gross score relative to par, e.g. par = 0, bogey = +1
    var entryMode: ScoreEntryMode?
    var value: String?              // Non-stroke scoring value (if it applies)
    var pickedUp: Bool              // Skipped hole, opted to not score

    // Forward-compatible fields for template-driven scoring
    var gameTemplateID: String?     // Join key for multi-template segments (side games)
    var points: Double?             // Computed points (stableford, match, custom)
    var outcome: HoleOutcome?       // Match play hole result

    var entryID: String             // ID of the player who entered this score
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.scores.rawValue }
    
    init(
        id: String = "",
        holeNumber: Int = 0,
        segmentID: String = "",
        groupID: String = "",
        scoringUnitID: String = "",
        participantIDs: [String] = [],
        strokes: Int? = nil,
        relativeToPar: Int? = nil,
        entryMode: ScoreEntryMode? = nil,
        value: String? = nil,
        pickedUp: Bool = false,
        gameTemplateID: String? = nil,
        points: Double? = nil,
        outcome: HoleOutcome? = nil,
        entryID: String = "",
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.holeNumber = holeNumber
        self.segmentID = segmentID
        self.groupID = groupID
        self.scoringUnitID = scoringUnitID
        self.participantIDs = participantIDs
        self.strokes = strokes
        self.relativeToPar = relativeToPar
        self.entryMode = entryMode
        self.value = value
        self.pickedUp = pickedUp
        self.gameTemplateID = gameTemplateID
        self.points = points
        self.outcome = outcome
        self.entryID = entryID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, strokes, value, schema, points, outcome
        case holeNumber = "hole_number"
        case segmentID = "segment_id"
        case groupID = "group_id"
        case scoringUnitID = "scoring_unit_id"
        case participantIDs = "participant_ids"
        case pickedUp = "picked_up"
        case gameTemplateID = "game_template_id"
        case entryID = "entry_id"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
        case relativeToPar = "relative_to_par"
        case entryMode = "entry_mode"
    }
}

extension ScoreEntry {
    static func makeID(hole: Int, segment: String, scoringUnit: String) -> String {
        "h\(hole)_s\(segment)_u\(scoringUnit)"
    }

    var resolvedEntryMode: ScoreEntryMode {
        if let entryMode {
            return entryMode
        }
        if relativeToPar != nil {
            return .relativeToPar
        }
        return .strokes
    }

    var hasRecordedScore: Bool {
        strokes != nil || relativeToPar != nil || pickedUp
    }
}

// MARK: - Scoring Unit (linked to RoundSegment)
struct ScoringUnitHandicapAllowance: Hashable, Codable {
    var unitStrokes: Double
    var memberStrokes: [String: Double]
    var sourceConfig: HandicapConfiguration

    init(
        unitStrokes: Double = 0,
        memberStrokes: [String: Double] = [:],
        sourceConfig: HandicapConfiguration = .individualStrokePlay
    ) {
        self.unitStrokes = unitStrokes
        self.memberStrokes = memberStrokes
        self.sourceConfig = sourceConfig
    }

    enum CodingKeys: String, CodingKey {
        case unitStrokes = "unit_strokes"
        case memberStrokes = "member_strokes"
        case sourceConfig = "source_config"
    }
}

struct ScoringUnit: Hashable, Codable, Identifiable {
    var id: String                                      // Unique ID for this scoring unit
    var owner: ScoringOwner                             // Whether a participant or team owns this score
    var ownerIDs: [String]                              // Who shares this score (1+ players)
    var scoringMethod: ScoringMethod                    // Individual scoring or aggregate of multiple participants
    var aggregation: Aggregation?                       // How scores are reflected (if participants.count > 1)
    var handicapAdjustments: [String: Double]?          // Adjusted HCP per player based on game format fairness
    var handicapAllowance: ScoringUnitHandicapAllowance? // Canonical unit handicap plus member contribution detail

    init(
        id: String = "",
        owner: ScoringOwner = .participant,
        ownerIDs: [String] = [],
        scoringMethod: ScoringMethod = .individual,
        aggregation: Aggregation? = nil,
        handicapAdjustments: [String : Double]? = nil,
        handicapAllowance: ScoringUnitHandicapAllowance? = nil
    ) {
        self.id = id
        self.owner = owner
        self.ownerIDs = ownerIDs
        self.scoringMethod = scoringMethod
        self.aggregation = aggregation
        self.handicapAdjustments = handicapAdjustments
        self.handicapAllowance = handicapAllowance
    }
    
    enum CodingKeys: String, CodingKey {
        case id, owner, aggregation
        case ownerIDs = "owner_ids"
        case scoringMethod = "scoring_method"
        case handicapAdjustments = "handicap_adjustments"
        case handicapAllowance = "handicap_allowance"
    }
    
    var teamID: String? {
        guard owner == .team else { return nil }
        return ownerIDs.first
    }
}

// MARK: - Hole Outcome (match play)
enum HoleOutcome: String, Codable {
    case win
    case loss
    case tie
}

enum ScoringOwner: String, Codable {
    case participant
    case team
    case scoreOwner = "score_owner"
}

enum ScoringMethod: String, Codable {
    case individual           // one participant per unit
    case aggregate            // team aggregate (sum or best-N per hole/round)
}
