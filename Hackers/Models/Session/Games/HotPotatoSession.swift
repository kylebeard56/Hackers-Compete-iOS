//
//  HotPotatoSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct HotPotatoSession: Hashable, Codable {
    var play: [Int: [String]] // [Hole: Player_IDs]
    var multiplier: [Int: Double]
}
