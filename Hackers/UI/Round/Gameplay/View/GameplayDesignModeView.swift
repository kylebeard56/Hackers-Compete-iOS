//
//  GameplayDesignModeView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SwiftUI

struct GameplayDesignModeView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: RoundViewModel
    @StateObject var vm = GameplayDesignViewModel()
    
    var isRedraw: Bool = false

    private let menuTint: Color = Color.systemBlack.opacity(0.69)
    private let menuScale: CGFloat = 0.9
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(.top, kPadding / 2)
            content
                .padding(.top, kPadding)
        }
        .environmentObject(appSession)
        .padding(kPadding)
        .background(Color.systemCard)
        .onAppear() {
            vm.teamRedrawCount = viewModel.teamRedrawCount
            vm.teamDifficulty = viewModel.teamDifficulty
            vm.players = viewModel.players
        }
    }
    
    // MARK: - Content
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            Text("Design Game Mode")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
    }
    
    private var content: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: kPadding / 2) {
                    cardDifficulty
                    
                    redrawCount
                        .padding(.top, kPadding * 2)
                }
                .padding(.horizontal, kPadding)
                .padding(.bottom, 64)
            }
            .padding(.horizontal, -kPadding)
            
            Spacer(minLength: 0)
            
            BigButton(
                style: .solid,
                title: isRedraw ? "Redraw" : "Draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: drawTapped
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Card Difficulty
    
    private var cardDifficulty: some View {
        VStack(spacing: 12) {
            Text("Card Difficulty")
                .font(.dmSans(size: 22, weight: .bold))
                .foregroundStyle(appSession.gameplayPack.style.linearGradient)
                .alignLeading()
            
            Group {
                Text("As the level of difficult increases, favor cards become more rare. ")
                + Text("Choose wisely based on skill level.").bold()
            }
            .font(.dmSans(size: 14, weight: .regular))
            .foregroundColor(Color.systemBlack)
            .alignLeading()
            .padding(.top, -8)
            .padding(.bottom, 8)
            
            Divider()
            
            HStack {
                Text("Team")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Spacer()
                
                Menu {
                    Button(action: { vm.teamDifficulty = GameDifficulty.easy }) {
                        Text(GameDifficulty.easy.label)
                    }
                    Button(action: { vm.teamDifficulty = GameDifficulty.medium }) {
                        Text(GameDifficulty.medium.label)
                    }
                    Button(action: { vm.teamDifficulty = GameDifficulty.hard }) {
                        Text(GameDifficulty.hard.label)
                    }
                } label: {
                    Text(vm.teamDifficulty.label)
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(4)
                        .alignTrailing()
                }
                .onTapGesture {
                    Haptics.fire(.light)
                    FirebaseEvent.teamDifficultyModified.log()
                }
            }
            
            Divider()
            
            ForEach(0..<vm.players.count, id: \.self) { i in
                HStack {
                    Text(vm.players[i].name)
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { vm.players[i].difficulty = GameDifficulty.easy }) {
                            Text(GameDifficulty.easy.label)
                        }
                        Button(action: { vm.players[i].difficulty = GameDifficulty.medium }) {
                            Text(GameDifficulty.medium.label)
                        }
                        Button(action: { vm.players[i].difficulty = GameDifficulty.hard }) {
                            Text(GameDifficulty.hard.label)
                        }
                    } label: {
                        Text(vm.players[i].difficulty.label)
                            .font(.dmSans(size: 15, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.systemGray6)
                            .cornerRadius(4)
                            .alignTrailing()
                    }
                    .onTapGesture {
                        Haptics.fire(.light)
                        FirebaseEvent.playerDifficultyModified.log()
                    }
                }
                
                Divider()
            }
        }
    }
    
    // MARK: - Shuffle Count
    
    private var redrawCount: some View {
        VStack(spacing: kPadding) {
            Text("How many redraws?")
                .font(.dmSans(size: 22, weight: .bold))
                .foregroundStyle(appSession.gameplayPack.style.linearGradient)
                .alignLeading()
            
            Text("Like a mulligan for cards, test your luck at redrawing for a more favorable ruling during the round.")
                .font(.dmSans(size: 14, weight: .regular))
                .foregroundColor(Color.systemBlack)
                .multilineTextAlignment(.leading)
                .alignLeading()
                .padding(.top, -8)
                .padding(.bottom, 8)
            
            Divider()
            
            HStack {
                Text("Team")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Spacer()
                
                Menu {
                    ForEach(0...6, id: \.self) { c in
                        Button(action: { vm.teamRedrawCount = c }) {
                            Text(c == 0 ? "None" : c == 6 ? "Unlimited" : "\(c)")
                        }
                    }
                } label: {
                    Text(vm.teamRedrawCount == 0
                         ? "None" : vm.teamRedrawCount == 6
                         ? "Unlimited" : "\(vm.teamRedrawCount)"
                    )
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.systemGray6)
                    .cornerRadius(4)
                    .alignTrailing()
                }
                .onTapGesture {
                    Haptics.fire(.light)
                    FirebaseEvent.teamRedrawsModified.log()
                }
            }
            
            Divider()
            
            ForEach(0..<vm.players.count, id: \.self) { i in
                HStack {
                    Text(vm.players[i].name)
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Spacer()
                    
                    Menu {
                        ForEach(0...6, id: \.self) { c in
                            Button(action: { vm.players[i].redrawCount = c }) {
                                Text(c == 0 ? "None" : c == 6 ? "Unlimited" : "\(c)")
                            }
                        }
                    } label: {
                        Text(vm.players[i].redrawCount == 0
                             ? "None" : vm.players[i].redrawCount == 6
                             ? "Unlimited" : "\(vm.players[i].redrawCount)"
                        )
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(4)
                        .alignTrailing()
                    }
                    .onTapGesture {
                        Haptics.fire(.light)
                        FirebaseEvent.playerRedrawsModified.log()
                    }
                }
                Divider()
            }
        }
    }

    // MARK: - Button Actions
    
    private func drawTapped() {
        print(#function)
        viewModel.teamDifficulty = vm.teamDifficulty
        viewModel.teamRedrawCount = vm.teamRedrawCount
        
        viewModel.players = vm.players
        Task(operation: viewModel.draw)
        dismiss()
    }
}

struct GameplayDesignModeView_Previews: PreviewProvider {
    static let vm = RoundViewModel()
    static let appSession = AppSession()
    static var previews: some View {
        Group {
            GameplayDesignModeView(viewModel: vm)
            .environmentObject(appSession)
            .lightModePreview()
            
            GameplayDesignModeView(viewModel: vm)
            .environmentObject(appSession)
            .darkModePreview()
            
            GameplayDesignModeView(viewModel: vm)
            .environmentObject(appSession)
            .previewDevice("iPhone 8")
            .previewDisplayName("iPhone 8")
        }
    }
}
