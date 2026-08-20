import SwiftUI

struct WatchHoleView: View {
    @ObservedObject var store: WatchRoundStore
    @State private var scoreBasis: WatchScoreBasis = .gross

    @ViewBuilder
    var body: some View {
        if let snapshot = store.snapshot {
            scoringList(snapshot: snapshot)
        } else {
            WatchEmptyRoundView()
        }
    }

    private func scoringList(snapshot: WatchRoundSnapshot) -> some View {
        let hole = snapshot.holes.first { $0.number == store.selectedHole }
        let hasPreviousHole = snapshot.holes.first?.number != store.selectedHole
        let hasNextHole = snapshot.holes.last?.number != store.selectedHole
        let completedCount = store.completedSubjectCount(on: store.selectedHole)

        return List {
            Section {
                HStack(spacing: 4) {
                    holeNavigationButton(
                        title: "Previous hole",
                        systemImage: "chevron.left",
                        isEnabled: hasPreviousHole,
                        action: store.selectPreviousHole
                    )

                    VStack(spacing: 4) {
                        Text("Hole \(store.selectedHole)")
                            .font(.headline)
                        Text("Par \(hole?.par ?? 4) · \(completedCount) of \(snapshot.subjects.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        ProgressView(
                            value: Double(completedCount),
                            total: Double(max(snapshot.subjects.count, 1))
                        )
                        .tint(.green)
                    }
                    .frame(maxWidth: .infinity)

                    holeNavigationButton(
                        title: "Next hole",
                        systemImage: "chevron.right",
                        isEnabled: hasNextHole,
                        action: store.selectNextHole
                    )
                }
            }

            if snapshot.phase == .paused {
                Section {
                    Label("Round paused", systemImage: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Tee Group") {
                ForEach(snapshot.subjects) { subject in
                    NavigationLink(value: WatchScoreEditorDestination(
                        subjectID: subject.id,
                        holeNumber: store.selectedHole
                    )) {
                        HStack(spacing: 8) {
                            Text(currentGrossLabel(for: subject))
                                .font(.title3.monospacedDigit().weight(.semibold))
                                .frame(width: 28, alignment: .leading)
                                .contentTransition(.numericText())

                            VStack(alignment: .leading, spacing: 4) {
                                WatchAdaptiveNameView(
                                    title: subject.title,
                                    compactTitle: subject.compactTitle
                                )

                                if let message = store.statusMessage(
                                    for: subject,
                                    holeNumber: store.selectedHole
                                ) {
                                    Text(message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 4)
                            WatchScoreStatusView(
                                state: store.status(for: subject, holeNumber: store.selectedHole)
                            )

                            VStack(alignment: .trailing, spacing: 0) {
                                Text(cumulativeScoreLabel(for: subject))
                                    .font(.headline.monospacedDigit())
                                    .contentTransition(.numericText())
                                Text(scoreBasis.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(
                        snapshot.phase == .paused
                            || store.status(for: subject, holeNumber: store.selectedHole) == .pending
                    )
                    .accessibilityLabel(accessibilityLabel(for: subject))
                }
            }

            if completedCount == snapshot.subjects.count, hasNextHole {
                Button("Next Hole", systemImage: "arrow.right.circle.fill") {
                    store.selectNextHole()
                }
                .buttonStyle(.borderedProminent)
            }

            Section {
                WatchChipPicker(
                    selection: $scoreBasis,
                    options: WatchScoreBasis.allCases.map {
                        .init(value: $0, label: $0.label)
                    }
                )
                .accessibilityLabel("Cumulative score")
            } footer: {
                Text("Partial rounds are shown relative to par.")
            }
        }
        .navigationTitle("Scores")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func currentGrossLabel(for subject: WatchRoundSnapshot.Subject) -> String {
        store.grossValue(for: subject, holeNumber: store.selectedHole).map(String.init) ?? "—"
    }

    private func cumulativeScoreLabel(for subject: WatchRoundSnapshot.Subject) -> String {
        store.cumulativeScore(for: subject, basis: scoreBasis).displayValue
    }

    private func accessibilityLabel(for subject: WatchRoundSnapshot.Subject) -> String {
        let current = currentGrossLabel(for: subject)
        let total = cumulativeScoreLabel(for: subject)
        return "\(subject.title), hole \(store.selectedHole) gross \(current), cumulative \(scoreBasis.label.lowercased()) \(total)"
    }

    private func holeNavigationButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint("Changes the scoring hole")
    }
}

#if DEBUG
#Preview("Hole Scoring") {
    NavigationStack {
        WatchHoleView(
            store: WatchRoundStore(
                snapshot: WatchPreviewFixtures.snapshot,
                defaults: UserDefaults(suiteName: "WatchHolePreview")!,
                activateSession: false
            )
        )
    }
}
#endif
