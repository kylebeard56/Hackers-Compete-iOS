import SwiftUI

struct RoundActivityMatchupSideView: View {
    let side: RoundLiveActivityAttributes.MatchupSideSummary
    let palette: RoundActivityPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(side.isCurrentUserSide ? "\(side.title) · YOU" : side.title)
                .font(.caption.bold())
                .foregroundStyle(side.isCurrentUserSide ? palette.brand : palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(side.score)
                .font(.title2.monospacedDigit().bold())
                .contentTransition(.numericText())

            Text(countingLabel)
                .font(.caption)
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }

    private var countingLabel: String {
        guard let players = side.countingPlayers, !players.isEmpty else {
            return "TBD"
        }
        return "\(players.joined(separator: " + ")) count"
    }
}
