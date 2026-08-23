//
//  EditSeriesNameView.swift
//  Hackers
//

import SwiftUI

struct EditSeriesNameView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let currentName: String
    var onSave: (String) -> Void

    @State private var name = ""
    @FocusState private var focus: Bool
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Edit series name")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Series name", text: $name)
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
            }

            Spacer(minLength: 0)

            PrimaryButton(
                appearance: .fill,
                title: "Save",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
                isLoading: .false,
                onTap: {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, focus ? 16 : 0)
        .background(palette.backgroundColor)
        .onAppear { name = currentName }
        .task(delay: 0.2) { focus = true }
        .resignKeyboardOnTapGesture()
    }
}
