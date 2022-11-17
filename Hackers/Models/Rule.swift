//
//  Rule.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import Foundation

enum RuleType: String {
    case team, player, round, hole, none
}

enum RuleDifficulty: String {
    case easy, hard, none, give, take, both
}

typealias HoleRules = [Int: RuleMap]
typealias RuleMap = [RuleType: [Rule]]

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
    
    var isEasy: Bool {
        difficulty == RuleDifficulty.easy.rawValue
    }
    
    var isHard: Bool {
        difficulty == RuleDifficulty.hard.rawValue
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
