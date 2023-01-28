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
    
    @StateObject var viewModel: GameplayViewModel
    @StateObject var vm = GameplayDesignViewModel()
    
    var isRedraw: Bool = false

    private let menuTint: Color = Color.systemBlack.opacity(06)
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
                    
                    shuffleCount
                        .padding(.top, kPadding * 2)
                    
                }
                .padding(.bottom, 64)
            }
            
            Spacer(minLength: 0)
            
            //Divider()
            
            BigButton(
                style: .solid,
                title: isRedraw ? "Redraw" : "Draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: { isRedraw ? redrawTapped() : drawTapped() }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Card Difficulty
    
    private var cardDifficulty: some View {
        VStack(spacing: 12) {
            Text("Card Difficulty")
                .font(.dmSans(size: 22, weight: .bold))
                .foregroundStyle(kGameplayPack.style.linearGradient)
                .alignLeading()
            
            Group {
                Text("As the level of difficult increases, favor cards become more rare. ")
                + Text("Choose wisely based on skill level.").bold()
            }
            .font(.dmSans(size: 14, weight: .regular))
            .foregroundColor(Color.systemGray)
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
                
                Picker("", selection: $vm.teamDifficulty) {
                    Text("Easy").tag(PlayerDifficulty.easy)
                    Text("Medium").tag(PlayerDifficulty.medium)
                    Text("Hard").tag(PlayerDifficulty.hard)
                }
                .scaleEffect(0.9)
                .pickerStyle(.menu)
                .tint(menuTint)
                .background(Color.systemGray6)
                .cornerRadius(4)
            }
            
            Divider()
            
            ForEach(0..<vm.players.count, id: \.self) { i in
                HStack {
                    Text(vm.players[i].name)
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Spacer()
                    
                    Picker("", selection: $vm.players[i].difficulty) {
                        Text("Easy").tag(PlayerDifficulty.easy)
                        Text("Medium").tag(PlayerDifficulty.medium)
                        Text("Hard").tag(PlayerDifficulty.hard)
                    }
                    .scaleEffect(menuScale)
                    .pickerStyle(.menu)
                    .tint(menuTint)
                    .background(Color.systemGray6)
                    .cornerRadius(4)
                }
                
                Divider()
            }
        }
    }
    
    // MARK: - Shuffle Count
    
    private var shuffleCount: some View {
        VStack(spacing: kPadding) {
            Text("How many shuffles?")
                .font(.dmSans(size: 22, weight: .bold))
                .foregroundStyle(kGameplayPack.style.linearGradient)
                .alignLeading()
            
            Text("Limit the number of times a card can be redrawn per hole. Shuffling won't change the card type.")
                .font(.dmSans(size: 14, weight: .regular))
                .foregroundColor(Color.systemGray)
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
                
                Picker("", selection: $vm.teamShuffleCount) {
                    Text("None").tag(0)
                    Text("One").tag(1)
                    Text("Two").tag(2)
                    Text("Three").tag(3)
                    Text("Unlimited").tag(4)
                }
                .scaleEffect(menuScale)
                .pickerStyle(.menu)
                .tint(menuTint)
                .background(Color.systemGray6)
                .cornerRadius(4)
            }
            
            Divider()
            
            ForEach(0..<vm.players.count, id: \.self) { i in
                HStack {
                    Text(vm.players[i].name)
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Spacer()
                    
                    Picker("", selection: $vm.players[i].shuffleCount) {
                        Text("None").tag(0)
                        Text("One").tag(1)
                        Text("Two").tag(2)
                        Text("Three").tag(3)
                        Text("Unlimited").tag(4)
                    }
                    .scaleEffect(menuScale)
                    .pickerStyle(.menu)
                    .tint(menuTint)
                    .background(Color.systemGray6)
                    .cornerRadius(4)
                }
                Divider()
            }
        }
    }

    // MARK: - Button Actions
    
    private func drawTapped() {
        print(#function)
        dismiss()
    }
    
    private func redrawTapped() {
        print(#function)
        dismiss()
    }
}

struct GameplayDesignModeView_Previews: PreviewProvider {
    static let vm = GameplayViewModel()
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
