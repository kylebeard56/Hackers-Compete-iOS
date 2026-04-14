//
//  NewSeriesView.swift
//  Hackers
//

import SwiftUI

struct NewSeriesView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var onCreate: ((String, SeriesExperiencePreset) -> Void)? = nil

    @State private var name = ""
    @State private var preset: SeriesExperiencePreset = .league
    @State private var isCreating = false
    @FocusState private var focus: Bool
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text(preset.creationFlowTitle)
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(SeriesExperiencePreset.allCases, id: \.self) { option in
                        Button {
                            preset = option
                        } label: {
                            Text(option.displayName)
                                .fontStyle(kFontName, size: 14, weight: .semibold)
                                .foregroundStyle(preset == option ? Color.white : palette.foregroundColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(preset == option ? Color.accentGreen : palette.whiteGlassButtonColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    TextField(preset.nameEntryPlaceholder, text: $name)
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .textInputAutocapitalization(.words)
                        .focused($focus)

                    Spacer(minLength: 0)

                    if focus && name.isPopulated {
                        ClearTextButton(theme: palette.theme, onTap: { name = "" })
                    }
                }
                .borderedContentStyle(isActive: focus, theme: palette.theme)

                Text(preset.newExperienceDescription)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }

            Spacer(minLength: 0)

            PrimaryButton(
                appearance: .fill,
                title: "Create",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating),
                isLoading: .constant(isCreating),
                onTap: {
                    guard !isCreating else { return }
                    isCreating = true
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onCreate?(trimmed, preset)
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, focus ? 16 : 0)
        .background(palette.backgroundColor)
        .task(delay: 0.2) {
            focus = true
        }
        .resignKeyboardOnTapGesture()
    }
}

#Preview {
    Color.neutral.sheet(isPresented: .true) {
        NewSeriesView()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}
