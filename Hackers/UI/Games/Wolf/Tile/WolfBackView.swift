//
//  WolfBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct WolfBackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Wolf Hammer")
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
For each hole, the player designated as the **wolf** will set the structure of teams by either picking a partner for 2v2 or going solo and taking on the group 1v3. The hole is match play style with scoring paid out in units called **dots**.

The tee order is set during the game and dictates rotation of who is the wolf. Whoever tees last is on deck to be wolf.

On the tee, the wolf must pick from below:

**Blind lone wolf**
Tee first and take on the team 1v3 without anyone hitting a tee shot yet. Winning gives 6 points to the wolf or 2 points each to the players.

**Lone wolf**
Tee last after seeing everyone's tee shots and still take on the team 1v3. Winning gives 3 points to the wolf or 1 point each to the players.

**Partner**
Tee last and choose a player who you feel gives you a strong chance 2v2. Winning gives 1 point each to the winning pair.

No dots are rewarded for losing.

At any given point, one team can strategically decide to throw the **hammer** at the other team, which is an invitation to double the dots rewarded for the hole.

Once thrown, the other team must make a decision for any other shots are taken:

Accept the hammer which would double the dots, or
Concede the hole and forfeit the original allotment of dots.

The hammer can only be thrown when both teams still have one active player left.

Once the hole is finished, the dot payout is them added to each player’s running total.
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

struct WolfBackView_Previews: PreviewProvider {
    static var view: some View {
        ZStack {
            Color.systemGray5.edgesIgnoringSafeArea(.all)
            WolfBackView()
                .environmentObject(AppSession())
                .padding(16)
                .background(Color.systemWhite)
                .cornerRadius(12)
                .padding(16)
        }
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
