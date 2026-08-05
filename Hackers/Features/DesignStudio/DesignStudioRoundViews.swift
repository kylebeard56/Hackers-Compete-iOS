#if SANDBOX
import SwiftUI

struct DesignStudioLobbyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: DesignStudioRoundStore
    @State private var showLiveRound = false

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.section) {
                lobbyHeader
                configuration
                roster
            }
            .padding(.horizontal, DesignStudioTheme.Space.large)
            .padding(.bottom, DesignStudioTheme.Space.screen)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Game Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                DesignStudioPrimaryButton(title: "Start Round", symbol: "flag.fill") {
                    showLiveRound = true
                }
                .padding(DesignStudioTheme.Space.large)
            }
            .background(theme.canvas)
        }
        .navigationDestination(isPresented: $showLiveRound) {
            DesignStudioLiveRoundView(store: store)
        }
    }

    private var lobbyHeader: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.small) {
            Text("PINEVIEW GOLF CLUB")
                .font(DesignStudioTypography.font(.eyebrow))
                .tracking(1.4)
                .foregroundStyle(DesignStudioTheme.gold)
            Text("Saturday foursome")
                .font(DesignStudioTypography.font(.title))
                .foregroundStyle(theme.primaryText)
            HStack(spacing: DesignStudioTheme.Space.medium) {
                Label("Sat, Jul 25", systemImage: "calendar")
                Label("8:30 AM", systemImage: "clock")
                Label("18 holes", systemImage: "flag")
            }
            .font(DesignStudioTypography.font(.caption))
            .foregroundStyle(theme.secondaryText)
        }
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Round setup")
            DesignStudioSurface {
                VStack(spacing: 0) {
                    HStack {
                        Label("Scoring format", systemImage: "trophy.fill")
                            .font(DesignStudioTypography.font(.heading))
                        Spacer()
                        Picker("Format", selection: $store.format) {
                            ForEach(DesignStudioRoundStore.Format.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .tint(DesignStudioTheme.forest)
                    }
                    .padding(DesignStudioTheme.Space.large)

                    Divider().padding(.leading, 16)

                    Toggle(isOn: $store.teamsEnabled) {
                        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                            Text("Teams").font(DesignStudioTypography.font(.heading))
                            Text("Forest vs Gold").font(DesignStudioTypography.font(.caption)).foregroundStyle(theme.secondaryText)
                        }
                    }
                    .padding(DesignStudioTheme.Space.large)

                    Divider().padding(.leading, 16)

                    Toggle(isOn: $store.handicapsEnabled) {
                        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                            Text("Handicaps").font(DesignStudioTypography.font(.heading))
                            Text("Course strokes by player").font(DesignStudioTypography.font(.caption)).foregroundStyle(theme.secondaryText)
                        }
                    }
                    .padding(DesignStudioTheme.Space.large)
                }
                .foregroundStyle(theme.primaryText)
                .tint(DesignStudioTheme.forest)
            }
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            HStack {
                DesignStudioSectionLabel(title: "Players · \(store.players.count)")
                Button {
                    store.addMockPlayer()
                } label: {
                    Label("Add", systemImage: "person.badge.plus")
                        .font(DesignStudioTypography.font(.caption))
                        .foregroundStyle(DesignStudioTheme.forest)
                }
                .buttonStyle(.plain)
            }

            DesignStudioSurface {
                VStack(spacing: 0) {
                    ForEach(Array(store.players.enumerated()), id: \.element.id) { index, player in
                        playerRow(player)
                        if index < store.players.count - 1 { Divider().padding(.leading, 76) }
                    }
                }
            }
        }
    }

    private func playerRow(_ player: DesignStudioPlayer) -> some View {
        HStack(spacing: DesignStudioTheme.Space.medium) {
            DesignStudioInitialBadge(initials: player.initials, color: player.teamColor)
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                Text(player.name)
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(theme.primaryText)
                Text(store.teamsEnabled ? "\(player.teamName) team" : "Individual")
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
            if store.handicapsEnabled {
                HStack(spacing: DesignStudioTheme.Space.small) {
                    Button { store.updateHandicap(for: player.id, delta: -1) } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    Text(String(format: "%.1f", player.handicap ?? 0))
                        .font(DesignStudioTypography.font(.body))
                        .monospacedDigit()
                        .frame(minWidth: 34)
                    Button { store.updateHandicap(for: player.id, delta: 1) } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .foregroundStyle(DesignStudioTheme.forest)
            }
            Menu {
                Button(role: .destructive) { store.removePlayer(player) } label: {
                    Label("Remove player", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 32, height: 44)
            }
        }
        .padding(.horizontal, DesignStudioTheme.Space.large)
        .padding(.vertical, DesignStudioTheme.Space.medium)
    }
}

private enum DesignStudioLiveSheet: String, Identifiable {
    case scorecard
    case complete
    var id: String { rawValue }
}

struct DesignStudioLiveRoundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: DesignStudioRoundStore
    @State private var activeSheet: DesignStudioLiveSheet?

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        Group {
            if store.isRoundComplete {
                recap
            } else {
                liveContent
            }
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle(store.courseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.isRoundComplete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("End") { activeSheet = .complete }
                        .foregroundStyle(theme.danger)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .scorecard:
                DesignStudioScorecardSheet(store: store)
            case .complete:
                DesignStudioCompleteRoundSheet(store: store)
            }
        }
    }

    private var liveContent: some View {
        ScrollView {
            VStack(spacing: DesignStudioTheme.Space.section) {
                holeNavigation
                holeSummary
                scoringGroup
                leaderboard
            }
            .padding(DesignStudioTheme.Space.large)
            .padding(.bottom, DesignStudioTheme.Space.screen)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                activeSheet = .scorecard
            } label: {
                Label("View Scorecard", systemImage: "tablecells")
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(DesignStudioTheme.forest)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(DesignStudioTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignStudioTheme.Space.large)
            .padding(.vertical, DesignStudioTheme.Space.small)
            .background(theme.canvas)
        }
    }

    private var holeNavigation: some View {
        VStack(spacing: DesignStudioTheme.Space.medium) {
            HStack {
                Button {
                    store.selectedHole = max(1, store.selectedHole - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .disabled(store.selectedHole == 1)

                Spacer()
                VStack(spacing: DesignStudioTheme.Space.xSmall) {
                    Text("HOLE")
                        .font(DesignStudioTypography.font(.eyebrow))
                        .tracking(1.4)
                        .foregroundStyle(theme.secondaryText)
                    Text("\(store.selectedHole)")
                        .font(DesignStudioTypography.font(.hero))
                        .contentTransition(.numericText())
                        .foregroundStyle(theme.primaryText)
                }
                Spacer()

                Button {
                    store.selectedHole = min(18, store.selectedHole + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .disabled(store.selectedHole == 18)
            }
            .foregroundStyle(DesignStudioTheme.forest)

            ProgressView(value: Double(store.selectedHole), total: 18)
                .tint(DesignStudioTheme.gold)
        }
    }

    private var holeSummary: some View {
        DesignStudioSurface {
            HStack(spacing: 0) {
                stat("Par", "\(store.currentPar)", "flag.fill")
                Divider().frame(height: 48)
                stat("Yards", "\(store.currentYards)", "ruler.fill")
                Divider().frame(height: 48)
                stat("HCP", "\(((store.selectedHole * 7) % 18) + 1)", "chart.bar.fill")
            }
            .padding(.vertical, DesignStudioTheme.Space.large)
        }
    }

    private func stat(_ label: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: DesignStudioTheme.Space.xSmall) {
            Image(systemName: symbol).foregroundStyle(DesignStudioTheme.gold)
            Text(value).font(DesignStudioTypography.font(.title)).foregroundStyle(theme.primaryText)
            Text(label.uppercased()).font(DesignStudioTypography.font(.eyebrow)).foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoringGroup: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Scorecard for hole \(store.selectedHole)")
            DesignStudioSurface {
                VStack(spacing: 0) {
                    ForEach(Array(store.players.enumerated()), id: \.element.id) { index, player in
                        scoringRow(player)
                        if index < store.players.count - 1 { Divider().padding(.leading, 76) }
                    }
                }
            }
        }
    }

    private func scoringRow(_ player: DesignStudioPlayer) -> some View {
        HStack(spacing: DesignStudioTheme.Space.medium) {
            DesignStudioInitialBadge(initials: player.initials, color: player.teamColor, size: 40)
            Text(player.name)
                .font(DesignStudioTypography.font(.heading))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: DesignStudioTheme.Space.medium) {
                Button { store.adjustScore(for: player.id, delta: -1) } label: {
                    Image(systemName: "minus.circle.fill")
                }
                Text("\(store.score(for: player.id))")
                    .font(DesignStudioTypography.font(.title))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 28)
                Button { store.adjustScore(for: player.id, delta: 1) } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .foregroundStyle(DesignStudioTheme.forest)
        }
        .padding(DesignStudioTheme.Space.large)
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Leaderboard")
            DesignStudioSurface {
                VStack(spacing: 0) {
                    ForEach(Array(store.leaderboard.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: DesignStudioTheme.Space.medium) {
                            Text("\(index + 1)")
                                .font(DesignStudioTypography.font(.caption))
                                .foregroundStyle(theme.secondaryText)
                                .frame(width: 20)
                            Text(player.name)
                                .font(DesignStudioTypography.font(.body))
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            Text(relativeText(store.totalRelativeToPar(for: player.id)))
                                .font(DesignStudioTypography.font(.heading))
                                .monospacedDigit()
                                .foregroundStyle(theme.primaryText)
                        }
                        .padding(.horizontal, DesignStudioTheme.Space.large)
                        .padding(.vertical, DesignStudioTheme.Space.medium)
                        if index < store.leaderboard.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
            }
        }
    }

    private func relativeText(_ value: Int) -> String {
        value == 0 ? "E" : value > 0 ? "+\(value)" : "\(value)"
    }

    private var recap: some View {
        ScrollView {
            VStack(spacing: DesignStudioTheme.Space.section) {
                DesignStudioIconBadge(symbol: "checkmark.flag.fill", foreground: DesignStudioTheme.forest, background: DesignStudioTheme.gold, size: 72)
                VStack(spacing: DesignStudioTheme.Space.small) {
                    Text("Round complete")
                        .font(DesignStudioTypography.font(.hero))
                        .foregroundStyle(theme.primaryText)
                    Text("A clean local recap with no service writes.")
                        .font(DesignStudioTypography.font(.body))
                        .foregroundStyle(theme.secondaryText)
                }
                leaderboard
                DesignStudioPrimaryButton(title: "Play Again", symbol: "arrow.clockwise") { store.reset() }
            }
            .padding(DesignStudioTheme.Space.large)
        }
    }
}

private struct DesignStudioScorecardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: DesignStudioRoundStore

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Player").frame(width: 120, alignment: .leading)
                        ForEach(1...18, id: \.self) { Text("\($0)").frame(width: 42) }
                    }
                    .font(DesignStudioTypography.font(.eyebrow))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.vertical, DesignStudioTheme.Space.medium)

                    ForEach(store.players) { player in
                        HStack(spacing: 0) {
                            Text(player.name).frame(width: 120, alignment: .leading).lineLimit(1)
                            ForEach(1...18, id: \.self) { hole in
                                Text("\(store.score(for: player.id, hole: hole))").frame(width: 42)
                            }
                        }
                        .font(DesignStudioTypography.font(.caption))
                        .foregroundStyle(theme.primaryText)
                        .padding(.vertical, DesignStudioTheme.Space.medium)
                        Divider()
                    }
                }
                .padding(DesignStudioTheme.Space.large)
            }
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("Full Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct DesignStudioCompleteRoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: DesignStudioRoundStore

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignStudioTheme.Space.section) {
                DesignStudioIconBadge(symbol: "flag.checkered", foreground: theme.danger, background: DesignStudioTheme.softPink.opacity(0.55), size: 72)
                VStack(spacing: DesignStudioTheme.Space.small) {
                    Text("End this round?")
                        .font(DesignStudioTypography.font(.title))
                        .foregroundStyle(theme.primaryText)
                    Text("This finishes the local mock and opens the recap. Nothing is written to Firebase.")
                        .font(DesignStudioTypography.font(.body))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                DesignStudioPrimaryButton(title: "End Round", symbol: "flag.checkered") {
                    store.completeRound()
                    dismiss()
                }
                Button("Keep Playing") { dismiss() }
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(theme.primaryText)
                    .frame(minHeight: 44)
            }
            .padding(DesignStudioTheme.Space.section)
            .frame(maxHeight: .infinity)
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("Complete Round")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview("Lobby") {
    NavigationStack { DesignStudioLobbyView(store: .init()) }
}
#endif
