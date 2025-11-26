//
//  TeeTimePicker.swift
//  Hackers
//
//  Created by Kyle Beard on 11/26/25.
//

import SwiftUI

struct TeeTimePicker: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var group: TeeTimeGroup?
    var onDone: CallbackValue<String?>? = nil
    
    @State private var date: Date = .now
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Time for \(group?.name ?? "Tee Group")")
                .fontStyle(.poppins, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
                .padding(.top, 32)
            
            Spacer(minLength: 0)
            
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            
            Spacer(minLength: 0)
            
            //Line()
            
            HStack(spacing: 16) {
                PrimaryButton(
                    appearance: .fill,
                    title: "Clear",
                    labelColor: .white,
                    buttonColor: .systemError,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { onDone?(nil) }
                )
                
                PrimaryButton(
                    appearance: .fill,
                    title: "Set tee time",
                    labelColor: palette.backgroundColor,
                    buttonColor: palette.foregroundColor,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { onDone?(date.toTimeFormat) }
                )
            }
            .padding(.horizontal, 16)
        }
        .background(palette.backgroundColor)
        .onAppear() {
            if let d = group?.teeTime?.fromTimeFormat {
                date = d
            }
        }
    }
}
