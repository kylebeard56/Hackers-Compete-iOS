//
//  LeaderboardPlayerRow.swift
//  Hackers
//
//  Created by Kyle Beard on 6/22/23.
//

import SwiftUI

struct LeaderboardPlayerRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var player: Player
    var currentHole: Int
    var holeRange: [Int]
    var holesThru: Int
    
    @State private var currentScore: String = ""
    @State private var selectedScore: PlayerScore = .none
    
    var body: some View {
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
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 2, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() { setScore() }
        .onChange(of: player, perform: { _ in setScore()})
        .onChange(of: selectedScore, perform: { s in
            player.score[currentHole] = s.rawValue
        })
    }
    
    private func setScore() {
        /// 1. Initialize the selected score should appear or the player change
        selectedScore = PlayerScore(rawValue: player.score[currentHole] ?? "") ?? .none
        
        /// 2. Calculate the accured score total from the starting hole to this hole
        var score: Int = 0
        for h in 0...holesThru {
            let s = PlayerScore(rawValue: player.score[h] ?? "") ?? .par
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
                .font(.dmSans(size: 13, weight: .medium))
                .foregroundColor(selectedScore == .none ? Color.systemGray : Color.systemBlack)
                .padding(.vertical, selectedScore == .none ? 6 : 4)
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
        LeaderboardPlayerRow(player: player, currentHole: 1, holeRange: Array(1...18), holesThru: 3)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
