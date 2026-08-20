import SwiftUI
import WidgetKit

struct RoundActivityLockScreenContainer: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: RoundLiveActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        RoundActivityContentView(state: state, isStale: isStale)
            .activityBackgroundTint(palette.background)
            .activitySystemActionForegroundColor(palette.primary)
    }

    private var palette: RoundActivityPalette {
        let presentation = RoundActivityPresentation(state: state, isStale: isStale)
        return RoundActivityPalette(colorScheme: colorScheme, status: presentation.status)
    }
}
