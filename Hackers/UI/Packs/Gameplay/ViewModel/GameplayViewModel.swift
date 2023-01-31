//
//  GameplayViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import OrderedCollections
import SwiftUI

typealias HoleRuleDictionary = OrderedDictionary<Int, Rule>
/// ^ Source: https://github.com/apple/swift-collections/blob/main/Documentation/OrderedDictionary.md

@MainActor
class GameplayViewModel: Hackable {
    @Published var currentHole: Int = 1
    
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = 3

    @Published var players: [Player] = []
    
    @Published var allRules: [Rule] = []
    @Published var teamRules: HoleRuleDictionary = [:]
    @Published var playerRules: [HoleRuleDictionary] = []
    
    @Published var rulesExist: [Int: Bool] = [:]
    @Published var rulesRevealed: [Bool] = Array(repeating: false, count: 18)
    
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
            self.isDrawing = false
        }
        
        await computeRules()
        rulesExist[currentHole] = true
        rulesRevealed[currentHole] = false
    }
    
    private func computeRules() async {
        await drawTeamRule()
        for player in players {
            await drawPlayerRule(for: player)
        }
    }
    
    func drawTeamRule() async {
        let rules = teamRules.compactMap({ $0.value })
        let newRule = drawRule(from: rules, with: .team, and: teamDifficulty.randomRuleDifficulty)
        teamRules.updateValue(newRule, forKey: currentHole)
    }
    
    func drawPlayerRule(for player: Player) async {
        if playerRules.isEmpty {
            var blankDictionary: HoleRuleDictionary = [:]
            for i in 0..<kHoleCount { blankDictionary.updateValue(Rule(), forKey: i) }
            players.forEach { _ in playerRules.append(blankDictionary) }
        }
        
        printPretty(playerRules)
        if let i = players.firstIndex(where: { $0.id == player.id }) {
            let rules = playerRules[i].filter({ !$0.value.id.isEmpty }).compactMap({ $0.value })
            let newRule = drawRule(from: rules, with: .player, and: player.difficulty.randomRuleDifficulty)
            playerRules[i].updateValue(newRule, forKey: currentHole)
        }
        
//        let rules = playerRules[player.id]?.compactMap({ $0.value }) ?? []
//        let newRule = drawRule(from: rules, with: .player, and: player.difficulty.randomRuleDifficulty)
//
//        if let v = playerRules[player.id] {
//            var dict = v
//            dict.updateValue(newRule, forKey: currentHole)
//            playerRules.updateValue(dict, forKey: player.id)
//        } else {
//            playerRules.updateValue([currentHole: newRule], forKey: player.id)
//        }
        
//        if let _ = playerRules[player.id] {
//            /// Dictionary for player already initiated, set hole-rule as kvp.
//            playerRules.updateValue([currentHole: newRule], forKey: player.id)
//            playerRules.up
//        } else {
//            /// Dictionary DNE -> initialize for player and current hole-rule as kvp.
//            playerRules[player.id] = [currentHole : newRule]
//        }
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
        
        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
        
        /// 3. Set current rule
        //return availableRules.randomElement() ?? kMissingGameplayRule
    }
    
    // MARK: - Get
    
    func getPlayerRule(for id: String) -> Rule? {
        //return playerRules[id]?[currentHole]
        if let i = players.firstIndex(where: { $0.id == id }) {
            return playerRules[i][currentHole]
        }
        return nil
    }
    
    func getTeamRule() -> Rule? {
        return teamRules[currentHole]
    }
    
    // MARK: - Redraw
    
    @Sendable func redrawTeamCard() async {
        if teamRedrawCount < 6 {
            teamRedrawCount -= 1
        }
        await drawTeamRule()
    }
    
    @Sendable func redrawCard(for p: Player) async throws {
        if let i = players.firstIndex(where: { p.id == $0.id }) {
            if players[i].redrawCount < 6 {
                players[i].redrawCount -= 1
            }
            await drawPlayerRule(for: p)
        } else {
            throw HackersError.redrawFailed
        }
    }
    
    // MARK: - Clear
    
    func clearHoleRule() {
        rulesRevealed[currentHole] = true
        rulesExist[currentHole] = false
    }
}
