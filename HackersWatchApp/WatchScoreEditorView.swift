import SwiftUI
import WatchKit

struct WatchScoreEditorDestination: Hashable {
    let subjectID: String
    let holeNumber: Int
}

struct WatchScoreEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WatchRoundStore
    @State private var subjectID: String
    let holeNumber: Int
    @State private var draftPosition: Double
    @FocusState private var crownFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var scoreFontSize: CGFloat = 48

    init(store: WatchRoundStore, destination: WatchScoreEditorDestination) {
        self.store = store
        subjectID = destination.subjectID
        holeNumber = destination.holeNumber

        let snapshot = store.snapshot
        let subject = snapshot?.subjects.first { $0.id == destination.subjectID }
        let hole = snapshot?.holes.first { $0.number == destination.holeNumber }
        let par = hole?.par ?? 4
        let fallback = snapshot?.inputMode == .relativeToPar ? 0 : par
        let value = subject.flatMap {
            store.value(for: $0, holeNumber: destination.holeNumber)
        } ?? fallback
        _draftPosition = State(initialValue: Double(value))
    }

    private var snapshot: WatchRoundSnapshot? { store.snapshot }
    private var subject: WatchRoundSnapshot.Subject? {
        snapshot?.subjects.first { $0.id == subjectID }
    }
    private var hole: WatchRoundSnapshot.Hole? {
        snapshot?.holes.first { $0.number == holeNumber }
    }
    private var par: Int { hole?.par ?? 4 }
    private var existingValue: Int? {
        subject.flatMap { store.value(for: $0, holeNumber: holeNumber) }
    }
    private var valueRange: ClosedRange<Int> {
        let fallback: ClosedRange<Int> = snapshot?.inputMode == .relativeToPar ? -4...16 : 1...20
        let minimum = min(hole?.inputMinimum ?? fallback.lowerBound, existingValue ?? Int.max)
        let maximum = max(hole?.inputMaximum ?? fallback.upperBound, existingValue ?? Int.min)
        return minimum...maximum
    }
    private var clearPosition: Int { valueRange.lowerBound - 1 }
    private var selectedInputValue: Int? {
        let position = Int(draftPosition.rounded())
        return position == clearPosition ? nil : min(max(position, valueRange.lowerBound), valueRange.upperBound)
    }
    private var selectedGrossValue: Int? {
        guard let selectedInputValue else { return nil }
        guard snapshot?.inputMode == .relativeToPar else { return selectedInputValue }
        return max(1, par + selectedInputValue)
    }
    private var strokesReceived: Int {
        subject?.unit(for: holeNumber)?.strokesReceived ?? 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button("Back", systemImage: "chevron.left") {
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .background(.white.opacity(0.12), in: Circle())

                WatchAdaptiveNameView(
                    title: subject?.title ?? "Score",
                    compactTitle: subject?.compactTitle
                )
                .font(.headline)

                Color.clear
                    .frame(width: 36, height: 36)
            }

            Text("Hole \(holeNumber) · Par \(par)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                scoreAdjustmentButton(
                    title: "Decrease score",
                    systemImage: "minus",
                    adjustment: -1,
                    isEnabled: Int(draftPosition.rounded()) > clearPosition
                )

                VStack(spacing: 0) {
                    Text("Gross Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(selectedGrossValue.map(String.init) ?? "—")
                        .font(.system(size: scoreFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedInputValue == nil ? Color.secondary : Color.green)
                        .contentTransition(.numericText())

                    Text(scoreDescription)
                        .font(.headline)
                        .lineLimit(1)

                    if let netLabel {
                        Text(netLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .focusable()
                .focused($crownFocused)
                .digitalCrownRotation(
                    $draftPosition,
                    from: Double(clearPosition),
                    through: Double(valueRange.upperBound),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Gross score")
                .accessibilityValue(selectedGrossValue.map(String.init) ?? "No score")

                scoreAdjustmentButton(
                    title: "Increase score",
                    systemImage: "plus",
                    adjustment: 1,
                    isEnabled: Int(draftPosition.rounded()) < valueRange.upperBound
                )
            }

            Button(action: commitAndAdvance) {
                Text(saveButtonTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        selectedInputValue == nil ? Color.red : Color.green,
                        in: Capsule()
                    )
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selectedInputValue == nil && existingValue == nil)
            .accessibilityHint(saveAccessibilityHint)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            crownFocused = true
        }
    }

    private var scoreDescription: String {
        guard let gross = selectedGrossValue else { return "Clear score" }
        switch gross - par {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case 3: return "Triple Bogey"
        default: return "+\(gross - par)"
        }
    }

    private var netLabel: String? {
        guard strokesReceived > 0, let gross = selectedGrossValue else { return nil }
        return "Net \(max(0, gross - strokesReceived))"
    }

    private var saveButtonTitle: String {
        guard selectedInputValue != nil else { return "Clear Score" }
        guard let subject else { return existingValue == nil ? "Save Score" : "Update Score" }
        if nextUnscoredSubject(after: subject) != nil {
            return existingValue == nil ? "Save & Next" : "Update & Next"
        }
        guard let snapshot,
              snapshot.holes.last?.number != holeNumber else {
            return existingValue == nil ? "Save Score" : "Update Score"
        }
        return existingValue == nil ? "Save & Next Hole" : "Update & Next Hole"
    }

    private var saveAccessibilityHint: String {
        guard let subject else { return "Saves this score" }
        if let next = nextUnscoredSubject(after: subject) {
            return "Saves this score and opens score entry for \(next.title)"
        }
        guard snapshot?.holes.last?.number != holeNumber else {
            return "Saves this score"
        }
        return "Saves this score and advances to the next hole"
    }

    private func scoreAdjustmentButton(
        title: String,
        systemImage: String,
        adjustment: Int,
        isEnabled: Bool
    ) -> some View {
        Button {
            draftPosition += Double(adjustment)
            WKInterfaceDevice.current().play(.click)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Color.secondary.opacity(0.3), in: Circle())
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func commitAndAdvance() {
        guard let subject, let snapshot else { return }

        guard let selectedInputValue else {
            store.clear(subject: subject, holeNumber: holeNumber)
            WKInterfaceDevice.current().play(.click)
            dismiss()
            return
        }

        store.save(value: selectedInputValue, subject: subject, holeNumber: holeNumber)
        WKInterfaceDevice.current().play(.click)

        guard let next = nextUnscoredSubject(after: subject) else {
            store.selectNextHole()
            dismiss()
            return
        }

        subjectID = next.id
        let fallback = snapshot.inputMode == .relativeToPar ? 0 : par
        draftPosition = Double(store.value(for: next, holeNumber: holeNumber) ?? fallback)
        crownFocused = true
    }

    private func nextUnscoredSubject(
        after subject: WatchRoundSnapshot.Subject
    ) -> WatchRoundSnapshot.Subject? {
        guard let snapshot,
              let currentIndex = snapshot.subjects.firstIndex(where: { $0.id == subject.id }) else {
            return nil
        }
        let nextIndex = snapshot.subjects.index(after: currentIndex)
        let later = Array(snapshot.subjects[nextIndex...])
        let earlier = Array(snapshot.subjects[..<currentIndex])
        return (later + earlier).first {
            store.value(for: $0, holeNumber: holeNumber) == nil
        }
    }
}

#if DEBUG
#Preview("Score Editor") {
    NavigationStack {
        WatchScoreEditorView(
            store: WatchRoundStore(
                snapshot: WatchPreviewFixtures.snapshot,
                defaults: UserDefaults(suiteName: "WatchEditorPreview")!,
                activateSession: false
            ),
            destination: .init(subjectID: "p1", holeNumber: 7)
        )
    }
}
#endif
