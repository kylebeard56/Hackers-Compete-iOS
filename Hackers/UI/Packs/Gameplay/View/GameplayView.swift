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
    
    @State private var showDesign: Bool = false
    @State private var isRedraw: Bool = false
    @State private var showHowTo: Bool = false
    @State private var showDelete: Bool = false
    
    private let kShuffleDelay: CGFloat = 0.375
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rulesExist[viewModel.currentHole] ?? false {
                if viewModel.isDrawing {
                    //skeletonView
                    ProgressView()
                } else {
                    cardsView
                }
            } else {
                setupView
            }
        }
        .environmentObject(appSession)
        .sheet(isPresented: $showDesign) {
            GameplayDesignModeView(
                viewModel: viewModel,
                isRedraw: viewModel.rulesExist[viewModel.currentHole] ?? false
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHowTo) {
            GameplayHowToView()
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
        VStack(spacing: kPadding) {
            Button(action: { showHowTo = true }) {
                Text("The Gameplay Pack")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
            }
            .padding(.horizontal, kPadding)
            
            VStack(spacing: 2) {
                Text("A collection of amusing scenarios designed to")
                Text("make you enjoy golf in a refreshing way.").bold()
            }
            .font(.dmSans(size: 15, weight: .regular))
            .padding(.horizontal, kPadding)
           
            Spacer(minLength: 0)
            
            InfiniteScroller()
            
            Spacer(minLength: 0)
            
            BigButton(
                style: .solid,
                title: "Quick draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: quickDrawTapped
            )
            .padding(.horizontal, kPadding)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            Button(action: {
                showDesign = true
                Haptics.fire(.light)
            }) {
                Text("Design game mode")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                    .padding(.horizontal, kPadding)
                    .padding(.vertical, 12)
                    .background(Color.systemGray5)
                    .cornerRadius(8)
            }
            .padding(.horizontal, kPadding)
        }
    }
    
    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: kPadding) {
                ForEach(0...(viewModel.players.count + 1), id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, kPadding)
        }
    }
    
    private var cardsView: some View {
        VStack(spacing: kPadding) {
            Button(action: { showHowTo = true }) {
                Text("Gameplay is ready!")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
            }
            .padding(.horizontal, kPadding)
            
            Text("Your cards have been drawn for this hole.")
                .font(.dmSans(size: 15, weight: .regular))
                .padding(.horizontal, kPadding)
                .multilineTextAlignment(.center)
           
            Spacer(minLength: 0)
            
            ZStack {
                RuleScroller(viewModel: viewModel)
                    .padding(.vertical, 16)
                Button(action: {
                    Haptics.fire(.light)
                    viewModel.rulesRevealed[viewModel.currentHole] = true
                }) {
                    ZStack {
                        Blur(style: colorScheme == .light ? .light : .dark)
                        Text("Want a hint?")
                            .font(.dmSans(size: 20, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                    }
                }
                .opacity(viewModel.rulesRevealed[viewModel.currentHole] ? 0 : 1)
            }
            
            Spacer(minLength: 0)
            
            BigButton(
                style: .solid,
                title: "Reveal cards",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: revealTapped
            )
            .padding(.horizontal, kPadding)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            HStack(spacing: kPadding) {
                Button(action: {
                    showDelete = true
                    Haptics.fire(.light)
                }) {
                    Text("Discard")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemRed)
                        .alignCenter()
                        .padding(.horizontal, kPadding)
                        .padding(.vertical, 12)
                        .background(Color.systemGray5)
                        .cornerRadius(8)
                }
                Button(action: {
                    showDesign = true
                    Haptics.fire(.light)
                }) {
                    Text("Modify")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                        .padding(.horizontal, kPadding)
                        .padding(.vertical, 12)
                        .background(Color.systemGray5)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, kPadding)
        }
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
    
    // MARK: - Button Actions
    
    private func revealTapped() {
        viewModel.rulesRevealed[viewModel.currentHole] = true
        withAnimation(.easeOut) {
            appSession.revealCards = true
            appSession.revealedView = .gameplay
        }
    }
    
    private func quickDrawTapped() {
        Task {
            await viewModel.draw()
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
