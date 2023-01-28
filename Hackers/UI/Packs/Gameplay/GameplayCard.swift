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
            
            // TODO: Make line limit of 2 with a more button
            /// Find a way to determine if the text will be three lines or not. If so, put "more" button which would
            /// simply chance line limit from 2 to say.. 10.
            ZStack {
                text
                //.lineLimit(lineLimit)
                .alignCenter()
//                .background(
//                    // Render the limited text and measure its size
//                    text
//                        .lineLimit(lineLimit)
//                        .background(GeometryReader { displayedGeometry in
//
//                            // Create a ZStack with unbounded height to allow the inner Text as much
//                            // height as it likes, but no extra width.
//                            ZStack {
//
//                                // Render the text without restrictions and measure its size
//                                text
//                                    .background(GeometryReader { fullGeometry in
//
//                                        // And compare the two
//                                        Color.clear.onAppear {
//                                            self.showMore = fullGeometry.size.height > displayedGeometry.size.height
//                                        }
//                                    })
//                            }
//                            .frame(height: .greatestFiniteMagnitude)
//                        })
//                        .hidden() // Hide the background
//                )
//
//                if showMore {
//                    Text("... More")
//                        .font(.dmSans(size: 15, weight: .medium))
//                        .foregroundColor(Color.systemGray)
//                        .padding(.horizontal, 8)
//                        .background(Color.systemMarquee)
//                        .alignBottom()
//                        .alignTrailing()
//                }
            }
        }
        .padding(kPadding)
        //.frame(minHeight: 200) // Geometry Reader measured 198pt
        .background(Color.systemMarquee)
        .border(Color.systemGray4, width: 2, cornerRadius: 12)
        .cornerRadius(12)
//        .onTapGesture(perform: {
//            lineLimit = 10
//            showMore = false
//            Haptics.fire(.light)
//        })
    }
    
    private var text: some View {
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
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func shuffleTapped() {
        if let action = onShuffle {
            //lineLimit = 2
            //showMore = false
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
                    GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Joe", color: Color.systemBlue))
                }
            }
            .padding(kPadding)
            .lightModePreview()
            
            ScrollView {
                VStack(spacing: kPadding) {
                    GameplayCard(rule: kBreakfastBall, player: Player())
                    GameplayCard(rule: kBlindFinish, player: Player(name: "Kyle", color: Color.systemGreen))
                    GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Joe", color: Color.systemBlue))
                }
            }
            .padding(kPadding)
            .darkModePreview()
        }
    }
}
