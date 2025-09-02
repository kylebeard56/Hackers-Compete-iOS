//
//  Aggregation.swift
//  Hackers
//
//  Created by Kyle Beard on 9/2/25.
//

import Foundation

enum AggregationMode: String, Codable {
    case sumAll = "sum_all"
    case countBest = "count_best_n"
}

enum AggregationScope: String, Codable {
    case perHole = "per_hole"
    case perRound = "per_round"
}

struct Aggregation: Codable, Hashable {
    var mode: AggregationMode = .sumAll
    var scope: AggregationScope
    var bestN: Int?
    
    init(
        mode: AggregationMode = .sumAll,
        scope: AggregationScope = .perHole,
        bestN: Int? = nil
    ) {
        self.mode = mode
        self.scope = scope
        self.bestN = bestN
    }
    
    enum CodingKeys: String, CodingKey {
        case mode, scope
        case bestN = "best_n"
    }
}
