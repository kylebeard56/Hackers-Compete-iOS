//
//  SeriesHandicapSettingsView.swift
//  Hackers
//

import SwiftUI

struct SeriesHandicapSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    @State private var handicapMode: SeriesHandicapMode = .off
    @State private var differentialMultiplier: Double = 0.96
    @State private var defaultPar: Double = 36
    @State private var maximumHandicap: Int = 21
    @State private var minimumScores: Int = 1
    @State private var bestNScores: Int = 1
    @State private var usesCourseRatingSlopeAdjustment = true
    /// `nil` = all scores in the pool (no rolling date window).
    @State private var rollingPoolSize: Int? = nil
    @State private var scorePoolPolicy: HandicapScorePoolPolicy = .bestOfUsedCount

    @State private var exampleScores: String = ""
    @State private var previewResult: HandicapIndexResult?

    @State private var showOverrideList = false
    @State private var selectedMemberForScores: SeriesMember?

    @FocusState private var exampleScoresFocused: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Handicap Settings",
                    subtitle: "Configure series handicaps, baseline scores, and overrides.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    enableToggle
                    if handicapMode.isEnabled {
                        configSection
                        livePreviewSection
                        memberHandicapsSection
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    PrimaryButton(
                        appearance: .fill,
                        title: "Save",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        fillWidth: true,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: {
                            save()
                            dismiss()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear { loadFromConfig() }
        .sheet(item: $selectedMemberForScores) { member in
            SeriesBaselineScoresView(viewModel: viewModel, member: member)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showOverrideList) {
            SeriesHandicapOverrideView(viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Enable Toggle

    private var enableToggle: some View {
        SeriesSheetCard(palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    Text("Series Handicap")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    Text("Choose whether handicaps are off, fixed for scoring only, or updated dynamically from eligible rounds.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }

                HStack(spacing: 8) {
                    ForEach(SeriesHandicapMode.allCases, id: \.self) { mode in
                        Button {
                            handicapMode = mode
                        } label: {
                            Text(mode.displayName)
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(handicapMode == mode ? Color.white : palette.foregroundColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(handicapMode == mode ? Color.accentGreen : palette.cardEmbeddedRowBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(modeSubtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Configuration".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            SeriesSheetRow(palette: palette) {
                configRow(title: "Multiplier", subtitle: "Applied to differential average") {
                    Menu {
                        ForEach([0.90, 0.93, 0.96, 1.0], id: \.self) { val in
                            Button {
                                differentialMultiplier = val
                                updatePreview()
                            } label: {
                                HStack {
                                    Text(String(format: "%.2f", val))
                                    if differentialMultiplier == val {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        configMenuLabel(String(format: "%.2f", differentialMultiplier))
                    }
                }
            }

            SeriesSheetRow(palette: palette) {
                configRow(title: "Default par", subtitle: "Base par for index computation") {
                    Menu {
                        ForEach([36.0, 72.0], id: \.self) { val in
                            Button {
                                defaultPar = val
                                updatePreview()
                            } label: {
                                HStack {
                                    Text("\(Int(val))")
                                    if defaultPar == val {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        configMenuLabel("\(Int(defaultPar))")
                    }
                }
            }

            SeriesSheetRow(palette: palette) {
                Toggle(isOn: $usesCourseRatingSlopeAdjustment) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Course adjustment")
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text("Normalize round scores using that tee's rating and slope before they enter the index.")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }
                .tint(.accentGreen)
                .onChange(of: usesCourseRatingSlopeAdjustment) { _, _ in updatePreview() }
            }

            SeriesSheetRow(palette: palette) {
                configRow(
                    title: "Pool size",
                    subtitle: "How many recent scores by date are considered."
                ) {
                    Menu {
                        Button {
                            rollingPoolSize = nil
                            updatePreview()
                        } label: {
                            HStack {
                                Text("All scores")
                                if rollingPoolSize == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        ForEach([5, 10, 15, 20], id: \.self) { m in
                            Button {
                                rollingPoolSize = m
                                updatePreview()
                            } label: {
                                HStack {
                                    Text("\(m)")
                                    if rollingPoolSize == m {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        configMenuLabel(rollingPoolSize.map { "\($0)" } ?? "All")
                    }
                }
            }

            SeriesSheetRow(palette: palette) {
                configRow(title: "Scores in average", subtitle: "How many low scores from the pool count toward the index") {
                    Menu {
                        ForEach(1...8, id: \.self) { n in
                            Button {
                                bestNScores = n
                                updatePreview()
                            } label: {
                                HStack {
                                    Text("\(n)")
                                    if bestNScores == n {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        configMenuLabel("\(bestNScores)")
                    }
                }
            }

            SeriesSheetRow(palette: palette) {
                configRow(title: "Score pool", subtitle: scorePoolSubtitle) {
                    Menu {
                        Button {
                            scorePoolPolicy = .bestOfUsedCount
                            updatePreview()
                        } label: {
                            HStack {
                                Text("Lowest scores (WHS-style)")
                                if scorePoolPolicy == .bestOfUsedCount {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button {
                            scorePoolPolicy = .latestOfUsedCount
                            updatePreview()
                        } label: {
                            HStack {
                                Text("Most recent scores")
                                if scorePoolPolicy == .latestOfUsedCount {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        configMenuLabel(scorePoolMenuLabel)
                    }
                }
            }

            SeriesSheetRow(palette: palette) {
                configRow(title: "Max handicap", subtitle: "Ceiling for computed index") {
                    Menu {
                        ForEach([15, 18, 21, 24, 30, 36, 54], id: \.self) { val in
                            Button {
                                maximumHandicap = val
                                updatePreview()
                            } label: {
                                HStack {
                                    Text("\(val)")
                                    if maximumHandicap == val {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        configMenuLabel("\(maximumHandicap)")
                    }
                }
            }

            SeriesSheetRow(palette: palette) {
                configRow(title: "Min scores", subtitle: "Scores needed before index appears") {
                    Menu {
                        ForEach(1...5, id: \.self) { n in
                            Button {
                                minimumScores = n
                                updatePreview()
                            } label: {
                                HStack {
                                    Text("\(n)")
                                    if minimumScores == n {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        configMenuLabel("\(minimumScores)")
                    }
                }
            }
        }
    }

    private func configRow<Content: View>(title: String, subtitle: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text(subtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            Spacer(minLength: 0)
            trailing()
        }
    }

    private func configMenuLabel(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(Color.charcoal)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neutral6.opacity(0.4))
            )
    }

    // MARK: - Live Preview

    private var livePreviewSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Live Preview".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            TextField("Example scores (e.g. 42, 40, 45)", text: $exampleScores)
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .keyboardType(.numbersAndPunctuation)
                .focused($exampleScoresFocused)
                .onChange(of: exampleScores) { _, _ in updatePreview() }
                .borderedContentStyle(
                    isActive: exampleScoresFocused,
                    theme: palette.theme,
                    fill: palette.cardEmbeddedRowBackground
                )

            if let result = previewResult {
                SeriesSheetRow(palette: palette) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("Index")
                                    .fontStyle(kFontName, size: 11, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                                Text(String(format: "%.1f", result.handicapIndex))
                                    .fontStyle(kFontName, size: 20, weight: .bold)
                                    .foregroundStyle(Color.accentGreen)
                            }
                            VStack(spacing: 2) {
                                Text("Used")
                                    .fontStyle(kFontName, size: 11, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                                Text("\(result.gamesUsed) of \(result.gamesPlayed)")
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                            }
                            if result.isProvisional {
                                Chip(
                                    text: "Provisional",
                                    size: .tiny,
                                    foreground: Color.orange,
                                    background: Color.orange.opacity(0.15)
                                )
                            }
                        }
                        Text(previewPoolFootnote(for: result))
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }
            } else if !exampleScores.isEmpty {
                Text("Enter at least \(minimumScores) valid score\(minimumScores == 1 ? "" : "s")")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        }
    }

    // MARK: - Member Handicaps

    private var memberHandicapsSection: some View {
        SeriesSheetCard(palette: palette) {
            HStack {
                Text("Member Handicaps".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Button {
                    Haptics.fire(.light)
                    showOverrideList = true
                } label: {
                    Chip(
                        text: "Set overrides",
                        size: .xSmall,
                        foreground: .white,
                        background: Color.systemOrange
                    )
                }
                .buttonStyle(.plain)
            }

            if viewModel.activeMembers.isEmpty {
                Text("Add members to view their handicaps")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 12)
            } else {
                Text("Tap a member to manage baseline scores")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()

                ForEach(viewModel.activeMembers, id: \.id) { member in
                    Button {
                        Haptics.fire(.light)
                        selectedMemberForScores = member
                    } label: {
                        SeriesSheetRow(palette: palette) {
                            memberHandicapRow(member)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func memberHandicapRow(_ member: SeriesMember) -> some View {
        let hc = viewModel.memberHandicaps[member.id]
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name.fullName)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                HStack(spacing: 8) {
                    if let computed = hc?.computedIndex {
                        Text("Computed: \(String(format: "%.1f", computed))")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    } else {
                        Text(memberHandicapIndexStatusSubtitle(memberID: member.id))
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    if let over = hc, over.isOverridden, let val = over.overrideIndex {
                        Text("Override: \(String(format: "%.1f", val))")
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(Color.orange)
                    }

                    if hc?.isOverridden == true {
                        Chip(
                            text: "Override",
                            size: .xSmall,
                            foreground: .orange,
                            background: Color.orange.opacity(colorScheme.translucent)
                        )
                    }
                }
            }
            Spacer(minLength: 0)

            if let effective = viewModel.effectiveHandicap(for: member.id) {
                Text(String(format: "%.1f", effective))
                    .fontStyle(kFontName, size: 17, weight: .bold)
                    .foregroundStyle(Color.accentGreen)
            } else {
                Text("--")
                    .fontStyle(kFontName, size: 17, weight: .bold)
                    .foregroundStyle(Color.neutral)
            }
        }
        .padding(.vertical, 6)
    }

    /// Subtitle when there is no computed index yet (distinguishes empty history from “need more scores” per league minimum).
    private func memberHandicapIndexStatusSubtitle(memberID: String) -> String {
        let scoreCount = viewModel.handicapScores.filter { $0.memberID == memberID }.count
        let minNeeded = max(1, viewModel.series.handicapConfig.config.minimumScoresForIndex)
        if scoreCount == 0 {
            return "No scores"
        }
        if scoreCount < minNeeded {
            let need = minNeeded - scoreCount
            let scoreNoun = scoreCount == 1 ? "score" : "scores"
            let morePhrase = need == 1 ? "1 more" : "\(need) more"
            return "\(scoreCount) \(scoreNoun), need \(morePhrase)"
        }
        let noun = scoreCount == 1 ? "score" : "scores"
        return "\(scoreCount) \(noun) on file"
    }

    // MARK: - Helpers

    private func loadFromConfig() {
        let hc = viewModel.series.handicapConfig
        handicapMode = hc.mode
        differentialMultiplier = hc.config.differentialMultiplier
        defaultPar = hc.config.defaultParForIndex
        maximumHandicap = hc.config.maximumHandicap
        minimumScores = hc.config.minimumScoresForIndex
        usesCourseRatingSlopeAdjustment = hc.config.usesCourseRatingSlopeAdjustment

        if let first = hc.config.gamesUsedRules.first {
            bestNScores = first.used
        }
        scorePoolPolicy = hc.config.toConfig().scorePoolPolicy
        rollingPoolSize = hc.config.rollingPoolSize
    }

    private func mergedHandicapDTO(rules: [GamesUsedRuleDTO]) -> HandicapComputationConfigDTO {
        var base = viewModel.series.handicapConfig.config
        base.gamesUsedRules = rules
        base.differentialMultiplier = differentialMultiplier
        base.maximumHandicap = maximumHandicap
        base.minimumScoresForIndex = minimumScores
        base.defaultParForIndex = defaultPar
        base.usesCourseRatingSlopeAdjustment = usesCourseRatingSlopeAdjustment
        base.scorePoolPolicy = scorePoolPolicy == .bestOfUsedCount ? nil : "latest"
        base.rollingPoolSize = rollingPoolSize
        return base
    }

    private func save() {
        let rules = [GamesUsedRuleDTO(playedLower: 1, playedUpper: 100, used: bestNScores)]
        let dto = mergedHandicapDTO(rules: rules)
        let config = SeriesHandicapConfig(mode: handicapMode, config: dto)
        Task {
            await viewModel.saveHandicapSettings(config)
        }
    }

    private var modeSubtitle: String {
        switch handicapMode {
        case .off:
            return "Rounds stay gross unless commissioners manually turn handicaps on elsewhere."
        case .fixed:
            return "Use handicap indices for scoring, but round results never change the handicap pool."
        case .dynamic:
            return "Use handicap indices for scoring and update the handicap pool from eligible rounds."
        }
    }

    private func updatePreview() {
        let scores = exampleScores
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !scores.isEmpty else {
            previewResult = nil
            return
        }

        let samples = scores.enumerated().map { index, gross in
            HandicapScoreSample(
                id: "preview_\(index)",
                gross: gross,
                recordedAt: Time(iso: "1970-01-01T00:00:00Z", unix: Double(index)),
                sortOrder: index
            )
        }
        let rules = [GamesUsedRuleDTO(playedLower: 1, playedUpper: 100, used: bestNScores)]
        let dto = mergedHandicapDTO(rules: rules)
        previewResult = computeHandicapIndex(samples: samples, config: dto.toConfig())
    }

    private var scorePoolMenuLabel: String {
        switch scorePoolPolicy {
        case .bestOfUsedCount: return "Lowest"
        case .latestOfUsedCount: return "Recent"
        }
    }

    private var scorePoolSubtitle: String {
        switch scorePoolPolicy {
        case .bestOfUsedCount:
            return "Within the pool, use the lowest gross scores (WHS-style)"
        case .latestOfUsedCount:
            return "Within the pool, use the most recent scores by date"
        }
    }

    private func previewPoolFootnote(for result: HandicapIndexResult) -> String {
        let poolPrefix = rollingPoolSize.map { "Last \($0) scores by date in pool. " } ?? ""
        let values = result.selectedBestScores.map { String(format: "%.0f", $0) }.joined(separator: ", ")
        switch scorePoolPolicy {
        case .bestOfUsedCount:
            return poolPrefix + (values.isEmpty ? "Lowest scores in pool." : "Lowest \(result.gamesUsed) used: \(values)")
        case .latestOfUsedCount:
            return poolPrefix + (values.isEmpty ? "Most recent in pool." : "Latest \(result.gamesUsed) used: \(values)")
        }
    }
}
