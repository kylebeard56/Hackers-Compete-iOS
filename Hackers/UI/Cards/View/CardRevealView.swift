//
//  CardRevealView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import OrderedCollections
import SwiftUI

struct CardRevealView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: GameplayViewModel
    // TODO: ^ Add future Caddy and Drinking view models or find a way to simplify data inputs.
    // It should honestly be three different views that are similar but split.
    // AppSession has revealGameplay, revealCaddy, and revealDrinking
    // From there, we can control which is shown in HoleView ZStack
    
    @StateObject var vm = CardRevealViewModel()
    
    @State private var localPlayers: [Player] = [] //OrderedSet<Player>()
    
    var body: some View {
        ZStack {
            Blur(style: .dark)
            content
        }
        .edgesIgnoringSafeArea(.vertical)
        .environmentObject(appSession)
        .onAppear() {
            localPlayers = Array(viewModel.playerRules.keys)
        }
        .onChange(of: viewModel.playerRules, perform: { p in
            /// Note: Capture this and store locally since publisher doesn't catch changes to OrderedDict keys.
            print("setting local player rules")
            localPlayers = Array(p.keys)
            //printPretty(localPlayers)
        })
    }
    
    // MARK: - Content
    
    private var content: some View {
        TabView(selection: $vm.tab) {
            if let teamRule = viewModel.teamRules[viewModel.currentHole] {
                CardDetailView(
                    rule: teamRule,
                    player: Player(difficulty: viewModel.teamDifficulty, redrawCount: viewModel.teamRedrawCount),
                    onRedraw: redrawTeamTapped,
                    onClose: close
                )
                .tag("team")
                .padding(.bottom, kPadding)
                .onAppear() {
                    print("detail shown for team")
                }
            }
            ForEach(localPlayers, id: \.self) { player in
                if let playerRule = viewModel.playerRules[player]?[viewModel.currentHole] {
                    CardDetailView(
                        rule: playerRule,
                        player: player,
                        onRedraw: { redrawPlayerTapped(for: player) },
                        onClose: close
                    )
                    .tag(player.id)
                    .padding(.bottom, kPadding)
                    .onAppear() {
                        print("detail shown for \(player.name)")
                    }
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.bottom, kPadding)
    }
    
    private func close() {
        //withAnimation(.easeIn(duration: 0.2)) {
            appSession.revealCards = false
        //}
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
                CardRevealView(viewModel: GameplayViewModel())
            }
            .environmentObject(appSession)
            .lightModePreview()
            
            ZStack {
                HoleView()
                CardRevealView(viewModel: GameplayViewModel())
            }
            .environmentObject(appSession)
            .darkModePreview()
        }
    }
}
