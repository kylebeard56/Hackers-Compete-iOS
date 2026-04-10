//
//  SeriesBaselineScoresView.swift
//  Hackers
//

import SwiftUI

struct SeriesBaselineScoresView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    let member: SeriesMember

    @State private var newScore = ""
    @State private var addCaption = ""
    @State private var addMode: HandicapAddMode = .manual
    @State private var selectedSeriesRoundID: String?
    @State private var isAdding = false
    @State private var editingScore: SeriesHandicapScore?
    @State private var correctionRound: SeriesRound?
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
                        let par = viewModel.series.handicapConfig.config.defaultParForIndex
                        switch addMode {
                        case .manual:
                            await viewModel.addHandicapScore(
                                memberID: member.id,
                                score: score,
                                par: par,
                                segment: .front9,
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
                    Text("Green dot = counts toward index. Ring = in pool only.")
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
                    handicapRowIndicator(scoreID: score.id)
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

                    Text(Self.recordedFormatter.string(from: Date(timeIntervalSince1970: score.recordedAt.unix)))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral.opacity(0.85))
                }
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(score.holeSegment.title)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                    Menu {
                        if score.source == .baseline {
                            Button("Edit") {
                                editingScore = score
                            }
                        } else {
                            Button("Edit round score…") {
                                guard let rid = score.sourceRoundID else {
                                    missingRoundAlertMessage = "This score isn't linked to a round."
                                    showMissingRoundAlert = true
                                    return
                                }
                                if let sr = viewModel.seriesRound(forLiveRoundID: rid) {
                                    correctionRound = sr
                                } else {
                                    missingRoundAlertMessage = "This score is tied to a live round that no longer matches a league round on the schedule. You can still delete the history row or add corrections from the round’s detail screen if it exists."
                                    showMissingRoundAlert = true
                                }
                            }
                        }
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteHandicapScoreEntry(score) }
                        }
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

    @ViewBuilder
    private func handicapRowIndicator(scoreID: String) -> some View {
        let inPool = handicapPoolIDs.contains(scoreID)
        let counts = handicapCountingIDs.contains(scoreID)
        Group {
            if counts {
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

    private var handicapConfig: HandicapComputationConfig {
        viewModel.series.handicapConfig.config.toConfig()
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: member.name.fullName,
                    subtitle: handicapConfig.userFacingSummaryCaption(),
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    currentHandicapCard
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
    }

    private var currentHandicapCard: some View {
        let hc = viewModel.memberHandicaps[member.id]

        return SeriesSheetCard(palette: palette) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effective Index")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                    if let effective = viewModel.effectiveHandicap(for: member.id) {
                        Text(String(format: "%.1f", effective))
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

                    if let hc, hc.isOverridden, let override = hc.overrideIndex {
                        Text("Override: \(String(format: "%.1f", override))")
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(Color.orange)
                    }
                }
            }

            Text("\(memberScores.count) score\(memberScores.count == 1 ? "" : "s") on file \(kDot) \(handicapCountingIDs.count) counting")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scoresListSection: some View {
        SeriesSheetCard(palette: palette) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Score History".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Newest first.")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
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

    @ViewBuilder
    private func scoreRow(_ score: SeriesHandicapScore) -> some View {
        SeriesSheetRow(palette: palette) {
            HStack(alignment: .top, spacing: 8) {
                handicapRowIndicator(scoreID: score.id)
                    .padding(.top, 6)

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

                    Text(Self.recordedFormatter.string(from: Date(timeIntervalSince1970: score.recordedAt.unix)))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral.opacity(0.85))
                }

                Spacer(minLength: 0)

                Text(score.holeSegment.title)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        }
    }

    @ViewBuilder
    private func handicapRowIndicator(scoreID: String) -> some View {
        let inPool = handicapPoolIDs.contains(scoreID)
        let counts = handicapCountingIDs.contains(scoreID)
        Group {
            if counts {
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
            if let title = score.caption?.trimmingCharacters(in: .whitespacesAndNewlines), title.isPopulated {
                return title
            }
            return "Baseline"
        case .round:
            if let roundID = score.sourceRoundID,
               let seriesRound = viewModel.seriesRound(forLiveRoundID: roundID) {
                return seriesRound.title.isPopulated ? seriesRound.title : "Round \(seriesRound.index + 1)"
            }
            if let roundID = score.sourceRoundID, roundID.isPopulated {
                return "Round \(roundID.prefix(6))…"
            }
            return "Round"
        }
    }

    private static let recordedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum HandicapAddMode: String {
    case manual = "Manual"
    case roundFromSeries = "Round"
}
