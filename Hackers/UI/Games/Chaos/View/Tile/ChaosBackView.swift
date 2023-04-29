//
//  ChaosBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/27/23.
//

import SwiftUI

struct ChaosBackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Cards of Chaos")
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
This game gives your party a unique and amusing way to play each hole.

On each hole, your party draws cards that contain a random rule for how you can or cannot play the hole by influence scenarios involving club selection, ball advancement, or the treatment of certain terrains.

This game contains two types of cards - **favor** and **challenge**.

**Favor** cards are more helpful or supportive and grant opportunities to score.

**Challenge** cards are more penalizing or restrictive and test players to score.
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

struct ChaosBackView_Previews: PreviewProvider {
    static var view: some View {
        ZStack {
            Color.systemGray5.edgesIgnoringSafeArea(.all)
            ChaosBackView()
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
