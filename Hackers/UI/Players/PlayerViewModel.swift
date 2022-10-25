//
//  PlayerViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

class PlayerViewModel: Hackable {
    @Published var playerOne: Player = Player(color: .systemBlue)
    @Published var oneActive: Bool = false
    
    @Published var playerTwo: Player = Player(color: .systemGreen)
    @Published var twoActive: Bool = false
    
    @Published var playerThree: Player = Player(color: .systemPurple)
    @Published var threeActive: Bool = false
    
    @Published var playerFour: Player = Player(color: .systemRed)
    @Published var fourActive: Bool = false
    
    @Published var playerFive: Player = Player(color: .systemOrange)
    @Published var fiveActive: Bool = false
    
    @Published var players: [Player] = [
        Player(color: .systemBlue),
        Player(color: .systemGreen),
        Player(color: .systemPurple),
        Player(color: .systemRed),
        Player(color: .systemOrange)
    ]
    
    init() { }
    deinit { }
    
//    func load(players: [Player]) {
//        if players.count == 5 {
//            playerOne = players[0]
//            playerTwo = players[1]
//            playerThree = players[2]
//            playerFour = players[3]
//            playerFive = players[4]
//        }
//    }
}
