//
//  SeriesBaselineScoresView.swift
//  Hackers
//

import Charts
import SwiftUI

struct SeriesBaselineScoresView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    let member: SeriesMember

    @State private var newScore = ""
    @State private var addCaption = ""
    @State private var addMode: HandicapAddMode = .manual
    @State private var baselineStrokeBasis: SeriesHandicapStrokeBasis = .nineHole
    @State private var selectedSeriesRoundID: String?
    @State private var isAdding = false
    @State private var editingScore: SeriesHandicapScore?
    @State private var correctionRound: SeriesRound?
    @State private var pendingDeleteScore: SeriesHandicapScore?
    @State private var isDeletingScoreID: String?
    @State private var showMissingRoundAlert = false
    @State private var missingRoundAlertMessage = ""
    @FocusState private var focus: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var memberScores: [SeriesHandicapScore] {
        viewModel.handicapScores
            .filter { $0.memberID == member.id }
            .sorted {
                if $0.recordedAt.unix != $1.recordedAt.unix { return $0.recordedAt.unix > $1.recordedAt.unix }
                return $0.id > $1.id
            }
    }

    private var roundPickerRounds: [SeriesRound] {
        viewModel.rounds
            .filter { $0.roundID != nil && !$0.roundID!.isEmpty }
            .sorted { $0.index < $1.index }
    }

    private var handicapPoolIDs: Set<String> {
        viewModel.memberHandicapScoreSelections[member.id]?.poolIDs ?? []
    }

    private var handicapCountingIDs: Set<String> {
        viewModel.memberHandicapScoreSelections[member.id]?.countingIDs ?? []
    }

    private var handicapDotsLegend: Bool {
        viewModel.series.handicapConfig.isEnabled && !handicapPoolIDs.isEmpty
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: member.name.fullName,
                    subtitle: "Baseline scores and league handicap history.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    currentHandicapCard
                    addScoreSection
                    scoresListSection
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(palette.backgroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(palette.foregroundColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(item: $editingScore) { score in
            SeriesHandicapScoreEditorSheet(viewModel: viewModel, member: member, score: score)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $correctionRound) { sr in
            SeriesRoundScoreCorrectionSheet(
                viewModel: viewModel,
                seriesRound: sr,
                initialSeriesMemberID: member.id
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Can't edit round score", isPresented: $showMissingRoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(missingRoundAlertMessage)
        }
        .alert(
            "Delete score?",
            isPresented: Binding(
                get: { pendingDeleteScore != nil },
                set: { isPresented in
                    if !isPresented && isDeletingScoreID == nil {
                        pendingDeleteScore = nil
                    }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let score = pendingDeleteScore else { return }
                Task { await deleteScore(score) }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteScore = nil
            }
        } message: {
            Text("This removes the score from \(member.name.fullName)'s handicap history and recalculates their index.")
        }
    }

    private var currentHandicapCard: some View {
        SeriesSheetCard(palette: palette) {
            let hc = viewModel.memberHandicaps[member.id]

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effective Index")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                    if let eff = viewModel.effectiveHandicap(for: member.id) {
                        Text(String(format: "%.1f", eff))
                            .fontStyle(kFontName, size: 28, weight: .bold)
                            .foregroundStyle(Color.accentGreen)
                    } else {
                        Text("--")
                            .fontStyle(kFontName, size: 28, weight: .bold)
                            .foregroundStyle(Color.neutral)
                    }
                }
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    if let computed = hc?.computedIndex {
                        Text("Computed: \(String(format: "%.1f", computed))")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    if let hc, hc.isOverridden, let val = hc.overrideIndex {
                        Text("Override: \(String(format: "%.1f", val))")
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(Color.orange)
                    }
                }
            }

            Text("\(memberScores.count) score\(memberScores.count == 1 ? "" : "s") on file")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .alignLeading()
        }
    }

    private var addScoreSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Add score".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            Picker("Type", selection: $addMode) {
                Text(HandicapAddMode.manual.rawValue).tag(HandicapAddMode.manual)
                Text(HandicapAddMode.roundFromSeries.rawValue).tag(HandicapAddMode.roundFromSeries)
            }
            .pickerStyle(.segmented)

            if addMode == .manual {
                TextField("Optional title (blank = Baseline)", text: $addCaption)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(12)
                    .background(palette.cardEmbeddedRowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Picker("Holes", selection: $baselineStrokeBasis) {
                    ForEach(SeriesHandicapStrokeBasis.allCases, id: \.self) { basis in
                        Text(basis.displayName).tag(basis)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                if roundPickerRounds.isEmpty {
                    Text("No linked rounds yet. Link a round to the schedule first.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Picker("League round", selection: Binding(
                        get: { selectedSeriesRoundID ?? roundPickerRounds.first?.id },
                        set: { selectedSeriesRoundID = $0 }
                    )) {
                        ForEach(roundPickerRounds, id: \.id) { r in
                            Text(r.title.isPopulated ? r.title : "Round \(r.index + 1)")
                                .tag(Optional.some(r.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        if selectedSeriesRoundID == nil {
                            selectedSeriesRoundID = roundPickerRounds.first?.id
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("Gross (e.g. 42)", text: $newScore)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .keyboardType(.numberPad)
                    .focused($focus)
                    .borderedContentStyle(
                        isActive: focus,
                        theme: palette.theme,
                        fill: palette.cardEmbeddedRowBackground
                    )

                Button {
                    guard let score = Double(newScore.trimmingCharacters(in: .whitespaces)),
                          !isAdding else { return }
                    isAdding = true
                    focus = false
                    Task {
                        switch addMode {
                        case .manual:
                            let par = baselineStrokeBasis.baselineDefaultPar(
                                defaultParForIndex: viewModel.series.handicapConfig.config.defaultParForIndex
                            )
                            await viewModel.addHandicapScore(
                                memberID: member.id,
                                score: score,
                                par: par,
                                segment: baselineStrokeBasis.baselineStorageSegment,
                                source: .baseline,
                                sourceRoundID: nil,
                                caption: addCaption,
                                recordedAt: nil
                            )
                        case .roundFromSeries:
                            guard let sid = selectedSeriesRoundID ?? roundPickerRounds.first?.id,
                                  let sr = viewModel.rounds.first(where: { $0.id == sid }),
                                  let liveID = sr.roundID, liveID.isPopulated
                            else {
                                isAdding = false
                                return
                            }
                            let par = viewModel.series.handicapConfig.config.defaultParForIndex
                            await viewModel.addHandicapScore(
                                memberID: member.id,
                                score: score,
                                par: par,
                                segment: sr.courseOverride?.holeSegment ?? .front9,
                                source: .round,
                                sourceRoundID: liveID,
                                caption: nil,
                                recordedAt: nil
                            )
                        }
                        newScore = ""
                        addCaption = ""
                        isAdding = false
                    }
                } label: {
                    Chip(
                        text: isAdding ? "Adding..." : "Add",
                        size: .small,
                        foreground: .white,
                        background: canAddScore ? Color.accentGreen : Color.neutral4
                    )
                }
                .disabled(!canAddScore || isAdding)
                .buttonStyle(.plain)
            }
        }
    }

    private var canAddScore: Bool {
        guard Double(newScore.trimmingCharacters(in: .whitespaces)) != nil else { return false }
        if addMode == .roundFromSeries {
            return !(roundPickerRounds.isEmpty)
        }
        return true
    }

    private var scoresListSection: some View {
        SeriesSheetCard(palette: palette) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Score history".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if handicapDotsLegend {
                    Text("Green dot = counts toward index. Ring = in pool only. Dashed = unofficial (excluded from index).")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            if memberScores.isEmpty {
                Text("No scores recorded")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(memberScores, id: \.id) { score in
                        scoreRow(score)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scoreRow(_ score: SeriesHandicapScore) -> some View {
        SeriesSheetRow(palette: palette) {
            HStack(alignment: .top, spacing: 8) {
                if viewModel.series.handicapConfig.isEnabled {
                    handicapRowIndicator(score: score)
                        .padding(.top, 6)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(score.score))")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text(rowTitle(score))
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)

                    if let adjustmentSubtitle = viewModel.handicapScoreAdjustmentSubtitle(for: score) {
                        Text(adjustmentSubtitle)
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.accentGreen.opacity(0.9))
                    }

                    if !score.countsTowardHandicapIndex {
                        Text("Unofficial")
                            .fontStyle(kFontName, size: 11, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                    }

                    Text(Self.recordedFormatter.string(from: Date(timeIntervalSince1970: score.recordedAt.unix)))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral.opacity(0.85))
                }
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(scoreHoleCountLabel(for: score))
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                        if isEditableBaselineScore(score) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.neutral.opacity(0.7))
                        }
                    }
                    if showsRowMenu(for: score) {
                        Menu {
                            if viewModel.isCommissioner && viewModel.series.handicapConfig.isEnabled {
                                if score.countsTowardHandicapIndex {
                                    Button("Make unofficial") {
                                        Task { await viewModel.setHandicapScoreCountsTowardIndex(score, countsToward: false) }
                                    }
                                } else {
                                    Button("Make official") {
                                        Task { await viewModel.setHandicapScoreCountsTowardIndex(score, countsToward: true) }
                                    }
                                }
                            }
                            if score.source == .round {
                                Button("Edit round score…") {
                                    guard let rid = score.sourceRoundID else {
                                        missingRoundAlertMessage = "This score isn't linked to a round."
                                        showMissingRoundAlert = true
                                        return
                                    }
                                    if let sr = viewModel.seriesRound(forLiveRoundID: rid) {
                                        correctionRound = sr
                                    } else {
                                        missingRoundAlertMessage = "This score is tied to a live round that no longer matches a league round on the schedule. Use the round detail screen to correct scores if that round still exists."
                                        showMissingRoundAlert = true
                                    }
                                }
                            }
                            if showsDeleteMenuDivider(for: score) {
                                Divider()
                            }
                            Button(role: .destructive) {
                                pendingDeleteScore = score
                            } label: {
                                Text("Delete score")
                            }
                            .disabled(isDeletingScoreID == score.id)
                        } label: {
                            Icon(name: "ellipsis", size: 18, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditableBaselineScore(score) else { return }
            editingScore = score
        }
        .accessibilityAddTraits(isEditableBaselineScore(score) ? .isButton : [])
    }

    private func isEditableBaselineScore(_ score: SeriesHandicapScore) -> Bool {
        viewModel.isCommissioner && score.source == .baseline
    }

    private func showsRowMenu(for score: SeriesHandicapScore) -> Bool {
        viewModel.isCommissioner
    }

    private func showsDeleteMenuDivider(for score: SeriesHandicapScore) -> Bool {
        viewModel.series.handicapConfig.isEnabled || score.source == .round
    }

    private func deleteScore(_ score: SeriesHandicapScore) async {
        isDeletingScoreID = score.id
        _ = await viewModel.deleteHandicapScoreEntry(score)
        isDeletingScoreID = nil
        pendingDeleteScore = nil
    }

    @ViewBuilder
    private func handicapRowIndicator(score: SeriesHandicapScore) -> some View {
        let scoreID = score.id
        let inPool = handicapPoolIDs.contains(scoreID)
        let counts = handicapCountingIDs.contains(scoreID)
        Group {
            if !score.countsTowardHandicapIndex {
                Circle()
                    .stroke(Color.neutral4, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                    .frame(width: 7, height: 7)
            } else if counts {
                Circle()
                    .fill(Color.accentGreen)
                    .frame(width: 7, height: 7)
            } else if inPool {
                Circle()
                    .stroke(Color.neutral4, lineWidth: 1.5)
                    .frame(width: 7, height: 7)
            } else {
                Color.clear
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 10, alignment: .center)
    }

    private func rowTitle(_ score: SeriesHandicapScore) -> String {
        switch score.source {
        case .baseline:
            if let t = score.caption?.trimmingCharacters(in: .whitespacesAndNewlines), t.isPopulated {
                return t
            }
            return "Baseline"
        case .round:
            if let rid = score.sourceRoundID,
               let sr = viewModel.seriesRound(forLiveRoundID: rid) {
                return sr.title.isPopulated ? sr.title : "Round \(sr.index + 1)"
            }
            if let roundID = score.sourceRoundID, roundID.isPopulated {
                return "Round \(roundID.prefix(6))…"
            }
            return "Round"
        }
    }

    private func scoreHoleCountLabel(for score: SeriesHandicapScore) -> String {
        switch score.source {
        case .baseline:
            return score.baselineHoleCountDisplayName
        case .round:
            return score.holeSegment.title
        }
    }

    private static let recordedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

struct SeriesMemberHandicapBreakdownView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let member: SeriesMember

    @State private var showAddScoreSheet = false
    @State private var editingScore: SeriesHandicapScore?
    @State private var correctionRound: SeriesRound?
    @State private var pendingDeleteScore: SeriesHandicapScore?
    @State private var isDeletingScoreID: String?
    @State private var isBulkEditingScores = false
    @State private var selectedScoreIDs: Set<String> = []
    @State private var showBulkDeleteAlert = false
    @State private var isBulkDeletingScores = false
    @State private var roundUsageByScoreID: [String: SeriesHandicapRoundUsage] = [:]
    @State private var showMissingRoundAlert = false
    @State private var missingRoundAlertMessage = ""
    @State private var selectedTrendDate: Date?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var memberScores: [SeriesHandicapScore] {
        viewModel.handicapScores
            .filter { $0.memberID == member.id }
            .sorted {
                if $0.recordedAt.unix != $1.recordedAt.unix { return $0.recordedAt.unix > $1.recordedAt.unix }
                return $0.id > $1.id
            }
    }

    private var handicapPoolIDs: Set<String> {
        viewModel.memberHandicapScoreSelections[member.id]?.poolIDs ?? []
    }

    private var handicapCountingIDs: Set<String> {
        viewModel.memberHandicapScoreSelections[member.id]?.countingIDs ?? []
    }

    private var handicapDotsLegend: Bool {
        viewModel.series.handicapConfig.isEnabled && !handicapPoolIDs.isEmpty
    }

    private var handicapConfig: HandicapComputationConfig {
        viewModel.series.handicapConfig.config.toConfig()
    }

    private var selectedScores: [SeriesHandicapScore] {
        memberScores.filter { selectedScoreIDs.contains($0.id) }
    }

    private var defaultCourse: SeriesCourseSelection? {
        viewModel.series.defaultCourse
    }

    private var defaultCourseTee: Tee? {
        guard let course = defaultCourse, course.isConfigured else { return nil }
        let tees = viewModel.teeChoices(for: course)
        let memberTeeID = member.defaultTeeBoxID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let courseTeeID = course.defaultTeeBoxID.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredTeeID = memberTeeID?.isPopulated == true ? memberTeeID : (courseTeeID.isPopulated ? courseTeeID : nil)

        if let preferredTeeID,
           let tee = tees.first(where: { $0.id == preferredTeeID }) {
            return tee
        }
        return tees.first
    }

    private var currentCourseHandicap: Int? {
        guard let index = viewModel.effectiveHandicap(for: member.id),
              let tee = defaultCourseTee,
              let course = defaultCourse else {
            return nil
        }
        return SeriesCourseHandicapResolver.resolve(
            effectiveIndex: index,
            memberID: member.id,
            memberName: member.name.fullName,
            requestedTeeID: tee.id,
            tee: tee,
            courseID: course.courseID,
            courseName: course.cachedName,
            holeSegment: course.holeSegment,
            entryFormat: .courseHandicap,
            handicapStrokeBasis: viewModel.series.handicapConfig.strokeBasis,
            maximumHandicap: handicapConfig.maximumHandicap
        ).effectiveStrokes
    }

    private var defaultCourseContextText: String? {
        guard let course = defaultCourse, course.isConfigured else { return nil }
        var parts: [String] = []
        if let tee = defaultCourseTee {
            parts.append(tee.name)
        } else if course.defaultTeeBoxID.isPopulated {
            parts.append("Default tee")
        }
        parts.append(course.holeSegment.title)
        if course.cachedName.isPopulated {
            parts.append(course.cachedName)
        }
        return parts.joined(separator: " \(kDot) ")
    }

    private var handicapTrendPoints: [SeriesHandicapTrendPoint] {
        SeriesHandicapProjectionService.trend(
            memberID: member.id,
            scores: viewModel.handicapScores,
            rounds: viewModel.rounds,
            handicapConfig: viewModel.series.handicapConfig
        )
    }

    private var selectedTrendPoint: SeriesHandicapTrendPoint? {
        guard let selectedTrendDate else { return handicapTrendPoints.last }
        return handicapTrendPoints.min {
            abs($0.date.timeIntervalSince(selectedTrendDate)) < abs($1.date.timeIntervalSince(selectedTrendDate))
        }
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: member.name.fullName,
                    subtitle: handicapConfig.userFacingShortSheetSubtitle(),
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    currentHandicapCard
                    handicapTrendCard
                    scoresListSection
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    HStack(spacing: 12) {
                        if isBulkEditingScores {
                            PrimaryButton(
                                appearance: .fill,
                                title: "Cancel",
                                labelColor: palette.foregroundColor,
                                buttonColor: Color.neutral6,
                                theme: palette.theme,
                                fillWidth: false,
                                isDisabled: .constant(false),
                                isLoading: .constant(false),
                                onTap: { exitBulkEditMode() }
                            )

                            PrimaryButton(
                                appearance: .fill,
                                title: selectedScoreIDs.isEmpty ? "Delete" : "Delete \(selectedScoreIDs.count)",
                                labelColor: palette.backgroundColor,
                                buttonColor: .red,
                                theme: palette.theme,
                                fillWidth: true,
                                isDisabled: .constant(selectedScoreIDs.isEmpty),
                                isLoading: .constant(isBulkDeletingScores),
                                onTap: { showBulkDeleteAlert = true }
                            )
                        } else {
                            if viewModel.isCommissioner {
                                PrimaryButton(
                                    appearance: .fill,
                                    title: "Add score",
                                    labelColor: palette.foregroundColor,
                                    buttonColor: Color.neutral6,
                                    theme: palette.theme,
                                    fillWidth: false,
                                    isDisabled: .constant(false),
                                    isLoading: .constant(false),
                                    onTap: { showAddScoreSheet = true }
                                )
                            }

                            PrimaryButton(
                                appearance: .fill,
                                title: "Done",
                                labelColor: palette.backgroundColor,
                                buttonColor: palette.foregroundColor,
                                theme: palette.theme,
                                fillWidth: true,
                                isDisabled: .constant(false),
                                isLoading: .constant(false),
                                onTap: { dismiss() }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showAddScoreSheet) {
            SeriesBaselineScoresView(viewModel: viewModel, member: member)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingScore) { score in
            SeriesHandicapScoreEditorSheet(viewModel: viewModel, member: member, score: score)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $correctionRound) { sr in
            SeriesRoundScoreCorrectionSheet(
                viewModel: viewModel,
                seriesRound: sr,
                initialSeriesMemberID: member.id
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Can't edit round score", isPresented: $showMissingRoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(missingRoundAlertMessage)
        }
        .alert(
            "Delete score?",
            isPresented: Binding(
                get: { pendingDeleteScore != nil },
                set: { isPresented in
                    if !isPresented && isDeletingScoreID == nil {
                        pendingDeleteScore = nil
                    }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let score = pendingDeleteScore else { return }
                Task { await deleteScore(score) }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteScore = nil
            }
        } message: {
            Text("This removes the score from \(member.name.fullName)'s handicap history and recalculates their index.")
        }
        .alert(
            "Delete \(selectedScoreIDs.count) score\(selectedScoreIDs.count == 1 ? "" : "s")?",
            isPresented: $showBulkDeleteAlert
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteSelectedScores() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected scores from \(member.name.fullName)'s handicap history and recalculates their index.")
        }
        .onChange(of: memberScores.map(\.id)) { _, ids in
            selectedScoreIDs = selectedScoreIDs.intersection(Set(ids))
            roundUsageByScoreID = roundUsageByScoreID.filter { ids.contains($0.key) }
            if memberScores.isEmpty {
                exitBulkEditMode()
            }
        }
        .task(id: defaultCourse?.courseID) {
            await viewModel.ensureTeeChoicesLoaded(for: defaultCourse)
        }
    }

    private var currentHandicapCard: some View {
        let hc = viewModel.memberHandicaps[member.id]
        let effective = viewModel.effectiveHandicap(for: member.id)

        return SeriesSheetCard(palette: palette) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Handicap Index")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                    if let effective {
                        Text(String(format: "%.1f", effective))
                            .fontStyle(kFontName, size: 28, weight: .bold)
                            .foregroundStyle(palette.foregroundColor)
                    } else {
                        Text("--")
                            .fontStyle(kFontName, size: 28, weight: .bold)
                            .foregroundStyle(Color.neutral)
                    }
                }

                Spacer(minLength: 0)

                courseHandicapSummaryChip(value: currentCourseHandicap)
            }

            if let context = defaultCourseContextText {
                Text(context)
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ViewThatFits(in: .horizontal) {
                metricPillRow(hc: hc)
                VStack(alignment: .leading, spacing: 8) {
                    metricPillRow(hc: hc, limit: 2)
                    metricPillRow(hc: hc, dropFirst: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var handicapTrendCard: some View {
        SeriesSheetCard(palette: palette) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Handicap trend".uppercased())
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("Lower is better")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 8)

                if let point = selectedTrendPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", point.computedIndex))
                            .fontStyle(kFontName, size: 20, weight: .bold)
                            .foregroundStyle(Color.accentGreen)
                        Text(point.roundTitle)
                            .fontStyle(kFontName, size: 11, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(1)
                    }
                }
            }

            if handicapTrendPoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.neutral3)
                    Text("Complete a league round to start your trend.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityElement(children: .combine)
            } else {
                Chart {
                    ForEach(handicapTrendPoints) { point in
                        LineMark(
                            x: .value("Round date", point.date),
                            y: .value("Handicap index", point.computedIndex)
                        )
                        .foregroundStyle(Color.accentGreen)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Round date", point.date),
                            y: .value("Handicap index", point.computedIndex)
                        )
                        .foregroundStyle(Color.accentGreen)
                        .symbolSize(handicapTrendPoints.count == 1 ? 70 : 36)
                    }

                    if let point = selectedTrendPoint, selectedTrendDate != nil {
                        RuleMark(x: .value("Selected round", point.date))
                            .foregroundStyle(Color.neutral3.opacity(0.7))
                            .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(4, handicapTrendPoints.count))) { _ in
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
                .chartXSelection(value: $selectedTrendDate)
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(handicapTrendAccessibilityLabel)
                .accessibilityHint("Lower handicap index values are better.")

                if let point = selectedTrendPoint {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var handicapTrendAccessibilityLabel: String {
        guard let first = handicapTrendPoints.first, let last = handicapTrendPoints.last else {
            return "No completed league rounds in handicap trend."
        }
        if first.id == last.id {
            return "One completed league round. \(last.roundTitle), handicap index \(String(format: "%.1f", last.computedIndex))."
        }
        let direction = last.computedIndex < first.computedIndex ? "improved" : (last.computedIndex > first.computedIndex ? "increased" : "was unchanged")
        return "\(handicapTrendPoints.count) completed league rounds. Handicap index \(direction) from \(String(format: "%.1f", first.computedIndex)) to \(String(format: "%.1f", last.computedIndex))."
    }

    @ViewBuilder
    private func metricPillRow(hc: SeriesMemberHandicap?, limit: Int? = nil, dropFirst: Int = 0) -> some View {
        let pills = summaryMetricPills(hc: hc).dropFirst(dropFirst)
        let shown = limit.map { Array(pills.prefix($0)) } ?? Array(pills)
        if shown.isPopulated {
            HStack(spacing: 8) {
                ForEach(shown, id: \.title) { pill in
                    metricPill(
                        title: pill.title,
                        value: pill.value,
                        foreground: pill.foreground,
                        background: pill.background
                    )
                }
            }
        }
    }

    private func summaryMetricPills(hc: SeriesMemberHandicap?) -> [SummaryMetricPill] {
        var pills: [SummaryMetricPill] = [
            .init(title: "Scores", value: "\(memberScores.count)"),
            .init(title: "Counting", value: "\(handicapCountingIDs.count)")
        ]
        if let computed = hc?.computedIndex {
            pills.append(.init(title: "Computed", value: String(format: "%.1f", computed)))
        }
        if let hc, hc.isOverridden, let override = hc.overrideIndex {
            pills.append(
                .init(
                    title: "Override",
                    value: String(format: "%.1f", override),
                    foreground: .orange,
                    background: Color.orange.opacity(colorScheme.translucent)
                )
            )
        }
        return pills
    }

    private struct SummaryMetricPill {
        let title: String
        let value: String
        var foreground: Color = .neutral
        var background: Color?
    }

    private func courseHandicapSummaryChip(value: Int?) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Course HCP")
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
            Text(courseHandicapDisplayText(value))
                .fontStyle(kFontName, size: 20, weight: .bold)
                .foregroundStyle(palette.backgroundColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentGreen)
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Course handicap \(value.map { "\($0)" } ?? "unavailable")")
    }

    private func courseHandicapDisplayText(_ value: Int?) -> String {
        value.map { "\($0)" } ?? "--"
    }

    private func metricPill(
        title: String,
        value: String,
        foreground: Color = .neutral,
        background: Color? = nil
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .semibold)
            Text(value)
                .fontStyle(kFontName, size: 11, weight: .bold)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background ?? palette.cardEmbeddedRowBackground)
        .clipShape(Capsule())
    }

    private var scoresListSection: some View {
        SeriesSheetCard(palette: palette) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Score History".uppercased())
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Spacer(minLength: 0)

                    if viewModel.isCommissioner && !memberScores.isEmpty {
                        Button {
                            if isBulkEditingScores {
                                exitBulkEditMode()
                            } else {
                                isBulkEditingScores = true
                            }
                        } label: {
                            Text(isBulkEditingScores ? "Done" : "Edit")
                                .fontStyle(kFontName, size: 12, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(isBulkDeletingScores)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if handicapDotsLegend {
                    HStack(spacing: 8) {
                        handicapLegendToken(title: "Counts", style: .filled)
                        handicapLegendToken(title: "Pool", style: .ring)
                        handicapLegendToken(title: "Unofficial", style: .dashed)
                    }
                }
            }
            .padding(.bottom, 4)

            if memberScores.isEmpty {
                Text("No scores recorded")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(memberScores, id: \.id) { score in
                        scoreRow(score)
                    }
                }
            }
        }
    }

    private enum HandicapLegendStyle {
        case filled
        case ring
        case dashed
    }

    private func handicapLegendToken(title: String, style: HandicapLegendStyle) -> some View {
        HStack(spacing: 4) {
            legendDot(style: style)
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .semibold)
        }
        .foregroundStyle(Color.neutral)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(palette.cardEmbeddedRowBackground)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func legendDot(style: HandicapLegendStyle) -> some View {
        switch style {
        case .filled:
            Circle()
                .fill(Color.accentGreen)
                .frame(width: 7, height: 7)
        case .ring:
            Circle()
                .stroke(Color.neutral4, lineWidth: 1.5)
                .frame(width: 7, height: 7)
        case .dashed:
            Circle()
                .stroke(Color.neutral4, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                .frame(width: 7, height: 7)
        }
    }

    @ViewBuilder
    private func scoreRow(_ score: SeriesHandicapScore) -> some View {
        SeriesSheetRow(palette: palette) {
            HStack(alignment: .top, spacing: 8) {
                if viewModel.series.handicapConfig.isEnabled {
                    handicapRowIndicator(score: score)
                        .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(score.score))")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text(rowTitle(score))
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)

                    if let usage = roundUsageByScoreID[score.id] {
                        roundUsageChips(usage)
                    }

                    if let adjustmentSubtitle = viewModel.handicapScoreAdjustmentSubtitle(for: score) {
                        Text(adjustmentSubtitle)
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.accentGreen.opacity(0.9))
                    }

                    if !score.countsTowardHandicapIndex {
                        Text("Unofficial")
                            .fontStyle(kFontName, size: 11, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                    }

                    Text(Self.recordedFormatter.string(from: Date(timeIntervalSince1970: score.recordedAt.unix)))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral.opacity(0.85))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(scoreHoleCountLabel(for: score))
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                        if isEditableBaselineScore(score) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.neutral.opacity(0.7))
                        }
                    }
                    if isBulkEditingScores {
                        selectionButton(for: score)
                            .padding(.top, 8)
                    } else if showsRowMenu(for: score) {
                        Menu {
                            if viewModel.isCommissioner && viewModel.series.handicapConfig.isEnabled {
                                if score.countsTowardHandicapIndex {
                                    Button("Make unofficial") {
                                        Task { await viewModel.setHandicapScoreCountsTowardIndex(score, countsToward: false) }
                                    }
                                } else {
                                    Button("Make official") {
                                        Task { await viewModel.setHandicapScoreCountsTowardIndex(score, countsToward: true) }
                                    }
                                }
                            }
                            if score.source == .round {
                                Button("Edit round score…") {
                                    guard let rid = score.sourceRoundID else {
                                        missingRoundAlertMessage = "This score isn't linked to a round."
                                        showMissingRoundAlert = true
                                        return
                                    }
                                    if let sr = viewModel.seriesRound(forLiveRoundID: rid) {
                                        correctionRound = sr
                                    } else {
                                        missingRoundAlertMessage = "This score is tied to a live round that no longer matches a league round on the schedule. Use the round detail screen to correct scores if that round still exists."
                                        showMissingRoundAlert = true
                                    }
                                }
                            }
                            if showsDeleteMenuDivider(for: score) {
                                Divider()
                            }
                            Button(role: .destructive) {
                                pendingDeleteScore = score
                            } label: {
                                Text("Delete score")
                            }
                            .disabled(isDeletingScoreID == score.id)
                        } label: {
                            Icon(name: "ellipsis", size: 18, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isBulkEditingScores {
                toggleSelection(for: score)
                return
            }
            guard isEditableBaselineScore(score) else { return }
            editingScore = score
        }
        .accessibilityAddTraits((isBulkEditingScores || isEditableBaselineScore(score)) ? .isButton : [])
        .task(id: score.id) {
            await loadRoundUsage(for: score)
        }
    }

    private func roundUsageChips(_ usage: SeriesHandicapRoundUsage) -> some View {
        HStack(spacing: 6) {
            rowMetricChip(title: "Course HCP", value: "\(usage.courseHandicap)", foreground: palette.backgroundColor, background: Color.accentGreen)
            if let index = usage.handicapIndex {
                rowMetricChip(title: "Index", value: String(format: "%.1f", index), foreground: palette.foregroundColor, background: palette.cardEmbeddedRowBackground)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func rowMetricChip(title: String, value: String, foreground: Color, background: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .semibold)
            Text(value)
                .fontStyle(kFontName, size: 11, weight: .bold)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(Capsule())
    }

    private func loadRoundUsage(for score: SeriesHandicapScore) async {
        guard score.source == .round, roundUsageByScoreID[score.id] == nil else { return }
        guard let usage = await viewModel.handicapRoundUsage(for: score) else { return }
        roundUsageByScoreID[score.id] = usage
    }

    private func selectionButton(for score: SeriesHandicapScore) -> some View {
        Button {
            toggleSelection(for: score)
        } label: {
            Image(systemName: selectedScoreIDs.contains(score.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selectedScoreIDs.contains(score.id) ? Color.red : Color.neutral.opacity(0.75))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBulkDeletingScores)
        .accessibilityLabel(selectedScoreIDs.contains(score.id) ? "Deselect score" : "Select score")
    }

    private func toggleSelection(for score: SeriesHandicapScore) {
        guard isBulkEditingScores, !isBulkDeletingScores else { return }
        if selectedScoreIDs.contains(score.id) {
            selectedScoreIDs.remove(score.id)
        } else {
            selectedScoreIDs.insert(score.id)
        }
    }

    private func exitBulkEditMode() {
        isBulkEditingScores = false
        selectedScoreIDs.removeAll()
        showBulkDeleteAlert = false
    }

    private func isEditableBaselineScore(_ score: SeriesHandicapScore) -> Bool {
        viewModel.isCommissioner && score.source == .baseline
    }

    private func showsRowMenu(for score: SeriesHandicapScore) -> Bool {
        viewModel.isCommissioner
    }

    private func showsDeleteMenuDivider(for score: SeriesHandicapScore) -> Bool {
        viewModel.series.handicapConfig.isEnabled || score.source == .round
    }

    private func deleteScore(_ score: SeriesHandicapScore) async {
        isDeletingScoreID = score.id
        _ = await viewModel.deleteHandicapScoreEntry(score)
        isDeletingScoreID = nil
        pendingDeleteScore = nil
    }

    private func deleteSelectedScores() async {
        let scores = selectedScores
        guard !scores.isEmpty else {
            exitBulkEditMode()
            return
        }
        isBulkDeletingScores = true
        for score in scores {
            _ = await viewModel.deleteHandicapScoreEntry(score)
        }
        isBulkDeletingScores = false
        exitBulkEditMode()
    }

    @ViewBuilder
    private func handicapRowIndicator(score: SeriesHandicapScore) -> some View {
        let scoreID = score.id
        let inPool = handicapPoolIDs.contains(scoreID)
        let counts = handicapCountingIDs.contains(scoreID)
        Group {
            if !score.countsTowardHandicapIndex {
                Circle()
                    .stroke(Color.neutral4, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                    .frame(width: 7, height: 7)
            } else if counts {
                Circle()
                    .fill(Color.accentGreen)
                    .frame(width: 7, height: 7)
            } else if inPool {
                Circle()
                    .stroke(Color.neutral4, lineWidth: 1.5)
                    .frame(width: 7, height: 7)
            } else {
                Color.clear
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 10, alignment: .center)
    }

    private func rowTitle(_ score: SeriesHandicapScore) -> String {
        switch score.source {
        case .baseline:
            if let t = score.caption?.trimmingCharacters(in: .whitespacesAndNewlines), t.isPopulated {
                return t
            }
            return "Baseline"
        case .round:
            if let rid = score.sourceRoundID,
               let sr = viewModel.seriesRound(forLiveRoundID: rid) {
                return sr.title.isPopulated ? sr.title : "Round \(sr.index + 1)"
            }
            if let roundID = score.sourceRoundID, roundID.isPopulated {
                return "Round \(roundID.prefix(6))…"
            }
            return "Round"
        }
    }

    private func scoreHoleCountLabel(for score: SeriesHandicapScore) -> String {
        switch score.source {
        case .baseline:
            return score.baselineHoleCountDisplayName
        case .round:
            return score.holeSegment.title
        }
    }

    private static let recordedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

private enum HandicapAddMode: String {
    case manual = "Manual"
    case roundFromSeries = "Round"
}
