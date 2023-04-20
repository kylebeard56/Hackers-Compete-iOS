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
    
    private let kDiameter: CGFloat = 110
    private let kHaloOffset: CGFloat = 32
    private let kHornOffset: CGFloat = 24
    
    var ruleTypeOffset: CGFloat {
        rule.isFavor ? kHaloOffset : kHornOffset
    }
    
    var accentColor: Color {
        colorScheme == .light ? .systemGray5 : .systemGray4
    }
    
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                cardBody
                if rule.isChallenge {
                    hornsView
                        .padding(.top, 8)
                }
                iconCircle
                    .padding(.top, ruleTypeOffset)
                if rule.isFavor {
                    haloView
                }
            }
            .padding(kPadding)
        }
        .scaleEffect(UIScreen.isSmall ? 0.925 : 1.0)
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 0)
    }
    
    // MARK: - Components
    
    private var haloView: some View {
        Ellipse()
            .stroke(Color.systemYellow.opacity(0.75), lineWidth: 5)
            .frame(width: 60, height: 12)
    }
    
    private var hornsView: some View {
        Image(uiImage: Asset.Images.horns.image)
            .resizable()
            .scaledToFit()
            .frame(width: 80)
            .opacity(0.75)
    }
    
    private var tailView: some View {
        Image(uiImage: Asset.Images.tail.image)
            .resizable()
            .scaledToFit()
            .frame(width: 30)
            .opacity(0.75)
            .alignCenter()
            .alignBottom()
            .padding(.bottom, -8)
            .padding(.leading, kDiameter * 1.5)
    }
    
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(Color.systemCard)
                .frame(width: kDiameter, height: kDiameter)
            Circle()
                .stroke(Color.systemGray4, lineWidth: 3)
                .frame(width: kDiameter, height: kDiameter)
            
            AwesomeImage(
                rawIcon: rule.icon.unicode,
                style: .regular,
                size: 56,
                color: rule.isTeamRule ? appSession.gameplayPack.style.primaryColor : player.color.value,
                secondaryColor: rule.isTeamRule ? appSession.gameplayPack.style.secondaryColor : nil)
        }
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
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("This \(rule.difficulty) card is")
                                .font(.dmSans(size: 15, weight: .medium))
                                .foregroundColor(colorScheme == .light ? .systemGray2 : .systemGray)
                            
                            Text(rule.name)
                                .font(.dmSans(size: 40, weight: .bold))
                                .foregroundStyle(nameGradient)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .alignCenter()
                        }

                        PillDivider()
                        
                        Group {
                            Text(rule.bodySplits(for: player.name).0)
                                .bold()
                                .foregroundColor(rule.isPlayerRule ? player.color.value : Color.systemBlack)
                            + Text(rule.bodySplits(for: player.name).1)
                                .foregroundColor(Color.systemBlack.opacity(0.69))
                        }
                        .font(.dmSans(size: 20))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, kPadding)
                    }
                }
                .padding(.horizontal, -kPadding)
                .padding(.top, 32)
                
                Spacer(minLength: 0)
                
                BigButton(
                    style: .solid,
                    title: buttonLabel,
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    height: 50,
                    isDisabled: .constant(player.redrawCount <= 0),
                    isLoading: .false,
                    onTap: redrawTapped)
                .padding(.bottom, 8)
            }
            .alignCenter()
            .padding(16)
            .background(Color.systemGray6)
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.systemGray4, lineWidth: 3)
            )
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
                return player.color.value.toGradient
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
}

struct CardDetailView_Previews: PreviewProvider {
    static var detail: some View {
        CardDetailView(rule: kBreakfastBall, player: kPlayerKyle).environmentObject(AppSession())
    }
    
    static var view: some View {
        VStack {
            RoundView()
                .sheet(isPresented: .true) {
                    if #available(iOS 16.4, *) {
                        detail
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                    } else {
                        detail
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                    }
                }
        }
        .environmentObject(AppSession())
    }
    static var previews: some View {
        Group {
            detail.lightModePreview()
            detail.darkModePreview()
            detail.notchDevicePreview()
            detail.smallDevicePreview()
        }
    }
}
