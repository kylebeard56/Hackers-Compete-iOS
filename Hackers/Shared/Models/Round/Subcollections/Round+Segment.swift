//
//  Round+Segment.swift
//  Hackers
//
//  Created by Kyle Beard on 8/28/25.
//

import Foundation

struct RoundSegment: FirebaseSubcollectable {
    var id: String
    var roundID: String
    var holeRange: HoleRange                // Sub-range of holes for this specific format
    var gameFormat: GameFormat              // Can equal Round.primaryFormat or override (for Nassau or 6-6-6)
    var scoringUnits: [ScoringUnit]         // Atomic scoring subjects for this segment
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.segments.rawValue }
    
    init(
        id: String = "",
        roundID: String = "",
        holeRange: HoleRange = .init(),
        gameFormat: GameFormat = .strokePlay,
        scoringUnits: [ScoringUnit] = [],
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.roundID = roundID
        self.holeRange = holeRange
        self.gameFormat = gameFormat
        self.scoringUnits = scoringUnits
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, schema
        case roundID = "round_id"
        case holeRange = "hole_range"
        case gameFormat = "game_format"
        case scoringUnits = "scoring_units"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}
