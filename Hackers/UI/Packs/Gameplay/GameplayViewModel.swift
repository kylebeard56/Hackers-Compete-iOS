//
//  GameplayViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SwiftUI

class GameplayViewModel: Hackable {
    @Published var teamDifficulty: RuleDifficulty = .easy
    @Published var playerDifficulty: RuleDifficulty = .easy

    @Published var players: [Player] = [] {
        didSet {
            print("ACTIVE PLAYERS")
            printPretty(players)
        }
    }
    
    @Published var teamRules: [Int: Rule] = [:]
    @Published var playerRules: [Int: [Player: Rule]] = [:]
    
    @Published var activePlayerRule: Rule = Rule()
    @Published var activeTeamRules: [Player: Rule] = [:]
    
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
        await drawTeamRule()
        for p in players {
            await drawPlayerRule(p)
        }
    }
    
    /// Draw an individual team rule that doesn't repeat for previous holes.
    func drawTeamRule() async {
        
    }
    
    /// Draw an individual player rule that doesn't repeat for previous holes (for that player only).
    func drawPlayerRule(_ player: Player) async {
        
    }
    
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
