//
//  HammerSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct HammerSession: Hashable, Codable {
    var hammers: [Int: Int] // [Hole: # of hammers thrown]
    var firstMove: [Int: String] // [Hole: Team_ID]
}
