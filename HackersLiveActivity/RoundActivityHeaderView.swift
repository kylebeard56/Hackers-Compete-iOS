import SwiftUI

struct RoundActivityHeaderView: View {
    let presentation: RoundActivityPresentation
    let palette: RoundActivityPalette

    var body: some View {
        HStack(spacing: 6) {
            Text("HACKERS GOLF")
                .font(.caption.bold())
                .foregroundStyle(palette.brand)

            Circle()
                .fill(palette.status)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            Text(presentation.statusLabel)
                .font(.caption.bold())
                .foregroundStyle(palette.secondary)

            Spacer(minLength: 4)

            Text(presentation.holePositionLabel)
                .font(.caption.monospacedDigit().bold())
        }
        .lineLimit(1)
    }
}
