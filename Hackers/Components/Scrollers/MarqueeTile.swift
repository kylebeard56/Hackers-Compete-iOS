//
//  MarqueeTile.swift
//  Hackers
//
//  Created by Kyle Beard on 11/8/22.
//

import SwiftUI

let kTileWidth: CGFloat = 150 + 32

struct MarqueeTile: View {
    var icon: String
    var title: String
    var style: ThemeStyle
    var background: Color = Color.systemMarquee
    
    var padding: CGFloat { UIScreen.isSmall ? 6 : 8 }
    var iconSize: CGFloat { UIScreen.isSmall ? 24 : 32 }
    var titleSize: CGFloat { UIScreen.isSmall ? 13 : 15 }
    var width: CGFloat { UIScreen.isSmall ? 150 : 180 }
    var height: CGFloat { UIScreen.isSmall ? 75 : 90 }
    var radius: CGFloat { UIScreen.isSmall ? 6 : 8 }
    
    var body: some View {
        VStack(spacing: 10) {
            AwesomeImage(
                rawIcon: icon.unicode ?? "\u{f451}",
                style: .regular,
                size: iconSize,
                color: style.primaryColor,
                secondaryColor: style.secondaryColor)
            
            Text(title)
                .font(.dmSans(size: titleSize, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
        .padding()
        .frame(width: width, height: height)
        .background(background)
        .cornerRadius(radius)
        .border(Color.systemGray4, width: 1, cornerRadius: radius)
        .padding(padding)
        .shadow(color: Color.black.opacity(0.08), radius: radius, x: 0, y: 0)
    }
}

struct MarqueeTile_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MarqueeTile(icon: "f451", title: "Longest Yard", style: ThemeStyle(primary: "pink", secondary: "yellow"))
                .alignTop()
                .lightModePreview()
            
            MarqueeTile(icon: "f451", title: "Longest Yard", style: ThemeStyle(primary: "pink", secondary: "yellow"))
                .alignTop()
                .darkModePreview()
        }
    }
}
