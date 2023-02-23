//
//  GameplayCard.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SwiftUI

struct GameplayCard: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    
    var rule: Rule
    var player: Player = Player()
    var showShuffle: Bool = true
    
    @State private var showMore: Bool = false
    @State private var lineLimit: Int = 2
    @State private var height: CGFloat = 200
    
    var onShuffle: OnSelection?
    
    var body: some View {
        VStack(spacing: kPadding / 2) {
            ZStack {
                Circle()
                    .stroke(Color.systemGray4, lineWidth: 2)
                    .frame(width: 72, height: 72)
                
                AwesomeImage(
                    rawIcon: rule.icon.unicode,
                    style: .regular,
                    size: 28,
                    color: rule.isTeamRule ? appSession.gameplayPack.style.primaryColor : Color.systemBlack,
                    secondaryColor: rule.isTeamRule ? appSession.gameplayPack.style.secondaryColor : nil)
                
                if showShuffle {
                    Button(action: shuffleTapped) {
                        AwesomeImage(
                            icon: .shuffle,
                            style: .solid,
                            size: 17,
                            color: rule.isTeamRule ? appSession.gameplayPack.style.primaryColor : player.color.value,
                            secondaryColor: rule.isTeamRule ? appSession.gameplayPack.style.secondaryColor : nil)
                    }
                    .alignTrailing()
                    .alignTop()
                }
            }
            
            if rule.isTeamRule {
                Text(rule.name)
                    .font(.dmSans(size: 28, weight: .medium))
                    .foregroundStyle(appSession.gameplayPack.style.linearGradient)
                    .alignCenter()
            }
            
            if rule.isPlayerRule {
                Text(rule.name)
                    .font(.dmSans(size: 28, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            
            ZStack {
                text
                .alignCenter()
            }
        }
        .padding(kPadding)
        .background(Color.systemMarquee)
        .border(Color.systemGray4, width: 2, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private var text: some View {
        Group {
            Text(rule.bodySplits(for: player.name).0)
                .bold()
                .foregroundColor(rule.isPlayerRule ? player.color.value : Color.systemBlack)
                
            + Text(rule.bodySplits(for: player.name).1)
                .foregroundColor(Color.systemBlack)
        }
        .font(.dmSans(size: 15, weight: .regular))
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func shuffleTapped() {
        if let action = onShuffle {
            action!()
        }
    }
}

struct GameplayCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScrollView {
                VStack(spacing: kPadding) {
                    GameplayCard(rule: kBreakfastBall, player: Player())
                    GameplayCard(rule: kBlindFinish, player: Player(name: "Kyle", color: .green))
                    GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Joe", color: .blue))
                }
            }
            .padding(kPadding)
            .lightModePreview()
            
            ScrollView {
                VStack(spacing: kPadding) {
                    GameplayCard(rule: kBreakfastBall, player: Player())
                    GameplayCard(rule: kBlindFinish, player: Player(name: "Kyle", color: .green))
                    GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Joe", color: .blue))
                }
            }
            .padding(kPadding)
            .darkModePreview()
        }
    }
}
