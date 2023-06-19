//
//  SurvivorSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct SurvivorSession: Hashable, Codable {
    var lives: [String: Int] // [Player_ID: # of lives]
}
