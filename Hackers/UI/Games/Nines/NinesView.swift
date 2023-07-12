//
//  NinesView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/11/23.
//

import SwiftUI

struct NinesData {
    var id: String
    var value: Int
}

struct NinesView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var holeScores: [NinesData] = []
    @State private var totalScores: [String: Int] = [:]
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                thisHoleTile
                totalTile
            }
        }
        .onAppear() {
            computeHoleScoring(for: hole)
            computeTotalScoring()
        }
        .onReceive(roundSession.$players, perform: { _ in
            computeHoleScoring(for: hole)
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
                    
                    if let score = holeScores.first(where: { $0.id == player.id })?.value {
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
                    
                    if let score = totalScores[player.id] {
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
    
    // MARK: - Scoring Algorithm
    
    @discardableResult private func computeHoleScoring(for hole: Int) -> [NinesData] {
        self.holeScores = []
        var data: [NinesData] = []
        var scores: [String: Int] = [:]
        
        for p in roundSession.players {
            let v = (PlayerScore(rawValue: p.score[hole] ?? "") ?? .none)
            /// Don't compute until all scores are in.
            if v == .none { return [] }
            scores.updateValue(v.numericalValue, forKey: p.id)
        }
        
        let raw = scores.values.sorted(by: <)
        let best = raw.min() ?? -99
        
        /// 1. No ties, allocate points based on sorting order
        if scores.values.count == Array(scores.values).uniques.count {
            for (k,v) in scores {
                /// 1a. First place since first index of sorted raw scores is this value.
                if raw[0] == v {
                    data.append(NinesData(id: k, value: 5))
                }
                /// 1b. Second place since second index of sorted raw scores is this value.
                if raw[1] == v {
                    data.append(NinesData(id: k, value: 3))
                }
                /// 1c. Third place since third index of sorted raw scores is this value.
                if raw[2] == v {
                    data.append(NinesData(id: k, value: 1))
                }
            }
        /// 2. At least two players tied
        } else {
            for (k, v) in scores {
                /// 2a. Everyone tied
                if raw.uniques.count == 1 {
                    data.append(NinesData(id: k, value: 3))
                /// 2b. Check whether the raw scores contains tie on best value to figure out tie for first or second place.
                } else {
                    if raw.filter({ $0 == best }).count == 2 {
                        data.append(NinesData(id: k, value: v == best ? 4 : 1))
                    } else {
                        data.append(NinesData(id: k, value: v == best ? 5 : 2))
                    }
                }
            }
        }
        
        self.holeScores = data
        return data
    }

    private func computeTotalScoring() {
        self.totalScores = [:]
        var map: [String: Int] = [:]
        
        for h in viewModel.sideGameSession.holes {
            if h > hole { break }
            for data in computeHoleScoring(for: h) {
                let sum = (map[data.id] ?? 0) + data.value
                map.updateValue(sum, forKey: data.id)
            }
        }
        self.totalScores = map
    }
}

struct NinesView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    static var previews: some View {
        NinesView(viewModel: viewModel, hole: 2)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.currentHole = 2
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
