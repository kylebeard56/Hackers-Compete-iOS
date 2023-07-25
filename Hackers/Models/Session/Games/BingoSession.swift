//
//  BingoSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct BingoData: Hashable, Codable {
    var bingo: String
    var bango: String
    var bongo: String
    
    init(bingo: String = "", bango: String = "", bongo: String = "") {
        self.bingo = bingo
        self.bango = bango
        self.bongo = bongo
    }
}

struct BingoSession: Hashable, Codable {
    var play: [Int: BingoData]
}
