//
//  GameplayView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/26/22.
//

import SwiftUI

let tile = MarqueeTile(
    icon: .golfFlagHole,
    title: "Longest Yard",
    colors: (Color.systemPink.opacity(0.6), Color.systemYellow.opacity(0.6))
)

struct GameplayView: View {
    @StateObject var viewModel: GameplayViewModel
    
    @State private var showCustomize: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showCards {
                if viewModel.isDrawing {
                    skeletonView
                } else {
                    cardsView
                }
            } else {
                setupView
            }
        }
        .sheet(isPresented: $showCustomize) {
            CustomizeGamePlayView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var setupView: some View {
        VStack(spacing: kPadding / 2) {
            Text("The Gameplay Pack")
                .font(.dmSans(size: 28, weight: .medium))
            
            VStack(spacing: 2) {
                Text("A collection of amusing scenarios designed to")
                Text("make you enjoy golf in a refreshing way.").bold()
            }
            .font(.dmSans(size: 15, weight: .regular))
           
            Spacer(minLength: 0)
            
            VStack(spacing: 0) {
                InfiniteScroller(contentWidth: UIScreen.main.bounds.width) {
                    Group {
                        tile
                        tile
                        tile
                        tile
                    }
                    .padding(.vertical, 64)
                }
                .padding(.vertical, -64)
                InfiniteScroller(contentWidth: UIScreen.main.bounds.width, stagger: 70) {
                    Group {
                        tile
                        tile
                        tile
                        tile
                    }
                    .padding(.vertical, 64)
                }
                .padding(.vertical, -64)
            }
            
            Spacer(minLength: 0)
            
            BigButton(
                style: .outline,
                title: "Customize",
                labelColor: Color.systemBlack,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showCustomize = true }
            )
            .padding(.horizontal, kPadding)
            .padding(.bottom, kPadding / 2)
            
            BigButton(
                style: .solid,
                title: "Quick Draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: { viewModel.draw(random: true) }
            )
            .padding(.horizontal, kPadding)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    private var teamRuleHeader: some View {
        HStack(alignment: .bottom) {
            Group {
                Text("Your ")
                + Text("team rule").bold()
                + Text(" is...")
            }
            .font(.dmSans(size: 17))
            .foregroundColor(Color.systemBlack)
            
            Spacer()
            
            HStack {
                AwesomeImage(icon: .faceSmileHalo, style: .regular, size: 12, color: Color.systemBlack)
                Text("Easy")
                    .font(.dmSans(size: 12, weight: .medium))
                    .foregroundColor(Color.systemBlack)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 10)
            .border(Color.systemBlack, width: 1, cornerRadius: 4)
        }
        .padding(.top, 4)
    }
    
    private var playerRuleHeader: some View {
        HStack(alignment: .bottom) {
            Group {
                Text("Your ")
                + Text("player rules").bold()
                + Text(" are...")
            }
            .font(.dmSans(size: 17))
            .foregroundColor(Color.systemBlack)
            .padding(.top, kPadding)
            
            Spacer()
            
            HStack {
                AwesomeImage(icon: .faceSmileHalo, style: .regular, size: 12, color: Color.systemBlack)
                Text("Easy")
                    .font(.dmSans(size: 12, weight: .medium))
                    .foregroundColor(Color.systemBlack)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 10)
            .border(Color.systemBlack, width: 1, cornerRadius: 4)
        }
    }
    
    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: kPadding) {
                teamRuleHeader
                SkeletonCard()
                playerRuleHeader
                SkeletonCard()
                SkeletonCard()
                SkeletonCard()
            }
            .padding(.horizontal, kPadding)
        }
    }
    
    private var cardsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: kPadding) {
                teamRuleHeader
                GameplayCard(rule: kBreakfastBall)
                playerRuleHeader
                GameplayCard(rule: kBlindFinish, player: Player(name: "Kyle", color: Color.systemGreen))
                GameplayCard(rule: kTeeBoxDemotion, player: Player(name: "Santiago", color: Color.systemBlue))
                
                HStack(spacing: kPadding) {
                    Button(action: { }) {
                        AwesomeImage(icon: .trashcan, style: .regular, size: 20, color: Color.systemBlack)
                            .frame(width: 56, height: 56)
                            .border(Color.systemBlack, width: 2, cornerRadius: 10)
                    }

                    BigButton(
                        style: .solid,
                        title: "Shuffle",
                        awesomeIcon: .shuffle,
                        labelColor: Color.systemWhite,
                        buttonColor: Color.systemBlack,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { }
                    )
                    
                    Button(action: { }) {
                        AwesomeImage(icon: .pencil, style: .regular, size: 20, color: Color.systemBlack)
                            .frame(width: 56, height: 56)
                            .border(Color.systemBlack, width: 2, cornerRadius: 10)
                    }
                }
                .padding(.vertical, kPadding)
            }
            .padding(.horizontal, kPadding)
        }
    }
}

struct GameplayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GameplayView(viewModel: GameplayViewModel())
                .lightModePreview()
            GameplayView(viewModel: GameplayViewModel())
                .darkModePreview()
        }
    }
}
