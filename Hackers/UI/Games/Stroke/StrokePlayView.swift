//
//  StrokePlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

enum StrokeScoringFormat {
    case medal, stableford, football
}

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
            
            if roundSession.players.count > 2 && roundSession.teams.isEmpty  {
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
                    
                    Text(score(for: player))
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
            }
            
//            if isTwoBall {
//                HStack(spacing: 0) {
//                    Text("Two ball")
//                    Spacer(minLength: 0)
//                    Text("+1")
//                }
//                .foregroundColor(Color.systemHackersPurple)
//                .font(.dmSans(size: 15, weight: .medium))
//                .padding(.vertical, 4)
//                .padding(.horizontal, 12)
//                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
//                .cornerRadius(4)
//            }
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
    
    private func score(for player: Player) -> String {
        return (PlayerScore(rawValue: player.score[viewModel.currentHole] ?? "") ?? .none).numericalValue.toGolfScore
    }
    
    private func accruedScore(for player: Player) -> String {
        return roundSession.calculateAccruedScore(for: player, over: 0..<hole).toGolfScore
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
        let score = roundSession.players.compactMap({
            $0.team == name ? roundSession.calculateAccruedScore(for: $0, over: 0..<hole) : nil
        }).reduce(0, +)
        
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                Text("\(score > 0 ? "+" : "")\(score)")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            ForEach(roundSession.players, id: \.self) { player in
                if player.team == name {
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
    
    private var twoBallToggle: some View {
        VStack(spacing: 10) {
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
            
            if isTwoBall {
                Divider()
                
                HStack {
                    Text("This hole")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text(bestBallScore(for: hole).toGolfScore)
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
                    
                    Text(bestBallTotal())
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
            }
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
            .compactMap({ PlayerScore(rawValue:  $0) })
            .map({ $0.numericalValue })
            .sorted(by: <)
            .prefix(2)
        return scores.reduce(0, +)
    }
    
    private func bestBallTotal() -> String {
        /// Sum totals through holes
        var count: Int = 0
        for h in viewModel.sideGameSession.holes {
            if h > hole { break }
            count += bestBallScore(for: h)
        }
        return count.toGolfScore
    }
}

struct StrokePlayView_Previews: PreviewProvider {
    static var previews: some View {
        StrokePlayView(viewModel: HoleViewModel(), hole: 1, format: .medal)
            .environmentObject(RoundSession())
    }
}
