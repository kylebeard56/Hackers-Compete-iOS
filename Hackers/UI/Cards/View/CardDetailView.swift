//
//  CardDetailView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import SwiftUI

struct CardDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    var rule: Rule
    var player: Player
    var onRedraw: OnSelection?
    var onClose: OnSelection?
    
    private let kDiameter: CGFloat = 150
    private let kHaloOffset: CGFloat = 32
    private let kHornOffset: CGFloat = 24
    
    var ruleTypeOffset: CGFloat {
        rule.isFavor ? kHaloOffset : kHornOffset
    }
    
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                cardBody
                if rule.isChallenge {
                    hornsView
                }
                iconCircle
                    .padding(.top, ruleTypeOffset)
                if rule.isFavor {
                    haloView
                }
            }
            .padding(kPadding)
        }
    }
    
    // MARK: - Components
    
    private var haloView: some View {
        Ellipse()
            .stroke(Color.systemYellow.opacity(0.85), lineWidth: 5)
            .frame(width: 60, height: 12)
    }
    
    private var hornsView: some View {
        Image(uiImage: Asset.Images.horns.image)
            .resizable()
            .scaledToFit()
            .frame(width: 120)
            .opacity(0.85)
    }
    
    private var tailView: some View {
        Image(uiImage: Asset.Images.tail.image)
            .resizable()
            .scaledToFit()
            .frame(width: 40)
            .opacity(0.85)
            .alignCenter()
            .alignBottom()
            .padding(.bottom, -16)
            .padding(.leading, kDiameter * 2)
    }
    
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(Color.systemCard)
                .frame(width: kDiameter, height: kDiameter)
            Circle()
                .stroke(Color.systemGray3, lineWidth: 5)
                .frame(width: kDiameter, height: kDiameter)
            
            AwesomeImage(
                rawIcon: rule.icon.unicode,
                style: .regular,
                size: 72,
                color: rule.isTeamRule ? appSession.gameplayPack.style.primaryColor : player.color,
                secondaryColor: rule.isTeamRule ? appSession.gameplayPack.style.secondaryColor : nil)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 0)
    }
    
    private var cardBody: some View {
        VStack {
            ZStack {
                if rule.isChallenge {
                    tailView
                }
            }
            .frame(height: kDiameter * 0.6 + ruleTypeOffset)
            
            VStack(spacing: 24) {
                Button(action: closeTapped) {
                    AwesomeImage(icon: .xmark, style: .solid, size: 24, color: .systemGray3)
                        .alignMiddle()
                        .alignTrailing()
                        .padding(.trailing, 4)
                }
                .frame(height: 40)
                
                VStack(spacing: 8) {
                    Text("This \(rule.difficulty) card is")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(colorScheme == .light ? .systemGray3 : .systemGray)
                    
                    Text(rule.name)
                        .font(.dmSans(size: 40, weight: .bold))
                        .foregroundStyle(nameGradient)
                        .multilineTextAlignment(.center)
                        .alignCenter()
                }
                
                PillDivider()
                    .padding(.top, -8)
                
                ScrollView {
                    Group {
                        Text(rule.bodySplits(for: player.name).0)
                            .bold()
                            .foregroundColor(rule.isPlayerRule ? player.color : Color.systemBlack)
                            
                        + Text(rule.bodySplits(for: player.name).1)
                            .foregroundColor(Color.systemBlack.opacity(0.69))
                    }
                    .font(.dmSans(size: 20, weight: .regular))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, kPadding)
                }
                .padding(.horizontal, -kPadding)
                
                Spacer()//.frame(height: 24)
                
                BigButton(
                    style: .solid,
                    title: buttonLabel,
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    height: 50,
                    radius: 16,
                    isDisabled: .constant(player.redrawCount <= 0),
                    isLoading: .false,
                    onTap: redrawTapped)
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 4)
                .padding(.bottom, kPadding)
            }
            .alignCenter()
            .padding(kPadding)
            .background(Color.systemCard)
            .cornerRadius(50)
            .border(Color.systemGray2, width: 1, cornerRadius: 50)
        }
    }
    
    private var buttonLabel: String {
        return player.redrawCount < 6 ? "Redraw (\(player.redrawCount) left)" : "Redraw"
    }
    
    private var nameGradient: LinearGradient {
        if rule.packID == PackName.gameplay.rawValue {
            if rule.isTeamRule {
                return appSession.gameplayPack.style.linearGradient
            }
            if rule.isPlayerRule {
                return player.color.toGradient
            }
        }
        
        if rule.packID == PackName.drinking.rawValue {
            return appSession.drinkingPack.style.linearGradient
        }
        
        return Color.systemBlack.toGradient
    }
    
    // MARK: - Button Actions
    
    private func redrawTapped() {
        print(#function)
        if let action = onRedraw {
            action!()
        }
    }
    
    private func closeTapped() {
        print(#function)
        Haptics.fire(.light)
        if let action = onClose {
            action!()
        }
    }
}

struct CardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                HoleView()
                Blur(style: .dark)
                CardDetailView(rule: kBreakfastBall, player: kPlayerKyle)
            }
            .edgesIgnoringSafeArea(.vertical)
            .environmentObject(AppSession())
            .lightModePreview()
            
            ZStack {
                HoleView()
                Blur(style: .dark)
                CardDetailView(rule: kBreakfastBall, player: kPlayerKyle)
            }
            .edgesIgnoringSafeArea(.vertical)
            .environmentObject(AppSession())
            .darkModePreview()
        }
    }
}
