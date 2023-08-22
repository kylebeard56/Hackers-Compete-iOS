//
//  FootballSession.swift
//  Hackers
//
//  Created by Kyle Beard on 8/20/23.
//

import Foundation

struct FootballSession: Hashable, Codable {
    var possession: [Int: String]
    var onsideKick: [Int: OnsideKick]
    
    init(
        possession: [Int : String] = [:],
        onsideKick: [Int : OnsideKick] = [:]
    ) {
        self.possession = possession
        self.onsideKick = onsideKick
    }
    
    enum CodingKeys: String, CodingKey {
        case possession
        case onsideKick = "onside_kick"
    }
}

struct OnsideKick: Hashable, Codable {
    var attempted: Bool
    var successful: Bool?
    
    init(attempted: Bool = false, successful: Bool? = nil) {
        self.attempted = attempted
        self.successful = successful
    }
}
