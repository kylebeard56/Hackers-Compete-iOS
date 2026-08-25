//
//  StrokeSession.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import Foundation

struct StrokeSession: Hashable, Codable {
    var twoBall: Bool
    
    init(twoBall: Bool = false) {
        self.twoBall = twoBall
    }
    
    enum CodingKeys: String, CodingKey {
        case twoBall = "is_two_ball"
    }
}
