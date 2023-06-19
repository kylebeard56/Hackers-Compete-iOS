//
//  BingoSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct BingoPlay: Hashable, Codable {
    var bingo: String
    var bango: String
    var bongo: String
}

struct BingoSession: Hashable, Codable {
    var play: [Int: BingoPlay]
}
