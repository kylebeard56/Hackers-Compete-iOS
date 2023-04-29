//
//  VegasBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct VegasBackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Vegas Style")
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
This game requires your party to split 2v2 for the entirely of the match. Everyone plays their own ball and the *Vegas* score is determined after completing the hole by combining scores of the lower with the higher.

**Example:** Team 1 shoots a 6 and 8 while Team 2 shoots a 9 and 5. Team 1’s score is a 68 and Team 2’s is a 59. If a team has a double-digit score, it gets rolled over i.e. 7 and 10 would be 80 (70+ 10), not 710.

Vegas Style is great for pairings that struggle with scoring well consistently. The winning team has lowest sum of points after a series of holes.
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

struct VegasBackView_Previews: PreviewProvider {
    static var previews: some View {
        VegasBackView()
    }
}
