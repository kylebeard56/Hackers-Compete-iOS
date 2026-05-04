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
    let entryValue: Double?
    let entryFormat: HandicapEntryFormat
    let maximumValue: Int
    let onDebouncedEdit: CallbackValue<Double>?

    /// When true (series league handicap context, non-commissioner), show locked grey value + lock icon.
    var isSeriesHandicapLocked: Bool = false
    /// Baseline from series at participant creation; when set and value differs, commissioner sees orange text.
    var leagueHandicapBaseline: Int? = nil

    @FocusState.Binding var focusedField: String?

    @State private var isEditing = false
    @State private var text = ""
    @State private var hasTyped = false

    @StateObject private var debouncer: Debounce<Double>

    init(
        id: String,
        initialValue: Int,
        entryValue: Double? = nil,
        entryFormat: HandicapEntryFormat = .strokes,
        focusedField: FocusState<String?>.Binding,
        palette: DesignPalette,
        maximumValue: Int? = nil,
        onDebouncedEdit: CallbackValue<Double>? = nil,
        isSeriesHandicapLocked: Bool = false,
        leagueHandicapBaseline: Int? = nil
    ) {
        self.id = id
        self._focusedField = focusedField
        self.initialValue = initialValue
        self.entryValue = entryValue
        self.entryFormat = entryFormat
        self.palette = palette
        self.maximumValue = maximumValue ?? 36
        self.onDebouncedEdit = onDebouncedEdit
        self.isSeriesHandicapLocked = isSeriesHandicapLocked
        self.leagueHandicapBaseline = leagueHandicapBaseline

        _debouncer = StateObject(wrappedValue: Debounce(value: entryValue ?? Double(initialValue), milliseconds: 400))
        _text = State(initialValue: "")
    }

    private var commissionerModifiedOrange: Bool {
        guard !isSeriesHandicapLocked, let baseline = leagueHandicapBaseline else { return false }
        return initialValue != baseline
    }

    private var commissionerValueColor: Color {
        commissionerModifiedOrange ? Color.orange : palette.foregroundColor
    }

    private var displayText: String {
        guard entryFormat == .courseHandicap, let entryValue else { return "\(initialValue)" }
        return String(format: "%.1f", entryValue)
    }

    var body: some View {
        Group {
            if isSeriesHandicapLocked {
                HStack(spacing: 4) {
                    Text(displayText)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.neutral3)
                        .frame(minWidth: 28)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.neutral3)
                }
                .frame(width: 64)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            } else if isEditing {
                TextField(displayText, text: binding)
                    .keyboardType(entryFormat == .courseHandicap ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: id)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(commissionerValueColor)
                    .frame(width: 48)

            } else {
                Text(displayText)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(commissionerValueColor)
                    .frame(width: 48)
                    .onTapGesture {
                        isEditing = true
                        focusedField = id
                        hasTyped = false
                        text = ""
                    }
            }
        }
        .onChange(of: focusedField) {
            if focusedField == id {
                guard !isSeriesHandicapLocked else { return }
                isEditing = true
                hasTyped = false
                text = ""
            } else {
                if hasTyped {
                    onDebouncedEdit?(debouncer.value)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    withAnimation {
                        isEditing = false
                    }
                })
            }
        }
        .onChange(of: initialValue) {
            debouncer.value = entryValue ?? Double(initialValue)
        }
        .padding(.vertical, isSeriesHandicapLocked ? 0 : 6)
        .padding(.horizontal, isSeriesHandicapLocked ? 0 : 8)
        .border(isEditing && !isSeriesHandicapLocked ? palette.foregroundColor : Color.clear, width: 4, cornerRadius: 12)
        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
        .whiteGlassCardShadow(color: palette.shadowColor)
    }

    private var binding: Binding<String> {
        Binding(
            get: { text },
            set: { newText in
                hasTyped = true

                let filtered: String
                if entryFormat == .courseHandicap {
                    var hasDecimal = false
                    filtered = newText.reduce(into: "") { result, character in
                        if character.isNumber {
                            result.append(character)
                        } else if character == ".", !hasDecimal {
                            hasDecimal = true
                            result.append(character)
                        }
                    }
                } else {
                    filtered = newText.filter { $0.isNumber }
                }
                text = filtered

                let value = Double(filtered) ?? entryValue ?? Double(initialValue)
                if entryFormat == .courseHandicap {
                    debouncer.value = max(value, 0)
                } else {
                    debouncer.value = Double(min(max(Int(value), 0), maximumValue))
                }
            }
        )
    }
}
