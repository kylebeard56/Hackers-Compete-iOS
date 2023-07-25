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
    
    @State private var holeScores: [NinesData] = []
    @State private var totalScores: [NinesData] = []
    
    var body: some View {
        VStack(spacing: 10) {
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
            
            ForEach(roundSession.players, id: \.self) { player in
                HStack {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    if let score = holeScores.first(where: { $0.player == player.id })?.value {
                        Text("\(score)")
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                    } else {
                        Text("-")
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
                    
                    if let score = totalScores.first(where: { $0.player == player.id }) {
                        Text("\(score.value)")
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                    } else {
                        Text("-")
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

    private func computeTotalScoring() {
        let left = viewModel.sideGameSession.holes.first ?? 0
        let right = viewModel.sideGameSession.holes.firstIndex(of: hole) ?? 0
        self.totalScores = ScoreUtil.Nines.computeResults(for: roundSession.players, over: Array(left...right))
    }
}

struct NinesView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    static var previews: some View {
        NinesView(viewModel: viewModel, hole: 2)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGameSession.holes = [1, 2]
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy]
                roundSession.players[0].score = [1: "par", 2: "par"]
                roundSession.players[1].score = [1: "double", 2: "par"]
                roundSession.players[2].score = [1: "birdie", 2: "par"]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
