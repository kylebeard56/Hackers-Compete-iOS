//
//  TraditionalBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/30/23.
//

import SwiftUI

struct TraditionalBackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(HackersGame.traditional.name)
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
The first written history of the game of golf came in 1457 when King James II, King of Scotland at the time, declared it illegal for citizens to play golf to instead focus on archery for military conquests.

Over 450 years later, this game is growing in popularity at a pace more rapid than every expected. 

In this game mode, you play the most classic round of golf, true scoring either against your party or by making teams.

The player or team with the lowest sum after the series of holes wins.
"""
                )
                .font(.dmSans(size: 13, weight: .regular))
                .foregroundColor(Color.systemGray)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
        .alignTop()
    }
}

struct TraditionalBackView_Previews: PreviewProvider {
    static var previews: some View {
        TraditionalBackView()
    }
}
