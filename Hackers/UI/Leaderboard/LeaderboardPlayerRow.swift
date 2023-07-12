//
//  LeaderboardPlayerRow.swift
//  Hackers
//
//  Created by Kyle Beard on 6/22/23.
//

import SwiftUI

extension LeaderboardPlayerRow {
    func triggerOnScoreUpdate(_ value: Int) {
        if let action = onScoreUpdate {
            action(value)
        }
    }
    
    func onScoreUpdate(perform action: @escaping (Int) -> Void) -> Self {
        var a = self
        a.onScoreUpdate = action
        return a
    }
}

struct LeaderboardPlayerRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    @Binding var player: Player
    var hole: Int
    var teamStyle: Bool = false
    
    @State private var currentScore: String = ""
    @State private var selectedScore: PlayerScore = .none
    
    var onScoreUpdate: ((Int) -> Void)?
    
    var body: some View {
        Button(action: {
            HackersNotification.displayPlayerScorecard.send(
                with: roundSession.players.firstIndex(where: { $0.id == player.id }) ?? 0
            )
            Haptics.fire(.light)
        }) {
            if teamStyle {
                content
                    .background(Color.systemCard)
                    .cornerRadius(12)
            } else {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.systemCard)
                    .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
                    .cornerRadius(12)
            }
        }
        .environmentObject(roundSession)
    }
    
    var content: some View {
        HStack(spacing: 16) {
            Text(currentScore)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(player.color.value)
                .frame(width: 48, height: 40)
                .background(player.color.value.opacity(colorScheme.translucent))
                .cornerRadius(8)
            
            Text(player.name)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(teamStyle ? Color.systemBlack : player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            Spacer(minLength: 0)
            
            scoringMenu
        }
        .onAppear() { setScore() }
        .onChange(of: player, perform: { _ in setScore() })
        .onChange(of: selectedScore, perform: { s in
            /// If the player's score didn't change, we don't need to update (which would trigger unnecessary session persist)
            if player.score[hole] == s.rawValue { return }
            player.score.updateValue(s.rawValue, forKey: hole)
        })
    }
    
    private func setScore() {
        /// 1. Initialize the selected score should appear or the player change
        selectedScore = PlayerScore(rawValue: player.score[hole] ?? "") ?? .none
        currentScore = "0"
        if roundSession.netHoleNumber < 1 { return }
        
        let score = roundSession.calculateAccruedScore(for: player, over: 0..<hole)
        currentScore = score.toGolfScore
        triggerOnScoreUpdate(score)
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
                .minimumScaleFactor(0.5)
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
    static let kyle: Binding<Player> = .constant(
        Player(name: "Kyle", color: .blue, score: [1: "par", 2: "bogey", 3: "double"])
    )
    static var previews: some View {
        VStack(spacing: 10) {
            /// For players or individual scoring
            LeaderboardPlayerRow(player: kyle, hole: 1)
            LeaderboardPlayerRow(player: .constant(kPlayerSarah), hole: 1)
            LeaderboardPlayerRow(player: .constant(kPlayerMurphy), hole: 1)
            LeaderboardPlayerRow(player: .constant(kPlayerPablo), hole: 1)
            
            /// Embedded into the team scoring
            LeaderboardPlayerRow(player: kyle, hole: 1, teamStyle: true)
                .padding(.horizontal, 12)
        }
        .environmentObject(RoundSession())
        .background(Color.systemViewBackground)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
