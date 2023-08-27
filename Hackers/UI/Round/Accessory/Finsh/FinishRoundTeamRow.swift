//
//  FinishRoundTeamRow.swift
//  Hackers
//
//  Created by Kyle Beard on 8/27/23.
//

import SwiftUI

struct FinishRoundTeamRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    var players: [Player]
    var team: String
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
            .cornerRadius(12)
    }
    
    @ViewBuilder private var content: some View {
        let finalScore = players
            .flatMap({ $0.score.values })
            .compactMap({ PlayerScore(rawValue: $0)?.numericalValue })
            .reduce(0, +)
            .toGolfScore
        
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text(team)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text(finalScore)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
            }
            
            ForEach(players, id: \.self) { player in
                FinishRoundPlayerRow(player: player)
            }
        }
    }
}

struct FinishRoundTeamRow_Previews: PreviewProvider {
    static var previews: some View {
        FinishRoundTeamRow(players: [kPlayerKyle, kPlayerSarah], team: "Team one")
    }
}
