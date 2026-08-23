import SwiftUI

struct RoundActivityCompactView: View {
    let presentation: RoundActivityPresentation
    let palette: RoundActivityPalette

    var body: some View {
        HStack(spacing: 8) {
            compactProgressMark

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.compactHoleParLabel)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(presentation.grossScore.value)
                        .font(.headline.monospacedDigit().bold())

                    if let netScore = presentation.netScore {
                        Text("N \(netScore.value)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(palette.brand)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text(presentation.compactHolesRemainingLabel)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)

                if let standing = presentation.matchStandingLabel {
                    Text(standing)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.brand)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
    }

    private var compactProgressMark: some View {
        ZStack {
            Circle()
                .stroke(palette.outline, lineWidth: 3)

            Circle()
                .trim(from: 0, to: presentation.progress)
                .stroke(
                    palette.status,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "figure.golf")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.brand)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

}
