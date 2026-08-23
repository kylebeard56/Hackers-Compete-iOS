import ActivityKit
import SwiftUI
import WidgetKit

struct RoundLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            RoundActivityLockScreenContainer(
                state: context.state,
                isStale: context.isStale
            )
            .widgetURL(context.state.deepLinkURL)
        } dynamicIsland: { context in
            let presentation = RoundActivityPresentation(
                state: context.state,
                isStale: context.isStale
            )

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.15))
                            Image(systemName: "figure.golf")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(presentation.holeTitle) · \(presentation.holeDetail)")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(presentation.personalContextLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(presentation.grossScore.value)
                            .font(.title2.monospacedDigit().bold())
                            .contentTransition(.numericText())
                        if let netScore = presentation.netScore {
                            Text("Net \(netScore.value)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .contentTransition(.numericText())
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if presentation.isPersonalScoreCounting {
                            RoundActivityCountingPill(fill: .green)
                        }

                        Text(presentation.contextPrimaryLabel)
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(
                                presentation.emphasizesMatchup ? Color.green : Color.primary
                            )
                            .lineLimit(1)
                        if let secondary = presentation.contextSecondaryLabel {
                            Text(secondary)
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(
                                    presentation.emphasizesMatchup ? Color.green : Color.secondary
                                )
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    islandProgress(presentation)
                }
            } compactLeading: {
                Text(presentation.grossScore.value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(presentation.compactContextLabel)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            } minimal: {
                Text(presentation.grossScore.value)
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(.green)
            }
            .keylineTint(context.isStale ? .orange : .green)
            .widgetURL(context.state.deepLinkURL)
        }
        .supplementalActivityFamilies([.small, .medium])
    }

    private func islandProgress(
        _ presentation: RoundActivityPresentation
    ) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text(presentation.combinedProgressLabel)
                    .font(.caption2)
                    .foregroundStyle(
                        Color.secondary
                    )
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(presentation.holesRemainingLabel)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: proxy.size.width * presentation.progress)
                }
            }
            .frame(height: 3)
        }
    }
}
