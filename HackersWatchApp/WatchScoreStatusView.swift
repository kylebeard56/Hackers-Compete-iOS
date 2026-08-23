import SwiftUI

struct WatchScoreStatusView: View {
    let state: PendingWatchMutation.State?

    var body: some View {
        switch state {
        case .pending:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Pending sync")
        case .conflict:
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .foregroundStyle(.yellow)
                .accessibilityLabel("Changed elsewhere")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Needs attention")
        case nil:
            EmptyView()
        }
    }
}
