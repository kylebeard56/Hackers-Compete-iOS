//
//  ChaosRow.swift
//  Hackers
//
//  Created by Kyle Beard on 11/18/22.
//

import SwiftUI

struct ChaosRow: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    
    var rule: Rule
    var player: Player = Player()
    
    @State private var prefix: String = ""
    @State private var suffix: String = ""
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.systemGray4, lineWidth: 2)
                    .frame(width: 54, height: 54)
                
                AwesomeImage(
                    rawIcon: rule.icon.unicode,
                    style: .regular,
                    size: 22,
                    color: rule.isTeamRule ? appSession.gameplayPack.style.primaryColor : Color.systemBlack,
                    secondaryColor: rule.isTeamRule ? appSession.gameplayPack.style.secondaryColor : nil)
            }
            
            VStack(spacing: 4) {
                Text(rule.name)
                    .font(.dmSans(size: 20, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Group {
                    Text(prefix)
                        .bold()
                        .foregroundColor(rule.isPlayerRule ? player.color.value : Color.systemBlack)
                        
                    + Text(suffix)
                        .foregroundColor(Color.systemBlack)
                }
                .font(.dmSans(size: 12))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .lineSpacing(2)
                .alignLeading()
            }
        }
        .padding(16)
        .background(Color.systemMarquee)
        .border(Color.systemGray4, width: 2, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() {
            let components = rule.description
                .replacingOccurrences(of: "<player-name>", with: player.name)
                .components(separatedBy: "[-b]")
            
            prefix = components[0]
            if components.count == 2 {
                suffix = components[1]
            }
        }
    }
}

struct ChaosRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScrollView {
                VStack(spacing: 16) {
                    ChaosRow(rule: kBreakfastBall, player: Player())
                    ChaosRow(rule: kBlindFinish, player: Player(name: "Kyle", color: .green))
                    ChaosRow(rule: kTeeBoxDemotion, player: Player(name: "Santiago", color: .blue))
                }
            }
            .padding(16)
            .lightModePreview()
            
            ScrollView {
                VStack(spacing: 16) {
                    ChaosRow(rule: kBreakfastBall, player: Player())
                    ChaosRow(rule: kBlindFinish, player: Player(name: "Kyle", color: .green))
                    ChaosRow(rule: kTeeBoxDemotion, player: Player(name: "Santiago", color: .blue))
                }
            }
            .padding(16)
            .darkModePreview()
        }
    }
}
