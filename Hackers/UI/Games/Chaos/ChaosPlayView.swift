//
//  ChaosPlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct ChaosData: Hashable, Codable {
    var id: String = UUID().uuidString
    var key: String = ""
    var value: String = ""
}

/// Draw cards auto for current hole ONLY if on first hole or previous hole is scored, otherwise show option to draw (you didn't score the last hole, would you like to play through?).
struct ChaosPlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var teamRule: String = ""
    @State private var playerRules: [ChaosData] = []
    @State private var playingThru: Bool = false
    
    @State private var showRuleDetail: Bool = false
    @State private var showRuleModifier: Bool = false
    
    @State private var arr: ChaosCardsArrangement?
    
    var body: some View {
        VStack(spacing: 20) {
            if let arr {
                if arr == .team || arr == .combo {
                    teamTile
                }
                if arr == .player || arr == .combo {
                    playerTiles
                }
            }
            
            SmallButton(title: "Modify rules", isDisabled: .false, isLoading: .false)
                .onTap {
                    showRuleModifier = true
                }
        }
        .onAppear() {
            self.load(for: viewModel.sideGameSession)
        }
        .onReceive(viewModel.$sideGameSession, perform: { s in
            self.load(for: s)
        })
        .onReceive(HackersNotification.refreshChaosRules.publisher(), perform: { _ in
            Task {
                await viewModel.reloadChaosRules()
            }
        })
        .sheet(isPresented: $showRuleDetail) {
            ChaosRuleDetailView(viewModel: viewModel, hole: hole)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showRuleModifier) {
            ChaosModifyRulesView(viewModel: viewModel, hole: hole)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }
    
    private func load(for s: SideGameSession) {
        Task {
            let isDrawn = viewModel.isDrawn(for: hole)
            
            /// 1. Load rules if view model hasn't yet, or rules aren't drawn.
            if viewModel.chaosRules.isEmpty || !isDrawn {
                await viewModel.reloadChaosRules()
            }
            
            /// 2. If rules aren't drawn, draw them.
            if !isDrawn {
                await viewModel.draw(for: roundSession.players, on: hole)
                self.buildRules(viewModel.sideGameSession)
            } else {
                self.buildRules(viewModel.sideGameSession)
            }
        }
    }
    
    private func buildRules(_ s: SideGameSession) {
        guard let chaos = s.chaos else { return }
        arr = ChaosCardsArrangement(rawValue: chaos.arrangement)
        teamRule = chaos.teamRule[hole] ?? ""
        playerRules = chaos.playerRules
            .compactMap { ChaosData(key: $0.key, value: $0.value[hole] ?? "") }
            .sorted(by: {
                let p = roundSession.players
                let id1 = $0.key
                let id2 = $1.key
                return p.firstIndex(where: { $0.id == id1 }) ?? 99 < p.firstIndex(where: { $0.id == id2 }) ?? 99
            })
    }
    
    @ViewBuilder private var teamTile: some View {
        let t = Player(id: "team", name: "Team")
        if let rule = viewModel.chaosRuleMap[teamRule] {
            tile(for: t, for: rule)
        } else {
            loadingTile(for: t)
        }
    }
    
    @ViewBuilder private var playerTiles: some View {
        let columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: playerRules.count % 2 == 0 ? 2 : 1)
        LazyVGrid(columns: columns, spacing: 10) {
            if !playerRules.isEmpty {
                ForEach(playerRules, id: \.self) { data in
                    if let player = roundSession.players.first(where: { $0.id == data.key }),
                       let rule = viewModel.chaosRuleMap[data.value] {
                        tile(for: player, for: rule)
                    }
                }
            } else {
                ForEach(roundSession.players, id: \.self) { player in
                    loadingTile(for: player)
                }
            }
        }
    }
    
    @ViewBuilder private func tile(for player: Player, for r: Rule) -> some View {
        let color = player.id == "team" ? Color.systemBlack : player.color.value
        Button(action: {
            roundSession.chaosTab = player.id
            showRuleDetail = true
            Haptics.fire(.light)
        }) {
            VStack(spacing: 4) {
                AwesomeImage(rawIcon: r.icon.unicode, style: .regular, size: 20, color: color)
                    .alignCenter()
                Text(player.name)
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(color)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .alignCenter()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                (player.id == "team" ? Color.systemHackersPurple : player.color.value).opacity(colorScheme.translucent)
            )
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder private func loadingTile(for player: Player) -> some View {
        let color = player.id == "team" ? Color.systemBlack : player.color.value
        VStack(spacing: 4) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(color)
                .alignCenter()
            Text(player.name)
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .alignCenter()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            (player.id == "team" ? Color.systemHackersPurple : player.color.value).opacity(colorScheme.translucent)
        )
        .cornerRadius(8)
    }
}

struct ChaosPlayView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo

        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
        
        k.score = [1: "par"]
        s.score = [1: "par"]
        m.score = [1: "par"]
        p.score = [1: "par"]
        
        return [k, s, m]
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2, 3]
        vm.sideGameSession.monkey = MonkeySession(
            play: [1: "kyle", 2: "sarah", 3: "murphy", 4: "murphy"],
            skins: true
        )
        return vm
    }
    
    static var previews: some View {
        ChaosPlayView(viewModel: viewModel, hole: 4)
            .environmentObject(roundSession)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
