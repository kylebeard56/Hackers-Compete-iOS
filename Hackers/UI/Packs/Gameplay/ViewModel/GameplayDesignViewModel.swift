//
//  GameplayDesignViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/28/23.
//

import SwiftUI

@MainActor
class GameplayDesignViewModel: Hackable {
    @Published var players: [Player] = []
    @Published var teamDifficulty: PlayerDifficulty = .medium
    @Published var teamShuffleCount: Int = 3
    
    init() { print("init GameplayDesignViewModel") }
    deinit { print("deinit GameplayDesignViewModel") }
}
