//
//  MarqueeTile.swift
//  Hackers
//
//  Created by Kyle Beard on 11/8/22.
//

import SwiftUI

struct MarqueeTile: View {
    var icon: Awesome
    var title: String
    var colors: (Color, Color)
    var background: Color = Color.systemMarquee
    var padding: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 12) {
            AwesomeImage(icon: icon, style: .regular, size: 24, color: colors.0, secondaryColor: colors.1)
            
            Text(title)
                .font(.dmSans(size: 13, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
        //.padding(.horizontal, 24)
        //.padding(.vertical, 12)
        .padding()
        .frame(width: 150, height: 75)
        .background(background)
        .cornerRadius(6)
        .border(Color.systemGray4, width: 1, cornerRadius: 6)
        .padding(padding)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 0)
    }
}

struct MarqueeTile_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MarqueeTile(
                icon: .golfFlagHole,
                title: "Longest Yard",
                colors: (Color.systemPink.opacity(0.6), Color.systemYellow.opacity(0.6))
            )
            .alignTop()
            .lightModePreview()
            
            MarqueeTile(
                icon: .golfFlagHole,
                title: "Longest Yard",
                colors: (Color.systemPink.opacity(0.6), Color.systemYellow.opacity(0.6))
            )
            .alignTop()
            .darkModePreview()
        }
    }
}
