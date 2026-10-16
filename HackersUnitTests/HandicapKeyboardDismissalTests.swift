import Combine
import SwiftUI
import UIKit
import XCTest
@testable import Hackers

/// Exercises the real SwiftUI editors, UIKit text input, and accessible Done
/// activation without a Firebase connection or a separate app test route.
@MainActor
final class HandicapKeyboardDismissalTests: XCTestCase {
    func testHandicapEntryIndexDoneKeepsDraftWithoutSavingOrDismissing() async throws {
        try await checkHandicapEntry(.courseHandicap, text: "22.6")
    }

    func testHandicapEntryStrokesDoneKeepsDraftWithoutSavingOrDismissing() async throws {
        try await checkHandicapEntry(.strokes, text: "14")
    }

    func testManagePlayerIndexDoneKeepsDraftWithoutUpdatingOrNavigating() async throws {
        try await checkManagePlayer(.courseHandicap, text: "22.6")
    }

    func testManagePlayerStrokesDoneKeepsDraftWithoutUpdatingOrNavigating() async throws {
        try await checkManagePlayer(.strokes, text: "14")
    }

    func testRosterIndexDoneAddsNoSaveAndKeepsAutosavedValue() async throws {
        try await checkRoster(.courseHandicap, text: "22.6", dismissImmediately: false)
    }

    func testRosterStrokesDoneAddsNoSaveAndKeepsAutosavedValue() async throws {
        try await checkRoster(.strokes, text: "14", dismissImmediately: false)
    }

    func testRosterFastIndexDismissPreservesPendingInput() async throws {
        try await checkRoster(.courseHandicap, text: "22.6", dismissImmediately: true)
    }

    func testRosterFastStrokesDismissPreservesPendingInput() async throws {
        try await checkRoster(.strokes, text: "14", dismissImmediately: true)
    }

    func testRosterEmptyDismissDoesNotCreateAZeroOrSave() async throws {
        let audit = RosterAudit(value: 8)
        let screen = try HostedScreen(RosterEditor(format: .strokes, audit: audit))
        defer { screen.close() }
        try await pause()
        XCTAssertTrue(try screen.button("Handicap 8").accessibilityActivate())
        try await Task.sleep(for: .milliseconds(200))
        let field = try screen.field("roster-player-handicapInput")
        XCTAssertTrue(field.isFirstResponder)
        let done = try screen.button("Done")
        XCTAssertTrue(done.accessibilityActivate())
        try await pause()
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertTrue(audit.edits.isEmpty)
        XCTAssertEqual(audit.value, 8)
    }

    func testRosterExplicitZeroResolvesPendingStrokesWithoutSavingOnDone() async throws {
        let audit = RosterAudit(value: 0)
        audit.isUnresolved = true
        let screen = try HostedScreen(RosterEditor(format: .strokes, audit: audit))
        defer { screen.close() }
        try await pause()
        XCTAssertTrue(try screen.button("Handicap —").accessibilityActivate())
        try await Task.sleep(for: .milliseconds(200))
        let field = try screen.field("roster-player-handicapInput")
        try await enter("0", into: field, format: .strokes)
        XCTAssertEqual(audit.edits, [0], "Explicit zero must resolve an initially pending value")
        XCTAssertFalse(audit.isUnresolved)
        XCTAssertTrue(try dismissControl(in: screen).accessibilityActivate())
        try await pause()
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertEqual(audit.edits, [0], "Done must not submit another edit")
        XCTAssertEqual(audit.value, 0)
        XCTAssertNotNil(try screen.button("Handicap 0"))
    }

    func testPendingRosterIndexDoesNotAutosaveAsStrokesAfterModeChange() async throws {
        let audit = RosterAudit(value: 8)
        let screen = try HostedScreen(RosterEditor(format: .courseHandicap, audit: audit))
        defer { screen.close() }
        try await pause()
        XCTAssertTrue(try screen.button("Handicap 8.0").accessibilityActivate())
        try await Task.sleep(for: .milliseconds(200))
        let field = try screen.field("roster-player-handicapInput")
        try await enter("22.6", into: field, format: .courseHandicap, settle: false)
        audit.format = .strokes
        try await pause()
        XCTAssertTrue(audit.edits.isEmpty, "A pending Index edit must never be submitted as strokes")
        XCTAssertEqual(audit.value, 8)
    }

    private func checkHandicapEntry(_ format: HandicapEntryFormat, text: String) async throws {
        var saved: [RoundParticipant] = []
        var disappeared = false
        let player = participant()
        let screen = try HostedScreen(
            HandicapEntryView(participant: .constant(player), entryFormat: format,
                courseSegment: course(), onComplete: { saved.append($0) })
                .onDisappear { disappeared = true }
        )
        defer { screen.close() }
        try await pause()
        let field = try screen.field("handicapEntryInput")
        try await enter(text, into: field, format: format)
        let events = KeyboardEvents()
        defer { events.stop() }
        try await dismissKeyboard(in: screen, field: field, events: events, name: "HandicapEntry-\(format.rawValue)")
        XCTAssertEqual(field.text, text)
        XCTAssertTrue(saved.isEmpty, "Done must not call the separate Save action")
        XCTAssertFalse(disappeared)
        XCTAssertNotNil(field.window, "The editor stays on screen")
        // A later explicit Save still receives the preserved draft, including decimals.
        XCTAssertTrue(try screen.button("Save handicap entry").accessibilityActivate())
        try await pause()
        XCTAssertEqual(saved.count, 1)
        if format == .courseHandicap {
            XCTAssertEqual(saved.first?.handicapIndex, Double(text))
        } else {
            XCTAssertEqual(saved.first?.handicapResolution?.effectiveStrokes, Int(text))
        }
    }

    private func checkManagePlayer(_ format: HandicapEntryFormat, text: String) async throws {
        let player = participant()
        let session = RoundSession()
        session.snapshot = RoundSnapshot(round: Round(id: "keyboard-test", status: .lobby,
            configuration: RoundConfiguration(courses: [course()], handicapIndexBasis: .eighteenHole,
                handicapsEnabled: true, handicapEntryFormat: format)), participants: [player])
        let original = session.snapshot
        var disappeared = false
        let screen = try HostedScreen(ManagePlayerView(roundSession: session, participant: player)
            .onDisappear { disappeared = true })
        defer { screen.close() }
        try await pause()
        let field = try screen.field("managePlayerHandicapInput")
        let events = KeyboardEvents()
        defer { events.stop() }
        try await enter(text, into: field, format: format)
        try await dismissKeyboard(in: screen, field: field, events: events, name: "ManagePlayer-\(format.rawValue)")
        XCTAssertEqual(field.text, text)
        XCTAssertFalse(disappeared, "Done must not invoke Update player or dismiss this sheet")
        XCTAssertEqual(session.snapshot.round, original.round)
        XCTAssertEqual(session.snapshot.participants, original.participants)
        XCTAssertNotNil(field.window)
        XCTAssertNotNil(try screen.button("Update player"))
    }

    private func checkRoster(_ format: HandicapEntryFormat, text: String, dismissImmediately: Bool) async throws {
        let audit = RosterAudit(value: 8)
        let screen = try HostedScreen(RosterEditor(format: format, audit: audit))
        defer { screen.close() }
        try await pause()
        XCTAssertTrue(try screen.button(format == .courseHandicap ? "Handicap 8.0" : "Handicap 8").accessibilityActivate())
        try await Task.sleep(for: .milliseconds(200))
        let field = try screen.field("roster-player-handicapInput")
        let events = KeyboardEvents()
        defer { events.stop() }
        try await enter(text, into: field, format: format, settle: !dismissImmediately)
        let done = try dismissControl(in: screen)
        attach(screen, name: "Roster-\(format.rawValue)-keyboard-active")
        if !dismissImmediately {
            XCTAssertEqual(audit.edits, [Double(text)!], "The input edit autosaves before Done")
        } else {
            XCTAssertTrue(audit.edits.isEmpty)
        }
        let countBeforeDone = audit.edits.count
        XCTAssertTrue(done.accessibilityActivate())
        XCTAssertEqual(audit.edits.count, countBeforeDone, "Done itself must not submit an edit")
        try await pause()
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertGreaterThan(events.hideCount, 0, "Done must dismiss the system keyboard")
        XCTAssertEqual(audit.edits, [Double(text)!], "Only the intended input autosave may occur")
        XCTAssertEqual(audit.value, Double(text))
        XCTAssertFalse(audit.disappeared)
        XCTAssertNotNil(try screen.button("Handicap \(text)"), "The roster still shows the entered value")
        attach(screen, name: "Roster-\(format.rawValue)-\(dismissImmediately ? "fast" : "settled")-dismissed")
    }

    private func enter(_ text: String, into field: UITextField, format: HandicapEntryFormat, settle: Bool = true) async throws {
        field.becomeFirstResponder()
        // Let FocusState establish editing before changing the real UIKit input.
        try await Task.sleep(for: .milliseconds(100))
        field.text = ""
        field.sendActions(for: .editingChanged)
        field.insertText(text)
        XCTAssertEqual(field.keyboardType, format == .courseHandicap ? .numbersAndPunctuation : .numberPad)
        if settle { try await pause() }
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, text)
    }

    private func dismissKeyboard(in screen: HostedScreen, field: UITextField, events: KeyboardEvents, name: String) async throws {
        let done = try dismissControl(in: screen)
        attach(screen, name: name + "-keyboard-active")
        XCTAssertTrue(done.accessibilityActivate())
        try await pause()
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertGreaterThan(events.hideCount, 0, "The system keyboard receives a hide event")
        attach(screen, name: name + "-keyboard-dismissed")
    }

    private func dismissControl(in screen: HostedScreen) throws -> NSObject {
        let done = try screen.button("Done")
        XCTAssertEqual(done.accessibilityHint, "Dismiss keyboard and keep the entered value")
        XCTAssertGreaterThanOrEqual(done.accessibilityFrame.height, 44)
        XCTAssertTrue(screen.window.frame.contains(done.accessibilityFrame), "Done must be visible within the mobile screen")
        return done
    }

    private func pause() async throws { try await Task.sleep(for: .milliseconds(600)) }

    private func attach(_ screen: HostedScreen, name: String) {
        let image = UIGraphicsImageRenderer(bounds: screen.window.bounds).image { _ in
            screen.window.drawHierarchy(in: screen.window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func participant() -> RoundParticipant {
        RoundParticipant(id: "keyboard-player", name: Name("Keyboard", "Player"), teeBoxID: "white",
            originalHandicap: 8, adjustedHandicap: 8, handicapIndex: 8.5)
    }

    private func course() -> CourseSegment {
        let tee = Tee(id: "white", name: "White", gender: "male", totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: nil, slopeFront: nil, ratingBack: nil, slopeBack: nil)
        return CourseSegment(courseInfo: .init(id: "keyboard-course", name: "Keyboard Course", totalHoles: 18, tees: [tee]),
            holeRange: HoleSegment.full18.holeRange, defaultTee: tee.id)
    }
}

@MainActor
private final class HostedScreen {
    let window: UIWindow
    private let previous: UIWindow?
    private let host: UIHostingController<AnyView>

    init<V: View>(_ view: V) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previous = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        host = UIHostingController(rootView: AnyView(view))
        window.rootViewController = host
        window.makeKeyAndVisible()
    }

    func close() {
        window.endEditing(true)
        window.isHidden = true
        previous?.makeKeyAndVisible()
    }

    func field(_ identifier: String) throws -> UITextField {
        func fields(in view: UIView) -> [UITextField] {
            (view as? UITextField).map { [$0] } ?? view.subviews.flatMap { fields(in: $0) }
        }
        // SwiftUI places identifiers on its accessibility wrapper rather than
        // the backing UITextField. Each editor has one numeric input.
        let inputs = fields(in: host.view).filter {
            $0.keyboardType == .numberPad || $0.keyboardType == .numbersAndPunctuation
        }
        XCTAssertEqual(inputs.count, 1, "Expected one numeric input for \(identifier)")
        return try XCTUnwrap(inputs.first, "Missing input \(identifier)")
    }

    func button(_ label: String) throws -> NSObject {
        var visited: Set<ObjectIdentifier> = []
        func nodes(in object: NSObject, depth: Int = 0) -> [NSObject] {
            guard depth < 20, visited.insert(ObjectIdentifier(object)).inserted else { return [] }
            var result = [object]
            if let view = object as? UIView {
                for child in view.subviews { result += nodes(in: child, depth: depth + 1) }
            }
            let count = object.accessibilityElementCount()
            if count > 0, count < 500 {
                for index in 0..<count {
                    if let child = object.accessibilityElement(at: index) as? NSObject {
                        result += nodes(in: child, depth: depth + 1)
                    }
                }
            }
            return result
        }
        return try XCTUnwrap(nodes(in: window).first {
            $0.accessibilityLabel == label && $0.accessibilityTraits.contains(.button)
        }, "Missing accessible button \(label)")
    }
}

/// The roster's real input and dismiss control with in-memory persistence so
/// assertions detect saves, duplicates, focus loss, and navigation independently.
@MainActor
private final class RosterAudit: ObservableObject {
    @Published var value: Double
    @Published var format: HandicapEntryFormat?
    @Published var isUnresolved = false
    var edits: [Double] = []
    var disappeared = false
    init(value: Double) { self.value = value }
}

private struct RosterEditor: View {
    let format: HandicapEntryFormat
    @ObservedObject var audit: RosterAudit
    @FocusState private var focus: String?
    private var entryFormat: HandicapEntryFormat { audit.format ?? format }
    private var palette: DesignPalette { .init(theme: .primary, scheme: .light) }

    var body: some View {
        VStack {
            HandicapTextField(id: "roster-player", initialValue: Int(audit.value),
                entryValue: entryFormat == .courseHandicap ? audit.value : nil, entryFormat: entryFormat,
                isUnresolved: audit.isUnresolved,
                focusedField: $focus, palette: palette,
                onDebouncedEdit: { value in
                    audit.edits.append(value)
                    audit.value = value
                    audit.isUnresolved = false
                })
            Spacer()
            if focus != nil { HandicapKeyboardDismissBar { focus = nil } }
        }
        .onDisappear { audit.disappeared = true }
    }
}

private final class KeyboardEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var observer: NSObjectProtocol?
    var hideCount: Int { lock.lock(); defer { lock.unlock() }; return count }
    init() {
        observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidHideNotification,
            object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.lock.lock(); self.count += 1; self.lock.unlock()
            }
    }
    func stop() { if let observer { NotificationCenter.default.removeObserver(observer) } }
}
