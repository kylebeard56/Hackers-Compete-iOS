//
//  LeaderboardTeamRow.swift
//  Hackers
//
//  Created by Kyle Beard on 6/23/23.
//

import SwiftUI

struct LeaderboardTeamRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession

    var team: String
    var hole: Int
    
    @State private var currentScore: String = ""
    @State private var scores: [String: Int] = [:]
    
    var body: some View {
        content
            .environmentObject(roundSession)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
            .cornerRadius(12)
    }
    
    private var content: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text(team)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text(currentScore)
                    .font(.dmSans, size: 20, weight: .bold)
                    .foregroundColor(Color.systemBlack)
            }
            
            ForEach($roundSession.players, id: \.self) { p in
                if p.team[hole].wrappedValue == team {
                    LeaderboardPlayerRow(player: p, hole: hole, teamStyle: true)
                        .onScoreUpdate(perform: { value in
                            self.updateScoring(with: value, for: p.wrappedValue.id)
                        })
                }
            }
        }
    }
    
    private func updateScoring(with value: Int, for playerID: String) {
        scores.updateValue(value, forKey: playerID)
        let sum = scores.values.reduce(0, +)
        currentScore = sum.toGolfScore
    }
}

struct LeaderboardTeamRow_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var previews: some View {
        LeaderboardTeamRow(team: "Team one", hole: 1)
            .environmentObject(roundSession)
            .onAppear() {
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                roundSession.teams = ["Team one", "Team two"]
            }
            .background(Color.systemViewBackground)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
