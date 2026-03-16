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
        NavigationView {
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
            .navigationTitle(member.name.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                }
            }
        }
    }

    private var currentHandicapCard: some View {
        VStack(spacing: 8) {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.1), radius: 8)
        )
    }

    private var addScoreSection: some View {
        VStack(spacing: 12) {
            Text("Add Baseline Score".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            HStack(spacing: 12) {
                TextField("Score (e.g. 42)", text: $newScore)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .keyboardType(.numberPad)
                    .focused($focus)
                    .textFieldStyle(.roundedBorder)

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
                    Text("Add")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Double(newScore) != nil ? Color.accentGreen : Color.neutral4)
                        )
                }
                .disabled(Double(newScore) == nil || isAdding)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.1), radius: 8)
        )
    }

    private var scoresListSection: some View {
        VStack(spacing: 12) {
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
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Int(score.score))")
                                .fontStyle(kFontName, size: 16, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)

                            Text(sourceLabel(score.source))
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                        }
                        Spacer(minLength: 0)

                        Text(score.holeSegment.title)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    .padding(.vertical, 6)
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

    private func sourceLabel(_ source: SeriesHandicapScoreSource) -> String {
        switch source {
        case .baseline: return "Baseline"
        case .round(let rid): return "Round \(rid.prefix(6))..."
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
        NavigationView {
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
            .navigationTitle("Handicap Overrides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.fire(.light)
                        saveOverrides()
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
        .onAppear { loadOverrides() }
    }

    private func overrideRow(_ member: SeriesMember) -> some View {
        let state = overrides[member.id] ?? OverrideState(isOverridden: false, valueText: "")
        let hc = viewModel.memberHandicaps[member.id]
        let computedText = hc?.computedIndex.map { String(format: "%.1f", $0) } ?? "--"

        return VStack(spacing: 8) {
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
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.backgroundColor)
                .shadow(color: palette.shadowColor.opacity(0.08), radius: 6)
        )
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
            viewModel.setHandicapOverride(
                memberID: memberID,
                value: value,
                isOverridden: state.isOverridden && value != nil
            )
        }
    }
}
