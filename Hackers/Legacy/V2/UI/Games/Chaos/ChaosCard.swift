//
//  ChaosCard.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct ChaosCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var rule: Rule
    var player: Player
    var onRedraw: OnSelection?
    
    private let kDiameter: CGFloat = 110
    private let kHaloOffset: CGFloat = 32
    private let kHornOffset: CGFloat = 24
    
    @State private var flipping: Bool = false
    @State private var isFlipped: Bool = false
    @State private var backDegree = 0.0
    @State private var frontDegree = -90.0
    @State private var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .top) {            
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: kDiameter + 10)
                cardBody
            }
            
            if rule.isChallenge {
                hornsView
                    .padding(.top, 8)
            }

            if rule.isFavor {
                haloView
            }
            
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: rule.isFavor ? kHaloOffset : kHornOffset)
                iconCircle
            }
        }
        .padding(20)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 0)
        .scaleEffect(scaleFactor)
        //.rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onReceive(HackersNotification.chaosRedraw.publisher(), perform: { _ in
            //flipCard()
            Haptics.fire(.light)
        })
    }
    
    /// This had some weird effects so we're going to skip using it
    private func flipCard() {
        print(#function)
        let durationAndDelay = 0.269420

        flipping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + durationAndDelay, execute: {
            flipping = false
        })
        
        withAnimation(.easeInOut(duration: durationAndDelay)) {
            isFlipped.toggle()
        }

        withAnimation(.easeInOut(duration: durationAndDelay / 2)) {
            scaleFactor = 0.725 // Tested on preview, corners don't clip.
        }

        withAnimation(.easeInOut(duration: durationAndDelay / 2).delay(durationAndDelay / 2)) {
            scaleFactor = 1.0
        }
    }

    // MARK: - Components
    
    private var haloView: some View {
        Ellipse()
            .stroke(Color.systemHackersYellow.opacity(0.75), lineWidth: 5)
            .frame(width: 60, height: 12)
    }
    
    private var hornsView: some View {
        Image(uiImage: Asset.Images.horns.image)
            .resizable()
            .scaledToFit()
            .frame(width: 80)
            .opacity(0.75)
    }
    
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(Color.systemCard)
                .frame(width: kDiameter, height: kDiameter)
            Circle()
                .stroke(rule.isTeamRule ? Color.systemHackersPurple : player.color.value, lineWidth: 3)
                .frame(width: kDiameter, height: kDiameter)
            
            AwesomeImage(
                rawIcon: rule.icon.unicode,
                style: .regular,
                size: 56,
                color: rule.isTeamRule ? Color.systemHackersPurple : player.color.value)
        }
    }
    
    private var cardBody: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Group {
                            Text("This ")
                                .foregroundColor(colorScheme == .light ? .systemGray2 : .systemGray)
                            + Text("**\(rule.difficulty)**")
                                .foregroundColor(rule.isFavor ? Color.systemHackersYellow : Color.systemRed)
                            + Text(" card is")
                                .foregroundColor(colorScheme == .light ? .systemGray2 : .systemGray)
                        }
                        .font(.dmSans, size: 15)
                        
//                        Text("This \(rule.difficulty) card is")
//                            .font(.dmSans, size: 15, weight: .medium)
//                            .foregroundColor(colorScheme == .light ? .systemGray2 : .systemGray)
                        
                        Text(rule.name)
                            .font(.dmSans, size: 40, weight: .bold)
                            .foregroundColor(rule.isTeamRule ? Color.systemHackersPurple : player.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    }
                    .alignCenter()
                    .padding(.horizontal, 20)

                    PillDivider()
                    
                    Group {
                        Text("**\(rule.bodySplits(for: player.name).0)**")
                            .foregroundColor(rule.isTeamRule ? Color.systemHackersPurple : player.color.value)
                        + Text(rule.bodySplits(for: player.name).1)
                            .foregroundColor(Color.systemBlack.opacity(0.69))
                    }
                    .font(.dmSans, size: 22)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.horizontal, -20)
            .padding(.top, 32)
            
            Spacer(minLength: 0)
        }
        .alignCenter()
        .padding(.horizontal, 20)
        .background(Color.systemViewBackground)
        .cornerRadius(40)
        .overlay(
            RoundedRectangle(cornerRadius: 40)
                .stroke(Color.systemGray5, lineWidth: 1)
        )
    }
}

struct ChaosCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                ChaosCard(viewModel: HoleViewModel(), rule: kBreakfastBall, player: Player())
                ChaosCard(viewModel: HoleViewModel(), rule: kBlindFinish, player: kPlayerKyle)
                ChaosCard(viewModel: HoleViewModel(), rule: kTeeBoxDemotion, player: kPlayerSarah)
                ChaosCard(viewModel: HoleViewModel(), rule: kBreakfastBall, player: kPlayerMurphy)
                ChaosCard(viewModel: HoleViewModel(), rule: kTeeBoxDemotion, player: kPlayerPablo)
            }
            .environmentObject(RoundSession())
        }
        .holisticPreview()
    }
}
