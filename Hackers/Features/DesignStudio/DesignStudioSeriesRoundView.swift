#if SANDBOX
import SwiftUI

struct DesignStudioSeriesRoundLaunchView: View {
    @StateObject private var store = DesignStudioSeriesRoundStore()

    var body: some View {
        DesignStudioSeriesRoundView(store: store)
    }
}

struct DesignStudioSeriesRoundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: DesignStudioSeriesRoundStore

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignStudioTheme.Space.large) {
                progressHeader
                metadata
                if store.didCreateRound { successBanner }
                configurationGroups
            }
            .padding(.horizontal, DesignStudioTheme.Space.medium)
            .padding(.top, DesignStudioTheme.Space.small)
            .padding(.bottom, DesignStudioTheme.Space.screen)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle(store.lifecycle == .setup ? "Round Setup" : "Configure Round")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.lifecycle == .editing {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Reset") {
                        ForEach(store.applicableSections) { section in
                            Button("Reset \(section.title)") { store.reset(section: section) }
                        }
                    }
                    .foregroundStyle(DesignStudioTheme.gold)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomActions }
        .sheet(item: $store.activeEditor) { section in
            DesignStudioSeriesEditorView(section: section, store: store)
        }
        .sheet(isPresented: $store.isReviewPresented) {
            DesignStudioSeriesReviewView(store: store)
        }
    }

    private var progressHeader: some View {
        HStack(spacing: DesignStudioTheme.Space.large) {
            Text("\(store.readyCount) of \(store.applicableSections.count) ready")
                .font(DesignStudioTypography.font(.heading))
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())
            HStack(spacing: DesignStudioTheme.Space.small) {
                ForEach(store.applicableSections) { section in
                    Capsule()
                        .fill(store.status(for: section) == .ready ? DesignStudioTheme.gold : theme.separator)
                        .frame(height: 5)
                }
            }
        }
        .padding(.vertical, DesignStudioTheme.Space.xSmall)
        .animation(.easeInOut(duration: 0.22), value: store.applicableSections)
        .animation(.easeInOut(duration: 0.22), value: store.readyCount)
    }

    private var metadata: some View {
        DesignStudioSurface {
            HStack(spacing: 0) {
                metadataItem("Round 3", "flag.fill")
                Divider().frame(height: 44)
                metadataItem("Sat, Jul 25", "calendar")
                Divider().frame(height: 44)
                metadataItem("Pineview", "mappin")
                Divider().frame(height: 44)
                metadataItem("16 players", "person.3.fill", detail: "4 teams")
            }
            .padding(.vertical, DesignStudioTheme.Space.small)
        }
    }

    private func metadataItem(_ value: String, _ symbol: String, detail: String? = nil) -> some View {
        VStack(spacing: DesignStudioTheme.Space.xSmall) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? DesignStudioTheme.gold : DesignStudioTheme.forest)
            Text(value)
                .font(DesignStudioTypography.font(.caption))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var successBanner: some View {
        HStack(spacing: DesignStudioTheme.Space.medium) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                Text("Mock round created")
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(theme.primaryText)
                Text("You are now viewing the jump-anywhere revision state.")
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignStudioTheme.Space.large)
        .background(theme.success.opacity(colorScheme == .dark ? 0.18 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous))
    }

    private var configurationGroups: some View {
        VStack(spacing: DesignStudioTheme.Space.large) {
            ForEach(["Play", "Field", "Awards"], id: \.self) { group in
                let sections = store.sections(in: group)
                if !sections.isEmpty {
                    VStack(alignment: .leading, spacing: DesignStudioTheme.Space.small) {
                        DesignStudioSectionLabel(title: group)
                            .padding(.horizontal, DesignStudioTheme.Space.medium)
                        DesignStudioSurface {
                            VStack(spacing: 0) {
                                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                                    sectionRow(section)
                                    if index < sections.count - 1 {
                                        Divider().padding(.leading, 72)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionRow(_ section: DesignStudioSeriesSection) -> some View {
        let status = store.status(for: section)
        let isRecommended: Bool = {
            if case .recommended = status { return true }
            return false
        }()
        let isReview: Bool = {
            if case .review = status { return true }
            return false
        }()

        return Button {
            store.activeEditor = section
        } label: {
            HStack(spacing: DesignStudioTheme.Space.medium) {
                DesignStudioIconBadge(
                    symbol: section.symbol,
                    foreground: isRecommended ? theme.lavenderText : isReview ? theme.danger : theme.primaryText,
                    background: isRecommended
                        ? DesignStudioTheme.lavender.opacity(0.38)
                        : isReview
                            ? DesignStudioTheme.softPink.opacity(0.55)
                            : iconBackground(for: section),
                    size: 40
                )
                VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                    Text(section.title)
                        .font(DesignStudioTypography.font(.heading))
                        .foregroundStyle(isRecommended ? theme.lavenderText : theme.primaryText)
                    Text(store.summary(for: section))
                        .font(DesignStudioTypography.font(.caption))
                        .foregroundStyle(isReview ? theme.danger : theme.secondaryText)
                        .lineLimit(2)
                    if section == .matchups, store.competitionScope == .matchup, !store.matchupsConfigured {
                        Label("Shown because Matchup format is on", systemImage: "circle.fill")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.lavenderText)
                            .labelStyle(CompactDotLabelStyle())
                    }
                }
                Spacer(minLength: 0)
                statusAccessory(status)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, DesignStudioTheme.Space.large)
            .padding(.vertical, isRecommended ? DesignStudioTheme.Space.medium : DesignStudioTheme.Space.small)
            .background(isRecommended ? DesignStudioTheme.lavender.opacity(colorScheme == .dark ? 0.16 : 0.18) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.title), \(store.summary(for: section))")
    }

    private func iconBackground(for section: DesignStudioSeriesSection) -> Color {
        switch section {
        case .roundCourse, .formatScoring: DesignStudioTheme.forest.opacity(colorScheme == .dark ? 0.35 : 0.12)
        case .handicapEligibility: DesignStudioTheme.softPink.opacity(0.45)
        case .matchups: DesignStudioTheme.lavender.opacity(0.35)
        case .teeSheet: DesignStudioTheme.skyBlue.opacity(0.25)
        case .pointsNotes: DesignStudioTheme.gold.opacity(0.35)
        }
    }

    @ViewBuilder
    private func statusAccessory(_ status: DesignStudioSeriesSectionStatus) -> some View {
        switch status {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
        case .review:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(theme.danger)
        case .recommended:
            Text("Recommended")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(theme.lavenderText)
                .padding(.horizontal, DesignStudioTheme.Space.small)
                .padding(.vertical, DesignStudioTheme.Space.xSmall)
                .background(DesignStudioTheme.lavender.opacity(0.28))
                .clipShape(Capsule())
        case .incomplete:
            Circle().stroke(theme.separator, lineWidth: 2).frame(width: 18, height: 18)
        case .optional:
            Text("Optional").font(DesignStudioTypography.font(.caption)).foregroundStyle(theme.secondaryText)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: DesignStudioTheme.Space.small) {
            DesignStudioPrimaryButton(
                title: store.lifecycle == .setup ? "Continue Setup" : "Review Round",
                symbol: "flag.fill"
            ) {
                if store.lifecycle == .setup { store.continueSetup() }
                else { store.presentReview() }
            }

            if store.lifecycle == .setup {
                Button("Finish later") { store.finishLater() }
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(theme.primaryText)
                    .frame(minHeight: 36)
            }
        }
        .padding(.horizontal, DesignStudioTheme.Space.medium)
        .padding(.top, DesignStudioTheme.Space.small)
        .background(theme.canvas)
    }
}

private struct CompactDotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 5))
            configuration.title
        }
    }
}

private struct DesignStudioSeriesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let section: DesignStudioSeriesSection
    @ObservedObject var store: DesignStudioSeriesRoundStore

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            Form {
                switch section {
                case .roundCourse: roundCourseEditor
                case .formatScoring: formatEditor
                case .handicapEligibility: handicapEditor
                case .matchups: matchupEditor
                case .teeSheet: teeSheetEditor
                case .pointsNotes: pointsEditor
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .tint(DesignStudioTheme.forest)
            .navigationTitle(section.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { store.reset(section: section) }
                        .foregroundStyle(theme.danger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var roundCourseEditor: some View {
        Group {
            Section("Round") {
                TextField("Round name", text: binding(\.draft.title))
                DatePicker("Scheduled date", selection: binding(\.draft.scheduledDate), displayedComponents: [.date, .hourAndMinute])
            }
            Section("Course") {
                Picker("Course", selection: $store.courseName) {
                    Text("Pineview Golf Club").tag("Pineview Golf Club")
                    Text("Harbor Hills Country Club").tag("Harbor Hills Country Club")
                    Text("Lakeside Municipal").tag("Lakeside Municipal")
                }
                Picker("Holes", selection: $store.holes) {
                    Text("18 holes").tag("18 holes")
                    Text("Front 9").tag("Front 9")
                    Text("Back 9").tag("Back 9")
                }
                Picker("Tee", selection: $store.teeName) {
                    Text("Blue · 6,742 yards").tag("Blue · 6,742 yards")
                    Text("White · 6,281 yards").tag("White · 6,281 yards")
                    Text("Gold · 5,834 yards").tag("Gold · 5,834 yards")
                }
            }
        }
    }

    private var formatEditor: some View {
        Group {
            Section("Format") {
                Picker("Template", selection: Binding(
                    get: { store.format },
                    set: { store.selectFormat($0) }
                )) {
                    ForEach(DesignStudioSeriesRoundStore.Format.allCases) { Text($0.rawValue).tag($0) }
                }

                Picker("Competition", selection: Binding(
                    get: { store.competitionScope },
                    set: { store.setCompetitionScope($0) }
                )) {
                    Text("Field").tag(CompetitionScope.field)
                    Text("Matchup").tag(CompetitionScope.matchup)
                }
                .pickerStyle(.segmented)

                if store.format.scoreSource == .shared {
                    Picker("Score entry", selection: binding(\.draft.scoreOwnerScope)) {
                        Text("Player").tag(RoundScoreOwnerScope.individual)
                        Text("Pair").tag(RoundScoreOwnerScope.partnership)
                        Text("Tee group").tag(RoundScoreOwnerScope.teeGroup)
                    }
                    TextField("Handicap allowance (35,15)", text: binding(\.draft.sharedScoreAllowanceText))
                        .keyboardType(.numbersAndPunctuation)
                }

                Picker("Max score", selection: binding(\.draft.maxScoreOverPar)) {
                    ForEach(MaxScoreOverPar.selectableCases(hasCoursePars: true), id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            }

            Section("Team leaderboard") {
                Picker("Count scores", selection: binding(\.draft.teamScoring.mode)) {
                    Text("All").tag(RoundTeamScoringMode.all)
                    Text("Best N").tag(RoundTeamScoringMode.bestN)
                    Text("Worst N").tag(RoundTeamScoringMode.worstN)
                }
                if store.draft.teamScoring.mode != .all {
                    Stepper("Count \(store.draft.teamScoring.count)", value: binding(\.draft.teamScoring.count), in: 1...4)
                    Picker("Compute per", selection: binding(\.draft.teamScoring.scope)) {
                        Text("Hole").tag(AggregationScope.perHole)
                        Text("Round").tag(AggregationScope.perRound)
                    }
                }
            }

            Section("Starting structure") {
                Toggle("Shotgun start", isOn: Binding(
                    get: { store.draft.sequentialTeeStartsEnabled },
                    set: { store.draft.sequentialTeeStartsEnabled = $0 }
                ))
                Picker("Pair grouping", selection: binding(\.draft.podGroupingStrategy)) {
                    Text("Manual").tag(SeriesPodGroupingStrategy.disabled)
                    Text("Align pairs").tag(SeriesPodGroupingStrategy.alignByIndex)
                    Text("Swap pairs").tag(SeriesPodGroupingStrategy.swapPairs)
                }
            }

            Section {
                Text(store.competitionScope == .matchup
                    ? "Matchups now appear in setup. Switching to Field removes that section and recalculates readiness."
                    : "Field scoring compares the full field, so no matchup setup is required.")
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var handicapEditor: some View {
        Group {
            Section("Playing handicap") {
                Toggle("Use course handicaps", isOn: Binding(
                    get: { store.draft.handicapEntryFormat == .courseHandicap },
                    set: { store.setCourseHandicapEnabled($0) }
                ))
                Picker("Normalize from", selection: binding(\.draft.handicapNormalizationMode)) {
                    Text("Off").tag(HandicapNormalizationMode.off)
                    Text("Field").tag(HandicapNormalizationMode.field)
                    Text("Matchup").tag(HandicapNormalizationMode.matchup)
                }
                Picker("Stroke basis", selection: binding(\.draft.handicapStrokeBasis)) {
                    Text("Auto").tag(SeriesHandicapStrokeBasis?.none)
                    Text("9 holes").tag(SeriesHandicapStrokeBasis?.some(.nineHole))
                    Text("18 holes").tag(SeriesHandicapStrokeBasis?.some(.eighteenHole))
                }
                Toggle("Count toward handicap pool", isOn: binding(\.draft.countsTowardHandicapPool))
            }

            Section("Player review") {
                ForEach(store.members) { member in
                    HStack(spacing: DesignStudioTheme.Space.medium) {
                        DesignStudioInitialBadge(initials: member.initials, color: member.teamColor, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                            Text(handicapLabel(for: member))
                                .font(DesignStudioTypography.font(.caption))
                                .foregroundStyle(store.handicapMissingPlayerIDs.contains(member.id) ? theme.danger : theme.secondaryText)
                        }
                        Spacer()
                        if store.handicapMissingPlayerIDs.contains(member.id) {
                            Button("Resolve") { store.toggleHandicapReview(for: member.id) }
                                .buttonStyle(.bordered)
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.success)
                        }
                    }
                }
            }

            Section("Eligibility") {
                ForEach(store.members) { member in
                    Toggle(member.name, isOn: Binding(
                        get: { !store.excludedPlayerIDs.contains(member.id) },
                        set: { _ in store.toggleEligibility(for: member.id) }
                    ))
                }
            }
        }
    }

    private var matchupEditor: some View {
        Group {
            Section {
                Picker("Matchup source", selection: $store.matchupSource) {
                    ForEach(DesignStudioSeriesRoundStore.MatchupSource.allCases) { Text($0.rawValue).tag($0) }
                }
                Button {
                    store.autoFillMatchups()
                } label: {
                    Label(store.matchupsConfigured ? "Rebuild matchups" : "Auto-fill matchups", systemImage: "wand.and.stars")
                }
            } footer: {
                Text("This section only exists because Matchup is selected in Format & Scoring.")
            }

            Section("Schedule") {
                if store.matchupsConfigured {
                    matchupRow("Match 1", "Forest", "Gold")
                    matchupRow("Match 2", "Lavender", "Sky")
                } else {
                    ContentUnavailableView(
                        "No matchups yet",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Auto-fill the team schedule or choose another source.")
                    )
                }
            }
        }
    }

    private func matchupRow(_ title: String, _ left: String, _ right: String) -> some View {
        HStack {
            Text(title).font(DesignStudioTypography.font(.caption)).foregroundStyle(theme.secondaryText)
            Spacer()
            Text(left).fontWeight(.semibold)
            Text("vs").foregroundStyle(theme.secondaryText)
            Text(right).fontWeight(.semibold)
        }
    }

    private var teeSheetEditor: some View {
        Group {
            Section {
                Button {
                    store.generateTeeSheet()
                } label: {
                    Label(store.teeSheetGenerated ? "Regenerate groups" : "Generate tee sheet", systemImage: "arrow.triangle.2.circlepath")
                }
            } footer: {
                Text(store.draft.sequentialTeeStartsEnabled ? "Shotgun starting holes will rotate across the course." : "All groups begin on the first tee unless changed.")
            }

            Section("Groups") {
                ForEach(0..<4, id: \.self) { group in
                    let players = Array(store.members[(group * 4)..<(group * 4 + 4)])
                    VStack(alignment: .leading, spacing: DesignStudioTheme.Space.small) {
                        HStack {
                            Text("Group \(group + 1)").fontWeight(.semibold)
                            Spacer()
                            Text(store.draft.sequentialTeeStartsEnabled ? "Starts #\([1, 5, 10, 14][group])" : "Starts #1")
                                .font(DesignStudioTypography.font(.caption))
                                .foregroundStyle(theme.secondaryText)
                        }
                        Text(players.map(\.name).joined(separator: " · "))
                            .font(DesignStudioTypography.font(.caption))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.vertical, DesignStudioTheme.Space.xSmall)
                }
            }
        }
    }

    private var pointsEditor: some View {
        Group {
            Section("Matchup points") {
                Picker("Scoring", selection: binding(\.draft.matchupScoringStyle)) {
                    Text("Round winner").tag(RoundMatchupScoringStyle.aggregateRoundTotal)
                    Text("Hole points").tag(RoundMatchupScoringStyle.holeByHolePoints)
                }
                if store.draft.matchupScoringStyle == .holeByHolePoints {
                    Stepper("Hole value \(store.draft.holeWinPoints, specifier: "%.1f")", value: binding(\.draft.holeWinPoints), in: 0.5...3, step: 0.5)
                    Stepper("Winner bonus \(store.draft.matchWinnerBonusPoints, specifier: "%.1f")", value: binding(\.draft.matchWinnerBonusPoints), in: 0...4, step: 1)
                }
            }

            Section("Profiles") {
                Picker("Team points", selection: $store.pointsConfigured) {
                    Text("Top 4 teams").tag(true)
                    Text("No team awards").tag(false)
                }
                Picker("Player points", selection: $store.pointsConfigured) {
                    Text("Top 8 players").tag(true)
                    Text("No player awards").tag(false)
                }
            }

            Section("Commissioner notes") {
                TextEditor(text: $store.notes)
                    .frame(minHeight: 120)
            }

            Section("Example") {
                Text("A team winning 3 & 2 earns the configured matchup award. Player results also feed the individual standings.")
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func handicapLabel(for member: DesignStudioPlayer) -> String {
        guard let handicap = member.handicap else { return "Missing handicap" }
        return String(format: "Index %.1f", handicap)
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<DesignStudioSeriesRoundStore, Value>) -> Binding<Value> {
        Binding(get: { store[keyPath: keyPath] }, set: { store[keyPath: keyPath] = $0 })
    }
}

private struct DesignStudioSeriesReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: DesignStudioSeriesRoundStore

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignStudioTheme.Space.section) {
                    VStack(alignment: .leading, spacing: DesignStudioTheme.Space.small) {
                        Text(store.validationIssues.isEmpty ? "Ready for the first tee" : "A few things need attention")
                            .font(DesignStudioTypography.font(.title))
                            .foregroundStyle(theme.primaryText)
                        Text("Review the applicable configuration before creating this local mock round.")
                            .font(DesignStudioTypography.font(.body))
                            .foregroundStyle(theme.secondaryText)
                    }

                    if !store.validationIssues.isEmpty {
                        DesignStudioSurface {
                            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
                                ForEach(store.validationIssues, id: \.self) { issue in
                                    Label(issue, systemImage: "exclamationmark.circle.fill")
                                        .font(DesignStudioTypography.font(.caption))
                                        .foregroundStyle(theme.danger)
                                }
                            }
                            .padding(DesignStudioTheme.Space.large)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
                        DesignStudioSectionLabel(title: "Round summary")
                        DesignStudioSurface {
                            VStack(spacing: 0) {
                                ForEach(Array(store.applicableSections.enumerated()), id: \.element.id) { index, section in
                                    HStack {
                                        Image(systemName: section.symbol).foregroundStyle(DesignStudioTheme.gold).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(section.title).font(DesignStudioTypography.font(.heading))
                                            Text(store.summary(for: section)).font(DesignStudioTypography.font(.caption)).foregroundStyle(theme.secondaryText)
                                        }
                                        Spacer()
                                    }
                                    .foregroundStyle(theme.primaryText)
                                    .padding(DesignStudioTheme.Space.large)
                                    if index < store.applicableSections.count - 1 { Divider().padding(.leading, 60) }
                                }
                            }
                        }
                    }

                    DesignStudioPrimaryButton(
                        title: store.validationIssues.isEmpty ? "Create Mock Round" : "Save Draft Anyway",
                        symbol: "checkmark.flag.fill"
                    ) {
                        store.createMockRound()
                    }
                }
                .padding(DesignStudioTheme.Space.large)
            }
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("Review Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

#Preview("Adaptive series setup") {
    NavigationStack { DesignStudioSeriesRoundView(store: .init()) }
}
#endif
