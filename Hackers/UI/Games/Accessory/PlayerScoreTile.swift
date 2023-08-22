//
//  PlayerScoreTile.swift
//  Hackers
//
//  Created by Kyle Beard on 8/22/23.
//

import SwiftUI

struct PlayerScoreTile: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var player: Player
    var score: String
    var subtitle: String? = nil
    
    /// Pass in the number of tiles you plan to show in a single row (default is round session player count)
    var scale: Int?
    
    var width: CGFloat {
        var count = roundSession.players.count
        if let scale { count = scale }
        
        let outsidePadding: CGFloat = 40
        let insidePadding = CGFloat(count - 1) * 10.0
        return (UIScreen.main.bounds.width - outsidePadding - insidePadding) / CGFloat(count)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(score)
                .font(.dmSans(size: 32, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 32)
            
            Text(player.name)
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 20)
            
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(colorScheme == .light ? Color.systemGray2 : Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: 15)
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
    }
}

struct PlayerScoreTile_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        return rs
    }
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                PlayerScoreTile(player: kPlayerKyle, score: "120", subtitle: "Won 120")
                PlayerScoreTile(player: kPlayerSarah, score: "69", subtitle: "Won 69")
                PlayerScoreTile(player: kPlayerMurphy, score: "-45", subtitle: "Lost 45")
                PlayerScoreTile(player: kPlayerPablo, score: "-100", subtitle: "Lost 100")
            }
            
            HStack(spacing: 10) {
                PlayerScoreTile(player: kPlayerKyle, score: "120", subtitle: "Won 120", scale: 3)
                PlayerScoreTile(player: kPlayerSarah, score: "69", subtitle: "Won 69", scale: 3)
                PlayerScoreTile(player: kPlayerMurphy, score: "-45", subtitle: "Lost 45", scale: 3)
            }
            
            HStack(spacing: 10) {
                PlayerScoreTile(player: kPlayerKyle, score: "120", subtitle: "Won 120", scale: 2)
                PlayerScoreTile(player: kPlayerSarah, score: "69", subtitle: "Won 69", scale: 2)
            }
            
            PlayerScoreTile(player: kPlayerKyle, score: "120", subtitle: "Won 120", scale: 1)
        }
        .padding(.horizontal, 20)
        .alignCenter()
        .alignTop()
        .background(Color.systemViewBackground)
        .environmentObject(roundSession)
        .holisticPreview()
    }
}
