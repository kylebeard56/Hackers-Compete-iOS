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
    @StateObject var viewModel: GameplayViewModel
    
    @State private var showCustomize: Bool = false
    @State private var showRedraw: Bool = false
    @State private var showDelete: Bool = false
    
    private let kShuffleDelay: CGFloat = 0.375
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rulesExist[viewModel.currentHole] ?? false {
                if viewModel.isDrawing {
                    skeletonView
                } else {
                    cardsView
                }
            } else {
                setupView
            }
        }
        .environmentObject(appSession)
        .sheet(isPresented: $showCustomize) {
            CustomizeGameplayView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRedraw) {
            CustomizeGameplayView(viewModel: viewModel, isRedraw: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDelete) {
            deleteCard
                .presentationDetents([.height(225)])
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
            
            InfiniteScroller()
            
            Spacer(minLength: 0)
            
//            BigButton(
//                style: .outline,
//                title: "Customize",
//                labelColor: Color.systemBlack,
//                buttonColor: Color.systemBlack,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: { showCustomize = true }
//            )
//            .padding(.horizontal, kPadding)
//            .padding(.bottom, kPadding / 2)
            
            BigButton(
                style: .solid,
                title: "Quick Draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                //gradient: appSession.gameplayPack.style.linearGradient,
                isDisabled: .false,
                isLoading: .false,
                onTap: quickDrawTapped
            )
            .padding(.horizontal, kPadding)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            Button(action: {
                showCustomize = true
                Haptics.fire(.light)
            }) {
                Text("Customize")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .padding(.horizontal, kPadding)
                    .padding(.vertical, kPadding / 2)
            }
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
        VStack {
            teamRuleSection
            playerRuleSection
            buttonToolbar
        }
        .padding(.horizontal, kPadding)
    }
    
    // MARK: - Rule Sections
    
    private var teamRuleSection: some View {
        VStack(spacing: kPadding) {
            teamRuleHeader
            
            if let teamRule = viewModel.teamRules[viewModel.currentHole] {
                GameplayCard(rule: teamRule, onShuffle: {
                    Task { await viewModel.drawTeamRule() }
                    Haptics.fire(.light)
                })
            } else {
                teamRuleMissing
            }
        }
    }
    
    private var playerRuleSection: some View {
        VStack(spacing: kPadding) {
            playerRuleHeader
            
            ForEach(viewModel.playerRules.keys, id: \.self) { player in
                if let playerRule = viewModel.playerRules[player]?[viewModel.currentHole] {
                    GameplayCard(rule: playerRule, player: player, onShuffle: {
                        Task { await viewModel.drawPlayerRule(for: player) }
                        Haptics.fire(.light)
                    })
                } else {
                    playerRuleMissing(player.name)
                }
            }
        }
    }
    
    // MARK: - Section Components
    
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
                AwesomeImage(icon: viewModel.teamDifficulty.icon, style: .regular, size: 12, color: Color.systemBlack)
                Text(viewModel.teamDifficulty.name)
                    .font(.dmSans(size: 12, weight: .medium))
                    .foregroundColor(Color.systemBlack)
            }
            .padding(.vertical, 4)
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
                AwesomeImage(icon: viewModel.playerDifficulty.icon, style: .regular, size: 12, color: Color.systemBlack)
                Text(viewModel.playerDifficulty.name)
                    .font(.dmSans(size: 12, weight: .medium))
                    .foregroundColor(Color.systemBlack)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .border(Color.systemBlack, width: 1, cornerRadius: 4)
        }
    }
    
    private var teamRuleMissing: some View {
        HStack(spacing: kPadding) {
            AwesomeImage(icon: .cardsBlank, style: .regular, size: 20, color: Color.systemGray)
            Group {
                Text("Oops!").bold()
                + Text(" This team rule is missing and it's our fault  - sorry...")
            }
            .font(.dmSans(size: 13))
            .foregroundColor(Color.systemGray)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .alignLeading()
        }
        .padding(kPadding)
        .background(Color.systemGray6)
        .cornerRadius(10)
    }
    
    private func playerRuleMissing(_ name: String) -> some View {
        HStack(spacing: kPadding) {
            AwesomeImage(icon: .cardsBlank, style: .regular, size: 20, color: Color.systemGray)
            Group {
                Text("Oops!").bold()
                + Text(" The rule for \(name) is missing and it's our fault - sorry...")
            }
            .font(.dmSans(size: 13))
            .foregroundColor(Color.systemGray)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .alignLeading()
        }
        .padding(kPadding)
        .background(Color.systemGray6)
        .cornerRadius(10)
    }
    
    // MARK: - Delete Card
    
    private var deleteCard: some View {
        VStack(spacing: kPadding / 2) {
            Text("Remove for hole \(viewModel.currentHole)?")
                .font(.dmSans(size: 20, weight: .bold))
            
            Text("Both the team and player rules will be discarded back into the pile. Have no fear, they can be redrawn again!")
                .font(.dmSans(size: 15, weight: .regular))
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
                    onTap: { showDelete = false })
                BigButton(
                    title: "Remove",
                    labelColor: .white,
                    buttonColor: .systemRed,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        viewModel.clearHoleRule()
                        showDelete = false
                    })
            }
        }
        .padding(kPadding)
        .padding(.top, kPadding)
        .background(Color.systemCard)
    }
    
    // MARK: - Button Toolbar
    
    private var buttonToolbar: some View {
        HStack(spacing: kPadding) {
            Button(action: {
                //viewModel.clearHoleRule()
                showDelete = true
                Haptics.fire(.light)
            }) {
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
                onTap: {
                    quickDrawTapped()
                    Haptics.fire(.light)
                }
            )
            
            Button(action: {
                showRedraw = true
                Haptics.fire(.light)
            }) {
                AwesomeImage(icon: .pencil, style: .regular, size: 20, color: Color.systemBlack)
                    .frame(width: 56, height: 56)
                    .border(Color.systemBlack, width: 2, cornerRadius: 10)
            }
        }
        .padding(.vertical, kPadding)
    }
    
    // MARK: - Button Actions
    
    private func quickDrawTapped() {
        Task {
            await viewModel.draw(random: true)
        }
    }
}

struct GameplayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GameplayView(viewModel: GameplayViewModel())
                .environmentObject(AppSession())
                .lightModePreview()
            GameplayView(viewModel: GameplayViewModel())
                .environmentObject(AppSession())
                .darkModePreview()
        }
    }
}
