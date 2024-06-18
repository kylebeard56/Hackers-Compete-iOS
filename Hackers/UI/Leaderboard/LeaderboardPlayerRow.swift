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
        Group {
            if teamStyle {
                menu(for: teamContent)
            } else {
                menu(for: playerContent)
            }
        }
        .environmentObject(roundSession)
    }
    
    private var playerContent: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
            .cornerRadius(12)
    }
    
    private var teamContent: some View {
            content
                .background(Color.systemCard)
                .cornerRadius(12)
    }
    
    private func menu<Content: View>(for content: Content) -> some View {
        Menu {

            Group {
                button(for: .eagle)
                button(for: .birdie)
                button(for: .par)
                button(for: .bogey)
                button(for: .double)
                button(for: .triple)
            }
            Menu("More") {
                button(for: .albatross)
                button(for: .quad)
                button(for: .quin)
                button(for: .sex)
            }
            if selectedScore != .none {
                Divider()
                button(for: .none)
            }
        } label: {
            content
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    @ViewBuilder var content: some View {
        HStack(spacing: 16) {
            Text(currentScore)
                .font(.dmSans, size: 20, weight: .bold)
                .foregroundColor(player.color.value)
                .frame(width: 48, height: 40)
                .background(player.color.value.opacity(colorScheme.translucent))
                .cornerRadius(8)
            
            VStack(spacing: 2) {
                Text(player.name)
                    .font(.dmSans, size: 20, weight: .bold)
                    .foregroundColor(player.color.value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                if roundSession.usingHandicaps {
                    player.netScoreLabel(for: selectedScore, on: hole)
                }
            }
            
            Spacer(minLength: 0)
            
            ChipButton(
                style: selectedScore == .none ? .outline : .solid,
                text: selectedScore.name,
                foregroundColor: selectedScore == .none ? .systemGrayDark : .systemBlack,
                backgroundColor: selectedScore == .none ? colorScheme.lightGray : colorScheme.contrastGray
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .onAppear() { setScore() }
        .onChange(of: player, perform: { _ in setScore() })
        .onReceive(roundSession.$currentHole, perform: { _ in setScore() })
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
    
    @ViewBuilder private func button(for score: PlayerScore) -> some View {
        Button(role: score == .none ? .destructive : .none, action: {
            Haptics.fire(.light)
            selectedScore = score
        }) {
            Text(score == .none ? "Clear score" : score.menuName)
        }
    }
}

struct LeaderboardPlayerRow_Previews: PreviewProvider {
    static let kyle: Binding<Player> = .constant(
        Player(name: "Kyle", color: .blue, score: [1: "double", 2: "bogey", 3: "opar"], handicap: [1: 1])
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
                        .font(.dmSans, size: 15, weight: .bold)
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
                        .font(.dmSans, size: 15, weight: .bold)
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
            }
        }
        .environmentObject(RoundSession())
        .padding(.horizontal, 20)
        .background(Color.systemViewBackground)
        .holisticPreview()
    }
}
