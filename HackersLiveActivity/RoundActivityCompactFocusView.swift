import SwiftUI

struct RoundActivityCompactFocusView: View {
    let focus: RoundActivityPresentation.Focus
    let palette: RoundActivityPalette

    var body: some View {
        switch focus {
        case let .matchup(left, right, standing, _, _):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(standing)
                        .font(.headline.monospacedDigit().bold())
                    Text("\(left.title) \(left.score) · \(right.title) \(right.score)")
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Text(left.isCurrentUserSide ? left.score : right.score)
                    .font(.headline.monospacedDigit().bold())
            }
        case let .competition(kind, title, position, score, detail):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(kind == .team ? (score ?? "—") : (position ?? "—"))
                        .font(.headline.monospacedDigit().bold())
                    Text(kind == .team ? title : "Field position")
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Text(detail)
                    .font(.caption.bold())
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        case let .hole(_, par, yardage, detail):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Par \(par)")
                    .font(.headline.monospacedDigit().bold())
                if yardage != "—" {
                    Text("\(yardage) yd")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }
        }
    }
}
