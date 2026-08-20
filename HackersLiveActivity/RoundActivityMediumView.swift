import SwiftUI

struct RoundActivityMediumView: View {
    let presentation: RoundActivityPresentation
    let palette: RoundActivityPalette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundActivityProgressMark(
                progress: presentation.progress,
                palette: palette
            )
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(presentation.holeTitle)
                        .foregroundStyle(palette.primary)
                    Text("· \(presentation.holeDetail)")
                        .foregroundStyle(palette.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(presentation.grossScore.value)
                        .font(.title.monospacedDigit().bold())
                        .contentTransition(.numericText())

                    if let netScore = presentation.netScore {
                        Text("Net \(netScore.value)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.brand)
                            .contentTransition(.numericText())
                    }
                }

                HStack(spacing: 4) {
                    Text(presentation.personalContextLabel)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Divider()
                .overlay(palette.outline)
                .frame(height: 76)
                .accessibilityHidden(true)

            RoundActivityContextSummaryView(
                presentation: presentation,
                palette: palette
            )
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 112, maxHeight: 128)
    }
}

private struct RoundActivityProgressMark: View {
    let progress: Double
    let palette: RoundActivityPalette

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.surface)

            Circle()
                .stroke(palette.outline, lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    palette.status,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "figure.golf")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.brand)
        }
        .accessibilityHidden(true)
    }
}

private struct RoundActivityContextSummaryView: View {
    let presentation: RoundActivityPresentation
    let palette: RoundActivityPalette

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if presentation.isPersonalScoreCounting {
                RoundActivityCountingPill(fill: palette.brand)
            }

            Text(presentation.contextPrimaryLabel)
                .font(.title2.monospacedDigit().bold())
                .foregroundStyle(primaryColor)
                .lineLimit(1)

            if let secondary = presentation.contextSecondaryLabel {
                Text(secondary)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }

            if !presentation.contextDetailLabel.isEmpty {
                Text(presentation.contextDetailLabel)
                    .font(.caption)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
        }
    }

    private var primaryColor: Color {
        presentation.emphasizesMatchup ? palette.brand : palette.primary
    }

    private var secondaryColor: Color {
        presentation.emphasizesMatchup ? palette.brand : palette.secondary
    }

    private var detailColor: Color {
        presentation.contextKind == .combined ? palette.brand : palette.secondary
    }
}

struct RoundActivityCountingPill: View {
    let fill: Color

    var body: some View {
        Text("COUNTING")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fill, in: Capsule())
            .fixedSize()
            .accessibilityLabel("Your score is counting")
    }
}
