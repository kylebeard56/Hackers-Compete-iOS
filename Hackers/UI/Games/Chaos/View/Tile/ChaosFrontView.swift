//
//  ChaosFrontView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/27/23.
//

import SwiftUI

struct ChaosFrontView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var hole: Int

    @State private var showCards: Bool = false
    @State private var showSetRules: Bool = false
    @State private var showDiscard: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.doesRuleExist(for: hole) {
                drawnView
            } else {
                playView
            }
        }
        .environmentObject(appSession)
        .sheet(isPresented: $showCards, onDismiss: { AppStoreReviewManager.requestReview() }) {
            ChaosCardsRevealView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSetRules) {
            ChaosCardsRulesView(viewModel: viewModel, isRedraw: viewModel.doesRuleExist(for: hole) )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDiscard) {
            deleteCard
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Views
    
    private var header: some View {
        VStack(spacing: 8) {
            if UIScreen.isSmall {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    
                    ZStack {
                        Circle()
                            .fill(Color.systemHackersGreen.opacity(0.125))
                            .frame(width: 34, height: 34)
                        AwesomeImage(rawIcon: "f71d".unicode, style: .light, size: 17, color: .systemHackersGreen)
                    }
                    
                    Text("Cards of Chaos")
                        .font(.fugazOne(size: 24))
                        .foregroundColor(Color.systemHackersGreen)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGreen.opacity(0.125))
                        .frame(width: 56, height: 56)
                    AwesomeImage(rawIcon: "f71d".unicode, style: .light, size: 28, color: .systemHackersGreen)
                }
                
                Text("Cards of Chaos")
                    .font(.fugazOne(size: 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
            }
            
            Text("Draw cards with amusing fortunes for how your party is allowed to play each hole.")
                .font(.dmSans(size: 13, weight: .regular))
                .foregroundColor(Color.systemGray)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var playView: some View {
        VStack(spacing: 8) {
            header
            
            Spacer(minLength: 0)
            
            VStack(spacing: UIScreen.isSmall ? 10 : 16) {
                HStack {
                    Text("Players")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("2+")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
                HStack(spacing: 6) {
                    Text("Complexity")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    
                    Circle()
                        .fill(Color.systemHackersGreen)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.systemHackersGreen)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3)
                        .frame(width: 6, height: 6)
                }
                HStack {
                    Text("True scoring")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("No")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
                HStack {
                    Text("Pace of play")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("Slower")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
            }
            .padding(16)
            .border(Color.systemGray6, width: 2, cornerRadius: 8)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                Button(action: {
                    showSetRules = true
                    // TODO: Update firebase
                    FirebaseEvent.modifyGameModeTapped.log()
                    Haptics.fire(.light)
                }) {
                    Text("Rules")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
                Button(action: {
                    playNowTapped()
                    Haptics.fire(.light)
                }) {
                    Text(viewModel.chaosCardsIsLive() ? "Continue play" : "Play now")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemWhite)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemBlack)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var drawnView: some View {
        VStack(spacing: 0) {
            header
            
            Spacer(minLength: 0)
            
            Button(action: {
                showCards = true
                Haptics.fire(.light)
            }) {
                VStack(spacing: UIScreen.isSmall ? 12 : 24) {
                    AwesomeImage(rawIcon: "e4df".unicode, style: .light, size: UIScreen.isSmall ? 48 : 80, color: .systemHackersGreen)
                    
                    Text("Show cards")
                        .font(.fugazOne(size: UIScreen.isSmall ? 17 : 24))
                        .foregroundColor(Color.systemHackersGreen)
                        .alignCenter()
                }
                .padding(16)
                .alignMiddle()
                .background(Color.systemHackersGreen.opacity(0.125))
                .border(Color.systemHackersGreen, width: 8, cornerRadius: 12)
                .cornerRadius(12)
                .padding(.vertical, UIScreen.isSmall ? 12 : 24)
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                Button(action: {
                    showDiscard = true
                    // TODO: Update firebase
                    FirebaseEvent.discardCardsTapped.log()
                    Haptics.fire(.light)
                }) {
                    Text("Discard")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
                Button(action: {
                    showSetRules = true
                    // TODO: Update firebase
                    FirebaseEvent.modifyGameModeTapped.log()
                    Haptics.fire(.light)
                }) {
                    Text("Modify rules")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemWhite)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemBlack)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Delete Card
    
    private var deleteCard: some View {
        VStack(spacing: 8) {
//            Text("Put 'em back?")
//                .font(.fugazOne(size: 32))
//
//            Text("All cards will be put back into the pile.")
//                .font(.dmSans(size: 15, weight: .regular))
//                .foregroundColor(Color.systemGray)
//                .lineSpacing(2)
//                .multilineTextAlignment(.center)
//                .fixedSize(horizontal: false, vertical: true)
            
            Text("Wanna put 'em back?")
                .font(.fugazOne(size: 32))
                .foregroundColor(Color.systemBlack)
                .padding(.top, 16)
                .alignCenter()
            
            Text("Cards for hole \(viewModel.currentHole) will go back in the draw pile.")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.center)
                .alignCenter()
            
            Spacer(minLength: 0)
            
            HStack(spacing: kPadding) {
                BigButton(
                    title: "Close",
                    labelColor: .systemBlack,
                    buttonColor: colorScheme == .light ? .systemGray6 : .systemGray3,
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
        .padding(16)
        .background(Color.systemCard)
    }
    
    // MARK: - Button actions
    
    private func playNowTapped() {
        // TODO: Update firebase
        FirebaseEvent.quickDrawTapped.log()
        Task { await viewModel.draw() }
    }
}

struct ChaosFrontView_Previews: PreviewProvider {
    static var view: some View {
        RoundView()
            .environmentObject(AppSession())
//        ZStack {
//            Color.systemGray5.edgesIgnoringSafeArea(.all)
//            ChaosFrontView(viewModel: RoundViewModel(), hole: 1)
//                .environmentObject(AppSession())
//                .padding(16)
//                .background(Color.systemWhite)
//                .cornerRadius(12)
//                .padding(16)
//        }
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
