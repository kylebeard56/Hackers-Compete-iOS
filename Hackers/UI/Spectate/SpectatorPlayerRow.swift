//
//  SpectatorPlayerRow.swift
//  Hackers
//
//  Created by Kyle Beard on 7/19/23.
//

import SwiftUI

struct SpectatorPlayerRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: SpectateViewModel
    
    @Binding var player: Player
    var hole: Int
    
    @State private var currentScore: String = ""
    @State private var selectedScore: PlayerScore = .none
    
    var body: some View {
        content
            .background(Color.systemCard)
            .cornerRadius(12)
            .environmentObject(roundSession)
    }
    
    var content: some View {
        HStack(spacing: 16) {
            Text(currentScore)
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(player.color.value)
                .frame(width: 40, height: 36)
                .background(player.color.value.opacity(colorScheme.translucent))
                .cornerRadius(6)
            
            Text(player.name)
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            Spacer(minLength: 0)
            
            Text(selectedScore.spectatingName)
                .font(.dmSans(size: 15, weight: .medium))
                .foregroundColor(selectedScore == .none ? Color.systemGray : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .onAppear() { setScore() }
        .onChange(of: player, perform: { _ in setScore() })
    }
    
    private func setScore() {
        /// 1. Initialize the selected score should appear or the player change
        selectedScore = PlayerScore(rawValue: player.score[hole] ?? "") ?? .none
        currentScore = "0"
        
        // TODO: This breaks the session spectation since the hole range if different
        // We should probably make our own view for scores with tiles and options to refresh and stuff.
        
        let left = viewModel.holeRange.firstIndex(of: viewModel.startingHole) ?? 0
        let right = viewModel.holeRange.firstIndex(of: hole) ?? 0
        let range = viewModel.holeRange[left...right]
        let score = ScoreUtil.Stroke.computeTotal(for: player, over: Array(range), using: .medal)
        currentScore = score.toGolfScore
    }
}

struct SpectatorPlayerRow_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Leaderboard")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                SpectatorPlayerRow(viewModel: SpectateViewModel(), player: .constant(kPlayerKyle), hole: 1)
                SpectatorPlayerRow(viewModel: SpectateViewModel(), player: .constant(kPlayerSarah), hole: 1)
                SpectatorPlayerRow(viewModel: SpectateViewModel(), player: .constant(kPlayerMurphy), hole: 1)
                SpectatorPlayerRow(viewModel: SpectateViewModel(), player: .constant(kPlayerPablo), hole: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(Color.systemGray5, width: 3, cornerRadius: 12)
            .cornerRadius(12)
        }
        .environmentObject(RoundSession())
        .background(Color.systemViewBackground)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
