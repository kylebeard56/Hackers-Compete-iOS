//
//  TeamScoreTile.swift
//  Hackers
//
//  Created by Kyle Beard on 8/22/23.
//

import SwiftUI

struct TeamScoreTile: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var team: String
    var score: String
    var hole: Int
    var showTeamNames: Bool = true
    var subtitle: String? = nil
    var placeholder: Bool = false
    
    /// Pass in the number of tiles you plan to show in a single row (default is round session player count)
    var scale: Int?
    
    @State private var players: [Player] = []
    
    var width: CGFloat {
        var count = roundSession.teams.count
        if let scale { count = scale }
        
        let outsidePadding: CGFloat = 40
        let insidePadding = CGFloat(count - 1) * 10.0
        return (UIScreen.main.bounds.width - outsidePadding - insidePadding) / CGFloat(count)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(score)
                .font(.dmSans(size: 32, weight: .bold))
                .foregroundColor(placeholder ? Color.systemGrayDark.opacity(0.7) : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 32)
            
            Text(team)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 20)
            
            if showTeamNames {
                HStack(spacing: 6) {
                    ForEach(players, id: \.self) { p in
                        Text(p.name)
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(p.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        if p.id != players.last?.id {
                            Circle()
                                .fill(Color.systemGray3)
                                .frame(width: 3, height: 3)
                        }
                    }
                }
                .frame(height: 15)
            }
            
            if let subtitle {
                Text(subtitle)
                    .font(.dmSans(size: 13, weight: .bold))
                    .foregroundColor(colorScheme == .light ? Color.systemGray2 : Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: 13)
//                    .padding(.vertical, 2)
//                    .padding(.horizontal, 4)
//                    .frame(height: 17)
//                    .background(Color.systemGray6)
//                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: width)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() {
            players = roundSession.players.filter({ $0.team[hole] == team })
        }
    }
}

struct TeamScoreTile_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        rs.teams = ["Team one", "Team two"]
        return rs
    }
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                TeamScoreTile(team: "Team one", score: "420", hole: 1)
                TeamScoreTile(team: "Team two", score: "69", hole: 1)
            }
            
            HStack(spacing: 10) {
                TeamScoreTile(team: "Team one", score: "420", hole: 1, subtitle: "Won 100")
                TeamScoreTile(team: "Team two", score: "69", hole: 1, subtitle: "Lost 100")
            }
        }
        .padding(.horizontal, 20)
        .alignCenter()
        .alignTop()
        .background(Color.systemViewBackground)
        .environmentObject(roundSession)
        .holisticPreview()
    }
}
