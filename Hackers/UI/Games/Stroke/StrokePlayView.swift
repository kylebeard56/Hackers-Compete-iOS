//
//  StrokePlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

struct StrokePlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    @Binding var hole: Int
    var format: StrokeScoringFormat
    
    @State private var data: [GameScoreData] = []
    
    @State private var isTwoBall: Bool = false
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
            
            if roundSession.teams.isEmpty {
                playerDisplay
            } else {
                teamDisplay
            }
            
            // We'll let this linger for stableford and football too for fun.
            if roundSession.players.count > 2 {
                twoBallToggle
            }
        }
        .onAppear() {
            isTwoBall = viewModel.sideGameSession.stroke?.twoBall ?? false
            withAnimation(.linear(duration: 0.2)) {
                compute()
            }
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            if roundSession.isInSync { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isTwoBall = viewModel.sideGameSession.stroke?.twoBall ?? false
                compute()
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            withAnimation(.linear(duration: 0.2)) {
                compute()
            }
        })
        /// Publish local changes back to current hole view model
        .onChange(of: isTwoBall, perform: { value in
            viewModel.sideGameSession.stroke = StrokeSession(twoBall: value)
        })
    }
    
    // MARK: - Player
    
    private var playerDisplay: some View {
        HStack(spacing: 10) {
            ForEach(data, id: \.self) { d in
                if let player = roundSession.players.first(where: { $0.id == d.key }) {
                    let score = player.score(for: hole, handicaps: roundSession.usingHandicaps)
                    if score == .none {
                        PlayerScoreTile(
                            player: player,
                            score: "\(d.value)",
                            subtitle: roundSession.scoringExists(for: hole) ? "" : nil,
                            placeholder: true
                        )
                    } else {
                        if format == .medal {
                            PlayerScoreTile(
                                player: player,
                                score: d.value.toGolfScore,
                                subtitle: score.shortName
                            )
                        } else {
                            let points = format == .fibonacci ? score.fibonacciValue : score.stablefordValue
                            PlayerScoreTile(
                                player: player,
                                score: "\(d.value)",
                                subtitle: "\(points) points"
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Team
    
    @ViewBuilder private var teamDisplay: some View {
        HStack(spacing: 10) {
            ForEach(roundSession.teams, id: \.self) { team in
                let s = accruedTeamScore(for: team)
                TeamScoreTile(
                    team: team,
                    score: format == .medal ? s.toGolfScore : "\(accruedTeamScore(for: team))",
                    hole: hole,
                    placeholder: !roundSession.everyoneScored(on: hole, team: team),
                    scale: 2
                )
            }
        }
    }
    
    private func accruedTeamScore(for name: String) -> Int {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        let score = roundSession.players.compactMap({
            if $0.team[hole] == name {
                return ScoreUtil.Stroke.computeTotal(for: $0, over: Array(range), using: format)
            } else {
                return nil
            }
        }).reduce(0, +)
        
        return score
    }
    
    // MARK: - Two Ball
    
    @ViewBuilder private var twoBallToggle: some View {
        let score = ScoreUtil.Stroke.bestBallScore(
            for: roundSession.players,
            on: hole,
            using: format
        )
        
        let total = ScoreUtil.Stroke.bestBallTotal(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            using: format,
            upTo: hole
        )
        
        VStack(spacing: 10) {
            Toggle(isOn: $isTwoBall, label: {
                VStack(spacing: 4) {
                    Text("Two ball")
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    Text("As a \(roundSession.players.count == 3 ? "threesome" : "foursome"), the two best scores on each hole will count towards the total.")
                        .font(.dmSans, size: 13, weight: .regular)
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }
            })
            
            if let score, let total, isTwoBall, roundSession.everyoneScored(on: hole) {
                let s = format == .medal ? score.toGolfScore : "\(score)"
                InfoBanner(
                    icon: viewModel.sideGame.icon,
                    text: "You are \(total) overall (\(s) this hole)",
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
        }
        .tint(Color.systemHackersPurple)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Computation
    
    private func compute() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        var data: [GameScoreData] = []
        for player in roundSession.players {
            let score = ScoreUtil.Stroke.computeTotal(
                for: player,
                over: Array(range),
                using: format,
                handicaps: roundSession.usingHandicaps
            )
            data.append(GameScoreData(key: player.id, value: score))
        }
        
        self.data = data.sorted(by: {
            if $0.value == $1.value {
                return index(of: $1.key) > index(of: $0.key)
            } else {
                if format == .medal {
                    return $0.value < $1.value
                } else {
                    return $0.value > $1.value
                }
            }
        })
    
        func index(of id: String) -> Int {
            roundSession.players.firstIndex(where: { $0.id == id }) ?? 0
        }
        
        self.bannerText = ScoreUtil.Stroke.banner(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            for: hole,
            using: format,
            isTwoBall: isTwoBall,
            handicaps: roundSession.usingHandicaps
        )
    }
}

struct StrokePlayView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
//        k.team = [1: "Team one", 2: "Team one"]
//        s.team = [1: "Team one", 2: "Team one"]
//        m.team = [1: "Team two", 2: "Team two"]
//        p.team = [1: "Team two", 2: "Team two"]
        
        k.score = [1: "birdie", 2: "par"]
        s.score = [1: "par", 2: "bogey"]
        m.score = [1: "eagle", 2: "eagle"]
        p.score = [1: "par", 2: "birdie"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        StrokePlayView(viewModel: viewModel, hole: .constant(1), format: .medal)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGame = .medalPlay
                viewModel.sideGameSession.holes = [1, 2, 3, 4]
                viewModel.sideGameSession.stroke = StrokeSession(twoBall: true)
//                viewModel.teams = ["Team one", "Team two"]
                
                roundSession.players = previewPlayers
//                roundSession.teams = ["Team one", "Team two"]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
