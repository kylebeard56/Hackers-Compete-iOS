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
    let isUnresolved: Bool

    /// League-sourced values retain their lock provenance even when a commissioner overrides the round strokes.
    var isSeriesHandicapLocked: Bool = false
    var canOverrideSeriesHandicap: Bool = false
    /// Baseline from series at participant creation; when set and value differs, commissioner sees orange text.
    var leagueHandicapBaseline: Int? = nil

    @FocusState.Binding var focusedField: String?

    @State private var isEditing = false
    @State private var text = ""
    @State private var pendingEdit: Double?
    @State private var pendingEditFormat: HandicapEntryFormat?
    @State private var hasPendingSubmission = false
    @State private var hasConfirmedOverrideEdit = false
    @State private var showOverrideAlert = false

    @StateObject private var debouncer: Debounce<Double>

    init(
        id: String,
        initialValue: Int,
        entryValue: Double? = nil,
        entryFormat: HandicapEntryFormat = .strokes,
        isUnresolved: Bool = false,
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
        self.isUnresolved = isUnresolved
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
        if let pendingEdit, pendingEditFormat == entryFormat {
            return entryFormat == .courseHandicap
                ? pendingEdit.formatted(.number.precision(.fractionLength(1))) : String(Int(pendingEdit))
        }
        guard entryFormat == .courseHandicap else { return isUnresolved ? "—" : "\(initialValue)" }
        guard let entryValue else { return "—" }
        return entryValue.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 2) {
                if !isSeriesHandicapLocked {
                    Text(entryFormat == .courseHandicap ? "Index" : "Strokes")
                        .fontStyle(kFontName, size: 10, weight: .medium)
                        .foregroundStyle(Color.neutral)
                }
                fieldContent
            }

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
                text = ""
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation {
                        isEditing = false
                    }
                }
            }
        }
        .onReceive(debouncer.$debouncedValue) { value in
            // Preserve the roster's autosave behavior as an edit event. Releasing
            // focus (Done, outside tap, or another field) never submits an edit.
            guard hasPendingSubmission, let pendingEdit, pendingEditFormat == entryFormat,
                  pendingEdit == value else { return }
            hasPendingSubmission = false
            onDebouncedEdit?(pendingEdit)
        }
        .onChange(of: entryFormat) {
            hasPendingSubmission = false
            pendingEdit = nil
            pendingEditFormat = nil
            text = ""
            debouncer.value = entryValue ?? Double(initialValue)
        }
        .onChange(of: entryValue) { reconcileDisplayedValue() }
        .onChange(of: initialValue) { reconcileDisplayedValue() }
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
                    .keyboardType(entryFormat == .courseHandicap ? .numbersAndPunctuation : .numberPad)
                    .accessibilityLabel(entryFormat.displayName)
                    .accessibilityIdentifier("\(id)-handicapInput")
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
        text = ""
        focusedField = id
    }

    private func reconcileDisplayedValue() {
        let value = entryValue ?? Double(initialValue)
        if pendingEdit == value { pendingEdit = nil }
        if !isEditing, pendingEdit == nil { debouncer.value = value }
    }

    private func revertOverride() {
        hasPendingSubmission = false
        pendingEdit = nil
        focusedField = nil
        isEditing = false
        hasConfirmedOverrideEdit = false
        onRevertOverride?()
    }

    private var binding: Binding<String> {
        Binding(
            get: { text },
            set: { newText in
                let filtered: String
                if entryFormat == .courseHandicap {
                    filtered = HandicapIndexEntry.filtered(newText)
                } else {
                    guard newText.allSatisfy({ $0.isASCII && $0.isNumber }) else { return }
                    filtered = String(newText.prefix(6))
                }
                // UIKit may repeat the current binding value when editing ends.
                guard filtered != text else { return }
                text = filtered

                guard let value = Double(filtered), value.isFinite else {
                    hasPendingSubmission = false
                    pendingEdit = nil
                    return
                }
                let accepted = entryFormat == .courseHandicap
                    ? value : Double(min(max(Int(value), 0), maximumValue))
                pendingEditFormat = entryFormat
                pendingEdit = accepted
                hasPendingSubmission = true
                debouncer.value = accepted
            }
        )
    }
}
