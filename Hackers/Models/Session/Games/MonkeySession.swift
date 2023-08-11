//
//  MonkeySession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct MonkeySession: Hashable, Codable {
    var play: [Int: String] // [Hole: Player_ID]
    var skins: Bool
}
