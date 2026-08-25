import SwiftUI

struct RoundActivityHoleContextView: View {
    let number: String
    let par: String
    let yardage: String
    let detail: String
    let palette: RoundActivityPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("HOLE \(number) · PAR \(par)")
                .font(.caption.bold())
                .foregroundStyle(palette.secondary)

            Text(yardage == "—" ? "Round in progress" : "\(yardage) YDS")
                .font(.title2.monospacedDigit().bold())

            Text(detail)
                .font(.caption)
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
        }
    }
}
