import SwiftUI

struct RoundActivityProgressFooter: View {
    let presentation: RoundActivityPresentation
    let palette: RoundActivityPalette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            footer(oddsLabel: presentation.winOddsLongLabel)
            footer(oddsLabel: presentation.winOddsShortLabel)
        }
        .font(.caption)
        .foregroundStyle(palette.secondary)
    }

    private func footer(oddsLabel: String?) -> some View {
        HStack(spacing: 8) {
            Text(presentation.combinedProgressLabel.uppercased())
                .monospacedDigit()
                .lineLimit(1)

            Spacer(minLength: 8)

            Text((oddsLabel ?? presentation.holesRemainingLabel).uppercased())
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(oddsLabel == nil ? palette.secondary : palette.brand)
                .lineLimit(1)
        }
    }
}
