//
//  MatchSession.swift
//  Hackers
//
//  Created by Kyle Beard on 8/1/23.
//

import Foundation

struct MatchSession: Hashable, Codable {
    var skins: Bool
    
    init(skins: Bool = false) {
        self.skins = skins
    }
    
    enum CodingKeys: String, CodingKey {
        case skins = "use_skins"
    }
}
