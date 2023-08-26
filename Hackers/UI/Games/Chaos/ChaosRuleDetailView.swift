//
//  ChaosRuleDetailView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct ChaosRuleDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var teamRule: Rule?
    @State private var playerRules: [String: Rule] = [:]
    @State private var arr: ChaosCardsArrangement?
    
    var body: some View {
        ZStack {
            let _ = Self._printChanges()
            
            VStack {
                content
                
                if viewModel.sideGameSession.chaos?.redraws ?? false {
                    Group {
                        if let player = roundSession.players.first(where: { $0.id == roundSession.chaosTab }) {
                            BigButton(
                                title: "Redraw",
                                buttonColor: player.color.value,
                                isDisabled: .false,
                                isLoading: .false
                            )
                            .onTap { redrawPlayerTapped(for: player) }
                            
                        } else if roundSession.chaosTab == "team" {
                            BigButton(
                                title: "Redraw",
                                labelColor: Color.systemWhite,
                                buttonColor: Color.systemBlack,
                                isDisabled: .false,
                                isLoading: .false
                            )
                            .onTap { redrawTeamTapped() }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Button(action: close) {
                AwesomeImage(icon: .xmark, style: .solid, size: 20, color: .systemBlack)
                    .padding(20)
            }
            .alignTop()
            .alignTrailing()
        }
        .environmentObject(appSession)
        .background(
            ZStack {
                Color.systemGray6.opacity(0.5)
                if let player = roundSession.players.first(where: { $0.id == roundSession.chaosTab }) {
                    player.color.value.opacity(0.04)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        )
        .onAppear() {
            UIPageControl.appearance().currentPageIndicatorTintColor = .systemGray
            UIPageControl.appearance().pageIndicatorTintColor = .systemGray3
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        TabView(selection: $roundSession.chaosTab) {
            if let rule = viewModel.getTeamRule(for: hole) {
                ChaosCard(
                    viewModel: viewModel,
                    rule: rule,
                    player: Player(name: "Team"),
                    onRedraw: redrawTeamTapped
                )
                .tag("team")
                .padding(.top, 30)
                .padding(.bottom, 60)
            }
            
            ForEach(roundSession.players, id: \.self) { player in
                if let rule = viewModel.getRule(for: player.id, on: hole) {
                    ChaosCard(
                        viewModel: viewModel,
                        rule: rule,
                        player: player,
                        onRedraw: { redrawPlayerTapped(for: player) }
                    )
                    .tag(player.id)
                    .padding(.top, 30)
                    .padding(.bottom, 60)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .animation(.easeOut(duration: 1), value: viewModel.sideGameSession)
        .padding(.bottom, 20)
        .onChange(of: roundSession.chaosTab, perform: { _ in Haptics.fire(.light) })
    }
    
    private func close() {
        print(#function)
        dismiss()
        Haptics.fire(.light)
    }
    
    private func redrawTeamTapped() {
        Task {
            HackersNotification.chaosRedraw.send()
            await viewModel.drawTeamRule(on: hole)
        }
    }
    
    private func redrawPlayerTapped(for p: Player) {
        Task {
            HackersNotification.chaosRedraw.send()
            await viewModel.drawPlayerRule(for: p, on: hole)
        }
    }
}

struct ChaosRuleDetailView_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        return rs
    }
    
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2, 3]
        vm.sideGameSession.chaos = ChaosSession(
            arrangement: ChaosCardsArrangement.player.rawValue,
            difficulty: ChaosCardsDifficulty.medium.rawValue,
            redraws: true,
            teamRule: [:],
            playerRules: [
                "kyle": [1: "", 2: "", 3: ""],
                "sarah": [1: "", 2: "", 3: ""],
                "murphy": [1: "", 2: "", 3: ""],
                "pablo": [1: "", 2: "", 3: ""]
            ]
        )
        return vm
    }
    
    static var previews: some View {
        ChaosRuleDetailView(viewModel: viewModel, hole: 4)
            .environmentObject(roundSession)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
