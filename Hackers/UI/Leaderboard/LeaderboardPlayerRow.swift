//
//  LeaderboardPlayerRow.swift
//  Hackers
//
//  Created by Kyle Beard on 6/22/23.
//

import SwiftUI

struct LeaderboardPlayerRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var viewModel: RoundViewModel
    
    @Binding var player: Player
//    var currentHole: Int
//    var holeRange: [Int]
//    var netHoleNumber: Int
    
    @State private var currentScore: String = ""
    @State private var selectedScore: PlayerScore = .none
    
    var body: some View {
        Button(action: {
            print("todo")
            Haptics.fire(.light)
        }) {
            content
        }
    }
    
    var content: some View {
        HStack(spacing: 16) {
            Text(currentScore)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(player.color.value)
                .frame(width: 40, height: 40)
                .background(player.color.value.opacity(0.1))
                .cornerRadius(8)
            
            Text(player.name)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
            
            scoringMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() { setScore() }
        .onChange(of: player, perform: { _ in setScore() })
//        .onReceive(viewModel.$currentHole, perform: { _ in setScore() })
        .onReceive(viewModel.$netHoleNumber, perform: { _ in setScore() })
        .onChange(of: selectedScore, perform: { s in
            player.score[viewModel.currentHole] = s.rawValue
        })
    }
    
    private func setScore() {
        /// 1. Initialize the selected score should appear or the player change
        selectedScore = PlayerScore(rawValue: player.score[viewModel.currentHole] ?? "") ?? .none
        currentScore = "0"
        if viewModel.netHoleNumber < 1 { return }
        
        // TODO: THIS IS BROKEN FIX IT
        /// 2. Calculate the accured score total from the starting hole to this hole
        ///
        /// If we're on hole 13 and started on 12, we're thru 2 so 0..<2 is [0,1]
        /// If we got the hole range we'd get hr[0] = bogey and hr
        
        var score: Int = 0
        for i in 0..<viewModel.netHoleNumber {
            let hole = viewModel.holeRange[i]
            let s = PlayerScore(rawValue: player.score[hole] ?? "") ?? .par
            print("Score for \(player.name) on hole \(hole) is \(s)")
            score += s.numericalValue
        }
        currentScore = "\(score > 0 ? "+" : "")\(score)"
    }
    
    @ViewBuilder private var scoringMenu: some View {
        Menu {
            button(for: .none)
            Divider()
            Group {
                button(for: .albatross)
                button(for: .eagle)
                button(for: .birdie)
                button(for: .par)
            }
            Divider()
            Group {
                button(for: .bogey)
                button(for: .double)

                if deviceDefaults.maxScoreOverPar >= 3 {
                    button(for: .triple)
                }
                if deviceDefaults.maxScoreOverPar >= 4 {
                    button(for: .quad)
                }
                if deviceDefaults.maxScoreOverPar >= 5 {
                    button(for: .quin)
                }
                if deviceDefaults.maxScoreOverPar >= 6 {
                    button(for: .sex)
                }
            }
        } label: {
            Text(selectedScore.name)
                .font(.dmSans(size: 15, weight: .medium))
                .foregroundColor(selectedScore == .none ? Color.systemGray : Color.systemBlack)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color.systemGray6)
                .cornerRadius(4)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignTrailing()
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    private func button(for score: PlayerScore) -> some View {
        Button(action: {
            Haptics.fire(.light)
            selectedScore = score
        }) {
            Text(score.name)
        }
    }
}

struct LeaderboardPlayerRow_Previews: PreviewProvider {
    static let player: Binding<Player> = .constant(
        Player(name: "Kyle", color: .blue, score: [1: "par", 2: "bogey", 3: "double"])
    )
    static var previews: some View {
        LeaderboardPlayerRow(viewModel: RoundViewModel(), player: player)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
