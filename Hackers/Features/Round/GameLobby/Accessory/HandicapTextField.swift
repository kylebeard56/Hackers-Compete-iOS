//
//  HandicapTextField.swift
//  Hackers
//
//  Created by Kyle Beard on 11/20/25.
//

import SwiftUI

struct HandicapTextField: View {
    let id: String
    let palette: DesignPalette
    let initialValue: Int
    let onDebouncedEdit: CallbackValue<Int>?

    @FocusState.Binding var focusedField: String?

    @State private var isEditing = false
    @State private var text = ""
    @State private var hasTyped = false
    @State private var hasEmittedInitial = false

    @StateObject private var debouncer: Debounce<Int>

    init(
        id: String,
        initialValue: Int,
        focusedField: FocusState<String?>.Binding,
        palette: DesignPalette,
        onDebouncedEdit: CallbackValue<Int>? = nil
    ) {
        self.id = id
        self._focusedField = focusedField
        self.initialValue = initialValue
        self.palette = palette
        self.onDebouncedEdit = onDebouncedEdit

        // IMPORTANT: initialize debouncer with the real value, not 0
        _debouncer = StateObject(wrappedValue: Debounce(value: initialValue, milliseconds: 400))
        _text = State(initialValue: "")   // will show "" on first edit
    }

    var body: some View {
        Group {
            if isEditing {
                TextField("\(initialValue)", text: binding)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: id)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 48)
//                    .onChange(of: focusedField) {
//                        // When losing focus:
//                        if focusedField != id {
//                            // If user never typed, revert
//                            if !hasTyped {
//                                text = ""
//                            }
//                            isEditing = false
//                        }
//                    }
                    .onChange(of: focusedField) {
                        if focusedField != id {
                            if hasTyped {
                                onDebouncedEdit?(debouncer.value)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                                isEditing = false
                            })
                        }
                    }

            } else {
                // Read-only mode
                Text("\(initialValue)")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 48)
                    .onTapGesture {
                        isEditing = true
                        focusedField = id
                        hasTyped = false
                        text = "" // blank start for new input
                    }
            }
        }
        .padding(.vertical, 6)
        .background(palette.backgroundColor)
        .cornerRadius(8)
//        .onReceive(debouncer.$debouncedValue) { value in
//            // Skip the initial emission from Combine
//            guard hasEmittedInitial else {
//                hasEmittedInitial = true
//                return
//            }
//            onDebouncedEdit?(value)
//        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { text },
            set: { newText in
                hasTyped = true
                
                let filtered = newText.filter { $0.isNumber }
                text = filtered
                
                let intValue = Int(filtered) ?? initialValue
                debouncer.value = min(max(intValue, 0), 36)
            }
        )
    }
}

