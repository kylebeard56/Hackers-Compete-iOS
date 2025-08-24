//
//  Round+Scoring.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - HoleScore
struct HoleScore: Hashable, Codable {
    var hole: Int                   // Unique key for this score using the hole number
    var strokes: Int?               // Stroke count
    var friendlyScore: String?      // Stroke friendly name (birdie, par, bogey)
    var par: Int?                   // Par value for the hole, so we can always return net logic
    var handicapStrokes: Int?       // Number of strokes given for handicap
    var skipped: Bool               // True if a user opted to skip scoring this hole
    var lastUpdatedAt: Time         // When the score was set
    var updatedBy: String           // Who set the score
    
    init(
        hole: Int = 0,
        strokes: Int? = nil,
        friendlyScore: String? = nil,
        par: Int? = nil,
        handicapStrokes: Int? = nil,
        skipped: Bool = false,
        lastUpdatedAt: Time = .init(),
        updatedBy: String = ""
    ) {
        self.hole = hole
        self.strokes = strokes
        self.friendlyScore = friendlyScore
        self.par = par
        self.handicapStrokes = handicapStrokes
        self.skipped = skipped
        self.lastUpdatedAt = lastUpdatedAt
        self.updatedBy = updatedBy
    }
    
    enum CodingKeys: String, CodingKey {
        case hole, strokes, par, skipped
        case friendlyScore = "friendly_score"
        case handicapStrokes = "handicap_strokes"
        case lastUpdatedAt = "last_updated_at"
        case updatedBy = "updated_by"
    }
    
    // Computed properties for easier querying
    var isScored: Bool { strokes != nil }
    var isUnscored: Bool { strokes == nil && !skipped }
    
    // Get the actual score result if scored
    func scoreResult(par: Int) -> ScoreResult? {
        guard let strokes = strokes else { return nil }
        let netStrokes = max(strokes - (handicapStrokes ?? 0), 1)
        return ScoreResult.from(strokes: netStrokes, par: par)
    }
    
    // Mutating methods for state changes
    mutating func recordScore(_ strokes: Int) {
        self.strokes = strokes
        self.skipped = false  // Clear skip flag when scoring
    }
    
    mutating func markSkipped() {
        self.strokes = nil
        self.skipped = true
    }
    
    mutating func clearScore() {
        self.strokes = nil
        self.skipped = false  // Back to unscored state
    }
}
