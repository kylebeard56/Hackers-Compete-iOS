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
    
    var body: some View {
        VStack(spacing: 10) {
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
            isTwoBall = viewModel.sideGameSession.stroke?.twoBall ?? false
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
    
    private var thisHoleTile: some View {
        VStack(spacing: 8) {
            Text("This hole")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            ForEach(roundSession.players, id: \.self) { player in
                HStack {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text(score(for: player, on: hole))
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
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
                HStack {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text(accruedScore(for: player))
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func score(for player: Player, on hole: Int) -> String {
        let value = (PlayerScore(rawValue: player.score[hole] ?? "") ?? .none)
        if value == .none { return "-" }
        
        switch format {
        case .medal:
            return value.numericalValue.toGolfScore
        case .stableford:
            return "\(value.stablefordValue)"
        case .football:
            return "\(value.footballValue)"
        }
    }
    
    private func accruedScore(for player: Player) -> String {
        let range = (viewModel.sideGameSession.holes.first ?? 0)...hole
        let value = roundSession.calculateAccruedScore(for: player, over: Array(range), using: format)
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
        let range = (viewModel.sideGameSession.holes.first ?? 0)...hole
        let score = roundSession.players.compactMap({
            $0.team[hole] == name ? roundSession.calculateAccruedScore(for: $0, over: Array(range), using: format) : nil
        }).reduce(0, +)
        
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                Text(score.toGolfScore)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            ForEach(roundSession.players, id: \.self) { player in
                if player.team[hole] == name {
                    HStack {
                        Text(player.name)
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(player.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        Spacer(minLength: 0)
                        
                        Text(accruedScore(for: player))
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Two Ball
    
    @ViewBuilder private var twoBallToggle: some View {
        let score = roundSession.bestBallScore(for: hole, using: format)
        let total = roundSession.bestBallTotal(
            over: viewModel.sideGameSession.holes,
            using: format,
            upTo: hole)

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
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func bestBallScore(for hole: Int) -> Int {
        let scores = roundSession.players
            .compactMap({ $0.score[hole] })
            .compactMap({ PlayerScore(rawValue: $0) })
        switch format {
        case .medal:        return scores.map({ $0.numericalValue }).sorted(by: <).prefix(2).reduce(0, +)
        case .stableford:   return scores.map({ $0.stablefordValue }).sorted(by: >).prefix(2).reduce(0, +)
        case .football:     return scores.map({ $0.footballValue }).sorted(by: >).prefix(2).reduce(0, +)
        }
    }
    
    private func bestBallTotal() -> String {
        /// Sum totals through holes
        var value: Int = 0
        for h in viewModel.sideGameSession.holes {
            if h > hole { break }
            value += bestBallScore(for: h)
        }
        return format == .medal ? value.toGolfScore : "\(value)"
    }
}

struct StrokePlayView_Previews: PreviewProvider {
    static var previews: some View {
        StrokePlayView(viewModel: HoleViewModel(), hole: 1, format: .medal)
            .environmentObject(RoundSession())
    }
}
