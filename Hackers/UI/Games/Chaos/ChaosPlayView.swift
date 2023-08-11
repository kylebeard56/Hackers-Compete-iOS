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
    
    var body: some View {
        VStack(spacing: 10) {
            
            if roundSession.players.count == 4 {
                // 2x2
            } else {
                // 1xN
            }
            
            content
            
            // Modify rules button
        }
        .task(priority: .background) {
            /// Determine if user has scrolled two holes past the last drawn hole
            /// i.e. Start on hole 1, go to hole 2,
            let first = viewModel.sideGameSession.holes.first ?? 0
            playingThru = first == hole
            
            if !viewModel.isDrawn(for: hole) {
                await viewModel.draw(for: roundSession.players, on: hole)
            }
        }
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            guard let chaos = sideGameSession.chaos else { return }
            teamRule = chaos.teamRule[hole] ?? ""
            playerRules = chaos.playerRules.compactMap { ChaosData(key: $0.key, value: $0.value[hole] ?? "") }
        })
    }
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 8) {
            ForEach(playerRules, id: \.self) { data in
                if let player = roundSession.players.first(where: { $0.id == data.key }),
                   let rule = viewModel.chaosRuleMap[data.value] {
                    tile(for: player, for: rule)
                }
            }
        }
    }
    
    @ViewBuilder private func tile(for player: Player, for r: Rule) -> some View {
        VStack(spacing: 4) {
            AwesomeImage(rawIcon: r.icon, style: .regular, size: 20, color: player.color.value)
                .alignCenter()
            Text(player.name)
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(player.color.value)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .alignCenter()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(player.color.value.opacity(colorScheme.translucent))
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
