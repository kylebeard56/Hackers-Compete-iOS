//
//  NewSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct NewSeriesRoundSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    var onCreated: () -> Void

    @State private var title = ""
    @State private var scheduledDate = Date()
    @State private var hasDate = false
    @State private var isCreating = false
    @FocusState private var focus: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Schedule round")
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
            }

            Spacer(minLength: 0)

            PrimaryButton(
                appearance: .fill,
                title: "Create",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(isCreating),
                isLoading: .constant(isCreating),
                onTap: {
                    guard !isCreating else { return }
                    isCreating = true
                    let roundTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayTitle = roundTitle.isEmpty ? "Round \(viewModel.rounds.count + 1)" : roundTitle
                    Task {
                        _ = await viewModel.addRound(
                            title: displayTitle,
                            scheduledAt: hasDate ? Time(for: scheduledDate) : nil
                        )
                        isCreating = false
                        onCreated()
                    }
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(palette.backgroundColor)
        .task(delay: 0.2) { focus = true }
        .resignKeyboardOnTapGesture()
    }
}
