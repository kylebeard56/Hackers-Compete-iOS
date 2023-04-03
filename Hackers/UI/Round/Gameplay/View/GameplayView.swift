//
//  GameplayView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/26/22.
//

import SwiftUI

struct GameplayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var hole: Int
    
    @State private var isRedraw: Bool = false
    @State private var showReveal: Bool = false
    @State private var showDesign: Bool = false
    @State private var showHowTo: Bool = false
    @State private var showDiscard: Bool = false
    
    private let kShuffleDelay: CGFloat = 0.375
    private var gradient: LinearGradient {
        let p = appSession.gameplayPack.style.primaryColor
        let s = appSession.gameplayPack.style.secondaryColor
        return LinearGradient(colors: [p, s], startPoint: .top, endPoint: .bottom)
    }
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.doesRuleExist(for: hole) {
                if viewModel.isDrawing {
                    ProgressView()
                } else {
                    cardsView
                }
            } else {
                setupView
            }
        }
        .environmentObject(appSession)
        .sheet(isPresented: $showReveal) {
            CardRevealView(viewModel: viewModel)
        }
        .sheet(isPresented: $showDesign) {
            GameplayDesignModeView(
                viewModel: viewModel,
                isRedraw: viewModel.doesRuleExist(for: hole)
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHowTo) {
            GameplayHowToView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDiscard) {
            deleteCard
                .presentationDetents([.height(225)])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var setupView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("The Strategy Pack")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                
                VStack(spacing: 2) {
                    Text("A collection of amusing scenarios designed to")
                    Text("make you enjoy golf in a refreshing way.").bold()
                }
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.systemGrayDark)
                
//                Button(action: {
//                    showHowTo = true
//                    Haptics.fire(.light)
//                }) {
//                    Text("How to play")
//                        .font(.dmSans(size: 15, weight: .medium))
//                        .foregroundStyle(appSession.gameplayPack.style.linearGradient)
//                        .alignCenter()
//                        .padding(.horizontal, kPadding)
//                        .padding(.vertical, 12)
//                        .background(Color.systemGray5)
//                        .cornerRadius(8)
//                }
//                .padding(.horizontal, 16)
            }
            
            Spacer(minLength: 0)
            
            InfiniteScroller()
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                Button(action: {
                    showHowTo = true
                    Haptics.fire(.light)
                }) {
                    Text("How to play")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemGray5)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            
//            Button(action: {
//                showDesign = true
//                Haptics.fire(.light)
//            }) {
//                Text("Design game mode")
//                    .font(.dmSans(size: 15, weight: .medium))
//                    .foregroundColor(Color.systemBlack)
//                    .alignCenter()
//                    .padding(.horizontal, kPadding)
//                    .padding(.vertical, 12)
//                    .background(Color.systemGray5)
//                    .cornerRadius(8)
//            }
//            .padding(.horizontal, 16)
            
            BigButton(
                style: .solid,
                title: "Quick draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: quickDrawTapped
            )
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    private var cardsView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("The Strategy Pack")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                
                VStack(spacing: 2) {
                    Text("A collection of amusing scenarios designed to")
                    Text("make you enjoy golf in a refreshing way.").bold()
                }
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.systemGrayDark)
            }
            
//            Spacer(minLength: 0)
            
            // Fun icons here like the app setup view with borders
//            IconMosaicGrid(
//                primary: appSession.gameplayPack.style.primaryColor,
//                secondary: appSession.gameplayPack.style.secondaryColor//,
//                //icons: viewModel.buildMosaic()
//            )
            
//            Spacer(minLength: 0)
            
            //InfiniteScroller()
            
            GradientButton(
                title: "Reveal cards",
                awesomeIcon: "e4df",
                labelTint: .systemBlack,
                backgroundTint: .systemCard,
                primaryTint: appSession.gameplayPack.style.primaryColor,
                secondaryTint: appSession.gameplayPack.style.secondaryColor,
                iconSize: 72,
                fontSize: 28,
                radius: 12,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showReveal = true }
            )
            .padding(16)
            
//            BigButton(
//                style: .solid,
//                title: "Reveal cards",
//                labelColor: Color.systemWhite,
//                buttonColor: Color.systemBlack,
//                //fillContainer: true,
//                fontSize: 32,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: { showReveal = true }
//            )
//            .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                Button(action: {
                    showDiscard = true
                    Haptics.fire(.light)
                }) {
                    Text("Discard")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
//                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemGray5)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showDesign = true
                    Haptics.fire(.light)
                }) {
                    Text("Modify game mode")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                        .padding(.horizontal, kPadding)
                        .padding(.vertical, 12)
                        .background(Color.systemGray5)
                        .cornerRadius(8)
                }
//                .padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)
            
//            Button(action: {
//                showDesign = true
//                Haptics.fire(.light)
//            }) {
//                Text("Modify game mode")
//                    .font(.dmSans(size: 15, weight: .medium))
//                    .foregroundColor(Color.systemBlack)
//                    .alignCenter()
//                    .padding(.horizontal, kPadding)
//                    .padding(.vertical, 12)
//                    .background(Color.systemGray5)
//                    .cornerRadius(8)
//            }
//            .padding(.horizontal, 16)
        }
    }
    
//    private var setupView_: some View {
//        VStack(spacing: kPadding) {
//            VStack(spacing: 8) {
//                Button(action: { showHowTo = true }) {
//                    Text("The Gameplay Pack")
//                        .font(.dmSans(size: 28, weight: .bold))
//                        .foregroundColor(Color.systemBlack)
//                }
//
//                VStack(spacing: 2) {
//                    Text("A collection of amusing scenarios designed to")
//                    Text("make you enjoy golf in a refreshing way.").bold()
//                }
//                .font(.dmSans(size: 15, weight: .regular))
//                .foregroundColor(Color.systemGrayDark)
//            }
//            .padding(.horizontal, kPadding)
//
//            Spacer(minLength: 0)
//
//            InfiniteScroller()
//
//            Spacer(minLength: 0)
//
//            BigButton(
//                style: .solid,
//                title: "Quick draw",
//                labelColor: Color.systemWhite,
//                buttonColor: Color.systemBlack,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: quickDrawTapped
//            )
//            .padding(.horizontal, kPadding)
//            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
//
//            Button(action: {
//                showDesign = true
//                Haptics.fire(.light)
//            }) {
//                Text("Design game mode")
//                    .font(.dmSans(size: 15, weight: .medium))
//                    .foregroundColor(Color.systemBlack)
//                    .alignCenter()
//                    .padding(.horizontal, kPadding)
//                    .padding(.vertical, 12)
//                    .background(Color.systemGray5)
//                    .cornerRadius(8)
//            }
//            .padding(.horizontal, kPadding)
//        }
//    }
//
//    private var cardsView_: some View {
//        VStack(spacing: kPadding) {
//            VStack(spacing: 8) {
//                Button(action: { showHowTo = true }) {
//                    Text("Gameplay is ready!")
//                        .font(.dmSans(size: 28, weight: .bold))
//                        .foregroundColor(Color.systemBlack)
//                }
//
//                Text("Your cards have been drawn for this hole.")
//                    .font(.dmSans(size: 15, weight: .regular))
//                    .foregroundColor(Color.systemGrayDark)
//            }
//            .padding(.horizontal, kPadding)
//
//            Spacer(minLength: 0)
//
//            RuleScroller(viewModel: viewModel)
//                .padding(.vertical, 16)
//
//            Spacer(minLength: 0)
//
//            BigButton(
//                style: .solid,
//                title: "Reveal cards",
//                labelColor: Color.systemWhite,
//                buttonColor: Color.systemBlack,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: revealTapped
//            )
//            .padding(.horizontal, kPadding)
//            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
//
//            HStack(spacing: kPadding) {
//                Button(action: {
//                    showDelete = true
//                    Haptics.fire(.light)
//                }) {
//                    Text("Discard")
//                        .font(.dmSans(size: 15, weight: .medium))
//                        .foregroundColor(Color.systemRed)
//                        .alignCenter()
//                        .padding(.horizontal, kPadding)
//                        .padding(.vertical, 12)
//                        .background(Color.systemGray5)
//                        .cornerRadius(8)
//                }
//
//                Button(action: {
//                    showDesign = true
//                    Haptics.fire(.light)
//                }) {
//                    Text("Modify")
//                        .font(.dmSans(size: 15, weight: .medium))
//                        .foregroundColor(Color.systemBlack)
//                        .alignCenter()
//                        .padding(.horizontal, kPadding)
//                        .padding(.vertical, 12)
//                        .background(Color.systemGray5)
//                        .cornerRadius(8)
//                }
//
////                Button(action: scoreTapped) {
////                    Text("Score")
////                        .font(.dmSans(size: 15, weight: .medium))
////                        .foregroundColor(Color.systemBlack)
////                        .alignCenter()
////                        .padding(.horizontal, kPadding)
////                        .padding(.vertical, 12)
////                        .background(Color.systemGray5)
////                        .cornerRadius(8)
////                }
//            }
//            .padding(.horizontal, kPadding)
//        }
//    }
    
    // MARK: - Delete Card
    
    private var deleteCard: some View {
        VStack(spacing: kPadding / 2) {
            Text("Discard for hole \(viewModel.currentHole)?")
                .font(.dmSans(size: 20, weight: .bold))
            
            Text("Both the team and player rules will be discarded back into the pile.")
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.systemGray)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            HStack(spacing: kPadding) {
                BigButton(
                    title: "Close",
                    labelColor: .systemBlack,
                    buttonColor: colorScheme == .light ? .systemGray5 : .systemGray3,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showDiscard = false })
                BigButton(
                    title: "Discard",
                    labelColor: .white,
                    buttonColor: .systemRed,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        viewModel.clearHoleRule()
                        showDiscard = false
                    })
            }
        }
        .padding(kPadding)
        .padding(.top, kPadding)
        .background(Color.systemCard)
    }
    
    // MARK: - Button Actions
    
    private func quickDrawTapped() {
        Task { await viewModel.draw() }
    }
}

struct GameplayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GameplayView(viewModel: RoundViewModel(), hole: 1)
                .environmentObject(AppSession())
                .lightModePreview()
            GameplayView(viewModel: RoundViewModel(), hole: 1)
                .environmentObject(AppSession())
                .darkModePreview()
        }
    }
}
