//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Combine
import FirebaseAuth
import SwiftUI

@MainActor
class AppSession: Hackable {
    //@Published var players: [Player] = Array.init(repeating: Player(), count: 5)
    @Published var players: [Player] = [
        Player(color: .systemBlue),
        Player(color: .systemGreen),
        Player(color: .systemPurple),
        Player(color: .systemRed),
        Player(color: .systemOrange)
    ]
    
    init() { print("init AppSession") }
    deinit { print("deinit AppSession") }
}
