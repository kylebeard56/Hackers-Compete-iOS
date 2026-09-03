//
//  MatchupCountingChancesCard.swift
//  Hackers
//

import SwiftUI

struct MatchupCountingChancesCard: View {
    let sides: [MatchupResultPresentation.Side]
    let probabilities: [String: Int]
    let isFinal: Bool
    let palette: DesignPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isFinal ? "Final scoring contributors" : "Chance of counting")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text("Probability each player finishes in the Best 2 used for the matchup total")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(sides) { side in
                let accent = side.accentColor ?? palette.foregroundColor
                let players = side.participants
                    .filter { probabilities[$0.id] != nil }
                    .sorted {
                        let leftChance = probabilities[$0.id, default: 0]
                        let rightChance = probabilities[$1.id, default: 0]
                        if leftChance != rightChance { return leftChance > rightChance }
                        return $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
                    }

                if players.isPopulated {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(accent)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text(side.title.uppercased())
                                .fontStyle(kFontName, size: 11, weight: .semibold)
                                .foregroundStyle(Color.neutral2)
                        }

                        ForEach(players) { participant in
                            let probability = max(0, min(100, probabilities[participant.id, default: 0]))

                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(participant.name.fullName)
                                        .fontStyle(kFontName, size: 13, weight: .medium)
                                        .foregroundStyle(palette.foregroundColor)
                                        .lineLimit(1)

                                    Spacer(minLength: 8)

                                    Text("\(probability)%")
                                        .fontStyle(kFontName, size: 13, weight: .semibold)
                                        .foregroundStyle(accent)
                                        .contentTransition(.numericText())
                                }

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.neutral5.opacity(0.35))
                                        Capsule()
                                            .fill(accent)
                                            .frame(width: geometry.size.width * CGFloat(probability) / 100)
                                    }
                                }
                                .frame(height: 7)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "\(participant.name.fullName), \(probability) percent chance of counting in the Best 2"
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }
}
