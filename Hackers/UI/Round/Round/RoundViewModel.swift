//
//  RoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

//import OrderedCollections
import SwiftUI

typealias HoleRuleDictionary = [Int: Rule] //OrderedDictionary<Int, Rule>
/// ^ Source: https://github.com/apple/swift-collections/blob/main/Documentation/OrderedDictionary.md

@MainActor
class RoundViewModel: Hackable {
    @Published var currentHole: Int = 1
    
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = 3

    @Published var players: [Player] = [] { didSet { print("gameVM players didSet") }}
    
    @Published var allRules: [Rule] = []
    @Published var teamRules: HoleRuleDictionary = [:]
    @Published var playerRules: [HoleRuleDictionary] = []
    //@Published var playerRules: [String: [HoleRuleDictionary] = []
    
    @Published var rulesExist: [Int: Bool] = [:]
    @Published var rulesRevealed: [Bool] = Array(repeating: false, count: 18)
    
    @Published var isDrawing: Bool = false
    
    init() {
        print("init RoundViewModel")
        for i in 1..<kHoleCount {
            rulesExist[i] = false
        }
    }
    
    deinit { print("deinit RoundViewModel") }
    
    // MARK: - Reload
    
    func reload(for rules: [Rule]) {
        self.allRules = rules
    }
    
    // MARK: - Rules
    
    @Sendable
    func draw() async {
        //print(#function)
        isDrawing = true
        defer {
            self.isDrawing = false
        }
        
        await computeRules()
        rulesExist[currentHole] = true
        rulesRevealed[currentHole] = false
    }
    
    private func computeRules() async {
        //print(#function)
        await drawTeamRule()
        for player in players {
            await drawPlayerRule(for: player)
        }
    }
    
    func drawTeamRule() async {
        print(#function)
        let rules = teamRules.compactMap({ $0.value })
        let newRule = drawRule(from: rules, with: .team, and: teamDifficulty.randomRuleDifficulty)
        //print("start updateValue() for team")
        teamRules.updateValue(newRule, forKey: currentHole)
        //print("end updateValue() for team")
    }
    
    func drawPlayerRule(for player: Player) async {
        //print(#function)
        if playerRules.isEmpty {
            //print("player rules empty")
            var blankDictionary: HoleRuleDictionary = [:]
            for i in 0..<kHoleCount { blankDictionary.updateValue(Rule(), forKey: i) }
            players.forEach { _ in playerRules.append(blankDictionary) }
        }
        
        if let i = players.firstIndex(where: { $0.id == player.id }) {
            //print("filtering players by rule")
            let rules = playerRules[i].filter({ !$0.value.id.isEmpty }).compactMap({ $0.value })

            let newRule = drawRule(from: rules, with: .player, and: player.difficulty.randomRuleDifficulty)
            //print("start updateValue() for \(player.name)")
            playerRules[i].updateValue(newRule, forKey: currentHole)
            //print("end updateValue() for \(player.name)")
        }
    }
    
    private func drawRule(from data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
        print(#function)
        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
        let usedIDs = Dictionary(uniqueKeysWithValues: data.map { ($0.id, "") })
        //print("usedIDs built")
        
        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
        let availableRules: [Rule] = allRules.filter({
            $0.type == type.rawValue
            && $0.difficulty == difficulty.rawValue
            && usedIDs[$0.id] == nil
        })
        
        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
    }
    
    // MARK: - Get
    
    func getPlayerRule(for id: String) -> Rule? {
        //print(#function)
        if let i = players.firstIndex(where: { $0.id == id }) {
            return playerRules[i][currentHole]
        }
        return nil
    }
    
    func getTeamRule() -> Rule? {
        //print(#function)
        return teamRules[currentHole]
    }
    
    // MARK: - Redraw
    
    @Sendable func redrawTeamCard() async {
        if teamRedrawCount < 6 {
            //print("start decrement for team")
            teamRedrawCount -= 1
            //print("start decrement for team")
        }
        await drawTeamRule()
    }
    
    @Sendable func redrawCard(for p: Player) async throws {
//        defer {
//            print("defer \(#function)")
//        }
        if let i = players.firstIndex(where: { p.id == $0.id }) {
            if players[i].redrawCount < 6 {
                //print("start decrement for \(p.name)")
                players[i].redrawCount -= 1
                //print("end decrement for \(p.name)")
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
