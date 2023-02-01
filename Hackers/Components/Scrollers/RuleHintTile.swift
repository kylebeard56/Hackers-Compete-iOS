//
//  RuleHintTile.swift
//  Hackers
//
//  Created by Kyle Beard on 1/30/23.
//

import SwiftUI

struct RuleHintTile: View {
    var tile: RuleTile
    var invertStyle: Bool = false
    var padding: CGFloat = 6
    
    private var gradient: LinearGradient {
        LinearGradient(colors: [tile.pColor, tile.sColor], startPoint: .top, endPoint: .bottom)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            AwesomeImage(
                rawIcon: tile.icon.unicode ?? "\u{f451}",
                style: .regular,
                size: 40,
                color: .white)
            
            Spacer()
            
            Text(tile.name)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.white)
            
            Spacer()
        }
        .padding()
        .frame(width: 225)//, height: 150)
        .background(
            ZStack {
                Color.white
                gradient
            }
        )
        .cornerRadius(16)
        .padding(padding)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 0)
    }
}

struct RuleHintTile_Previews: PreviewProvider {
    static let tile = RuleTile(
        name: "Team",
        icon: "f451",
        pColor: Color.systemPink.opacity(0.6),
        sColor: Color.systemYellow.opacity(0.6)
    )
    static var previews: some View {
        Group {
            RuleHintTile(tile: tile)
                .environmentObject(AppSession())
                .lightModePreview()
            
            RuleHintTile(tile: tile)
                .environmentObject(AppSession())
                .darkModePreview()
        }
    }
}
