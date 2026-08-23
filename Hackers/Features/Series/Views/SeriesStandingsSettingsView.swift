import SwiftUI

struct SeriesStandingsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    @State private var draft = SeriesStandingsTiebreakDraft()
    @State private var hasLoaded = false
    @State private var showPreparationConfirmation = false
    @State private var showActivationConfirmation = false
    @State private var showLegacyRepairConfirmation = false
    @State private var showLegacyConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var isBusy: Bool {
        viewModel.isSavingStandingsPolicy
            || viewModel.isAssessingStandingsMigration
            || viewModel.isPreparingCanonicalStandings
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Standings Tiebreakers",
                    subtitle: "Scoring-average rules and canonical leaderboard rollout.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    authoritySection
                    formatContractSection
                    if viewModel.series.settings.useTeamStandings {
                        trackSection(track: .team, draft: $draft.team)
                    }
                    if viewModel.series.settings.useIndividualStandings {
                        trackSection(track: .individual, draft: $draft.individual)
                    }
                    rolloutPreviewSection
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: { footer },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .task {
            guard !hasLoaded else { return }
            draft = SeriesStandingsRollout.draft(from: viewModel.series.settings)
            hasLoaded = true
        }
        .confirmationDialog(
            "Prepare the next standings batch?",
            isPresented: $showPreparationConfirmation,
            titleVisibility: .visible
        ) {
            Button("Prepare up to \(SeriesViewModel.standingsMigrationBatchSize) rounds") {
                prepareNextBatch()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the next unprepared completed rounds will be rebound and regenerated. Legacy standings remain authoritative.")
        }
        .confirmationDialog(
            "Activate canonical standings?",
            isPresented: $showActivationConfirmation,
            titleVisibility: .visible
        ) {
            Button("Activate standings") { activateCanonicalStandings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The readiness check found complete canonical coverage and no unexplained legacy mismatch. Canonical ordering and scoring averages will become authoritative.")
        }
        .confirmationDialog(
            "Use legacy standings?",
            isPresented: $showLegacyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Use legacy standings", role: .destructive) { restoreLegacyStandings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The existing persisted leaderboard will become authoritative again. Canonical round results are retained.")
        }
        .confirmationDialog(
            "Rebuild legacy standings?",
            isPresented: $showLegacyRepairConfirmation,
            titleVisibility: .visible
        ) {
            Button("Rebuild legacy standings") { repairLegacyStandings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The persisted V1 leaderboard will be rebuilt from its existing point awards, then compared with canonical results again. Authority will not change.")
        }
        .alert("Standings update failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .interactiveDismissDisabled(isBusy)
    }

    private var authoritySection: some View {
        SeriesSheetCard(palette: palette) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCanonicalActive ? "checkmark.seal.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isCanonicalActive ? Color.accentGreen : Color.neutral)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isCanonicalActive ? "Scoring averages active" : "Legacy standings active")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text(authoritySubtitle)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if viewModel.isAssessingStandingsMigration {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking canonical coverage")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            } else if viewModel.isPreparingCanonicalStandings, let progress = viewModel.standingsRolloutProgress {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress.fractionCompleted)
                        .tint(Color.accentGreen)
                    Text("Prepared \(progress.completedCount) of \(progress.totalCount) rounds")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
            } else if isCanonicalActive {
                Button("Use legacy standings", systemImage: "arrow.uturn.backward") {
                    showLegacyConfirmation = true
                }
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.systemError)
                .buttonStyle(.plain)
                .disabled(isBusy)
            } else if savedPolicyMatchesDraft {
                migrationActions
            }
        }
    }

    @ViewBuilder
    private var migrationActions: some View {
        Divider()

        if let assessment = viewModel.standingsMigrationAssessment {
            VStack(alignment: .leading, spacing: 6) {
                migrationCountRow("Ready", count: assessment.plan.readyItems.count)
                migrationCountRow("Needs preparation", count: assessment.plan.pendingItems.count)
                migrationCountRow("Blocked", count: assessment.plan.blockedItems.count)
                if let comparison = assessment.comparison {
                    migrationCountRow(
                        "Unexplained mismatches",
                        count: comparison.unexplainedMismatchCount
                    )
                }
            }

            ForEach(Array(assessment.plan.blockedItems.prefix(3))) { item in
                if case .blocked(let blocker) = item.disposition {
                    Label("\(item.title): \(migrationBlockerTitle(blocker))", systemImage: "exclamationmark.triangle.fill")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.systemOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if assessment.projectionError != nil {
                Label(
                    "Canonical results do not yet pass final validation.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(Color.systemOrange)
                .fixedSize(horizontal: false, vertical: true)
            }

            if assessment.canActivate {
                Button("Activate standings", systemImage: "checkmark.shield") {
                    showActivationConfirmation = true
                }
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .buttonStyle(.plain)
                .disabled(isBusy)
            } else if assessment.plan.blockedItems.isEmpty,
                      assessment.plan.pendingItems.isPopulated {
                Button(
                    "Prepare next \(min(SeriesViewModel.standingsMigrationBatchSize, assessment.plan.pendingItems.count))",
                    systemImage: "arrow.forward.square"
                ) {
                    showPreparationConfirmation = true
                }
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .buttonStyle(.plain)
                .disabled(isBusy)
            } else if assessment.plan.isReadyForActivation,
                      assessment.comparison?.isActivationSafe == false {
                Button("Rebuild legacy standings", systemImage: "wrench.and.screwdriver") {
                    showLegacyRepairConfirmation = true
                }
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.systemOrange)
                .buttonStyle(.plain)
                .disabled(isBusy)
            } else {
                Button("Check again", systemImage: "arrow.clockwise") {
                    refreshMigrationAssessment()
                }
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        } else {
            Button("Run readiness check", systemImage: "checkmark.circle") {
                refreshMigrationAssessment()
            }
            .fontStyle(kFontName, size: 13, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .buttonStyle(.plain)
            .disabled(isBusy || policyValidationError != nil)
        }
    }

    private func migrationCountRow(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(Color.neutral)
            Spacer(minLength: 8)
            Text("\(count)")
                .foregroundStyle(palette.foregroundColor)
                .monospacedDigit()
        }
        .fontStyle(kFontName, size: 12, weight: .medium)
    }

    private func migrationBlockerTitle(_ blocker: SeriesStandingsMigrationBlocker) -> String {
        switch blocker {
        case .missingLinkedRound: return "missing linked round"
        case .snapshotUnavailable: return "snapshot unavailable"
        case .invalidCompatibility: return "invalid scoring compatibility"
        }
    }

    private var formatContractSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Scoring contract".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            valueRow("Format", value: viewModel.series.settings.defaultRoundConfig.template.name)
            valueRow("Score basis", value: defaultScoreBasisTitle)
            valueRow("Course", value: viewModel.series.settings.defaultCourse?.cachedName ?? "Not set")
            valueRow("Holes", value: defaultHoleCount.map(String.init) ?? "Not set")
            if viewModel.series.settings.useTeamStandings {
                valueRow("Team score", value: teamScoringTitle)
            }
        }
    }

    private func trackSection(
        track: SeriesAwardTrack,
        draft: Binding<SeriesStandingsTrackTiebreakDraft>
    ) -> some View {
        SeriesSheetCard(palette: palette) {
            Toggle(isOn: draft.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trackTitle(track)) scoring average")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("Used after total points when competitors are tied.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
            .tint(Color.accentGreen)

            if draft.wrappedValue.isEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    Picker("Priority", selection: draft.direction) {
                        Text("Lowest wins").tag(SeriesTiebreakDirection.lowestFirst)
                        Text("Highest wins").tag(SeriesTiebreakDirection.highestFirst)
                    }
                    .pickerStyle(.segmented)
                }

                settingsRow(title: "Average value", subtitle: scoreComponentSubtitle(draft.wrappedValue.scoreComponent)) {
                    Menu {
                        scoreComponentButton("Scoring total", value: .total, selection: draft.scoreComponent)
                        scoreComponentButton("Raw strokes", value: .rawStrokes, selection: draft.scoreComponent)
                        scoreComponentButton("Net strokes", value: .netStrokes, selection: draft.scoreComponent)
                        scoreComponentButton("Score to par", value: .scoreToPar, selection: draft.scoreComponent)
                    } label: {
                        menuLabel(scoreComponentTitle(draft.wrappedValue.scoreComponent))
                    }
                    .buttonStyle(.plain)
                }

                settingsRow(title: "Minimum rounds", subtitle: "Required for every competitor in a tied points group.") {
                    Stepper(value: draft.minimumEligibleRounds, in: 1...50) {
                        Text("\(draft.wrappedValue.minimumEligibleRounds)")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .monospacedDigit()
                    }
                    .labelsHidden()
                    .accessibilityLabel("Minimum eligible rounds")
                    .accessibilityValue("\(draft.wrappedValue.minimumEligibleRounds)")
                }
            }
        }
    }

    @ViewBuilder
    private var rolloutPreviewSection: some View {
        if let error = policyValidationError {
            SeriesSheetCard(palette: palette) {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.systemOrange)
            }
        } else if let preview = rolloutPreview {
            SeriesSheetCard(palette: palette) {
                Text("Historical preview".uppercased())
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                valueRow("Completed rounds", value: "\(preview.completedRoundCount)")
                ForEach(enabledTracks, id: \.self) { track in
                    if let trackPreview = preview.tracks[track] {
                        valueRow(
                            trackTitle(track),
                            value: "\(trackPreview.eligibleRoundCount + trackPreview.normalizedRoundCount) eligible, \(trackPreview.excludedRoundCount) excluded"
                        )
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Line()
            PrimaryButton(
                appearance: .fill,
                title: "Save policy",
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                theme: palette.theme,
                fillWidth: true,
                isDisabled: .init(
                    get: { !hasUnsavedChanges || isBusy || policyValidationError != nil },
                    set: { _ in }
                ),
                isLoading: .init(get: { viewModel.isSavingStandingsPolicy }, set: { _ in }),
                onTapAsync: { await savePolicy() }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(palette.backgroundColor)
    }

    private var isCanonicalActive: Bool {
        viewModel.series.settings.standingsReadAuthority == .canonicalWhenReady
    }

    private var authoritySubtitle: String {
        if isCanonicalActive {
            return "Canonical round results determine ordering and scoring-average tiebreaks."
        }
        if viewModel.series.settings.standingsPolicyRevision != nil,
           !savedPolicyMatchesCurrentScoringContract {
            return "The league scoring contract changed. Save the policy again before checking completed rounds."
        }
        if viewModel.series.settings.standingsPolicyRevision != nil {
            return "The policy is saved. Check, prepare, and activate completed rounds in resumable batches."
        }
        return "Save a policy before preparing canonical standings."
    }

    private var hasUnsavedChanges: Bool {
        draft != SeriesStandingsRollout.draft(from: viewModel.series.settings)
            || !savedPolicyMatchesCurrentScoringContract
    }

    private var savedPolicyMatchesDraft: Bool {
        viewModel.series.settings.standingsPolicyRevision != nil
            && savedPolicyMatchesCurrentScoringContract
            && draft == SeriesStandingsRollout.draft(from: viewModel.series.settings)
    }

    private var savedPolicyMatchesCurrentScoringContract: Bool {
        guard let revision = viewModel.series.settings.standingsPolicyRevision else { return true }
        return SeriesStandingsRollout.revisionMatchesCurrentScoringContract(
            settings: viewModel.series.settings,
            revision: revision
        )
    }

    private var enabledTracks: [SeriesAwardTrack] {
        SeriesAwardTrack.allCases.filter { track in
            switch track {
            case .team: return viewModel.series.settings.useTeamStandings
            case .individual: return viewModel.series.settings.useIndividualStandings
            }
        }
    }

    private var draftRevision: SeriesPolicyRevision? {
        guard case .success(let revision) = SeriesStandingsRollout.makeRevision(
            settings: viewModel.series.settings,
            draft: draft,
            id: "preview"
        ) else { return nil }
        return revision
    }

    private var policyValidationError: String? {
        guard case .failure(let error) = SeriesStandingsRollout.makeRevision(
            settings: viewModel.series.settings,
            draft: draft,
            id: "preview"
        ) else { return nil }
        return error.localizedDescription
    }

    private var rolloutPreview: SeriesStandingsRolloutPreview? {
        guard let revision = draftRevision else { return nil }
        return SeriesStandingsRollout.preview(
            series: viewModel.series,
            completedRounds: viewModel.completedRounds,
            revision: revision
        )
    }

    private var defaultHoleCount: Int? {
        viewModel.series.settings.defaultCourse?.holeSegment.holeCount
    }

    private var defaultScoreBasisTitle: String {
        let config = viewModel.series.settings.defaultRoundConfig
        let basis = config.scoreBasisOverride ?? config.template.requirements.defaultScoreBasis
        return basis == .gross ? "Gross" : "Net"
    }

    private var teamScoringTitle: String {
        let scoring = viewModel.series.settings.defaultRoundConfig.teamScoring
        switch scoring.mode {
        case .all:
            return "All scores"
        case .bestN:
            return "Best \(scoring.count) \(scoring.scope == .perHole ? "per hole" : "per round")"
        case .worstN:
            return "Worst \(scoring.count) \(scoring.scope == .perHole ? "per hole" : "per round")"
        }
    }

    private func savePolicy() async {
        switch await viewModel.saveStandingsTiebreakPolicy(draft) {
        case .success:
            draft = SeriesStandingsRollout.draft(from: viewModel.series.settings)
        case .failure(let error):
            present(error)
        }
    }

    private func refreshMigrationAssessment() {
        Task {
            if case .failure(let error) = await viewModel.refreshStandingsMigrationAssessment() {
                if !(error is CancellationError) { present(error) }
            }
        }
    }

    private func prepareNextBatch() {
        Task {
            if case .failure(let error) = await viewModel.prepareNextCanonicalStandingsBatch() {
                if !(error is CancellationError) { present(error) }
            }
        }
    }

    private func activateCanonicalStandings() {
        Task {
            if case .failure(let error) = await viewModel.activateCanonicalStandings() {
                if !(error is CancellationError) { present(error) }
            }
        }
    }

    private func repairLegacyStandings() {
        Task {
            if case .failure(let error) = await viewModel.repairLegacyStandingsForMigration() {
                if !(error is CancellationError) { present(error) }
            }
        }
    }

    private func restoreLegacyStandings() {
        Task {
            if case .failure(let error) = await viewModel.useLegacyStandings() {
                present(error)
            }
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            Text(value)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.trailing)
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text(subtitle)
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            content()
        }
    }

    private func menuLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .fontStyle(kFontName, size: 12, weight: .semibold)
        .foregroundStyle(palette.foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.cardEmbeddedRowBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func scoreComponentButton(
        _ title: String,
        value: SeriesTiebreakScoreComponent,
        selection: Binding<SeriesTiebreakScoreComponent>
    ) -> some View {
        Button {
            selection.wrappedValue = value
        } label: {
            Label(title, systemImage: selection.wrappedValue == value ? "checkmark" : "circle")
        }
    }

    private func trackTitle(_ track: SeriesAwardTrack) -> String {
        track == .team ? "Team" : "Individual"
    }

    private func scoreComponentTitle(_ component: SeriesTiebreakScoreComponent) -> String {
        switch component {
        case .total: return "Scoring total"
        case .rawStrokes: return "Raw strokes"
        case .netStrokes: return "Net strokes"
        case .scoreToPar: return "Score to par"
        }
    }

    private func scoreComponentSubtitle(_ component: SeriesTiebreakScoreComponent) -> String {
        switch component {
        case .total: return "The format's resolved aggregate score."
        case .rawStrokes: return "Gross strokes before handicap adjustments."
        case .netStrokes: return "Strokes after handicap adjustments."
        case .scoreToPar: return "Relative-to-par values across compatible courses."
        }
    }
}
