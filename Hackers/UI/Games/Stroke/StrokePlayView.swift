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
    @StateObject var roundViewModel: RoundViewModel
    @StateObject var holeViewModel: HoleViewModel
    
    var hole: Int
    var format: StrokeScoringFormat
    
    @State private var isTwoBall: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            if viewModel.teams.isEmpty {
                playerDisplay
            } else {
                teamDisplay
            }
            
            /// Two ball only works if you have 3 or 4 players, otherwise just sum the team of 2.
            /// We also don't want to show two ball if playing as a team.
            if viewModel.players.count > 2 && viewModel.teams.isEmpty  {
                twoBallToggle
            }
        }
        .onAppear() {
            isTwoBall = viewModel.isPlayingTwoBall
        }
        .onChange(of: isTwoBall, perform: { value in
            if let index = viewModel.sideGameSessions.firstIndex(where: { $0.holes.contains(hole) }) {
                viewModel.sideGameSessions[index].stroke = StrokeSession(twoBall: value)
            }
        })
        .onChange(of: viewModel.isPlayingTwoBall, perform: { value in
            isTwoBall = value
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
            
            ForEach(viewModel.players, id: \.self) { player in
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
            
            if isTwoBall {
                HStack(spacing: 0) {
                    Text("Two ball")
                    Spacer(minLength: 0)
                    Text("+1")
                }
                .foregroundColor(Color.systemHackersPurple)
                .font(.dmSans(size: 15, weight: .medium))
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                .cornerRadius(4)
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
            
            ForEach(viewModel.players, id: \.self) { player in
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
        return viewModel.calculateAccruedScore(for: player, over: 0..<hole).toGolfScore
    }
    
    private func bestBallScore(for hole: Int) -> Int {
        let scores = viewModel.players
            .compactMap({ $0.score[hole] })
            .compactMap({ PlayerScore(rawValue:  $0) })
            .map({ $0.numericalValue })
            .sorted(by: <)
            .prefix(2)
        return scores.reduce(0, +)
    }
    
    private func bestBallTotal() -> String {
        for h in 0..<viewModel.sideGameSession { }
    }
    
    // MARK: - Team
    
    private var teamDisplay: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.teams, id: \.self) { team in
                teamTile(for: team)
            }
        }
    }
    
    @ViewBuilder private func teamTile(for name: String) -> some View {
        let score = viewModel.players.compactMap({
            $0.team == name ? viewModel.calculateAccruedScore(for: $0, over: 0..<hole) : nil
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
            
            ForEach(viewModel.players, id: \.self) { player in
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
        VStack {
            Toggle(isOn: $isTwoBall, label: {
                VStack(spacing: 4) {
                    Text("Two ball")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    Text("As a \(viewModel.players.count == 3 ? "threesome" : "foursome"), the two best scores on each hole will count towards the total.")
                        .font(.dmSans(size: 13, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }
            })
            .tint(Color.systemHackersPurple)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
            .cornerRadius(12)
        }
    }
}

struct StrokePlayView_Previews: PreviewProvider {
    static var previews: some View {
        StrokePlayView(viewModel: RoundViewModel(), hole: 1, format: .medal)
    }
}
