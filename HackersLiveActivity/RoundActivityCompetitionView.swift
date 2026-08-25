import SwiftUI

struct RoundActivityCompetitionView: View {
    let kind: RoundLiveActivityAttributes.CompetitionSummary.Kind
    let title: String
    let position: String?
    let score: String?
    let detail: String
    let formatLabel: String?
    let palette: RoundActivityPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(kind == .team ? title : "FIELD POSITION")
                        .font(.caption.bold())
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                    Text(kind == .team ? (score ?? "—") : (position ?? "—"))
                        .font(.title2.monospacedDigit().bold())
                }

                Spacer(minLength: 2)

                if kind == .team, let position {
                    Text("#\(position)")
                        .font(.headline.monospacedDigit().bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(palette.elevatedSurface, in: Capsule())
                }
            }

            HStack(spacing: 5) {
                Text(detail)
                if let formatLabel {
                    Text("·")
                    Text(formatLabel)
                }
            }
            .font(.caption)
            .foregroundStyle(palette.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
    }
}
