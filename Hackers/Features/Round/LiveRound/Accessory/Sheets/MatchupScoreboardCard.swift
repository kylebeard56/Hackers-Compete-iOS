//
//  MatchupScoreboardCard.swift
//  Hackers
//

import SwiftUI

struct MatchupScoreboardCard: View {
    let presentation: MatchupResultPresentation
    let matchIndex: Int
    let statusTitle: String
    let statusDetail: String
    let isFinal: Bool
    let holesCompleted: Int
    let totalHoles: Int
    let leftColor: Color
    let rightColor: Color
    let palette: DesignPalette

    private var progressLabel: String {
        if isFinal {
            return "Final"
        }
        guard holesCompleted > 0, totalHoles > 0 else { return "Not started" }
        return "Thru \(min(holesCompleted, totalHoles)) of \(totalHoles)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Match \(matchIndex)".uppercased())
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral2)

                Spacer(minLength: 8)

                Text(progressLabel.uppercased())
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(isFinal ? Color.accentGreen : Color.neutral)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .fontStyle(kFontName, size: 21, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(statusDetail)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 12) {
                if let leftSide = presentation.sides.first {
                    sideColumn(
                        leftSide,
                        color: leftColor,
                        alignment: .leading
                    )
                }

                Text("VS")
                    .fontStyle(kFontName, size: 11, weight: .bold)
                    .foregroundStyle(Color.neutral2)
                    .accessibilityHidden(true)

                if let rightSide = presentation.sides.dropFirst().first {
                    sideColumn(
                        rightSide,
                        color: rightColor,
                        alignment: .trailing
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(
            interactive: false,
            forceMaterial: true,
            tint: palette.cardColor,
            strokeOpacity: 0.42,
            shadowOpacity: 0.14
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func sideColumn(
        _ side: MatchupResultPresentation.Side,
        color: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(side.scoreLabel)
                .fontStyle(kFontName, size: 32, weight: .semibold)
                .foregroundStyle(color)
                .contentTransition(.numericText())

            HStack(spacing: 6) {
                if alignment == .trailing {
                    resultSymbol(for: side)
                }

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(side.title)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(2)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)

                if alignment == .leading {
                    resultSymbol(for: side)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    @ViewBuilder
    private func resultSymbol(for side: MatchupResultPresentation.Side) -> some View {
        if presentation.isTie, presentation.hasCompleteSides {
            Image(systemName: "equal.circle.fill")
                .foregroundStyle(Color.neutral)
                .accessibilityLabel("Tied")
        } else if presentation.winningSideID == side.id {
            Image(systemName: isFinal ? "checkmark.seal.fill" : "arrow.up.right.circle.fill")
                .foregroundStyle(side.accentColor ?? palette.foregroundColor)
                .accessibilityLabel(isFinal ? "Winner" : "Leader")
        }
    }

    private var accessibilitySummary: String {
        let scores = presentation.sides.prefix(2).map {
            "\($0.title), \($0.scoreLabel)"
        }.joined(separator: "; ")
        return "Match \(matchIndex). \(statusTitle). \(statusDetail). \(scores). \(progressLabel)."
    }
}
