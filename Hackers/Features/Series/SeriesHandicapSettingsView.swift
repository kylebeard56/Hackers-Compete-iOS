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

    @State private var exampleScores: String = ""
    @State private var previewResult: HandicapIndexResult?

    @State private var showOverrideList = false
    @State private var selectedMemberForScores: SeriesMember?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    enableToggle
                    if isEnabled {
                        configSection
                        livePreviewSection
                        memberHandicapsSection
                    }
                    Padding(.vertical, 32)
                }
                .padding(.horizontal, 16)
            }
            .background(palette.backgroundColor)
            .navigationTitle("Handicap Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.fire(.light)
                        save()
                        dismiss()
                    }
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .fontStyle(kFontName, size: 15, weight: .regular)
                }
            }
        }
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.1), radius: 8)
        )
    }

    // MARK: - Config Section

    private var configSection: some View {
        VStack(spacing: 14) {
            Text("Configuration".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

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

            configRow(title: "Best scores used", subtitle: "How many lowest scores count") {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.1), radius: 8)
        )
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
        VStack(spacing: 12) {
            Text("Live Preview".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            VStack(spacing: 8) {
                TextField("Example scores (e.g. 42, 40, 45)", text: $exampleScores)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .onChange(of: exampleScores) { _, _ in updatePreview() }

                if let result = previewResult {
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
                            Text("Provisional")
                                .fontStyle(kFontName, size: 11, weight: .medium)
                                .foregroundStyle(Color.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral6.opacity(0.3))
                    )
                } else if !exampleScores.isEmpty {
                    Text("Enter at least \(minimumScores) valid score\(minimumScores == 1 ? "" : "s")")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.1), radius: 8)
        )
    }

    // MARK: - Member Handicaps

    private var memberHandicapsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Member Handicaps".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Button("Overrides") {
                    Haptics.fire(.light)
                    showOverrideList = true
                }
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(Color.orange)
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
                        memberHandicapRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.1), radius: 8)
        )
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
    }

    private func save() {
        let rules = [GamesUsedRuleDTO(playedLower: 1, playedUpper: 100, used: bestNScores)]
        let dto = HandicapComputationConfigDTO(
            gamesUsedRules: rules,
            differentialMultiplier: differentialMultiplier,
            maximumHandicap: maximumHandicap,
            minimumScoresForIndex: minimumScores,
            defaultParForIndex: defaultPar
        )
        viewModel.series.handicapConfig = SeriesHandicapConfig(isEnabled: isEnabled, config: dto)
        viewModel.series.lastUpdatedAt = Time()
        Task {
            _ = await FirebaseService.shared.updateSeries(viewModel.series)
            viewModel.recomputeAllHandicaps()
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
        let dto = HandicapComputationConfigDTO(
            gamesUsedRules: rules,
            differentialMultiplier: differentialMultiplier,
            maximumHandicap: maximumHandicap,
            minimumScoresForIndex: minimumScores,
            defaultParForIndex: defaultPar
        )
        previewResult = computeHandicapIndex(scores: scores, config: dto.toConfig())
    }
}
