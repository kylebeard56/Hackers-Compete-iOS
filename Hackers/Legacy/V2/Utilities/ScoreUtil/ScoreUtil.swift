//
//  ScoreUtil.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import Foundation

class ScoreUtil {
    init() { }
    deinit { }
}

struct GameScoreData: Hashable, Identifiable {
    var id: UUID = UUID()
    var key: String // Player or Team ID
    var value: Int
}
