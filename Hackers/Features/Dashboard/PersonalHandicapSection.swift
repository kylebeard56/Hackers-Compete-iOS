import Charts
import SwiftUI

struct PersonalHandicapSection: View {
    let player: Player
    let palette: DesignPalette
    var onSaved: (Player) -> Void = { _ in }
    var onLeagueTap: (String) -> Void

    @State private var viewerUserID: String?
    @State private var history = PersonalHandicapHistory()
    @State private var leagues: [ProfileLeagueHandicap] = []
    @State private var isLoading = true
    @State private var isRefreshingHistory = false
    @State private var historyError: String?
    @State private var leagueError: String?
    @State private var editor: StartingIndexEditorInput?
    @State private var selectedDate: Date?
    @State private var selectedPoint: PersonalHandicapHistoryPoint?
    @State private var postingReview: PersonalHandicapScoreRecord?

    private var profile: PersonalHandicapProfile {
        var profile = player.personalHandicap ?? .init()
        if let reviewed = history.calculation { profile.calculation = reviewed }
        return profile
    }
    private var calculation: PersonalHandicapCalculation? { history.calculation ?? profile.calculation }
    private var trendPoint: PersonalHandicapHistoryPoint? {
        guard let selectedDate else { return history.points.last }
        return history.points.min { abs($0.playedAt.unix - selectedDate.timeIntervalSince1970) < abs($1.playedAt.unix - selectedDate.timeIntervalSince1970) }
    }

    var body: some View {
        VStack(spacing: 16) {
            personalCard
            trendCard
            scoreHistoryCard
            leagueCard
        }
        .task(id: player.id) { await load() }
        .sheet(item: $editor) { input in
            StartingIndexEditor(input: input, palette: palette) { manual in
                let saved = try await FirebaseService.shared.saveManualPersonalHandicap(playerID: player.id, manual: manual)
                onSaved(saved)
                await loadHistory()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $postingReview) { score in
            PersonalHandicapPostingEditor(score: score, palette: palette) { purpose, reason in
                let loaded = try await FirebaseService.shared.setPersonalHandicapPurpose(playerID: player.id, roundID: score.roundID, sourceCollection: score.sourceCollection ?? Collections.rounds.name, purpose: purpose, partialReason: reason)
                history = loaded
                if let refreshed = loaded.player { onSaved(refreshed) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedPoint) { point in
            NavigationStack {
                List {
                    LabeledContent("Round", value: point.roundTitle)
                    LabeledContent("Played", value: Date(timeIntervalSince1970: point.playedAt.unix).formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Hackers Index", value: ManualPersonalHandicap.display(point.calculation.qualifiedIndex))
                    LabeledContent("Calculated", value: point.calculation.asOf.formattedDate)
                    LabeledContent("Qualifying scores", value: "\(Set(point.calculation.qualifyingScoreIDs).count)")
                    LabeledContent("Score pool", value: "\(Set(point.calculation.poolScoreIDs).count)")
                    LabeledContent("Counting scores", value: "\(Set(point.calculation.countingScoreIDs).count)")
                    Text("Unofficial Hackers personal calculation on an 18-hole basis.")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Personal Handicap")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedPoint = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var personalCard: some View {
        SeriesSheetCard(palette: palette) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    title("Personal Handicap")
                    Text(ManualPersonalHandicap.display(profile.effectiveIndex))
                        .fontStyle(kFontName, size: 36, weight: .bold)
                        .foregroundStyle(Color.accentGreen)
                        .accessibilityLabel("Effective personal Handicap Index \(ManualPersonalHandicap.display(profile.effectiveIndex))")
                    detail(profile.effectiveSource == .calculated ? "Hackers Calculated Index · 18 holes" : profile.manual != nil ? "Manual starting · 18-hole Index" : "Personal Index unavailable")
                }
                Spacer(minLength: 8)
                if player.canEditPersonalHandicap(as: viewerUserID) {
                    Button(profile.manual == nil ? "Add Index" : "Edit") {
                        editor = .init(id: player.id, manual: profile.manual)
                    }
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
                    .frame(minHeight: 44)
                }
            }
            Divider()
            HStack {
                detail("Manual starting Index")
                Spacer()
                Text(ManualPersonalHandicap.display(profile.manual?.value)).monospacedDigit()
            }
            if let manual = profile.manual {
                detail("\(manual.source.title) · Updated \(manual.updatedAt.formattedDate)")
            }
            HStack {
                detail("Calculated Hackers Index")
                Spacer()
                Text(ManualPersonalHandicap.display(calculation?.effectiveCalculatedIndex)).monospacedDigit()
            }
            if let date = calculation?.retainedAsOf { detail("Last valid Index: \(date.formattedDate) · newer conversion pending") }
            if let calculation {
                detail("Latest review: \(calculation.asOf.formattedDate)")
            }
            if calculation?.status == .blocked {
                detail(calculation?.blockers?.first ?? PersonalHandicapEngine.unavailableMessage)
            }
            detail("WHS-inspired and unofficial. Missing official PCC is explicitly assumed to be zero. Your starting Index is kept separately.")
            Button("Refresh personal handicap") { Task { await loadHistory() } }
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .disabled(isLoading || isRefreshingHistory)
        }
    }

    private var trendCard: some View {
        SeriesSheetCard(palette: palette) {
            HStack {
                title("Personal Handicap Trend")
                Spacer(minLength: 8)
                if let point = trendPoint {
                    Text(ManualPersonalHandicap.display(point.calculation.qualifiedIndex))
                        .fontStyle(kFontName, size: 20, weight: .bold)
                        .foregroundStyle(Color.accentGreen)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack { countPill("Qualifying", calculation.map { Set($0.qualifyingScoreIDs).count }); countPill("Pool", calculation.map { Set($0.poolScoreIDs).count }); countPill("Counting", calculation.map { Set($0.countingScoreIDs).count }) }
                VStack(alignment: .leading) { countPill("Qualifying", calculation.map { Set($0.qualifyingScoreIDs).count }); countPill("Pool", calculation.map { Set($0.poolScoreIDs).count }); countPill("Counting", calculation.map { Set($0.countingScoreIDs).count }) }
            }
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else if let historyError {
                detail(historyError)
                Button("Retry") { Task { await load() } }
            } else if history.points.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 24, weight: .medium)).foregroundStyle(Color.neutral3)
                    detail(calculation?.status == .blocked ? "Nine-hole / partial conversion is pending expected-score input." : "Your calculated Index trend will appear after 54 qualifying holes and valid differentials are available.")
                    if let calculation, let required = calculation.requiredHoles, required > 0 {
                        ProgressView(value: Double(min(calculation.qualifyingHoles, required)), total: Double(required))
                            .tint(Color.accentGreen)
                        detail("\(calculation.qualifyingHoles) of \(required) qualifying holes")
                    } else {
                        detail("Personal calculation is not yet available. You can use a manual starting Index.")
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(history.points) { point in
                        LineMark(x: .value("Round date", Date(timeIntervalSince1970: point.playedAt.unix)), y: .value("Handicap Index", point.calculation.qualifiedIndex!))
                            .foregroundStyle(Color.accentGreen).interpolationMethod(.catmullRom)
                        PointMark(x: .value("Round date", Date(timeIntervalSince1970: point.playedAt.unix)), y: .value("Handicap Index", point.calculation.qualifiedIndex!))
                            .foregroundStyle(Color.accentGreen).symbolSize(history.points.count == 1 ? 70 : 36)
                    }
                    if let point = trendPoint, selectedDate != nil {
                        RuleMark(x: .value("Selected round", Date(timeIntervalSince1970: point.playedAt.unix)))
                            .foregroundStyle(Color.neutral3.opacity(0.7)).lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(4, history.points.count))) { _ in
                        AxisGridLine().foregroundStyle(Color.neutral5.opacity(0.35))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.neutral5.opacity(0.35))
                        AxisValueLabel()
                    }
                }
                .chartXSelection(value: $selectedDate)
                .frame(height: 180)
                .accessibilityLabel("Personal Handicap Index progression, \(history.points.count) qualifying round calculations")
                if let point = trendPoint {
                    Button { selectedPoint = point } label: {
                        HStack {
                            Text(point.roundTitle).lineLimit(1)
                            Spacer()
                            Text(point.playedAt.formattedDate)
                            Image(systemName: "info.circle")
                        }
                        .fontStyle(kFontName, size: 12, weight: .medium)
                    }
                    .foregroundStyle(Color.neutral)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private var scoreHistoryCard: some View {
        SeriesSheetCard(palette: palette) {
            HStack {
                title("Score History")
                Spacer()
                if player.canEditPersonalHandicap(as: viewerUserID) { detail("Tap a score to review") }
            }
            HStack(spacing: 12) {
                legend("Counts", style: 0)
                legend("Pool", style: 1)
                legend("Unofficial", style: 2)
                legend("Pending", style: 2)
            }
            if history.scores.isEmpty {
                detail(isLoading ? "Loading personal score history…" : historyError != nil ? "Personal score history could not be loaded." : "No personal handicap scores recorded yet.")
                    .padding(.vertical, 12)
            }
            ForEach(history.scores) { score in
                let status = PersonalHandicapPresentation.scoreStatus(score, calculation: calculation)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(score.roundTitle).fontStyle(kFontName, size: 14, weight: .semibold)
                        detail("\(score.playedAt.formattedDate) · \(score.holeCount) holes")
                        if let reason = score.exclusionReason ?? score.pendingReason { detail(reason) }
                        if let pcc = score.pcc { detail(pcc.title) }
                        if let adjusted = score.adjustedGrossScore { detail("Adjusted gross (\(score.qualifyingHoles ?? score.holeCount) qualifying holes): \(adjusted)") }
                        if let differential = score.differential {
                            detail("18-hole differential: \(String(format: "%.1f", differential))")
                        } else if let played = score.playedDifferential {
                            detail("Played nine differential: \(String(format: "%.1f", played)) · conversion pending")
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(score.grossScore.map { "Gross \($0)" } ?? "—").monospacedDigit()
                        legend(status, style: status == "Counts" ? 0 : status == "Pool" ? 1 : 2)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    if player.canEditPersonalHandicap(as: viewerUserID) { postingReview = score }
                }
                .accessibilityAddTraits(player.canEditPersonalHandicap(as: viewerUserID) ? .isButton : [])
            }
        }
    }

    private var leagueCard: some View {
        SeriesSheetCard(palette: palette) {
            title("League Handicaps")
            if let leagueError {
                detail(leagueError)
                Button("Retry") { Task { await load() } }
            } else if leagues.isEmpty {
                detail(isLoading ? "Loading league handicaps…" : "No joined leagues.")
            }
            ForEach(leagues) { league in
                Button { onLeagueTap(league.id) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(league.name).fontStyle(kFontName, size: 15, weight: .semibold)
                            detail("\(league.basis.holeCount)-hole league Index")
                        }
                        Spacer(minLength: 0)
                        Text(ManualPersonalHandicap.display(league.index)).monospacedDigit()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).fontStyle(kFontName, size: 14, weight: .semibold).foregroundStyle(palette.foregroundColor)
    }

    private func detail(_ text: String) -> some View {
        Text(text).fontStyle(kFontName, size: 12, weight: .regular).foregroundStyle(Color.neutral)
    }

    private func countPill(_ title: String, _ count: Int?) -> some View {
        Text("\(title) \(count.map(String.init) ?? "—")")
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(Color.neutral)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(palette.cardEmbeddedRowBackground).clipShape(Capsule())
    }

    private func legend(_ title: String, style: Int) -> some View {
        HStack(spacing: 4) {
            if style == 0 {
                Circle().fill(Color.accentGreen).frame(width: 7, height: 7)
            } else {
                Circle().stroke(Color.neutral4, style: StrokeStyle(lineWidth: 1.5, dash: style == 2 ? [2, 2] : [])).frame(width: 7, height: 7)
            }
            Text(title).fontStyle(kFontName, size: 10, weight: .semibold).foregroundStyle(Color.neutral)
        }
    }

    @MainActor private func load() async {
        isLoading = true
        defer { isLoading = false }
        viewerUserID = await AppData.shared.user?.id
        historyError = nil
        leagueError = nil
        async let historyResult: Void = loadHistory()
        async let leagueResult: Void = loadLeagues()
        _ = await (historyResult, leagueResult)
    }

    @MainActor private func loadHistory() async {
        guard !isRefreshingHistory else { return }
        isRefreshingHistory = true
        defer { isRefreshingHistory = false }
        do {
            let loaded = try await FirebaseService.shared.fetchPersonalHandicapHistory(playerID: player.id)
            history = loaded
            historyError = nil
            if let refreshed = loaded.player { onSaved(refreshed) }
        }
        catch { historyError = "Couldn't load personal handicap history. Try again." }
    }

    @MainActor private func loadLeagues() async {
        do { leagues = try await FirebaseService.shared.fetchProfileLeagueHandicaps(playerID: player.id) }
        catch { leagueError = "Couldn't load league handicaps. Try again." }
    }
}

private struct StartingIndexEditorInput: Identifiable {
    let id: String
    let manual: ManualPersonalHandicap?
}

private struct StartingIndexEditor: View {
    let input: StartingIndexEditorInput
    let palette: DesignPalette
    let save: (ManualPersonalHandicap?) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var source: PersonalHandicapSource = .manual
    @State private var isPlus = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Unknown", text: $text).keyboardType(.decimalPad).accessibilityLabel("Starting Handicap Index")
                    Toggle("Plus handicap", isOn: $isPlus)
                    Picker("Source", selection: $source) {
                        Text("Self-reported").tag(PersonalHandicapSource.manual)
                        Text("GHIN / USGA (manual entry)").tag(PersonalHandicapSource.external)
                    }
                } header: {
                    Text("18-hole Handicap Index")
                } footer: {
                    Text("An official handicap is optional. Leave blank if unknown. This starting Index is preserved when Hackers calculations become available. A plus handicap means better than scratch.")
                }
                if let error { Text(error).foregroundStyle(Color.systemError) }
            }
            .scrollContentBackground(.hidden)
            .background(palette.backgroundColor)
            .tint(Color.accentGreen)
            .navigationTitle("Starting Handicap Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await submit() } }.disabled(isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear {
            text = input.manual.map { String(format: "%.1f", abs($0.value)) } ?? ""
            source = input.manual?.source ?? .manual
            isPlus = (input.manual?.value ?? 0) < 0
        }
    }

    @MainActor private func submit() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let manual = try ManualPersonalHandicap.parse(isPlus && !trimmed.isEmpty ? "+\(trimmed)" : trimmed, source: source)
            try await save(manual)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}


private struct PersonalHandicapPostingEditor: View {
    let score: PersonalHandicapScoreRecord
    let palette: DesignPalette
    let save: (PersonalHandicapRoundPurpose, String?) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var purpose: PersonalHandicapRoundPurpose = .acceptable
    @State private var reason = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(score.roundTitle) {
                    Picker("Personal handicap posting", selection: $purpose) {
                        Text("Include eligible individual score").tag(PersonalHandicapRoundPurpose.acceptable)
                        Text("Practice").tag(PersonalHandicapRoundPurpose.practice)
                        Text("Unofficial / exclude").tag(PersonalHandicapRoundPurpose.unofficial)
                        Text("Needs review").tag(PersonalHandicapRoundPurpose.unverified)
                    }
                    if score.holeCount < 18 {
                        Picker("If an 18-hole round ended early", selection: $reason) {
                            Text("No partial-round reason").tag("")
                            ForEach(PersonalHandicapPartialReason.allCases, id: \.rawValue) { reason in
                                Text(reason.title).tag(reason.rawValue)
                            }
                        }
                    }
                    Text("Completed individual cards are included for the unofficial personal calculation unless excluded. Only choose a partial-round reason when it prevented completing an intended 18-hole round. Shared, Scramble and invalid scorecards stay excluded. This does not change scores, league handicaps or round strokes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(Color.systemError) }
            }
            .scrollContentBackground(.hidden).background(palette.backgroundColor)
            .navigationTitle("Personal Handicap Score").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await submit() } }.disabled(isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear { purpose = score.postingPurpose ?? .acceptable; reason = score.partialReason ?? "" }
    }

    @MainActor private func submit() async {
        isSaving = true
        defer { isSaving = false }
        do { try await save(purpose, reason.isEmpty ? nil : reason); dismiss() }
        catch { self.error = "Could not save and refresh this posting. Try again." }
    }
}
