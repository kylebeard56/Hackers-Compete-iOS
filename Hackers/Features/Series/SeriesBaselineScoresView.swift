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
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.foregroundColor)
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
                TextField("Score (e.g. 42)", text: $newScore)
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
                    SeriesSheetRow(palette: palette) {
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
