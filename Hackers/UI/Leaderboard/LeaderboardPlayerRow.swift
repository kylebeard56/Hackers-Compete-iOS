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
    var isSpectating: Bool = false
    
    @State private var currentScore: String = ""
    @State private var selectedScore: PlayerScore = .none
    
    var onScoreUpdate: ((Int) -> Void)?
    
    var body: some View {
        Button(action: {
            if isSpectating { return }
            let i = roundSession.players.firstIndex(where: { $0.id == player.id }) ?? 0
            HackersNotification.displayPlayerScorecard.send(with: i)
            Haptics.fire(.light)
        }) {
            if teamStyle || isSpectating {
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
                .font(.dmSans(size: isSpectating ? 17: 20, weight: .bold))
                .foregroundColor(player.color.value)
                .frame(width: isSpectating ? 40 : 48, height: isSpectating ? 32 : 40)
                .background(player.color.value.opacity(colorScheme.translucent))
                .cornerRadius(8)
            
            Text(player.name)
                .font(.dmSans(size: isSpectating ? 17: 20, weight: .bold))
                .foregroundColor(player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            Spacer(minLength: 0)
            
            if isSpectating {
                Text(selectedScore.spectatingName)
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(selectedScore == .none ? Color.systemGray : Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                scoringMenu
            }
        }
        .onAppear() { setScore() }
        .onChange(of: player, perform: { _ in setScore() })
        .onChange(of: selectedScore, perform: { s in
            /// If the player's score didn't change, we don't need to update (which would trigger unnecessary session persist).
            if player.score[hole] == s.rawValue { return }
            player.score.updateValue(s.rawValue, forKey: hole)
        })
    }
    
    private func setScore() {
        /// 1. Initialize the selected score should appear or the player change
        selectedScore = PlayerScore(rawValue: player.score[hole] ?? "") ?? .none
        currentScore = "0"
        if roundSession.netHoleNumber < 1 { return }
        
        // TODO: This breaks the session spectation since the hole range if different
        // We should probably make our own view for scores with tiles and options to refresh and stuff.
        
        let left = roundSession.holeRange.firstIndex(of: roundSession.startingHole) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        let score = ScoreUtil.Stroke.computeTotal(for: player, over: Array(range), using: .medal)
        currentScore = score.toGolfScore
        triggerOnScoreUpdate(score)
    }
    
    @ViewBuilder private var scoringMenu: some View {
        Menu {
            button(for: .none)
            Divider()
            Group {
                button(for: .eagle)
                button(for: .birdie)
                button(for: .par)
                button(for: .bogey)
                button(for: .double)
                button(for: .triple)
            }
            Menu("Other") {
                button(for: .albatross)
                button(for: .quad)
                button(for: .quin)
                button(for: .sex)
            }
        } label: {
            ChipButton(
                text: selectedScore.name,
                foregroundColor: selectedScore == .none ? Color.systemGray : Color.systemBlack
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .alignTrailing()
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    @ViewBuilder private func button(for score: PlayerScore) -> some View {
        let trailingS = (player.name.last == "s") ? "'" : "'s"
        Button(action: {
            Haptics.fire(.light)
            selectedScore = score
        }) {
            Text(score == .none ? "Enter \(player.name)\(trailingS) score" : score.menuName)
        }
    }
}

struct LeaderboardPlayerRow_Previews: PreviewProvider {
    static let kyle: Binding<Player> = .constant(
        Player(name: "Kyle", color: .blue, score: [1: "par", 2: "bogey", 3: "double"])
    )
    static var previews: some View {
        ScrollView {
            VStack(spacing: 10) {
                /// For players or individual scoring
                LeaderboardPlayerRow(player: kyle, hole: 1)
                LeaderboardPlayerRow(player: .constant(kPlayerSarah), hole: 1)
                LeaderboardPlayerRow(player: .constant(kPlayerMurphy), hole: 1)
                LeaderboardPlayerRow(player: .constant(kPlayerPablo), hole: 1)
                
                /// Embedded into the team scoring
                VStack(spacing: 10) {
                    Text("Team one")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    LeaderboardPlayerRow(player: kyle, hole: 1, teamStyle: true)
                    LeaderboardPlayerRow(player: .constant(kPlayerSarah), hole: 1, teamStyle: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemCard)
                .border(Color.systemGray5, width: 3, cornerRadius: 12)
                .cornerRadius(12)
                
                VStack(spacing: 10) {
                    Text("Team two")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    LeaderboardPlayerRow(player: .constant(kPlayerMurphy), hole: 1, teamStyle: true)
                    LeaderboardPlayerRow(player: .constant(kPlayerPablo), hole: 1, teamStyle: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemCard)
                .border(Color.systemGray5, width: 3, cornerRadius: 12)
                .cornerRadius(12)
                
                VStack(spacing: 10) {
                    Text("Leaderboard")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    LeaderboardPlayerRow(player: kyle, hole: 1, isSpectating: true)
                    LeaderboardPlayerRow(player: .constant(kPlayerSarah), hole: 1, isSpectating: true)
                    LeaderboardPlayerRow(player: .constant(kPlayerMurphy), hole: 1, isSpectating: true)
                    LeaderboardPlayerRow(player: .constant(kPlayerPablo), hole: 1, isSpectating: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemCard)
                .border(Color.systemGray5, width: 3, cornerRadius: 12)
                .cornerRadius(12)
            }
        }
        .environmentObject(RoundSession())
        .background(Color.systemViewBackground)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
