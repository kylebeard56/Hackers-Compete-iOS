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
    // TODO: ^ Add future Caddy and Drinking view models or find a way to simplify data inputs.
    // It should honestly be three different views that are similar but split.
    // AppSession has revealGameplay, revealCaddy, and revealDrinking
    // From there, we can control which is shown in HoleView ZStack
    
    @StateObject var vm = CardRevealViewModel()
    
    var body: some View {
        ZStack {
            Blur(style: .dark).onTapGesture(perform: close)
            if viewModel.doesRuleExist(for: viewModel.currentHole) {
                content
            } else {
                Text("These cards were discarded")
                    .font(.dmSans(size: 15, weight: .regular))
                    .italic()
                    .foregroundColor(Color.white)
            }
        }
        .edgesIgnoringSafeArea(.vertical)
        .environmentObject(appSession)
    }
    
    // MARK: - Content
    
    private var content: some View {
        TabView(selection: $vm.tab) {
            if let rule = viewModel.getTeamRule() {
                CardDetailView(
                    rule: rule,
                    player: Player(difficulty: viewModel.teamDifficulty, redrawCount: viewModel.teamRedrawCount),
                    onRedraw: redrawTeamTapped,
                    onClose: close
                )
                .tag("team")
                .padding(.bottom, kPadding)
            }
            ForEach(viewModel.players, id: \.self) { player in
                if let rule = viewModel.getPlayerRule(for: player.id) {
                    CardDetailView(
                        rule: rule,
                        player: player,
                        onRedraw: { redrawPlayerTapped(for: player) },
                        onClose: close
                    )
                    .tag(player.id)
                    .padding(.bottom, kPadding)
                    .onAppear() {
                        print("\(player.name), \(rule.name)")
                    }
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.bottom, kPadding)
        .onChange(of: vm.tab, perform: { _ in Haptics.fire(.light) })
    }
    
    private func close() {
        appSession.revealCards = false
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
                HoleView()
                CardRevealView(viewModel: RoundViewModel())
            }
            .environmentObject(appSession)
            .lightModePreview()
            
            ZStack {
                HoleView()
                CardRevealView(viewModel: RoundViewModel())
            }
            .environmentObject(appSession)
            .darkModePreview()
        }
    }
}
