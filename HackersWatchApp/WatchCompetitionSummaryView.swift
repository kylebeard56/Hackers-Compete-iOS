import SwiftUI

struct WatchCompetitionDestination: Hashable {
    let kind: WatchRoundSnapshot.Competition.Kind
}

struct WatchCompetitionSummaryView: View {
    let competition: WatchRoundSnapshot.Competition

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(competition.summary.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(competition.summary.primary)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let secondary = competition.summary.secondary {
                    Text(secondary)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                }
            }

            Text(competition.summary.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Match Summary") {
    List {
        NavigationLink(value: WatchCompetitionDestination(kind: .matchup)) {
            WatchCompetitionSummaryView(
                competition: WatchPreviewFixtures.matchupCompetition
            )
        }
    }
}
#endif
