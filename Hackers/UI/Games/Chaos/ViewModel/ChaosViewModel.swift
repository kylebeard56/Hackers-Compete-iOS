//
//  ChaosViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/28/23.
//

import SwiftUI

@MainActor
class ChaosViewModel: Hackable {
    @Published var players: [Player] = []
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = 3
    
    init() { print("init ChaosViewModel") }
    deinit { print("deinit ChaosViewModel") }
}
