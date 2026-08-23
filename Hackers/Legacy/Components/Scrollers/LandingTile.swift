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
    var tile: LandingTileData
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
        .background(tile.color)
        .cornerRadius(16)
        .padding(padding)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 0)
    }
}
