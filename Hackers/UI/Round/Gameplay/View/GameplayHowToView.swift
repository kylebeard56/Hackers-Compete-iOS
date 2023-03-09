//
//  GameplayHowToView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/28/23.
//

import SwiftUI

struct GameplayHowToView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(.top, kPadding / 2)
            
            content
        }
        .environmentObject(appSession)
        .edgesIgnoringSafeArea(.bottom)
        .padding(kPadding)
        .background(Color.systemCard)
    }
    
    // MARK: - Content
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            Text("The Strategy Pack")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundStyle(appSession.gameplayPack.style.linearGradient)
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                howItWorks

                Divider()
                
                configuringGameMode
            }
            .padding(.horizontal, kPadding)
        }
        .padding(.top, kPadding)
        .padding(.horizontal, -kPadding)
    }
    
    // MARK: - How It Works
    
    private var howItWorks: some View {
        VStack(spacing: 24) {
            Text("How it works")
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            Text("""
            On every hole, your party has the choice to draw cards from this pack. If drawn, you will get (1) team card and (1) player card each.
            """)
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            Group {
                Text("""
                Each card contains a rule or instruction for how the golfer must play the hole. Rules influence club selection, ball advancement, or treatment of certain terrains. This pack contains two types of cards -
                """)
                + Text(" favor").bold() + Text(" and ") + Text("challenge.").bold()
            }
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            Group {
                Text("Favor").bold()
                + Text(" cards are helpful or supportive and grant players the opportunity to score better than usual.")
            }
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            Group {
                Text("Challenge").bold()
                + Text(" cards are penalizing or restrictive and will test players to score as usual.")
            }
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            HStack(spacing: kPadding) {
                AwesomeImage(
                    icon: .calculator,
                    style: .regular,
                    size: 20,
                    color: Color.systemBlack)
                
                Group {
                    Text("With over 2400 combinations").bold()
                    + Text(", each draw gives your party a new perspective for playing a hole.")
                }
                .font(.dmSans(size: 12, weight: .regular))
                .foregroundColor(Color.systemBlack)
                .multilineTextAlignment(.leading)
                .alignLeading()
            }
            .padding(kPadding)
            .background(Color.systemGray6)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemGray3, lineWidth: 1))
            .padding(1)
        }
    }
    
    // MARK: - Configuring Game Mode
    
    private var configuringGameMode: some View {
        VStack(spacing: 24) {
            Text("Configuring game mode")
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            Group {
                Text("""
                This pack has two settings for game mode  -
                """)
                + Text(" difficulty").bold() + Text(" and ") + Text("redraw count.").bold()
            }
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            Group {
                Text("Difficulty").bold()
                + Text(" determines the odds of drawing favor or challenge cards throughout the round.")
            }
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            Group {
                Text("Redraw count").bold()
                + Text(" is the card version of a mulligan and sets the number of times a card can be discarded and replaced with a new one. Redrawing allows players the advantageous risk of shuffling their current ruling for a more formitable one.")
            }
            .font(.dmSans(size: 15, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            HStack(spacing: kPadding) {
                AwesomeImage(
                    icon: .lightbulb,
                    style: .regular,
                    size: 20,
                    color: Color.systemBlack)
                
                Group {
                    Text("With golfers of varying skill level").bold()
                    + Text(", designing a strategic game mode can equalize your party, similar to using handicaps.")
                }
                .font(.dmSans(size: 12, weight: .regular))
                .foregroundColor(Color.systemBlack)
                .multilineTextAlignment(.leading)
                .alignLeading()
            }
            .padding(kPadding)
            .background(Color.systemGray6)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemGray3, lineWidth: 1))
            .padding(1)
        }
    }
}

struct GameplayHowToView_Previews: PreviewProvider {
    static var view: some View {
        GameplayHowToView()
            .environmentObject(AppSession())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
    
}
