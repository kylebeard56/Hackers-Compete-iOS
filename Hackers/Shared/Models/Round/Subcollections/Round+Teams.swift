//
//  Round+Team.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import SwiftUI

enum TeamColor: String {
    case red, blue, green, purple, orange, unknown
    
    var index: Int {
        switch self {
        case .red:      return 0
        case .blue:     return 1
        case .green:    return 2
        case .purple:   return 3
        case .orange:   return 4
        default:        return -1
        }
    }
    
    var name: String {
        switch self {
        case .red:      return "Red"
        case .blue:     return "Blue"
        case .green:    return "Green"
        case .purple:   return "Purple"
        case .orange:   return "Orange"
        default:        return "Black"
        }
    }
    
    var value: Color {
        switch self {
        case .red:      return .systemRed
        case .blue:     return .systemBlue
        case .green:    return .accentGreen
        case .purple:   return .accentPurple
        case .orange:   return .systemOrange
        default:        return .foregroundPrimary
        }
    }
}

extension TeamColor {
    static let cycle: [TeamColor] = [.red, .blue, .green, .purple, .orange]
    
    static func colorAndSequence(for index: Int) -> (TeamColor, Int) {
        let colors = TeamColor.cycle
        let base = colors[index % colors.count]
        let sequence = (index / colors.count) + 1
        return (base, sequence)
    }
    
    static func teamValue(for index: Int) -> (Self, String) {
        let (color, sequence) = colorAndSequence(for: index)
        return (color, sequence == 1 ? "\(color.name) Team" : "\(color.name) Team \(sequence)")
    }
}

struct RoundTeam: FirebaseSubcollectable, IndexIterable {
    var id: String
    var name: String        // App assigned name like Team 1, Team 2, etc
    var color: String       // Color value identifier for the team
    var index: Int
    
    var createdAt: Time
    var lastUpdatedAt: Time
    var parentID: String
    var schema: Int = 1
    
    var teamColor: TeamColor { .init(rawValue: color) ?? .unknown }
    
    static var parentCollection: String { Collections.rounds.name }
    static var subcollectionName: String { RoundSubcollection.teams.rawValue }
    
    init(
        id: String,
        name: String,
        color: String,
        index: Int,
        createdAt: Time,
        lastUpdatedAt: Time = .init(),
        parentID: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.index = index
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.parentID = parentID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, index, schema
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case parentID = "parent_id"
    }
}
