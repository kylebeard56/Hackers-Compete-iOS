//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

struct Player: Equatable, Identifiable {
    var id: String
    var name: String
    var color: Color

    init(id: String = UUID().uuidString, name: String, color: Color) {
        self.id = id
        self.name = name
        self.color = color
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
}
