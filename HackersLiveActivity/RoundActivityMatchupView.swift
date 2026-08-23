import SwiftUI

struct RoundActivityMatchupView: View {
    let left: RoundLiveActivityAttributes.MatchupSideSummary
    let right: RoundLiveActivityAttributes.MatchupSideSummary
    let standing: String
    let palette: RoundActivityPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(standing)
                    .font(.headline.monospacedDigit().bold())
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text("TEAM MATCH")
                    .font(.caption.bold())
                    .foregroundStyle(palette.secondary)
            }

            HStack(spacing: 8) {
                RoundActivityMatchupSideView(side: left, palette: palette)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(palette.outline)
                    .frame(width: 1, height: 48)
                    .accessibilityHidden(true)

                RoundActivityMatchupSideView(side: right, palette: palette)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
