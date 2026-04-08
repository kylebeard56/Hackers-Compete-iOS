//
//  NewSeriesView.swift
//  Hackers
//

import SwiftUI

struct NewSeriesView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var onCreate: CallbackValue<String>? = nil

    @State private var name = ""
    @State private var isCreating = false
    @FocusState private var focus: Bool
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("New series")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Enter series name", text: $name)
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

                Text("Create a league, trip, or multi-round competition. You'll be the commissioner.")
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
                    onCreate?(trimmed)
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
