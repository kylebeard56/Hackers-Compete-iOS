import SwiftUI

struct WatchHoleDestination: Hashable {}

struct WatchRoundOverviewView: View {
    @ObservedObject var store: WatchRoundStore

    @ViewBuilder
    var body: some View {
        if let snapshot = store.snapshot {
            overviewList(snapshot: snapshot)
        } else {
            WatchEmptyRoundView()
        }
    }

    private func overviewList(snapshot: WatchRoundSnapshot) -> some View {
        let currentSubject = snapshot.subjects.first

        return List {
            Section {
                VStack(spacing: 8) {
                    Text(snapshot.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let currentSubject {
                        HStack(spacing: 0) {
                            scoreMetric(.gross, subject: currentSubject)
                            Divider()
                                .padding(.vertical, 4)
                            scoreMetric(.net, subject: currentSubject)
                        }

                        let progress = store.cumulativeScore(for: currentSubject, basis: .gross)
                        Text(progress.isComplete
                            ? "Round complete"
                            : "\(progress.completedHoles) of \(progress.totalHoles) holes scored")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                NavigationLink(value: WatchHoleDestination()) {
                    Label("Enter Scores", systemImage: "pencil")
                }

                NavigationLink(value: WatchCompetitionDestination(kind: .field)) {
                    Label("Leaderboard", systemImage: "trophy")
                }

                if store.competition(ofKind: .matchup) != nil {
                    NavigationLink(value: WatchCompetitionDestination(kind: .matchup)) {
                        Label("Matchups", systemImage: "person.2")
                    }
                }
            }
        }
        .navigationTitle("Round")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scoreMetric(
        _ basis: WatchScoreBasis,
        subject: WatchRoundSnapshot.Subject
    ) -> some View {
        let summary = store.cumulativeScore(for: subject, basis: basis)
        return VStack(spacing: 2) {
            Text(summary.displayValue)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(basis == .net ? Color.green : Color.primary)
                .contentTransition(.numericText())
            Text(basis.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(basis.label) score")
        .accessibilityValue(summary.displayValue)
    }
}

#if DEBUG
#Preview("Round Overview") {
    NavigationStack {
        WatchRoundOverviewView(
            store: WatchRoundStore(
                snapshot: WatchPreviewFixtures.snapshot,
                defaults: UserDefaults(suiteName: "WatchOverviewPreview")!,
                activateSession: false
            )
        )
    }
}
#endif
