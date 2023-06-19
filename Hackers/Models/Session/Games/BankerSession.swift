//
//  BankerSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct BankerSession: Hashable, Codable {
    var banker: [Int: String]
    var wagers: [Int: [String: Int]] // [Hole: [Player_ID: Wager value]]
    var playerPress: [Int: [String: Bool]] // [Hole: [Player_ID: Pressed]]
    var bankerPress: [Int: Bool] // [Hole: Pressed]
    var parThree: Bool
}
