//
//  SeriesHandicapScoreEditorSheet.swift
//  Hackers
//

import SwiftUI

struct SeriesHandicapScoreEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let member: SeriesMember
    let score: SeriesHandicapScore

    @State private var captionText: String = ""
    @State private var scoreText: String = ""
    @State private var parText: String = ""
    @State private var segment: HoleSegment = .front9
    @State private var recordedDate: Date = .init()
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var canMutateScore: Bool { viewModel.isCommissioner && score.source == .baseline }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Edit score",
                subtitle: "Baseline and history fields for \(member.name.fullName).",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    SeriesSheetCard(palette: palette) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Title (optional)".uppercased())
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            TextField("Leave blank for “Baseline”", text: $captionText)
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                                .padding(14)
                                .background(palette.cardEmbeddedRowBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    SeriesSheetCard(palette: palette) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gross score".uppercased())
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            TextField("e.g. 42", text: $scoreText)
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(palette.cardEmbeddedRowBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    SeriesSheetCard(palette: palette) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Par (index)".uppercased())
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            TextField("Par", text: $parText)
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                                .keyboardType(.decimalPad)
                                .padding(14)
                                .background(palette.cardEmbeddedRowBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    SeriesSheetCard(palette: palette) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Segment".uppercased())
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            if case .custom = segment {
                                Text(segment.title)
                                    .fontStyle(kFontName, size: 15, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            } else {
                                Picker("Segment", selection: $segment) {
                                    Text(HoleSegment.full18.title).tag(HoleSegment.full18)
                                    Text(HoleSegment.front9.title).tag(HoleSegment.front9)
                                    Text(HoleSegment.back9.title).tag(HoleSegment.back9)
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    SeriesSheetCard(palette: palette) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date & time".uppercased())
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            DatePicker(
                                "Recorded",
                                selection: $recordedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .fontStyle(kFontName, size: 14, weight: .regular)
                        }
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor)

            HStack(spacing: 12) {
                if canMutateScore {
                    PrimaryButton(
                        appearance: .fill,
                        title: "Delete score",
                        labelColor: .white,
                        buttonColor: .systemError,
                        theme: palette.theme,
                        fillWidth: false,
                        isDisabled: .constant(isSaving || isDeleting),
                        isLoading: $isDeleting,
                        onTap: { showDeleteConfirmation = true }
                    )
                }

                PrimaryButton(
                    appearance: .fill,
                    title: "Save",
                    labelColor: .white,
                    buttonColor: Color.accentGreen,
                    theme: palette.theme,
                    fillWidth: true,
                    isDisabled: .constant(!canSave || isSaving || isDeleting),
                    isLoading: $isSaving,
                    onTapAsync: { await save() }
                )
            }
            .padding(16)
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .alert("Delete score?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    isDeleting = true
                    let ok = await viewModel.deleteHandicapScoreEntry(score)
                    isDeleting = false
                    if ok { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the score from \(member.name.fullName)'s handicap history and recalculates their index.")
        }
        .onAppear {
            captionText = score.caption ?? ""
            scoreText = String(format: "%.0f", score.score)
            parText = score.par == floor(score.par) ? String(format: "%.0f", score.par) : String(format: "%.1f", score.par)
            segment = score.holeSegment
            recordedDate = Date(timeIntervalSince1970: score.recordedAt.unix)
        }
    }

    private var canSave: Bool {
        canMutateScore
            && Double(scoreText.trimmingCharacters(in: .whitespaces)) != nil
            && Double(parText.trimmingCharacters(in: .whitespaces)) != nil
    }

    private func save() async {
        guard let gross = Double(scoreText.trimmingCharacters(in: .whitespaces)),
              let par = Double(parText.trimmingCharacters(in: .whitespaces)) else { return }
        isSaving = true
        var updated = score
        let trimmed = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.caption = trimmed.isPopulated ? trimmed : nil
        updated.score = gross
        updated.par = par
        updated.holeSegment = segment
        updated.recordedAt = Time(for: recordedDate)
        updated.lastUpdatedAt = .init()
        let ok = await viewModel.updateHandicapScoreEntry(updated)
        isSaving = false
        if ok { dismiss() }
    }
}
