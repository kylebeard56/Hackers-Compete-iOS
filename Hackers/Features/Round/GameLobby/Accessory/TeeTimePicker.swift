//
//  TeeTimePicker.swift
//  Hackers
//
//  Created by Kyle Beard on 11/26/25.
//

import SwiftUI

struct TeeTimePicker: View {
    @Binding var group: TeeTimeGroup?
    var onDone: CallbackValue<String?>? = nil

    private var title: String {
        "Time for \(group?.name ?? "Tee Group")"
    }

    private var initialDate: Date {
        group?.teeTime?.fromAnyTeeTimeFormat ?? .now
    }

    var body: some View {
        WheelTimePickerSheet(
            title: title,
            primaryButtonTitle: "Set tee time",
            initialDate: initialDate,
            onComplete: { date in
                onDone?(date.map { $0.toTimeFormat })
            }
        )
    }
}
