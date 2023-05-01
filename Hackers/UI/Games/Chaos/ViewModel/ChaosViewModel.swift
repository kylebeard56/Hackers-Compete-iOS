//
//  ChaosViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/28/23.
//

import SwiftUI

/// Essentially a localized view model before setting values in the round view model...
/// TODO: Extract this and somehow link it update the session in round view model...
@MainActor class ChaosViewModel: Hackable {
    @Published var arrangement: ChaosCardArrangement = .team
    @Published var players: [Player] = []
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = kRedrawCountDefault
    
    init() { print("init ChaosViewModel") }
    deinit { print("deinit ChaosViewModel") }
    
    func setRedraws(to value: Int) {
        teamRedrawCount = value
        for i in 0..<players.count {
            players[i].chaosRedrawCount = value
        }
    }
    
    func resetRedraws() {
        setRedraws(to: kRedrawCountDefault)
    }
}
