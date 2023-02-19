//
//  Rule.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import Foundation
import SwiftUI

enum RuleType: String {
    case team, player, round, hole, none, both
}

enum RuleDifficulty: String {
    case favor, challenge, give, take, easy, hard, none
    
    var name: String {
        switch self {
        case .favor, .easy:         return "Favor"
        case .challenge, .hard:     return "Challenge"
        case .give:                 return "Give"
        case .take:                 return "Take"
        default:                    return ""
        }
    }
    
    var icon: Awesome {
        switch self {
        case .favor, .give, .easy:          return .faceSmileHalo
        case .challenge, .take, .hard:      return .faceSmileHorns
        default:                            return .golfFlagHole
        }
    }
    
    var color: Color {
        switch self {
        case .favor, .give, .easy:          return .systemGold
        case .challenge, .take, .hard:      return .systemPink
        default:                            return .systemBlack
        }
    }
}

struct Rule: FirebaseIdentifiable {
    var id: String
    var packID: String
    var name: String
    var description: String
    var icon: String
    var type: String
    var difficulty: String
    /// Describes which par this rule is applicable for (i.e. don't hit driver off par 3)
    var par: [Int]
    var conditions: [String]
    var lastUpdatedAt: Time
    
    init(
        id: String = "",
        packID: String = "",
        name: String = "",
        description: String = "",
        icon: String = "",
        type: String = "",
        difficulty: String = "",
        par: [Int] = [3, 4, 5],
        conditions: [String] = [],
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.packID = packID
        self.name = name
        self.description = description
        self.icon = icon
        self.type = type
        self.difficulty = difficulty
        self.par = par
        self.conditions = conditions
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case conditions, description, difficulty, icon, id, name, packID, par, type
        case lastUpdatedAt = "last_updated_at"
    }
    
    // MARK: - Text Builder
    
    func bodySplits(for name: String) -> (String, String) {
        var prefix: String = ""
        var suffix: String = ""
        
        let components = description
            .replacingOccurrences(of: "<player-name>", with: name)
            .components(separatedBy: "[-b]")
        
        prefix = components[0]
        if components.count == 2 {
            suffix = components[1]
        }
        return (prefix, suffix)
    }
    
    // MARK: - Helper Statuses
    
    var isFavor: Bool {
        difficulty == RuleDifficulty.favor.rawValue
    }
    
    var isChallenge: Bool {
        difficulty == RuleDifficulty.challenge.rawValue
    }
    
    var isTeamRule: Bool {
        type == RuleType.team.rawValue
    }
    
    var isPlayerRule: Bool {
        type == RuleType.player.rawValue
    }
    
    var isRoundRule: Bool {
        type == RuleType.round.rawValue
    }
    
    var isHoleRule: Bool {
        type == RuleType.hole.rawValue
    }
    
    var isGive: Bool {
        difficulty == RuleDifficulty.give.rawValue
    }
    
    var isTake: Bool {
        difficulty == RuleDifficulty.take.rawValue
    }    
}

extension Rule {
    @discardableResult
    func post() async -> Result<Rule, Error> {
        return await self.post(to: Collections.rules.rawValue)
    }

    @discardableResult
    func put() async -> Result<Rule, Error> {
        return await self.put(to: Collections.rules.rawValue)
    }

    @discardableResult
    func delete() async -> Result<Bool, Error> {
        return await self.delete(from: Collections.rules.rawValue)
    }
}
