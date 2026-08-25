//
//  Pack.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import Foundation
import SwiftUI

enum PackName: String {
    case drinking, gameplay
}

struct Pack: FirebaseIdentifiable {
    var id: String
    var name: String
    var icon: String
    var description: String
    var style: ThemeStyle
    var lastUpdatedAt: Time
    
    init(
        id: String = "",
        name: String = "",
        icon: String = "",
        description: String = "",
        style: ThemeStyle = ThemeStyle(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.style = style
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case description, icon, id, name, style
        case lastUpdatedAt = "last_updated_at"
    }
    
    var awesome: Awesome {
        Awesome(rawValue: icon) ?? .questionSquare
    }
}

extension Pack {
    @discardableResult
    func post() async -> Result<Pack, Error> {
        return await self.post(to: Collections.packs.rawValue)
    }

    @discardableResult
    func put() async -> Result<Pack, Error> {
        return await self.put(to: Collections.packs.rawValue)
    }

    @discardableResult
    func delete() async -> Result<Bool, Error> {
        return await self.delete(from: Collections.packs.rawValue)
    }
}

enum GradientColor: String {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case indigo
    case cyan
    case pink
    case teal
    case mint
    case brown
    
    var color: Color {
        switch self {
        case .red:              return Color.systemRed.opacity(0.6)
        case .orange:           return Color.systemOrange.opacity(0.6)
        case .yellow:           return Color.systemYellow.opacity(0.6)
        case .green:            return Color.systemGreen.opacity(0.6)
        case .blue:             return Color.systemBlue.opacity(0.6)
        case .purple:           return Color.systemPurple.opacity(0.6)
        case .indigo:           return Color.systemIndigo.opacity(0.6)
        case .cyan:             return Color.systemCyan.opacity(0.6)
        case .pink:             return Color.systemPink.opacity(0.6)
        case .teal:             return Color.systemTeal.opacity(0.6)
        case .mint:             return Color.systemMint.opacity(0.6)
        case .brown:            return Color.systemBrown.opacity(0.6)
        }
    }
}

struct ThemeStyle: Hashable, Codable {
    var primary: String
    var secondary: String
    
    init(
        primary: String = "",
        secondary: String = ""
    ) {
        self.primary = primary
        self.secondary = secondary
    }
    
    var primaryColor: Color {
        GradientColor(rawValue: primary)?.color ?? Color.systemGray
    }
    var secondaryColor: Color {
        GradientColor(rawValue: secondary)?.color ?? Color.systemGray4
    }
    
    var linearGradient: LinearGradient {
        LinearGradient(colors: [primaryColor, secondaryColor], startPoint: .leading, endPoint: .trailing)
    }
}
