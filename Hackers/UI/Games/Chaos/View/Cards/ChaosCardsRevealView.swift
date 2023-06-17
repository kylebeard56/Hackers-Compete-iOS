//
//  ChaosCardsRevealView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import SwiftUI

// https://betterprogramming.pub/custom-paging-ui-in-swiftui-13f1347cf529

struct ChaosCardsRevealView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: RoundViewModel
    
    @State private var tab: String = "team"
    
    var body: some View {
        ZStack {
            if viewModel.doesRuleExist(for: viewModel.currentHole) {
                content
            } else {
                Text("These cards were discarded")
                    .font(.dmSans(size: 15, weight: .regular))
                    .italic()
                    .foregroundColor(Color.white)
            }
            
            Button(action: close) {
                AwesomeImage(icon: .xmark, style: .solid, size: 20, color: .systemBlack)
                    .padding(16)
            }
            .alignTop()
            .alignTrailing()
        }
        .edgesIgnoringSafeArea(.vertical)
        .environmentObject(appSession)
        .background(Color.systemViewBackground)
//        .background(
//            ZStack {
//                if appSession.revealTab == "team" {
//                    Color.systemHackersGreen.opacity(0.025)
//                } else {
//                    viewModel.players
//                        .first(where: { $0.id == appSession.revealTab })?.color.value
//                        .opacity(0.025) ?? Color.systemViewBackground
//                }
//            }
//        )
        .onAppear() {
            UIPageControl.appearance().currentPageIndicatorTintColor = .systemGray2
            UIPageControl.appearance().pageIndicatorTintColor = .systemGray5
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        TabView(selection: $appSession.revealTab) {
            if let rule = viewModel.getTeamRule() {
                ChaosCardsDetailView(
                    rule: rule,
                    player: Player(name: "Team", difficulty: viewModel.teamDifficulty, redrawCount: viewModel.teamRedrawCount),
                    onRedraw: redrawTeamTapped
                )
                .tag("team")
                .padding(.vertical, 16)
            }
            
            ForEach(viewModel.players, id: \.self) { player in
                if let rule = viewModel.getPlayerRule(for: player.id) {
                    ChaosCardsDetailView(
                        rule: rule,
                        player: player,
                        onRedraw: { redrawPlayerTapped(for: player) }
                    )
                    .tag(player.id)
                    .padding(.vertical, 16)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.bottom, 16)
        .onChange(of: appSession.revealTab, perform: { _ in Haptics.fire(.light) })
    }
    
    private func close() {
        print(#function)
        dismiss()
        Haptics.fire(.light)
    }
    
    private func redrawTeamTapped() {
        Task(operation: viewModel.redrawTeamCard)
    }
    
    private func redrawPlayerTapped(for p: Player) {
        Task {
            do {
                try await viewModel.redrawCard(for: p)
            } catch {
                print("error redrawing player, show toast")
            }
        }
    }
}

struct ChaosCardsRevealView_Previews: PreviewProvider {
    static let appSession = AppSession()
    static var previews: some View {
        Group {
            ZStack {
                RoundView()
                ChaosCardsRevealView(viewModel: RoundViewModel())
            }
            .environmentObject(appSession)
            .lightModePreview()
            
            ZStack {
                RoundView()
                ChaosCardsRevealView(viewModel: RoundViewModel())
            }
            .environmentObject(appSession)
            .darkModePreview()
        }
    }
}
