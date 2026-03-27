//
//  SeriesHandicapSettingsView.swift
//  Hackers
//

import SwiftUI

struct SeriesHandicapSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    @State private var isEnabled: Bool = false
    @State private var differentialMultiplier: Double = 0.96
    @State private var defaultPar: Double = 36
    @State private var maximumHandicap: Int = 21
    @State private var minimumScores: Int = 1
    @State private var bestNScores: Int = 1
    @State private var scorePoolPolicy: HandicapScorePoolPolicy = .bestOfUsedCount

    @State private var exampleScores: String = ""
    @State private var previewResult: HandicapIndexResult?

    @State private var showOverrideList = false
    @State private var selectedMemberForScores: SeriesMember?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Handicap Settings",
                    subtitle: "Configure league handicaps, baseline scores, and overrides.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    enableToggle
                    if isEnabled {
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
                Button {
                    Haptics.fire(.light)
                    save()
                    dismiss()
                } label: {
                    Text("Save")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
            Toggle(isOn: $isEnabled) {
                VStack(spacing: 4) {
                    Text("League Handicap")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    Text("Compute and track handicap indices for series members")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            }
            .tint(.accentGreen)
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Configuration".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            SeriesSheetRow {
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

            SeriesSheetRow {
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

            SeriesSheetRow {
                configRow(title: "Scores in average", subtitle: "How many scores from the pool count") {
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

            SeriesSheetRow {
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

            SeriesSheetRow {
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

            SeriesSheetRow {
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
                .onChange(of: exampleScores) { _, _ in updatePreview() }
                .mutedGlassTextFieldContainer(cornerRadius: 14)

            if let result = previewResult {
                SeriesSheetRow {
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
                        text: "Overrides",
                        size: .xSmall,
                        foreground: .orange,
                        background: Color.orange.opacity(0.14)
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
                        SeriesSheetRow {
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
                        Text("No scores")
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

    // MARK: - Helpers

    private func loadFromConfig() {
        let hc = viewModel.series.handicapConfig
        isEnabled = hc.isEnabled
        differentialMultiplier = hc.config.differentialMultiplier
        defaultPar = hc.config.defaultParForIndex
        maximumHandicap = hc.config.maximumHandicap
        minimumScores = hc.config.minimumScoresForIndex

        if let first = hc.config.gamesUsedRules.first {
            bestNScores = first.used
        }
        scorePoolPolicy = hc.config.toConfig().scorePoolPolicy
    }

    private func mergedHandicapDTO(rules: [GamesUsedRuleDTO]) -> HandicapComputationConfigDTO {
        var base = viewModel.series.handicapConfig.config
        base.gamesUsedRules = rules
        base.differentialMultiplier = differentialMultiplier
        base.maximumHandicap = maximumHandicap
        base.minimumScoresForIndex = minimumScores
        base.defaultParForIndex = defaultPar
        base.scorePoolPolicy = scorePoolPolicy == .bestOfUsedCount ? nil : "latest"
        return base
    }

    private func save() {
        let rules = [GamesUsedRuleDTO(playedLower: 1, playedUpper: 100, used: bestNScores)]
        let dto = mergedHandicapDTO(rules: rules)
        let config = SeriesHandicapConfig(isEnabled: isEnabled, config: dto)
        Task {
            await viewModel.saveHandicapSettings(config)
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

        let rules = [GamesUsedRuleDTO(playedLower: 1, playedUpper: 100, used: bestNScores)]
        let dto = mergedHandicapDTO(rules: rules)
        previewResult = computeHandicapIndex(scores: scores, config: dto.toConfig())
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
            return "Uses the lowest differentials in the pool (WHS-style)"
        case .latestOfUsedCount:
            return "Uses the most recently entered scores in order"
        }
    }

    private func previewPoolFootnote(for result: HandicapIndexResult) -> String {
        let values = result.selectedBestScores.map { String(format: "%.0f", $0) }.joined(separator: ", ")
        switch scorePoolPolicy {
        case .bestOfUsedCount:
            return values.isEmpty ? "Pool: lowest scores" : "Lowest \(result.gamesUsed) used: \(values)"
        case .latestOfUsedCount:
            return values.isEmpty ? "Pool: most recent scores" : "Latest \(result.gamesUsed) used: \(values)"
        }
    }
}
