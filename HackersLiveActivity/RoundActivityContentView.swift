import ActivityKit
import SwiftUI
import WidgetKit

struct RoundActivityContentView: View {
    @Environment(\.activityFamily) private var activityFamily
    @Environment(\.colorScheme) private var colorScheme

    let state: RoundLiveActivityAttributes.ContentState
    var isStale = false

    var body: some View {
        Group {
            if activityFamily == .small {
                RoundActivityCompactView(presentation: presentation, palette: palette)
            } else {
                RoundActivityMediumView(presentation: presentation, palette: palette)
            }
        }
        .foregroundStyle(palette.primary)
        .background(palette.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilitySummary)
    }

    private var presentation: RoundActivityPresentation {
        RoundActivityPresentation(state: state, isStale: isStale)
    }

    private var palette: RoundActivityPalette {
        RoundActivityPalette(colorScheme: colorScheme, status: presentation.status)
    }
}
