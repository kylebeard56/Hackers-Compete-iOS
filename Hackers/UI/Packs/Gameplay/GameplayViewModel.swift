//
//  GameplayViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SwiftUI

/// Maps


class GameplayViewModel: Hackable {
    @Published var teamDifficulty: RuleDifficulty = .easy
    @Published var playerDifficulty: RuleDifficulty = .easy

    @Published var rules: HoleRules = [:]
    
    @Published var isDrawing: Bool = false
    @Published var showCards: Bool = false
    
    /// Rules can be stored as a nested map for each pack:
    /// [0: GameplayHoleRules, 1: .....] where GameplayHoleRules is map of [team: Rule, playerA: Rule, ...]
    init() {
        print("init GameplayViewModel")
    }
    
    deinit { }
    
    func draw(random: Bool = false) {
        print(#function)
        isDrawing = true
        showCards = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
            self.isDrawing = false
        })
    }
}
