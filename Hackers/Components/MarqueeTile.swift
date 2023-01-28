//
//  MarqueeTile.swift
//  Hackers
//
//  Created by Kyle Beard on 11/8/22.
//

import SwiftUI

let kTileWidth: CGFloat = 150 + kPadding * 2

struct MarqueeTile: View {
    var icon: String
    var title: String
    var style: PackStyle
    var background: Color = Color.systemMarquee
    var padding: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 12) {
            AwesomeImage(
                rawIcon: icon.unicode ?? "\u{f451}",
                style: .regular,
                size: 24,
                color: style.primaryColor,
                secondaryColor: style.secondaryColor)
            
            Text(title)
                .font(.dmSans(size: 13, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
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
            MarqueeTile(icon: "f451", title: "Longest Yard", style: PackStyle(primary: "pink", secondary: "yellow"))
                .alignTop()
                .lightModePreview()
            
            MarqueeTile(icon: "f451", title: "Longest Yard", style: PackStyle(primary: "pink", secondary: "yellow"))
                .alignTop()
                .darkModePreview()
        }
    }
}
