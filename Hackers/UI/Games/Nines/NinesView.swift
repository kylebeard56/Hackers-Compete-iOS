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
    
    var hole: Int
    
    @State private var holeScores: [GameScoreData] = []
    @State private var totalScores: [GameScoreData] = []
    @State private var bannerText: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            if !bannerText.isEmpty {
                HStack(spacing: 10) {
                    AwesomeImage(rawIcon: "f091".unicode, style: .regular, size: 15, color: Color.systemHackersPurple)
                    Text(LocalizedStringKey(bannerText))
                        .foregroundColor(Color.systemHackersPurple)
                        .font(.dmSans(size: 13, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                .cornerRadius(12)
            }
            
            HStack(spacing: 10) {
                thisHoleTile
                totalTile
            }
        }
        .onAppear() {
            self.holeScores = ScoreUtil.Nines.computeScore(for: roundSession.players, on: hole)
            computeTotalScoring()
        }
        .onReceive(roundSession.$players, perform: { _ in
            self.holeScores = ScoreUtil.Nines.computeScore(for: roundSession.players, on: hole)
            computeTotalScoring()
        })
    }
    
    // MARK: - Subviews
    
    private var thisHoleTile: some View {
        VStack(spacing: 8) {
            Text("This hole")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            ForEach(holeScores.sorted(by: { $0.value > $1.value }), id: \.self) { data in
                if let player = roundSession.players.first(where: { $0.id == data.key }) {
                    PlayerScoreRow(player: player, score: "\(data.value)")
                }
            }
            
//            ForEach(roundSession.players, id: \.self) { player in
//                if let score = holeScores.first(where: { $0.key == player.id })?.value {
//                    PlayerScoreRow(player: player, score: "\(score)")
//                } else {
//                    PlayerScoreRow(player: player, score: "-")
//                }
//            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private var totalTile: some View {
        VStack(spacing: 8) {
            Text("Total")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            ForEach(totalScores.sorted(by: { $0.value > $1.value }), id: \.self) { data in
                if let player = roundSession.players.first(where: { $0.id == data.key }) {
                    PlayerScoreRow(player: player, score: "\(data.value)")
                }
            }
            
//            ForEach(roundSession.players, id: \.self) { player in
//                if let score = totalScores.first(where: { $0.key == player.id })?.value {
//                    PlayerScoreRow(player: player, score: "\(score)")
//                } else {
//                    PlayerScoreRow(player: player, score: "-")
//                }
//            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }

    private func computeTotalScoring() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        self.totalScores = ScoreUtil.Nines.computeResults(for: roundSession.players, over: Array(range))
        self.bannerText = ScoreUtil.Nines.banner(for: roundSession.players, over: Array(range), upTo: hole)
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
        NinesView(viewModel: viewModel, hole: 2)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGameSession.holes = [1, 2, 3]
                roundSession.players = previewPlayers
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
