//
//  CardRevealView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import SwiftUI

struct CardRevealView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: RoundViewModel
//    @StateObject var vm: CardRevealViewModel
    
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
        .onAppear() {
            UIPageControl.appearance().currentPageIndicatorTintColor = .systemGray2
            UIPageControl.appearance().pageIndicatorTintColor = .systemGray5
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        TabView(selection: $viewModel.revealTab) {
            if let rule = viewModel.getTeamRule() {
                CardDetailView(
                    rule: rule,
                    player: Player(name: "Team", difficulty: viewModel.teamDifficulty, redrawCount: viewModel.teamRedrawCount),
                    onRedraw: redrawTeamTapped
                )
                .tag("team")
                .padding(.vertical, kPadding)
            }
            
            ForEach(viewModel.players, id: \.self) { player in
                if let rule = viewModel.getPlayerRule(for: player.id) {
                    CardDetailView(
                        rule: rule,
                        player: player,
                        onRedraw: { redrawPlayerTapped(for: player) }
                    )
                    .tag(player.id)
                    .padding(.vertical, kPadding)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.bottom, kPadding)
        .onChange(of: viewModel.revealTab, perform: { _ in Haptics.fire(.light) })
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

struct CardRevealView_Previews: PreviewProvider {
    static let appSession = AppSession()
    static var previews: some View {
        Group {
            ZStack {
                RoundView()
                CardRevealView(viewModel: RoundViewModel())
            }
            .environmentObject(appSession)
            .lightModePreview()
            
            ZStack {
                RoundView()
                CardRevealView(viewModel: RoundViewModel())
            }
            .environmentObject(appSession)
            .darkModePreview()
        }
    }
}
