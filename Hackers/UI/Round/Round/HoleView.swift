//
//  HoleView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/23/23.
//

import SwiftUI

struct HoleView: View {
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    @State private var showHoleList: Bool = false
    @State private var showHoleScoring: Bool = false
    @State private var showPlayerScoring: Bool = false
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Button(action: {
                    showHoleList = true
                    Haptics.fire(.light)
                }) {
                    Text("Hole \(hole)")
                        .font(.dmSans(size: 36, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                }
                .alignLeading()
                
                scorecardTile
                gamepackCards
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showHoleList) {
            HoleListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHoleScoring) {
            HoleScoringView(players: $viewModel.players, hole: hole)
                .presentationDetents([.height(viewModel.holeScoringHeight)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlayerScoring) {
            PlayerScoringView(players: $viewModel.players, index: $selectedIndex, hole: hole)
                .presentationDetents([.height(375), .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var scorecardTile: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Scorecard")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Button(action: { showHoleScoring = true }) {
                    AwesomeImage(icon: .squarePlus, style: .regular, size: 20, color: .systemBlack)
                }
            }
            
            if viewModel.scoringExists(for: hole) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Spacer().frame(width: 8)
                        ForEach(viewModel.players, id: \.self) { player in
                            Button(action: {
                                selectedPlayer = player
                                selectedIndex = viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0
                                showPlayerScoring = true
                                Haptics.fire(.light)
                            }) {
                                scoringTile(for: player)
                            }
                        }
                        Spacer().frame(width: 8)
                    }
                    .frame(minWidth: UIScreen.main.bounds.width - 32)
                }
                .padding(.horizontal, -16)
            } else {
                Text("Add score to get metrics for your round")
                    .font(.dmSans(size: 15, weight: .regular))
                    .foregroundColor(Color.systemGray2)
                    .alignCenter()
            }
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .border(Color.systemGray5, width: 1, cornerRadius: 8)
    }
    
    private func scoringTile(for p: Player) -> some View {
        VStack(spacing: 6) {
            Text(p.name)
                .font(.dmSans(size: 13, weight: .medium))
                .foregroundColor(p.color.value)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .alignLeading()
            HStack(spacing: 4) {
                Text(p.textualScore(for: hole))
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
//                if hole > 1 {
//                    Text("(\(p.scoringSum(for: 1...hole))")
//                        .font(.dmSans(size: 15, weight: .medium))
//                        .foregroundColor(Color.systemGray)
//                }
                    
                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .background(Color.systemCard)
        .border(Color.systemGray5, width: 2, cornerRadius: 6)
        .cornerRadius(6)
    }
    
    private var gamepackCards: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Game packs")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer()
                
                Button(action: { print("todo: show popup about packs") }) {
                    AwesomeImage(rawIcon: "f05a".unicode, style: .regular, size: 20, color: .systemBlack)
                }
            }

            Picker("", selection: $appSession.activePack) {
                Text("Strategy").padding(.top, 8).tag(0)
                Text("Drinking").padding(.top, 8).tag(1)
            }
            .pickerStyle(.segmented)
            .tint(Color.systemGray5)
            
            if appSession.activePack == 0 {
                GameplayView(viewModel: viewModel, hole: hole)
                    .padding(.vertical, 16)
                    .padding(.horizontal, -16)
            }
            if appSession.activePack == 1 {
                drinkingPackView
                    .padding(.vertical, 16)
                    .padding(.horizontal, -16)
            }
             
//            TabView(selection: $appSession.activePack) {
//                GameplayView(viewModel: viewModel).tag(0)
//                drinkingPackView.tag(1)
//            }
//            .tabViewStyle(.page(indexDisplayMode: .never))
//            .padding(.horizontal, -16)
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
        .border(Color.systemGray5, width: 1, cornerRadius: 8)
    }
    
    private var strategyPackView: some View {
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
            
            Spacer(minLength: 0)
            
            InfiniteScroller()
            
            Spacer(minLength: 0)
            
            Button(action: {
                print("todo: show design game mode")
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
            .padding(.horizontal, 16)
            
            BigButton(
                style: .solid,
                title: "Quick draw",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: { print("todo: draw now") }
            )
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    private var drinkingPackView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("The Drinking Pack")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                
                VStack(spacing: 2) {
                    Text("The only thing better than hitting a great shot is")
                    Text("making someone drink because you did it").bold()
                }
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.systemGrayDark)
                
            }
            
            Spacer(minLength: 0)

            GradientButton(
                title: "Join the waitlist",
                subtitle: "This pack is currently under construction.",
                awesomeIcon: "e0b3",
                labelTint: .systemBlack,
                backgroundTint: .systemCard,
                primaryTint: appSession.drinkingPack.style.primaryColor,
                secondaryTint: appSession.drinkingPack.style.secondaryColor,
                iconSize: 72,
                fontSize: 28,
                radius: 12,
                isDisabled: .false,
                isLoading: .false,
                onTap: { print("todo: show waitlist email") }
            )
        }
        .padding(.horizontal, 16)
    }
}

struct HoleView_Previews: PreviewProvider {
    static var view: some View {
        HoleView(viewModel: RoundViewModel(), hole: 1)
            .environmentObject(AppSession())
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
