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
    @State private var isAdding = false
    @FocusState private var focus: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var memberScores: [SeriesHandicapScore] {
        viewModel.handicapScores
            .filter { $0.memberID == member.id }
            .sorted { $0.createdAt.unix > $1.createdAt.unix }
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: member.name.fullName,
                subtitle: "Baseline scores and league handicap history.",
                onClose: { dismiss() }
            ) {
                Button {
                    dismiss()
                } label: {
                    Chip(
                        text: "Done",
                        size: .xSmall,
                        foreground: .white,
                        background: Color.accentGreen
                    )
                }
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    currentHandicapCard
                    addScoreSection
                    scoresListSection
                    Padding(.vertical, 32)
                }
                .padding(.horizontal, 16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
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
            Text("Add Baseline Score".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            HStack(spacing: 12) {
                SeriesSheetRow {
                    TextField("Score (e.g. 42)", text: $newScore)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .keyboardType(.numberPad)
                        .focused($focus)
                }

                Button {
                    guard let score = Double(newScore.trimmingCharacters(in: .whitespaces)),
                          !isAdding else { return }
                    isAdding = true
                    focus = false
                    Task {
                        await viewModel.addBaselineScore(
                            memberID: member.id,
                            score: score,
                            par: viewModel.series.handicapConfig.config.defaultParForIndex
                        )
                        newScore = ""
                        isAdding = false
                    }
                } label: {
                    Chip(
                        text: isAdding ? "Adding..." : "Add",
                        size: .small,
                        foreground: .white,
                        background: Double(newScore) != nil && !isAdding ? Color.accentGreen : Color.neutral4
                    )
                }
                .disabled(Double(newScore) == nil || isAdding)
                .buttonStyle(.plain)
            }
        }
    }

    private var scoresListSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Score History".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            if memberScores.isEmpty {
                Text("No scores recorded")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 16)
            } else {
                ForEach(memberScores, id: \.id) { score in
                    SeriesSheetRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(Int(score.score))")
                                    .fontStyle(kFontName, size: 16, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)

                                Text(sourceLabel(score))
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }
                            Spacer(minLength: 0)

                            Text(score.holeSegment.title)
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                        }
                    }
                }
            }
        }
    }

    private func sourceLabel(_ score: SeriesHandicapScore) -> String {
        switch score.source {
        case .baseline:
            return "Baseline"
        case .round:
            if let roundID = score.sourceRoundID, roundID.isPopulated {
                return "Round \(roundID.prefix(6))..."
            }
            return "Round"
        }
    }
}

// MARK: - Commissioner Override Sheet

struct SeriesHandicapOverrideView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    @State private var overrides: [String: OverrideState] = [:]

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private struct OverrideState {
        var isOverridden: Bool
        var valueText: String
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Handicap Overrides",
                subtitle: "Commissioner overrides replace the computed league handicap until turned off.",
                onClose: { dismiss() }
            ) {
                Button {
                    Haptics.fire(.light)
                    saveOverrides()
                    dismiss()
                } label: {
                    Chip(
                        text: "Save",
                        size: .xSmall,
                        foreground: .white,
                        background: Color.accentGreen
                    )
                }
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(viewModel.activeMembers, id: \.id) { member in
                        overrideRow(member)
                    }
                    Padding(.vertical, 32)
                }
                .padding(.horizontal, 16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear { loadOverrides() }
    }

    private func overrideRow(_ member: SeriesMember) -> some View {
        let state = overrides[member.id] ?? OverrideState(isOverridden: false, valueText: "")
        let hc = viewModel.memberHandicaps[member.id]
        let computedText = hc?.computedIndex.map { String(format: "%.1f", $0) } ?? "--"

        return SeriesSheetCard(palette: palette) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("Computed: \(computedText)")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)

                Toggle("", isOn: Binding(
                    get: { overrides[member.id]?.isOverridden ?? false },
                    set: {
                        overrides[member.id, default: OverrideState(isOverridden: false, valueText: "")].isOverridden = $0
                    }
                ))
                .tint(.orange)
                .labelsHidden()
            }

            if state.isOverridden {
                SeriesSheetRow {
                    HStack(spacing: 8) {
                        Text("Override value:")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                        TextField("Index", text: Binding(
                            get: { overrides[member.id]?.valueText ?? "" },
                            set: { overrides[member.id, default: OverrideState(isOverridden: true, valueText: "")].valueText = $0 }
                        ))
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.orange)
                        .keyboardType(.decimalPad)
                    }
                }
            }
        }
    }

    private func loadOverrides() {
        for member in viewModel.activeMembers {
            let hc = viewModel.memberHandicaps[member.id]
            overrides[member.id] = OverrideState(
                isOverridden: hc?.isOverridden ?? false,
                valueText: hc?.overrideIndex.map { String(format: "%.1f", $0) } ?? ""
            )
        }
    }

    private func saveOverrides() {
        for (memberID, state) in overrides {
            let value = Double(state.valueText)
            Task {
                await viewModel.setHandicapOverride(
                    memberID: memberID,
                    value: value,
                    isOverridden: state.isOverridden && value != nil
                )
            }
        }
    }
}
