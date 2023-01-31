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
    
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = 3

    @Published var players: [Player] = []
    
    @Published var allRules: [Rule] = []
    @Published var teamRules: HoleRuleDictionary = [:]
    @Published var playerRules: OrderedDictionary<Player, HoleRuleDictionary> = [:]
    @Published var playerRules2: OrderedDictionary<String, HoleRuleDictionary> = [:]
    // TODO: ^ This needs to be a playerID mapped to a holeruledictionary and then we can reference players index by ID
    
    @Published var rulesExist: [Int: Bool] = [:]
    
    @Published var isDrawing: Bool = false
    
    init() {
        print("init GameplayViewModel")
        for i in 0..<kHoleCount {
            rulesExist[i] = false
        }
    }
    
    deinit { }
    
    // MARK: - Reload
    
    func reload(for rules: [Rule]) {
        self.allRules = rules
    }
    
    // MARK: - Rules
    
    @Sendable
    func draw() async {
        isDrawing = true
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.675, execute: {
                self.isDrawing = false
            })
        }
        
        await computeRules()
        rulesExist[currentHole] = true
    }
    
    private func computeRules() async {
        await drawTeamRule()
        for player in players {
            await drawPlayerRule(for: player)
        }
    }
    
    func drawTeamRule() async {
        let rules = teamRules.compactMap({ $0.value })
        teamRules[currentHole] = drawRule(from: rules, with: .team, and: teamDifficulty.randomRuleDifficulty)
    }
    
    func drawPlayerRule(for player: Player) async {
        let rules = playerRules[player]?.compactMap({ $0.value }) ?? []
        let newRule = drawRule(from: rules, with: .player, and: player.difficulty.randomRuleDifficulty)
        
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
            && $0.difficulty == difficulty.rawValue
            && usedIDs[$0.id] == nil
        })
        
        /// 3. Set current rule
        return availableRules.randomElement() ?? kMissingGameplayRule
    }
    
    // MARK: - Redraw
    
    @Sendable func redrawTeamCard() async {
        teamRedrawCount -= 1
        await drawTeamRule()
    }
    
    @Sendable func redrawCard(for p: Player) async throws {
        if let i = players.firstIndex(where: { p.id == $0.id }) {
            players[i].redrawCount -= 1
            await drawPlayerRule(for: p)
        } else {
            throw HackersError.redrawFailed
        }
    }
    
    // MARK: - Clear
    
    func clearHoleRule() {
        rulesExist[currentHole] = false
    }
}
