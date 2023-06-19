//
//  SetupViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/23.
//

import SwiftUI

class SetupViewModel: ObservableObject {
    /// Setup your round
    @Published var numberOfHoles: Int = 18
    @Published var startingSide: String = "front"
    @Published var startingHole: Int = 1
    
    /// Pick your players
    @Published var players: [Player] = kDefaultPlayers { //[kPlayerKyle, kPlayerSarah, kPlayerMurphy] {
        didSet {
            arePlayersEmpty = players.compactMap({ !$0.name.isEmpty }).filter({ $0 }).isEmpty
        }
    }
    @Published var arePlayersEmpty: Bool = true
    
    
    
    init() {
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.updatePlayerValues() })
    }
    
    private func updatePlayerValues() {
        arePlayersEmpty = players.compactMap({ !$0.name.isEmpty }).filter({ $0 }).isEmpty
    }
}
