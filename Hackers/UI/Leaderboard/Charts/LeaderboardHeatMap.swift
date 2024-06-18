//
//  LeaderboardHeatMap.swift
//  Hackers
//
//  Created by Kyle Beard on 6/16/24.
//

import Charts
import SwiftUI

fileprivate enum MatrixScore {
    case eagleOrBetter, birdie, par, bogey, doubleOrWorse, none
    
    var label: String {
        switch self {
        case .eagleOrBetter:    return "Eagle or better"
        case .birdie:           return "Birdie"
        case .par:              return "Par"
        case .bogey:            return "Bogey"
        case .doubleOrWorse:    return "Double or worse"
        case .none:             return ""
        }
    }
    
    var value: Int {
        switch self {
        case .eagleOrBetter:    return -2
        case .birdie:           return -1
        case .par:              return 0
        case .bogey:            return 1
        case .doubleOrWorse:    return 2
        case .none:             return 999
        }
    }
}

fileprivate struct Matrix: Hashable, Identifiable {
    var id = UUID()
    var player: Player
    var score: MatrixScore
    var value: Int
    
    init(
        id: UUID = UUID(),
        player: Player = Player(),
        score: MatrixScore = .none,
        value: Int = 0
    ) {
        self.id = id
        self.player = player
        self.score = score
        self.value = value
    }
}

struct LeaderboardHeatMap: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession

//    @State private var matrix = Matrix()
    @State private var segmentID: String = ""
    
    @State private var useHCP: Bool = true
    
    private var matrix: [Matrix] = [
        Matrix(player: kPlayerKyle, score: .eagleOrBetter, value: 0),
        Matrix(player: kPlayerKyle, score: .birdie, value: 1),
        Matrix(player: kPlayerKyle, score: .par, value: 2),
        Matrix(player: kPlayerKyle, score: .bogey, value: 3),
        Matrix(player: kPlayerKyle, score: .doubleOrWorse, value: 3),
        
        Matrix(player: kPlayerSarah, score: .eagleOrBetter, value: 1),
        Matrix(player: kPlayerSarah, score: .birdie, value: 2),
        Matrix(player: kPlayerSarah, score: .par, value: 1),
        Matrix(player: kPlayerSarah, score: .bogey, value: 3),
        Matrix(player: kPlayerSarah, score: .doubleOrWorse, value: 2),
        
        Matrix(player: kPlayerMurphy, score: .eagleOrBetter, value: 0),
        Matrix(player: kPlayerMurphy, score: .birdie, value: 2),
        Matrix(player: kPlayerMurphy, score: .par, value: 4),
        Matrix(player: kPlayerMurphy, score: .bogey, value: 2),
        Matrix(player: kPlayerMurphy, score: .doubleOrWorse, value: 1),
        
        Matrix(player: kPlayerPablo, score: .eagleOrBetter, value: 0),
        Matrix(player: kPlayerPablo, score: .birdie, value: 0),
        Matrix(player: kPlayerPablo, score: .par, value: 1),
        Matrix(player: kPlayerPablo, score: .bogey, value: 4),
        Matrix(player: kPlayerPablo, score: .doubleOrWorse, value: 4)
    ]
    
    var body: some View {
        VStack {
            if roundSession.numberOfScoredHoles < 3 {
                emptyView
            } else {
                populatedView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() {
            buildHeatMap()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyView: some View {
        EmptyView()
    }
    
    // MARK: - Populated State
    
    private var populatedView: some View {
        VStack {
            populatedChart
                .frame(height: 300)

            if roundSession.usingHandicaps {
                HandicapComputationToggle(useHCP: $useHCP)
            }
        }
    }
    
    private var populatedChart: some View {
        Chart(matrix) {
            RectangleMark(
                x: .value("Name", $0.player.name),
                y: .value("Score", $0.score.value)
            )
            .foregroundStyle(by: .value("Number", $0.value))
        }
    }
    
    // MARK: - Functions
    
    private func buildHeatMap() { }
}

struct LeaderboardHeatMap_Previews: PreviewProvider {
    static var app = AppSession()
    static var purchase = PurchaseStore()
    static var round = RoundSession()
    
    static var previews: some View {
        VStack {
            Spacer(minLength: 0)
            
            LeaderboardHeatMap()
                .frame(height: 400)
                .padding(20)
            
            Spacer(minLength: 0)
        }
        .background(Color.systemBackground)
        .environmentObject(app)
        .environmentObject(purchase)
        .environmentObject(round)
        .holisticPreview()
        .onAppear() {
            round.holeRange = Array(1...9)
            round.startingHole = 1
            var kyle = kPlayerKyle
            kyle.score = [1: "triple", 2: "birdie", 3: "par", 4: "triple", 5: "eagle", 6: "bogey", 7: "bogey", 8: "double", 9: "par"]
            
            var sarah = kPlayerSarah
            sarah.score = [1: "birdie", 2: "par", 3: "triple", 4: "eagle", 5: "birdie", 6: "par", 7: "bogey", 8: "double", 9: "double"]
            
            var murphy = kPlayerMurphy
            murphy.score = [1: "par", 2: "bogey", 3: "bogey", 4: "double", 5: "par", 6: "bogey", 7: "double", 8: "birdie", 9: "par"]
            
            var pablo = kPlayerPablo
            pablo.score = [1: "bogey", 2: "par", 3: "bogey", 4: "eagle", 5: "eagle", 6: "bogey", 7: "bogey", 8: "bogey", 9: "double"]
            
            round.players = [kyle, sarah, murphy, pablo]
        }
    }
}
