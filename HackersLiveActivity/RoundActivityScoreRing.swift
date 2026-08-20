import SwiftUI

struct RoundActivityScoreRing: View {
    let score: RoundLiveActivityAttributes.ScoreSummary
    let progress: Double
    let progressLabel: String
    let palette: RoundActivityPalette

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.outline, lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    palette.status,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("YOU")
                    .font(.caption.bold())
                    .foregroundStyle(palette.secondary)
                    .minimumScaleFactor(0.72)

                Text(score.value)
                    .font(.largeTitle.monospacedDigit().bold())
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())

                Text(progressLabel)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(9)
        }
    }
}
