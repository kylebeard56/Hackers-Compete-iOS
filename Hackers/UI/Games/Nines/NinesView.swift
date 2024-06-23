//
//  NinesView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/11/23.
//

import SwiftUI

struct NinesView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    @Binding var hole: Int
    
    @State private var holeScores: [GameScoreData] = []
    @State private var totalScores: [GameScoreData] = []
    @State private var bannerText: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            if !bannerText.isEmpty {
                InfoBanner(
                    icon: viewModel.sideGame.icon,
                    text: bannerText,
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            HStack(spacing: 10) {
                if totalScores.isEmpty {
                    ForEach(roundSession.players) { player in
                        PlayerScoreTile(
                            player: player,
                            score: "0",
                            placeholder: true
                        )
                    }
                } else {
                    ForEach(totalScores, id: \.self) { total in
                        if let player = roundSession.players.first(where: { $0.id == total.key }) {
                            if let holeScore = holeScores.first(where: { $0.key == player.id }) {
                                PlayerScoreTile(
                                    player: player,
                                    score: "\(total.value)",
                                    subtitle: "\(holeScore.value) points"
                                )
                            } else {
                                PlayerScoreTile(
                                    player: player,
                                    score: "\(total.value)",
                                    placeholder: true
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear() {
            self.holeScores = ScoreUtil.Nines.computeScore(for: roundSession.players, on: hole)
            withAnimation(.linear(duration: 0.2)) {
                computeTotalScoring()
            }
        }
        .onReceive(roundSession.$players, perform: { _ in
            self.holeScores = ScoreUtil.Nines.computeScore(for: roundSession.players, on: hole)
            withAnimation(.linear(duration: 0.2)) {
                computeTotalScoring()
            }
        })
        .onChange(of: hole, perform: { h in
            self.holeScores = ScoreUtil.Nines.computeScore(for: roundSession.players, on: h)
            withAnimation(.linear(duration: 0.2)) {
                computeTotalScoring()
            }
        })
    }
    
    private func computeTotalScoring() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        self.totalScores = ScoreUtil.Nines
            .computeResults(for: roundSession.players, over: Array(range))
            .sorted(by: {
                if $0.value == $1.value {
                    return index(of: $1.key) > index(of: $0.key)
                } else {
                    return $0.value > $1.value
                }
            })
        
        func index(of id: String) -> Int {
            roundSession.players.firstIndex(where: { $0.id == id }) ?? 0
        }
        
        self.bannerText = ScoreUtil.Nines.banner(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            on: hole,
            handicaps: roundSession.usingHandicaps
        )
    }
}

struct NinesView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        
        k.team = [:]
        s.team = [:]
        m.team = [:]
        
        k.score = [1: "birdie", 2: "par"]
        s.score = [1: "par", 2: "bogey"]
        m.score = [1: "eagle", 2: "eagle"]
        
        return [k, s, m]
    }
    
    static var previews: some View {
        NinesView(viewModel: viewModel, hole: .constant(2))
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGame = .nines
                viewModel.sideGameSession.holes = [1, 2, 3]
                roundSession.players = previewPlayers
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
