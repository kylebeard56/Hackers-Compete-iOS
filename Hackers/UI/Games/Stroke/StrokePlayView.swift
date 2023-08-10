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
    
    var hole: Int
    var format: StrokeScoringFormat
    
    @State private var isTwoBall: Bool = false
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
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            withAnimation(.easeOut(duration: 0.2)) {
                isTwoBall = viewModel.sideGameSession.stroke?.twoBall ?? false
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            self.bannerText = ScoreUtil.Stroke.banner(
                for: roundSession.players,
                over: viewModel.sideGameSession.holes,
                for: hole,
                using: format,
                isTwoBall: isTwoBall,
                handicaps: roundSession.usingHandicaps
            )
        })
        /// Publish local changes back to current hole view model
        .onChange(of: isTwoBall, perform: { value in
            viewModel.sideGameSession.stroke = StrokeSession(twoBall: value)
        })
    }
    
    // MARK: - Player
    
    private var playerDisplay: some View {
        HStack(spacing: 10) {
            thisHoleTile
            totalTile
        }
    }
    
    @ViewBuilder private var thisHoleTile: some View {
        VStack(spacing: 8) {
            Text("This hole")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            ForEach(roundSession.players, id: \.self) { player in
                let score = ScoreUtil.Stroke.computeScore(for: player, on: hole, using: format)
                PlayerScoreRow(player: player, score: score)
            }
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
            
            ForEach(roundSession.players, id: \.self) { player in
                PlayerScoreRow(player: player, score: accruedScore(for: player))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func accruedScore(for player: Player) -> String {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        let value = ScoreUtil.Stroke.computeTotal(for: player, over: Array(range), using: format)
        return format == .medal ? value.toGolfScore : "\(value)"
    }
    
    // MARK: - Team
    
    private var teamDisplay: some View {
        HStack(spacing: 10) {
            ForEach(roundSession.teams, id: \.self) { team in
                teamTile(for: team)
            }
        }
    }
    
    @ViewBuilder private func teamTile(for name: String) -> some View {
        VStack(spacing: 8) {
            TeamScoreRow(name: name, score: accruedTeamScore(for: name).toGolfScore)
            
            ForEach(roundSession.players, id: \.self) { player in
                if player.team[hole] == name {
                    PlayerScoreRow(player: player, score: accruedScore(for: player))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
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
            if isTwoBall {
                HStack {
                    Text("This hole")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text(format == .medal ? score.toGolfScore : "\(score)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
                
                HStack {
                    Text("Total")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text(total)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
                
                Divider()
            }
            
            Toggle(isOn: $isTwoBall, label: {
                VStack(spacing: 4) {
                    Text("Two ball")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    Text("As a \(roundSession.players.count == 3 ? "threesome" : "foursome"), the two best scores on each hole will count towards the total.")
                        .font(.dmSans(size: 13, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }
            })
        }
        .tint(Color.systemHackersPurple)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
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
        
        k.team = [1: "Team one", 2: "Team one"]
        s.team = [1: "Team one", 2: "Team one"]
        m.team = [1: "Team two", 2: "Team two"]
        p.team = [1: "Team two", 2: "Team two"]
        
        k.score = [1: "birdie", 2: "par"]
        s.score = [1: "par", 2: "bogey"]
        m.score = [1: "eagle", 2: "eagle"]
        p.score = [1: "par", 2: "birdie"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        StrokePlayView(viewModel: viewModel, hole: 1, format: .medal)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGameSession.holes = [1, 2, 3, 4]
                viewModel.sideGameSession.stroke = StrokeSession(twoBall: true)
                roundSession.players = previewPlayers
                roundSession.teams = ["Team one", "Team two"]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
