//
//  FootballBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct FootballBackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Football")
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
This game is an alternate way to keep score based on single shot outcomes that reward or deduct points. The breakdown:

**Touchdowns** reward 6 points.

**Field goals** reward 3 points.

**Safeties** reward 2 points.

**Extra points** reward 1 point.

**Turnovers** deduct 1 point.

Highest score after a set of holes wins. Your party can set custom rules for what outcomes go with each scoring opportunity.
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

struct FootballBackView_Previews: PreviewProvider {
    static var previews: some View {
        FootballBackView()
    }
}
