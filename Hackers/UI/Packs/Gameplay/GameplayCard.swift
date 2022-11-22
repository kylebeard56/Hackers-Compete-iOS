//
//  GameplayCard.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SwiftUI

struct GameplayCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    var rule: Rule
    var player: Player = Player()
    var showShuffle: Bool = true
    
    //@State private var prefix: String = ""
    //@State private var suffix: String = ""
    
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
                    color: rule.isTeamRule ? kGameplayPack.style.primaryColor : Color.systemBlack,
                    secondaryColor: rule.isTeamRule ? kGameplayPack.style.secondaryColor : nil)
                
                if showShuffle {
                    Button(action: shuffleTapped) {
                        AwesomeImage(
                            icon: .shuffle,
                            style: .solid,
                            size: 17,
                            color: rule.isTeamRule ? kGameplayPack.style.primaryColor : player.color,
                            secondaryColor: rule.isTeamRule ? kGameplayPack.style.secondaryColor : nil)
                    }
                    .alignTrailing()
                    .alignTop()
                }
            }
            
            if rule.isTeamRule {
                Text(rule.name)
                    .font(.dmSans(size: 28, weight: .medium))
                    .foregroundStyle(kGameplayPack.style.linearGradient)
                    .alignCenter()
            }
            
            if rule.isPlayerRule {
                Text(rule.name)
                    .font(.dmSans(size: 28, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            
            Group {
                Text(rule.bodySplits(for: player.name).0)
                    .bold()
                    .foregroundColor(rule.isPlayerRule ? player.color : Color.systemBlack)
                    
                + Text(rule.bodySplits(for: player.name).1)
                    .foregroundColor(Color.systemBlack)
            }
            .font(.dmSans(size: 15, weight: .regular))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .alignCenter()
        }
        .padding(kPadding)
        .background(Color.systemMarquee)
        .border(Color.systemGray4, width: 2, cornerRadius: 12)
        .cornerRadius(12)
//        .onAppear() {
//            buildText()
//        }
    }
    
//    private func buildText() {
//        let components = rule.description
//            .replacingOccurrences(of: "<player-name>", with: player.name)
//            .components(separatedBy: "[-b]")
//
//        prefix = components[0]
//        if components.count == 2 {
//            suffix = components[1]
//        }
//    }
    
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
                    GameplayCard(rule: kBlindFinish, player: Player(name: "Kyle", color: Color.systemGreen))
                    GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Santiago", color: Color.systemBlue))
                }
            }
            .padding(kPadding)
            .lightModePreview()
            
            ScrollView {
                VStack(spacing: kPadding) {
                    GameplayCard(rule: kBreakfastBall, player: Player())
                    GameplayCard(rule: kBlindFinish, player: Player(name: "Kyle", color: Color.systemGreen))
                    GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Santiago", color: Color.systemBlue))
                }
            }
            .padding(kPadding)
            .darkModePreview()
        }
    }
}
