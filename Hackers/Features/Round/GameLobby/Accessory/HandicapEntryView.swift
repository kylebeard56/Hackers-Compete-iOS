import SwiftUI

/// Shared by round setup and participant editors; backed by the existing format model.
struct HandicapEntryModePicker: View {
    @Binding var selection: HandicapEntryFormat

    var body: some View {
        Picker("Handicap entry", selection: $selection) {
            Text("Handicap Index").tag(HandicapEntryFormat.courseHandicap)
            Text("Strokes Received").tag(HandicapEntryFormat.strokes)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("handicapEntryMode")
    }
}

/// Visible above the keyboard in sheets as well as navigation-hosted lobby content.
/// This action only releases focus; saving and navigation remain separate controls.
struct HandicapKeyboardDismissBar: View {
    @Environment(\.colorScheme) private var colorScheme
    var theme: PaletteTheme = .primary
    var onDismiss: Callback
    private var palette: DesignPalette { .init(theme: theme, scheme: colorScheme) }

    var body: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Label("Done", systemImage: "keyboard.chevron.compact.down")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.foregroundColor)
            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
            .accessibilityLabel("Done")
            .accessibilityHint("Dismiss keyboard and keep the entered value")
            .accessibilityIdentifier("dismissHandicapKeyboard")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(palette.backgroundColor)
    }
}

struct HandicapEntryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var participant: RoundParticipant
    var holes: Int = 18
    var maximumValue: Int = 36
    var entryFormat: HandicapEntryFormat = .strokes
    var courseSegment: CourseSegment? = nil
    var handicapStrokeBasis: SeriesHandicapStrokeBasis? = .eighteenHole
    var onFixCourseData: Callback? = nil
    var onComplete: CallbackValue<RoundParticipant>? = nil

    @FocusState private var focus: Bool
    @State private var draft = RoundHandicapEntryDraft()
    @State private var approveEstimate = false
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var indexBasis: SeriesHandicapStrokeBasis? {
        HandicapCalculator.entryIndexBasis(for: participant, configured: handicapStrokeBasis)
    }
    private var locked: Bool { participant.handicapSnapshot != nil || participant.leagueHandicapStrokesAtCreation != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Text(draft.format.displayName)
                        .fontStyle(kFontName, size: 24, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Spacer(minLength: 0)
                    NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
                    if draft.value != nil, !locked {
                        NavButton(icon: "f00c", color: palette.backgroundColor,
                                  background: palette.foregroundColor, onTap: finish)
                            .accessibilityLabel("Save handicap entry")
                    }
                }

                HandicapEntryModePicker(selection: $draft.format)
                    .disabled(locked)
                Text(draft.format == .courseHandicap
                     ? RoundHandicapEntryPresentation.indexLabel(previewParticipant, basis: indexBasis)
                     : "Strokes this round · \(holes) holes · max \(maximumValue)")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()

                TextField(draft.format == .courseHandicap ? "Index" : "Strokes", text: $draft.text)
                    .fontStyle(kFontName, size: 48, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .keyboardType(draft.format == .courseHandicap ? .numbersAndPunctuation : .numberPad)
                    .focused($focus)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(draft.format.displayName)
                    .accessibilityIdentifier("handicapEntryInput")
                    .disabled(locked)

                if draft.format == .courseHandicap {
                    CourseHandicapStatusView(calculation: calculation,
                        strokes: calculation.allowedStrokes(maximum: maximumValue, estimateApproved: estimateIsApproved),
                        estimateApproved: estimateIsApproved,
                        onUseEstimate: locked ? nil : { approveEstimate = true },
                        onFixCourseData: onFixCourseData,
                        onEnterStrokes: locked ? nil : { draft.format = .strokes })
                } else {
                    if let index = Double(draft.indexText) {
                        Text("Handicap Index: \(ManualPersonalHandicap.display(index)) · preserved")
                    }
                    if let value = draft.value {
                        Text("Strokes Received: \(min(Int(value), maximumValue))")
                    }
                    Text("Whole-number strokes for this round only. Saved personal and league Indexes are unchanged.")
                }
            }
            .padding(16)
        }
        .background(palette.backgroundColor)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focus { HandicapKeyboardDismissBar { focus = false } }
        }
        .onAppear { draft = RoundHandicapEntryDraft(participant: participant, defaultFormat: entryFormat) }
        .onChange(of: calculation) { approveEstimate = false }
        .task(delay: 0.2) { if !locked { focus = true } }
    }

    private var previewParticipant: RoundParticipant {
        var preview = participant
        preview.handicapIndex = Double(draft.indexText)
        return preview
    }

    private var calculation: CourseHandicapCalculation {
        HandicapCalculator.calculation(index: Double(draft.indexText), participant: participant,
            courseSegment: courseSegment, indexBasis: indexBasis)
    }

    private var estimateIsApproved: Bool {
        approveEstimate || (participant.handicapResolution?.calculation == calculation
            && participant.handicapResolution?.estimateApprovedAt != nil)
    }

    private func finish() {
        guard !locked, draft.value != nil else { return }
        onComplete?(draft.applying(to: participant, courseSegment: courseSegment,
            indexBasis: indexBasis, maximum: maximumValue, approveEstimate: estimateIsApproved))
    }
}

#Preview {
    Color.neutral.sheet(isPresented: .true) {
        HandicapEntryView(participant: .constant(.init()))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}

/// Shared status within existing setup editors; never used in live score entry.
struct CourseHandicapStatusView: View {
    let calculation: CourseHandicapCalculation
    let strokes: Int?
    var estimateApproved = false
    var onUseEstimate: (() -> Void)? = nil
    var onFixCourseData: (() -> Void)? = nil
    var onEnterStrokes: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let index = calculation.handicapIndex {
                Text("Handicap Index: \(String(format: "%.1f", index))")
            }
            switch calculation.status {
            case .exact:
                Text("Course HCP: \(calculation.courseHandicap ?? 0) · Exact")
            case .estimated:
                Text("Estimated Course HCP: \(calculation.courseHandicap ?? 0)")
                Text("Estimated from 18-hole tee data. Not an official nine-hole Course Handicap.")
                if !estimateApproved, let onUseEstimate {
                    Button("Use Estimate", action: onUseEstimate)
                }
            case .unavailable:
                Text("Course HCP: Unavailable")
                Text(calculation.handicapIndex == nil
                    ? "Enter a Handicap Index, or enter strokes for this round."
                    : "Course HCP needs: " + calculation.missingFields.joined(separator: ", ") + ". Your Index is preserved.")
                if let onFixCourseData { Button("Fix Course Data", action: onFixCourseData) }
                if let onEnterStrokes { Button("Enter strokes for this round", action: onEnterStrokes) }
            }
            if let strokes { Text("Strokes Received: \(strokes)") }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
