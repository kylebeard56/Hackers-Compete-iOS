//
//  EditSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct EditSeriesRoundSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    let seriesRound: SeriesRound
    var onSaved: () -> Void

    @State private var title: String = ""
    @State private var scheduledDate: Date = Date()
    @State private var hasDate: Bool = false
    @State private var selectedScoringProfileID: String?
    @State private var isSaving = false
    @FocusState private var focus: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Edit round")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Round title (optional)", text: $title)
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .textInputAutocapitalization(.words)
                        .focused($focus)

                    Spacer(minLength: 0)

                    if focus && title.isPopulated {
                        ClearTextButton(theme: palette.theme, onTap: { title = "" })
                    }
                }
                .borderedContentStyle(isActive: focus, theme: palette.theme)

                Toggle(isOn: $hasDate) {
                    Text("Set date")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                }
                .tint(.accentGreen)

                if hasDate {
                    DatePicker("", selection: $scheduledDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .alignLeading()
                }

                if !viewModel.scoringProfiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scoring profile")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(palette.foregroundColor)
                        Picker("", selection: $selectedScoringProfileID) {
                            Text("Default").tag(nil as String?)
                            ForEach(viewModel.scoringProfiles, id: \.id) { profile in
                                Text(profile.name).tag(profile.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            Spacer(minLength: 0)

            PrimaryButton(
                appearance: .fill,
                title: "Save",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(isSaving),
                isLoading: .constant(isSaving),
                onTap: {
                    guard !isSaving else { return }
                    isSaving = true
                    Task {
                        await viewModel.updateSeriesRound(
                            seriesRound,
                            title: title.isEmpty ? nil : title,
                            scheduledAt: hasDate ? Time(for: scheduledDate) : nil,
                            scoringProfileID: selectedScoringProfileID
                        )
                        isSaving = false
                        onSaved()
                        dismiss()
                    }
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(palette.backgroundColor)
        .task {
            title = seriesRound.title
            if let at = seriesRound.scheduledAt {
                hasDate = true
                scheduledDate = Date(timeIntervalSince1970: at.unix)
            }
            selectedScoringProfileID = seriesRound.scoringProfileID
        }
        .resignKeyboardOnTapGesture()
    }
}
