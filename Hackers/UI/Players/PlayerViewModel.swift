//
//  PlayerViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

enum PlayerField {
    case none, one, two, three, four, five
}

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
    
    @FocusState var focusedField: PlayerField?
    
    init() { }
    deinit { }
}
