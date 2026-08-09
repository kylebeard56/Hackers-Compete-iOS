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
    let onRevertOverride: Callback?

    /// League-sourced values retain their lock provenance even when a commissioner overrides the round strokes.
    var isSeriesHandicapLocked: Bool = false
    var canOverrideSeriesHandicap: Bool = false
    /// Baseline from series at participant creation; when set and value differs, commissioner sees orange text.
    var leagueHandicapBaseline: Int? = nil

    @FocusState.Binding var focusedField: String?

    @State private var isEditing = false
    @State private var text = ""
    @State private var hasTyped = false
    @State private var hasConfirmedOverrideEdit = false
    @State private var showOverrideAlert = false

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
        onRevertOverride: Callback? = nil,
        isSeriesHandicapLocked: Bool = false,
        canOverrideSeriesHandicap: Bool = false,
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
        self.onRevertOverride = onRevertOverride
        self.isSeriesHandicapLocked = isSeriesHandicapLocked
        self.canOverrideSeriesHandicap = canOverrideSeriesHandicap
        self.leagueHandicapBaseline = leagueHandicapBaseline

        _debouncer = StateObject(wrappedValue: Debounce(value: entryValue ?? Double(initialValue), milliseconds: 400))
        _text = State(initialValue: "")
    }

    private var commissionerModifiedOrange: Bool {
        guard let baseline = leagueHandicapBaseline else { return false }
        return initialValue != baseline
    }

    private var commissionerValueColor: Color {
        commissionerModifiedOrange ? Color.orange : palette.foregroundColor
    }

    private var displayText: String {
        guard entryFormat == .courseHandicap, let entryValue else { return "\(initialValue)" }
        return entryValue.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        HStack(spacing: 4) {
            fieldContent

            if isSeriesHandicapLocked && canOverrideSeriesHandicap {
                if commissionerModifiedOrange {
                    Button("Use computed value", systemImage: "arrow.uturn.backward", action: revertOverride)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.orange)
                        .frame(width: 44, height: 44)
                        .accessibilityHint("Restores the league-computed handicap for this round")
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
        .alert("Override handicap?", isPresented: $showOverrideAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Override handicap", action: confirmOverride)
        } message: {
            Text("This changes the strokes used for this round only. The league-computed value remains available to restore.")
        }
        .onChange(of: focusedField) {
            if focusedField == id {
                guard !isSeriesHandicapLocked || canOverrideSeriesHandicap else { return }
                if isSeriesHandicapLocked && !commissionerModifiedOrange && !hasConfirmedOverrideEdit {
                    focusedField = nil
                    showOverrideAlert = true
                    return
                }
                isEditing = true
                hasTyped = false
                text = ""
            } else {
                if hasTyped {
                    onDebouncedEdit?(debouncer.value)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation {
                        isEditing = false
                    }
                }
            }
        }
        .onChange(of: initialValue) {
            debouncer.value = entryValue ?? Double(initialValue)
        }
        .padding(.vertical, isSeriesHandicapLocked ? 0 : 6)
        .padding(.horizontal, isSeriesHandicapLocked ? 0 : 8)
        .border(isEditing && (!isSeriesHandicapLocked || canOverrideSeriesHandicap) ? palette.foregroundColor : Color.clear, width: 4, cornerRadius: 12)
        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
        .whiteGlassCardShadow(color: palette.shadowColor)
    }

    @ViewBuilder
    private var fieldContent: some View {
        if isEditing {
            HStack(spacing: 4) {
                TextField(displayText, text: binding)
                    .keyboardType(entryFormat == .courseHandicap ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: id)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(commissionerValueColor)
                    .frame(width: 44)

                if isSeriesHandicapLocked {
                    lockImage
                }
            }
            .frame(minWidth: 64, minHeight: 44)
        } else if isSeriesHandicapLocked && !canOverrideSeriesHandicap {
            lockedValueLabel
                .frame(minWidth: 64, minHeight: 44)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Handicap \(displayText), league locked")
        } else {
            Button(action: requestEdit) {
                if isSeriesHandicapLocked {
                    lockedValueLabel
                } else {
                    Text(displayText)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(commissionerValueColor)
                        .frame(width: 48)
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 64, minHeight: 44)
            .accessibilityLabel(isSeriesHandicapLocked ? "Handicap \(displayText), league locked" : "Handicap \(displayText)")
            .accessibilityHint(isSeriesHandicapLocked ? "Double tap to override the handicap for this round" : "Double tap to edit")
        }
    }

    private var lockedValueLabel: some View {
        HStack(spacing: 4) {
            Text(displayText)
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(commissionerModifiedOrange ? Color.orange : Color.neutral3)
                .frame(minWidth: 28)
            lockImage
        }
    }

    private var lockImage: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(commissionerModifiedOrange ? Color.orange : Color.neutral3)
    }

    private func requestEdit() {
        if isSeriesHandicapLocked && !commissionerModifiedOrange && !hasConfirmedOverrideEdit {
            showOverrideAlert = true
        } else {
            beginEditing()
        }
    }

    private func confirmOverride() {
        hasConfirmedOverrideEdit = true
        beginEditing()
    }

    private func beginEditing() {
        isEditing = true
        hasTyped = false
        text = ""
        focusedField = id
    }

    private func revertOverride() {
        focusedField = nil
        isEditing = false
        hasTyped = false
        hasConfirmedOverrideEdit = false
        onRevertOverride?()
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
