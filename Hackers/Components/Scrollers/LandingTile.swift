//
//  LandingTile.swift
//  Hackers
//
//  Created by Kyle Beard on 2/1/23.
//

import SwiftUI

struct LandingTileData: Hashable {
    var id: String = UUID().uuidString
    var icon: String
    var color: Color
}

struct LandingTile: View {
    @Environment(\.colorScheme) var colorScheme
    var tile: LandingTileData
    var invert: Bool
    var padding: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            AwesomeImage(
                rawIcon: tile.icon.unicode ?? "\u{f451}",
                style: .regular,
                size: 40,
                color: .white)
            
            Spacer()
        }
        .padding()
        .frame(width: 150)
        .background(invert ? Color.white.opacity(0.125) : tile.color)
        .border(invert ? Color.white : tile.color, width: 6, cornerRadius: 16)
        .cornerRadius(16)
        .padding(padding)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 0)
    }
}
