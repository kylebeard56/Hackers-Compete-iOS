//
//  TeamScoreRow.swift
//  Hackers
//
//  Created by Kyle Beard on 8/10/23.
//

import SwiftUI

enum ScoreRowSize {
    case normal, large
    
    var fontSize: CGFloat {
        switch self {
        case .normal:   return 15
        case .large:    return 17
        }
    }
    
    var chipSize: CGFloat {
        switch self {
        case .normal:   return 11
        case .large:    return 13
        }
    }
    
    var scoreWidth: CGFloat {
        switch self {
        case .normal:   return 20
        case .large:    return 40
        }
    }
}

// MARK: - Player

struct PlayerScoreRow: View {
    @Environment(\.colorScheme) var colorScheme
    var player: Player
    var score: String
    var size: ScoreRowSize = .normal
    var chipIcon: String? // AwesomeIcon
    var chipLabel: String?

    var body: some View {
        HStack {
            Text(player.name)
                .font(.dmSans(size: size.fontSize, weight: .bold))
                .foregroundColor(player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
            
            if let chipLabel {
                HStack(spacing: 4) {
                    if let chipIcon {
                        AwesomeImage(rawIcon: chipIcon.unicode, style: .regular, size: 13, color: player.color.value)
                    }
                    Text(chipLabel)
                        .font(.dmSans(size: size.fontSize, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(player.color.value.opacity(colorScheme.translucent))
                .cornerRadius(4)
            }
            
            Text(score)
                .font(.dmSans(size: size.fontSize, weight: .bold))
                .foregroundColor(player.color.value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

struct PlayerScoreRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PlayerScoreRow(player: kPlayerKyle, score: 99.toGolfScore)
            PlayerScoreRow(player: kPlayerKyle, score: 99.toGolfScore, chipIcon: "f077", chipLabel: "+240")
        }
        .holisticPreview()
    }
}

// MARK: - Team

struct TeamScoreRow: View {
    var name: String
    var score: String
    var size: ScoreRowSize = .normal
    
    var body: some View {
        HStack {
            Text(name)
                .font(.dmSans(size: size.fontSize, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
            
            Text(score)
                .font(.dmSans(size: size.fontSize, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                //.frame(width: size.scoreWidth, alignment: .center)
        }
    }
}

struct TeamScoreRow_Previews: PreviewProvider {
    static var previews: some View {
        TeamScoreRow(name: "Team one", score: 99.toGolfScore)
            .holisticPreview()
    }
}
