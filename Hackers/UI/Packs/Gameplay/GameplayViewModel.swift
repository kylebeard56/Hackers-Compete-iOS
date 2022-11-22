//
//  GameplayViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import OrderedCollections
import SwiftUI

typealias HoleRuleDictionary = OrderedDictionary<Int, Rule>

@MainActor
class GameplayViewModel: Hackable {
    @Published var currentHole: Int = 1
    
    @Published var teamDifficulty: RuleDifficulty = .easy
    @Published var playerDifficulty: RuleDifficulty = .easy

    @Published var players: [Player] = []
    
    @Published var allRules: [Rule] = []
    @Published var teamRules: HoleRuleDictionary = [:]
    @Published var playerRules: OrderedDictionary<Player, HoleRuleDictionary> = [:]
    
    @Published var rulesExist: [Int: Bool] = [:]
    
    @Published var isDrawing: Bool = false
    
    init() {
        print("init GameplayViewModel")
        for i in 0..<kHoleCount {
            rulesExist[i] = false
        }
    }
    
    deinit { }
    
    // MARK: - Rules
    
    func draw(random: Bool = false) async {
        isDrawing = true
        
        if random {
            let (t, p) = generateRandomDifficulty()
            teamDifficulty = t
            playerDifficulty = p
        }
        
        await computeRules()
        
        rulesExist[currentHole] = true
        self.isDrawing = false
    }
    
    func clearHoleRule() {
        rulesExist[currentHole] = false
    }
    
    private func computeRules() async {
        await drawTeamRule()
        for player in players {
            await drawPlayerRule(for: player)
        }
    }
    
    func drawTeamRule() async {
        let rules = teamRules.compactMap({ $0.value })
        teamRules[currentHole] = drawRule(from: rules, with: .team, and: teamDifficulty)
    }
    
    func drawPlayerRule(for player: Player) async {
        let rules = playerRules[player]?.compactMap({ $0.value }) ?? []
        let newRule = drawRule(from: rules, with: .player, and: playerDifficulty)
        
        if let _ = playerRules[player] {
            /// Dictionary for player already initiated, set hole-rule as kvp.
            playerRules[player]![currentHole] = newRule
        } else {
            /// Dictionary DNE -> initialize for player and current hole-rule as kvp.
            playerRules[player] = [currentHole : newRule]
        }
    }
    
    private func drawRule(from data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
        let usedIDs = Dictionary(uniqueKeysWithValues: data.map{ ($0.id, "") })

        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
        let availableRules: [Rule] = allRules.filter({
            $0.type == type.rawValue
            && (difficulty == .both ? true : $0.difficulty == difficulty.rawValue)
            && usedIDs[$0.id] == nil
        })
        
        /// 3. Set current rule
        return availableRules.randomElement() ?? kMissingGameplayRule
    }
    
    // MARK: - Random Generator
    
    /// Generate difficulty where 0 = none, 1 = easy, 2 = hard
    private func generateRandomDifficulty() -> (RuleDifficulty, RuleDifficulty) {
        // NOTE: Set range to 0...2 when you want to randomly draw nones.. Don't think we want this though.
        let a = Int.random(in: 1...2)
        let b = Int.random(in: 1...2)
        if a == 0 && b == 0 {
            return generateRandomDifficulty()
        } else {
            var team: RuleDifficulty = .none
            var player: RuleDifficulty = .none
            if a == 1 { team = .easy }
            if a == 2 { team = .hard }
            if b == 1 { player = .easy }
            if b == 2 { player = .hard }
            return (team, player)
        }
    }
}
