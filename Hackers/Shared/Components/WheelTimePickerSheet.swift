//
//  WheelTimePickerSheet.swift
//  Hackers
//

import SwiftUI

/// Wheel-style hour/minute picker with Clear and a primary confirm action. Caller dismisses the sheet from `onComplete`.
struct WheelTimePickerSheet: View {
    @Environment(\.colorScheme) var colorScheme

    let title: String
    let primaryButtonTitle: String
    let initialDate: Date
    let onComplete: (Date?) -> Void

    @State private var date: Date = .now

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
                .padding(.top, 32)

            Spacer(minLength: 0)

            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                PrimaryButton(
                    appearance: .fill,
                    title: "Clear",
                    labelColor: .white,
                    buttonColor: .systemError,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { onComplete(nil) }
                )

                PrimaryButton(
                    appearance: .fill,
                    title: primaryButtonTitle,
                    labelColor: palette.backgroundColor,
                    buttonColor: palette.foregroundColor,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { onComplete(date) }
                )
            }
            .padding(.horizontal, 16)
        }
        .background(palette.backgroundColor)
        .onAppear {
            date = initialDate
        }
    }
}
