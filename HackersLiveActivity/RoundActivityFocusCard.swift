import SwiftUI

struct RoundActivityFocusCard: View {
    let presentation: RoundActivityPresentation
    let palette: RoundActivityPalette

    var body: some View {
        Group {
            switch presentation.focus {
            case let .matchup(left, right, standing, _, _):
                RoundActivityMatchupView(
                    left: left,
                    right: right,
                    standing: standing,
                    palette: palette
                )
            case let .competition(kind, title, position, score, detail):
                RoundActivityCompetitionView(
                    kind: kind,
                    title: title,
                    position: position,
                    score: score,
                    detail: detail,
                    formatLabel: presentation.formatLabel,
                    palette: palette
                )
            case let .hole(number, par, yardage, detail):
                RoundActivityHoleContextView(
                    number: number,
                    par: par,
                    yardage: yardage,
                    detail: detail,
                    palette: palette
                )
            }
        }
    }
}
