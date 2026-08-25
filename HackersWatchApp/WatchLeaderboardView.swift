import SwiftUI

struct WatchLeaderboardView: View {
    @ObservedObject var store: WatchRoundStore
    let kind: WatchRoundSnapshot.Competition.Kind
    @State private var selectedVariantID = "individual"

    private var competition: WatchRoundSnapshot.Competition? {
        store.competition(ofKind: kind)
    }

    var body: some View {
        Group {
            if let competition {
                leaderboard(competition)
            } else {
                ContentUnavailableView(
                    "Standings Unavailable",
                    systemImage: "trophy",
                    description: Text("Open Hackers on iPhone to refresh this round.")
                )
            }
        }
        .navigationTitle(competition?.title ?? "Standings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func leaderboard(_ competition: WatchRoundSnapshot.Competition) -> some View {
        List {
            if let variants = competition.leaderboardVariants, variants.count > 1 {
                Section {
                    WatchChipPicker(
                        selection: $selectedVariantID,
                        options: variants.map { .init(value: $0.id, label: $0.label) }
                    )
                    .accessibilityLabel("Group standings")
                }
            }

            Section {
                summary(competition)
            } footer: {
                Text(competition.formatLabel)
            }

            ForEach(selectedSections(in: competition)) { section in
                Section {
                    ForEach(section.rows) { row in
                        standingRow(row, kind: competition.kind)
                            .listRowBackground(
                                row.isCurrentUser
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                        if let detail = section.detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
            }
        }
        .onAppear {
            selectAvailableVariant(in: competition)
        }
        .onChange(of: competition.leaderboardVariants?.map(\.id)) { _, _ in
            selectAvailableVariant(in: competition)
        }
    }

    private func selectedSections(
        in competition: WatchRoundSnapshot.Competition
    ) -> [WatchRoundSnapshot.Competition.Section] {
        competition.leaderboardVariants?
            .first { $0.id == selectedVariantID }?
            .sections
            ?? competition.leaderboardVariants?.first?.sections
            ?? competition.sections
    }

    private func selectAvailableVariant(in competition: WatchRoundSnapshot.Competition) {
        guard let variants = competition.leaderboardVariants, !variants.isEmpty else { return }
        if !variants.contains(where: { $0.id == selectedVariantID }) {
            selectedVariantID = variants[0].id
        }
    }

    private func summary(_ competition: WatchRoundSnapshot.Competition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(competition.summary.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(competition.summary.primary)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                if let secondary = competition.summary.secondary {
                    Text(secondary)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            Text(competition.summary.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func standingRow(
        _ row: WatchRoundSnapshot.Competition.Row,
        kind: WatchRoundSnapshot.Competition.Kind
    ) -> some View {
        if kind == .field {
            fieldStandingRow(row)
        } else {
            matchupStandingRow(row)
        }
    }

    private func fieldStandingRow(
        _ row: WatchRoundSnapshot.Competition.Row
    ) -> some View {
        HStack(spacing: 8) {
            Text(row.position ?? "—")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(row.isCurrentUser ? .primary : .secondary)
                .frame(minWidth: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.body.weight(row.isCurrentUser ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text([row.handicapLabel, row.thru].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                if let gross = row.grossScore {
                    scoreDetail(label: "G", value: gross, emphasized: row.netScore == nil)
                }
                if let net = row.netScore {
                    scoreDetail(label: "N", value: net, emphasized: true)
                }
                if row.grossScore == nil, row.netScore == nil {
                    Text(row.score)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func scoreDetail(label: String, value: String, emphasized: Bool) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(emphasized ? Color.primary : Color.secondary)
        }
        .font(.caption.monospacedDigit().weight(emphasized ? .semibold : .regular))
        .lineLimit(1)
    }

    private func matchupStandingRow(
        _ row: WatchRoundSnapshot.Competition.Row
    ) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.body.weight(row.isCurrentUser ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text([row.subtitle, row.thru].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.score)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)

                if let winPercentage = row.winPercentage {
                    Text("\(winPercentage)% win")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Field Leaderboard") {
    NavigationStack {
        WatchLeaderboardView(
            store: WatchRoundStore(
                snapshot: WatchPreviewFixtures.fieldSnapshot,
                defaults: UserDefaults(suiteName: "WatchLeaderboardPreview")!,
                activateSession: false
            ),
            kind: .field
        )
    }
}

#Preview("Matchups") {
    NavigationStack {
        WatchLeaderboardView(
            store: WatchRoundStore(
                snapshot: WatchPreviewFixtures.matchupSnapshot,
                defaults: UserDefaults(suiteName: "WatchMatchupsPreview")!,
                activateSession: false
            ),
            kind: .matchup
        )
    }
}
#endif
