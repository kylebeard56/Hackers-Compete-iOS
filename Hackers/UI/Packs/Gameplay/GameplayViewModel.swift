//
//  GameplayViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import OrderedCollections
import SwiftUI

typealias HoleRuleDictionary = OrderedDictionary<Int, Rule>

class GameplayViewModel: Hackable {
    @Published var currentHole: Int = 0
    
    @Published var teamDifficulty: RuleDifficulty = .easy
    @Published var playerDifficulty: RuleDifficulty = .easy

    @Published var players: [Player] = [] {
        didSet {
            print("ACTIVE PLAYERS")
            printPretty(players)
        }
    }
    
    @Published var allRules: [Rule] = [] { didSet { print("Gameplay rules updated") }}
    @Published var teamRules: HoleRuleDictionary = [:] //[Int: Rule] = [:]
    @Published var playerRules: OrderedDictionary<Player, HoleRuleDictionary> = [:] //[Player: [Int: Rule]] = [:]
    
    @Published var isDrawing: Bool = false
    @Published var showCards: Bool = false
    
    init() {
        print("init GameplayViewModel")
    }
    
    deinit { }
    
    func draw(random: Bool = false) async {
        print(#function)
        isDrawing = true
        showCards = true
        
        if random {
            let (t, p) = generateRandomDifficulty()
            teamDifficulty = t
            playerDifficulty = p
        }
        
        await computeRules()
        
        self.isDrawing = false
    }
    
    private func computeRules() async {
        let t = teamRules.compactMap({ $0.value })
        teamRules[currentHole] = drawRule(from: t, with: .team, and: teamDifficulty)
        for player in players {
            let p = playerRules[player]?.compactMap({ $0.value }) ?? []
            playerRules[player]?[currentHole] = drawRule(from: p, with: .player, and: playerDifficulty)
        }
    }
    
    func drawRule(from data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
        let usedIDs = Dictionary(uniqueKeysWithValues: data.map{ ($0.id, "") })

        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
        let availableRules: [Rule] = allRules.filter({
            $0.type == type.rawValue
            && (difficulty == .both ? true : $0.difficulty == difficulty.rawValue)
            && usedIDs[$0.id] == nil
        })

        printPretty("Used: \(data.map({ $0.name }))")
        printPretty("Available: \(availableRules.map({ $0.name }))")
        
        /// 3. Set current rule
        return availableRules.randomElement() ?? kMissingGameplayRule
    }
    
    /// Draw an individual team rule that doesn't repeat for previous holes.
//    func drawTeamRule() async {
//        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
//        let usedRules = teamRules.compactMap({ $0.value })
//        let usedIDs = Dictionary(uniqueKeysWithValues: usedRules.map{ ($0.id, "") })
//
//        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
//        let availableRules: [Rule] = allRules.filter({
//            $0.type == RuleType.team.rawValue && $0.difficulty == teamDifficulty.rawValue && usedIDs[$0.id] == nil
//        })
//
//        print("TEAM")
//        printPretty("Used: \(usedRules.map({ $0.name }))")
//        printPretty("Available: \(availableRules.map({ $0.name }))")
//
//        /// 3. Set current rule
//        teamRules[currentHole] = availableRules.randomElement() ?? Rule()
//    }
//
//    /// Draw an individual player rule that doesn't repeat for previous holes (for that player only).
//    func drawPlayerRule(_ player: Player) async {
//        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
//        let usedRules = playerRules.compactMap({ $0.value })
//        let usedIDs = Dictionary(uniqueKeysWithValues: usedRules.map{ ($0.id, "") })
//
//        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
//        let availableRules: [Rule] = allRules.filter({
//            $0.type == RuleType.team.rawValue && $0.difficulty == teamDifficulty.rawValue && usedIDs[$0.id] == nil
//        })
//
//        print("TEAM")
//        printPretty("Used: \(usedRules.map({ $0.name }))")
//        printPretty("Available: \(availableRules.map({ $0.name }))")
//
//        /// 3. Set current rule
//        teamRules[currentHole] = availableRules.randomElement() ?? Rule()
//    }
    
    /// Generate difficulty where 0 = none, 1 = easy, 2 = hard
    private func generateRandomDifficulty() -> (RuleDifficulty, RuleDifficulty) {
        let a = Int.random(in: 0...2)
        let b = Int.random(in: 0...2)
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
