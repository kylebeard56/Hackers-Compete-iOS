//
//  StablefordBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct StablefordBackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Stableford")
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
This game was designed to make average golfers be more competitive due to the scoring system. It rewards bogey or better without letting your bad holes punish you.
 
Here’s the scoring breakdown:
**Albatross** = 5 points
**Eagle** = 4 points
**Birdie** = 3 points
**Par** = 2 points
**Bogey** = 1 point
**Double bogey or worse** = 0 points

Pace of play speeds up since you can pick up your ball once you hit double bogey.

The player with the most points wins!
"""
                )
                .font(.dmSans(size: 13, weight: .regular))
                .foregroundColor(Color.systemGray)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
        .alignTop()
    }
}

struct StablefordBackView_Previews: PreviewProvider {
    static var previews: some View {
        StablefordBackView()
    }
}
