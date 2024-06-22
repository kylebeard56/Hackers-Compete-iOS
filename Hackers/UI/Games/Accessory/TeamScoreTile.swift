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
    /// If subtitle does not exists, player names will show instead.
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
                .font(.dmSans, size: 32, weight: .bold)
                .foregroundColor(placeholder ? Color.systemGray3 : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 32)
            
            Text(team)
                .font(.dmSans, size: 20, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 20)
            
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(colorScheme == .light ? Color.systemGray2 : Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: 15)
            } else {
                HStack(spacing: 6) {
                    ForEach(players, id: \.self) { p in
                        Text(p.name)
                            .font(.dmSans, size: 15, weight: .bold)
                            .foregroundColor(p.color.value)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        if p.id != players.last?.id {
                            Circle()
                                .fill(colorScheme == .light ? Color.systemGray3 : Color.systemGray)
                                .frame(width: 3, height: 3)
                        }
                    }
                }
                .frame(height: 15)
            }
        }
//        .padding(.horizontal, 10)
//        .padding(.vertical, 10)
//        .frame(width: width)
//        .background(Color.systemCard)
//        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
//        .cornerRadius(12)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: width)
        .background(placeholder ? Color.clear : Color.systemCard)
        .cornerRadius(12)
        .overlay(
            Group {
                if placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: strokeStyle)
                        .foregroundStyle(colorScheme.lightGray)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme.lightGray, lineWidth: 2)
                }
            }
        )
        .onAppear() {
            players = roundSession.players.filter({ $0.team[hole] == team })
        }
    }
    
    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0,
            dash: [1, 6],
            dashPhase: 0
        )
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
                TeamScoreTile(team: "Team two", score: "69", hole: 1, placeholder: true)
            }
            
            HStack(spacing: 10) {
                TeamScoreTile(team: "Team one", score: "420", hole: 1)
                TeamScoreTile(team: "Team two", score: "69", hole: 1)
            }
            
            HStack(spacing: 10) {
                TeamScoreTile(team: "Team one", score: "420", hole: 1, subtitle: "Won 100")
                TeamScoreTile(team: "Team two", score: "69", hole: 1, subtitle: "Lost 100")
            }
            
            HStack(spacing: 10) {
                TeamScoreTile(team: "Team one", score: "420", hole: 1, placeholder: true)
                TeamScoreTile(team: "Team two", score: "69", hole: 1, placeholder: true)
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
