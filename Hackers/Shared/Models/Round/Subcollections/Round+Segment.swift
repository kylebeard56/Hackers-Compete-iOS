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
    var holeRange: HoleRange
    var gameFormat: GameFormat
    var scoringUnits: [ScoringUnit]
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentCollection: String
    var parentID: String
    var subcollectionName: String
}

// Simplified: A scoring unit is the atomic unit of score entry
struct ScoringUnit: Codable, Identifiable {
    var id: String                     // Unique ID for this scoring unit
    var participants: [String]         // Who shares this score (1+ players)
    var name: String?                  // Optional: "Team Red", "Pair 1", player name
    var teamID: String?                // Optional: For team competitions (Ryder Cup)
    var scoringMethod: ScoringMethod
    
    // Handicaps for players in this unit
    var handicapAdjustments: [String: HandicapAdjustment]?
    
    // Computed helpers for UI
    var isIndividual: Bool {
        participants.count == 1
    }
    
    var displayName: String {
        name ?? (isIndividual ? "Individual" : "Team")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, participants
        case teamID = "team_id"
        case scoringMethod = "scoring_method"
    }
}

extension ScoringUnit {
    static func individual(_ participant: RoundParticipant) -> ScoringUnit {
        let adjustment = HandicapAdjustment(value: 1.0)
        
         return ScoringUnit(
             id: participant.id,
             participants: [participant.id],
             name: participant.displayName,
             teamID: nil,
             scoringMethod: .individual,
             handicapAdjustments: [participant.id: adjustment]
         )
     }
    
    static func shared(_ participants: [RoundParticipant], name: String, teamID: String?) -> ScoringUnit {
        let adjustments = participants.reduce(into: [String: HandicapAdjustment]()) { result, p in
            result[p.id] = HandicapAdjustment(value: 1.0)
        }
        
        return ScoringUnit(
            id: HackersID.string(),
            participants: participants.compactMap { $0.id },
            name: name,
            teamID: teamID,
            scoringMethod: .shared,
            handicapAdjustments: adjustments
        )
    }
}

enum ScoringMethod: String, Codable {
    case individual                    // Each player has own score
    case shared                        // Players share one score (scramble, alt shot)
    case bestBall = "best_ball"        // Track individually, use best
    case aggregate                     // Track individually, sum all
}

struct HandicapAdjustment: Codable {
    var value: Double

    func playingHandicap(from courseHandicap: Int) -> Int {
        return Int(round(Double(courseHandicap) * value))
    }
}
