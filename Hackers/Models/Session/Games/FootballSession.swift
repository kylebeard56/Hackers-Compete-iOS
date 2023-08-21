//
//  FootballSession.swift
//  Hackers
//
//  Created by Kyle Beard on 8/20/23.
//

import Foundation

enum OnsideKick: String {
    case success = "success"
    case failure = "failure"
    case notAttempted = "not_attempted"
}

struct FootballSession: Hashable, Codable {
    var possession: [Int: String]
    var onsideKick: [Int: String]
    
    init(
        possession: [Int : String] = [:],
        onsideKick: [Int : String] = [:]
    ) {
        self.possession = possession
        self.onsideKick = onsideKick
    }
    
    enum CodingKeys: String, CodingKey {
        case possession
        case onsideKick = "onside_kick"
    }
}
