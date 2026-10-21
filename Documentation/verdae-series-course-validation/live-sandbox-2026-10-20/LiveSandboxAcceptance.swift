import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import XCTest
@testable import Hackers

/// Explicitly authorized live Sandbox acceptance. Never runs by default.
@MainActor
final class SeriesSandboxAcceptanceTests: XCTestCase {
    private let db = Firestore.firestore()
    private let runID = "pr16-" + UUID().uuidString.prefix(12)
    private var seriesID: String?
    private var ownerID = ""
    private var titles: [String] = []
    private var ownedRoundIDs = Set<String>()
    private var protected: [String: [String: Any]] = [:]
    private var evidence: [[String: Any]] = []
    private var deletedPaths: [String] = []
    private var temporaryPlayerID: String?
    private enum Failure: Error { case invalidScope, missingAuthentication, timedOut(String) }


    func testStableReadOnlyCompactScreens() async throws {
        guard FirebaseApp.app()?.options.projectID == "hackers-compete-sandbox",
              ProcessInfo.processInfo.environment["PR16_VALIDATION_NO_SESSION_RESTORE"] == "1" else { throw XCTSkip("Isolated read-only Sandbox visual check") }
        let course = try await db.collection("courses").document("2petFWO6L40zc95XvacraA8N8wKp").getDocument(source: .server).data(as: Course.self)
        let blue = try XCTUnwrap(course.tees.first { $0.name == "Blue" && $0.gender == "male" })
        let wasAnimating = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(wasAnimating) }
        for (label, segment, basis, missing) in [
            ("18-net", HoleSegment.full18, ScoreBasis.net, false),
            ("front-net", .front9, .net, false), ("back-net", .back9, .net, false),
            ("18-gross", .full18, .gross, false), ("one-missing", .full18, .net, true)
        ] {
            let courseSegment = CourseSegment(courseInfo: CourseInfo(course: course, for: segment), holeRange: segment.holeRange, defaultTee: blue.id)
            let defaultsName = "PR16.ReadOnlyVisual." + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
            defer { defaults.removePersistentDomain(forName: defaultsName) }
            let vm = SeriesViewModel(handicapDraftDefaults: defaults)
            vm.series = Series(id: "local-visual-series", name: "Local visual fixture", commissionerUserID: "local-owner")
            vm.currentUserID = "local-owner"
            vm.members = [
                .init(id: "registered", userID: "local-owner", playerID: "local-registered", name: Name("Registered Test"), parentID: vm.series.id),
                .init(id: "zero-index", playerID: "local-zero-index", name: Name("Offline Zero Index"), parentID: vm.series.id),
                .init(id: "manual", playerID: "local-manual", name: Name("Offline Manual"), parentID: vm.series.id),
                .init(id: "zero-manual", playerID: "local-zero-manual", name: Name("Offline Zero Strokes"), parentID: vm.series.id)
            ]
            var round = SeriesRound(id: "local-visual-round", parentID: vm.series.id)
            round.roundConfig.scoreBasisOverride = basis
            round.roundConfig.handicapEntryFormat = .courseHandicap
            round.handicapInputs = [
                "registered": .init(method: .personalIndex, value: 17.7, teeBoxID: blue.id),
                "manual": .init(method: .strokes, value: 12, teeBoxID: blue.id),
                "zero-manual": .init(method: .strokes, value: 0, teeBoxID: blue.id)
            ]
            if !missing { round.handicapInputs["zero-index"] = .init(method: .personalIndex, value: 0, teeBoxID: blue.id) }
            vm.rounds = [round]
            let screen = try SandboxAcceptanceScreen(SeriesRoundHandicapReviewView(viewModel: vm, seriesRound: round, course: courseSegment,
                onRoundCreated: { _ in XCTFail("Read-only visual check must never create a round") }))
            defer { screen.close() }
            let start = try await screen.waitForButton("Start Round")
            try await Task.sleep(for: .milliseconds(600))
            XCTAssertTrue(screen.labels.contains(missing ? "Handicap Setup Needed" : "Ready to Start"))
            XCTAssertEqual(start.accessibilityTraits.contains(.notEnabled), missing)
            XCTAssertEqual(screen.labels.filter { $0.hasPrefix("Entry method") }.count, missing ? 1 : 0)
            XCTAssertFalse(start.accessibilityFrame.isEmpty)
            XCTAssertTrue(screen.window.bounds.contains(start.accessibilityFrame), "Primary action must be on screen")
            screen.attach(to: self, name: "Stable-ReadOnly-" + label)
            screen.close()
        }
    }

    func testReadOnlyExistingPlayerAndDeletedFixtureReferences() async throws {
        guard FirebaseApp.app()?.options.projectID == "hackers-compete-sandbox",
              ProcessInfo.processInfo.environment["PR16_VALIDATION_NO_SESSION_RESTORE"] == "1" else {
            throw XCTSkip("Isolated Sandbox-only diagnostic")
        }
        let playerRef = db.collection("players").document("TCH42Fhb96Th4tazhMEqk2SMZdZ4")
        let player = try await playerRef.getDocument(source: .server).data(as: Player.self)
        let firstRoundIDs = ["Zn8s2rOJX1WpKAxAQOP7Yosxrat7", "PzKbna1f3vitsFT8wmNkyQrq1yaB", "5Qx4NlwOynEeWSmr6zJE571LAWKo", "5gnwrfbdvw8AyfpJtf9T7hWgJKZX"]
        let encoded = String(decoding: try JSONEncoder().encode(player), as: UTF8.self)
        for id in firstRoundIDs {
            XCTAssertFalse(encoded.contains(id), "Temporary round reference remains on existing player")
            let root = db.collection(Collections.rounds.name).document(id)
            let snapshot = try await root.getDocument(source: .server)
            XCTAssertFalse(snapshot.exists)
        }
        XCTAssertFalse(encoded.contains("pr16-A02B80F5-239"))
        for name in ["personal-handicap-scores", "personal-handicap-history"] {
            let docs = try await playerRef.collection(name).getDocuments(source: .server)
            for document in docs.documents {
                let values = String(describing: document.data())
                for id in firstRoundIDs { XCTAssertFalse(values.contains(id), "Temporary round remains in existing personal history") }
            }
        }
        let summary: [String: Any] = [
            "existingPlayerHasTemporaryRoundReferences": false,
            "effectiveIndex": player.personalHandicap?.effectiveIndex as Any? ?? NSNull(),
            "manualIndex": player.personalHandicap?.manual?.value as Any? ?? NSNull(),
            "calculationAsOf": player.personalHandicap?.calculation?.asOf.iso as Any? ?? NSNull(),
            "lastUpdatedAt": player.lastUpdatedAt.iso,
            "checkedDeletedRoundCount": firstRoundIDs.count
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "PR16-ReadOnly-Existing-Player-Metadata"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAuthorizedLiveSandboxCreationScoringAndCleanup() async throws {
        guard ProcessInfo.processInfo.environment["AUTHORIZE_PR16_SANDBOX_WRITE"] == "1" else {
            throw XCTSkip("Requires explicit authorization for temporary Live Sandbox test data")
        }
        guard FirebaseApp.app()?.options.projectID == "hackers-compete-sandbox",
              ProcessInfo.processInfo.environment["PR16_VALIDATION_NO_SESSION_RESTORE"] == "1",
              ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"] == nil,
              Bundle.main.bundleIdentifier == "com.tigermindlabs.hackers.compete.sandbox" else { throw Failure.invalidScope }
        guard let auth = Auth.auth().currentUser, let email = auth.email else { throw Failure.missingAuthentication }
        let user = try await FirebaseService.shared.getUserByEmail(email).get()
        await AppData.shared.setUser(user)
        let primaryResult = await AppData.shared.getPrimaryPlayer()
        let primary = try XCTUnwrap(primaryResult)
        ownerID = user.id
        for path in ["users/\(user.id)", "players/\(primary.id)",
                     "series/V6Egarw4RtsnnUNKSeM1oTubHFUH", "courses/24833",
                     "courses/2petFWO6L40zc95XvacraA8N8wKp"] {
            protected[path] = try await db.document(path).getDocument(source: .server).data()
        }
        let library = try await db.collection("courses").document("2petFWO6L40zc95XvacraA8N8wKp").getDocument(source: .server).data(as: Course.self)
        XCTAssertEqual(library.golfCourseApiID, 27322)
        let blue = try XCTUnwrap(library.tees.first { $0.name == "Blue" && $0.gender == "male" })
        let numeric27322 = try await db.collection("courses").document("27322").getDocument(source: .server)
        XCTAssertFalse(numeric27322.exists)
        let old = try await db.collection("courses").document("24833").getDocument(source: .server).data(as: Course.self)
        let oldBlue = try XCTUnwrap(old.tees.first { $0.name == "Blue" && $0.gender == "male" })
        let legacy18 = await SeriesRoundCourseHandicapAvailability.check(selection(old, oldBlue, .full18))
        XCTAssertEqual(legacy18.status, .ready)
        for segment in [HoleSegment.front9, .back9] {
            let estimated = await SeriesRoundCourseHandicapAvailability.check(selection(old, oldBlue, segment))
            XCTAssertEqual(estimated.status, .estimated)
        }
        var stale = selection(library, blue, .full18)
        stale.defaultTeeBoxID = "deleted-tee-" + String(runID)
        let unavailable = await SeriesRoundCourseHandicapAvailability.check(stale)
        XCTAssertEqual(unavailable.status, .teeUnavailable)
        XCTAssertNil(unavailable.courseSegment)

        let fixtureID = String(runID) + "-series"
        guard try await !db.collection("series").document(fixtureID).getDocument(source: .server).exists else { throw Failure.invalidScope }
        seriesID = fixtureID
        var settings = SeriesSettings(experiencePreset: .trip, useTeams: false)
        settings.handicapConfig = .init(mode: .fixed, strokeBasis: .eighteenHole, entryFormat: .courseHandicap)
        settings.defaultRoundConfig.handicapEntryFormat = .courseHandicap
        settings.defaultRoundConfig.handicapNormalizationMode = .off
        settings.defaultRoundConfig.scoreBasisOverride = .net
        settings.defaultRoundConfig.countsTowardHandicapPool = false
        let testPlayer = Player(id: String(runID) + "-registered", userID: user.id,
                                name: Name("TEMP PR16 Registered"), isPrimary: true)
        temporaryPlayerID = testPlayer.id
        let series = Series(id: fixtureID, name: "TEMP PR16 VALIDATION " + String(runID),
                            description: "Authorized temporary Sandbox acceptance; delete after validation.",
                            commissionerUserID: user.id, commissionerPlayerID: testPlayer.id,
                            memberPlayerIDs: [testPlayer.id], settings: settings)
        do {
            let playerExists = try await db.collection("players").document(testPlayer.id).getDocument(source: .server).exists
            guard !playerExists else { throw Failure.invalidScope }
            _ = try await testPlayer.post().get()
            var testUser = user
            testUser.players = [testPlayer.id] // In-memory only; never persist an existing user.
            await AppData.shared.setUser(testUser)
            _ = try await series.post().get()
            let members = [
                SeriesMember(id: "registered", userID: user.id, playerID: testPlayer.id, name: Name("Registered Test"), parentID: fixtureID),
                SeriesMember(id: "zero-index", playerID: String(runID) + "-zero-index", name: Name("Offline Zero Index"), parentID: fixtureID),
                SeriesMember(id: "manual", playerID: String(runID) + "-manual", name: Name("Offline Manual"), parentID: fixtureID),
                SeriesMember(id: "zero-manual", playerID: String(runID) + "-zero-manual", name: Name("Offline Zero Strokes"), parentID: fixtureID)
            ]
            for member in members { _ = try await member.post().get() }
            let cases: [(String, HoleSegment, ScoreBasis, Bool)] = [
                ("18-net", .full18, .net, false), ("front-net", .front9, .net, true),
                ("back-net", .back9, .net, true), ("18-gross", .full18, .gross, false)
            ]
            for (label, holes, basis, savedPath) in cases {
                let chosen = selection(library, blue, holes)
                let validation = await SeriesRoundCourseHandicapAvailability.check(chosen)
                XCTAssertEqual(validation.status, .ready)
                let segment = try XCTUnwrap(validation.courseSegment)
                let expectedRating = holes == .full18 ? 72.2 : (holes == .front9 ? 36.4 : 35.8)
                let expectedSlope = holes == .full18 ? 137 : (holes == .front9 ? 130 : 143)
                XCTAssertEqual(validation.calculation?.rating, expectedRating)
                XCTAssertEqual(validation.calculation?.slope, expectedSlope)
                XCTAssertEqual(validation.calculation?.par, holes == .full18 ? 72 : 36)
                let defaultsName = String(runID) + "-" + label
                let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
                defer { defaults.removePersistentDomain(forName: defaultsName) }
                let vm = SeriesViewModel(handicapDraftDefaults: defaults)
                vm.series = series
                vm.currentUserID = user.id
                vm.members = members
                var draft = SeriesRoundDraft(settings: settings, suggestedCourse: nil, usesTeams: false)
                draft.title = String(runID) + "-" + label
                draft.selectedCourse = chosen
                draft.handicapEntryFormat = .courseHandicap
                titles.append(draft.title)
                let maybePlanned = await vm.addRound(draft: draft, courseValidation: validation, fallbackTitle: draft.title)
                var planned = try XCTUnwrap(maybePlanned, "Planning failed for \(label)")
                planned.roundConfig.scoreBasisOverride = basis
                planned.handicapInputs = [
                    "registered": .init(method: .personalIndex, value: 17.7, teeBoxID: blue.id),
                    "zero-index": .init(method: .personalIndex, value: 0, teeBoxID: blue.id),
                    "manual": .init(method: .strokes, value: 12, teeBoxID: blue.id),
                    "zero-manual": .init(method: .strokes, value: 0, teeBoxID: blue.id)
                ]
                let didSave = await vm.saveRoundHandicapSetup(planned)
                XCTAssertTrue(didSave)
                planned = try XCTUnwrap(vm.rounds.first)
                let persisted = try await db.collection("series").document(fixtureID).collection("rounds").document(planned.id).getDocument(source: .server).data(as: SeriesRound.self)
                XCTAssertEqual(persisted.courseOverride, chosen)
                XCTAssertEqual(persisted.handicapInputs, planned.handicapInputs)
                XCTAssertEqual(persisted.roundConfig.scoreBasisOverride, basis)
                if label == "18-net" {
                    var missing = planned
                    missing.handicapInputs["zero-index"] = nil
                    vm.rounds = [missing]
                    let needs = try SandboxAcceptanceScreen(SeriesRoundHandicapReviewView(viewModel: vm, seriesRound: missing, course: segment, onRoundCreated: { _ in XCTFail("No start requested") }))
                    _ = try await needs.waitForButton("Edit Handicaps")
                    XCTAssertTrue(needs.labels.contains("Handicap Setup Needed"))
                    XCTAssertEqual(needs.labels.filter { $0.hasPrefix("Entry method") }.count, 1)
                    needs.attach(to: self, name: "Live-Sandbox-Only-One-Missing")
                    needs.close()
                    vm.rounds = [planned]
                }
                var callbackID: String?
                let picker = CourseSelectionViewModel()
                let screen = try SandboxAcceptanceScreen(CourseSelectionForSeriesRoundSheet(
                    viewModel: vm, seriesRound: planned, reviewSavedCourse: savedPath, courseViewModel: picker,
                    onRoundCreated: { callbackID = $0 })
                    .environmentObject(AppSession(restoresAuthentication: false))
                    .environmentObject(LocationService()).environmentObject(RoundSession()))
                defer { screen.close() }
                if !savedPath {
                    for _ in 0..<50 { if picker.onSetSeriesRoundCourse != nil { break }; try await Task.sleep(for: .milliseconds(100)) }
                    let choose = try XCTUnwrap(picker.onSetSeriesRoundCourse)
                    choose(segment)
                }
                _ = try await screen.waitForButton("Edit Handicaps")
                XCTAssertTrue(screen.labels.contains("Ready to Start"))
                XCTAssertTrue(screen.labels.contains("4 of 4 players ready"))
                XCTAssertFalse(screen.labels.contains { $0.hasPrefix("Entry method") })
                screen.attach(to: self, name: "Live-Sandbox-Compact-" + label)
                let start = try await screen.waitForButton("Start Round")
                XCTAssertFalse(start.accessibilityTraits.contains(.notEnabled))
                XCTAssertTrue(start.accessibilityActivate())
                _ = start.accessibilityActivate() // Deliberate repeated tap; must create only one round.
                for _ in 0..<1200 {
                    if callbackID != nil || vm.roundCreationErrorMessage != nil || vm.handicapSetupErrorMessage != nil { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let roundID = try XCTUnwrap(callbackID, "Start failed: \(vm.roundCreationErrorMessage ?? vm.handicapSetupErrorMessage ?? screen.labels.joined(separator: " | "))")
                ownedRoundIDs.insert(roundID)
                screen.close()
                let duplicate = await vm.createLiveRound(from: planned, courseSegment: segment)
                XCTAssertNil(duplicate)
                let live = try await db.collection(Collections.rounds.name).document(roundID).getDocument(source: .server).data(as: Round.self)
                XCTAssertEqual(live.configuration.courses.first?.courseInfo.id, library.id)
                XCTAssertEqual(live.configuration.courses.first?.defaultTee, blue.id)
                XCTAssertEqual(live.configuration.courses.first?.holeSegment, holes)
                XCTAssertEqual(live.configuration.primaryFormat.configuration.basis, basis)
                let participantDocs = try await db.collection(Collections.rounds.name).document(roundID).collection("participants").getDocuments(source: .server)
                let participants = try participantDocs.documents.map { try $0.data(as: RoundParticipant.self) }
                XCTAssertEqual(participants.count, 4)
                let expectedIndexStrokes = holes == .full18 ? 22 : 11
                for participant in participants {
                    let expected = participant.seriesMemberID == "registered" ? expectedIndexStrokes : (participant.seriesMemberID == "manual" ? 12 : 0)
                    XCTAssertEqual(participant.lockedHandicapAllowance, expected)
                    XCTAssertEqual(participant.teeBoxID, blue.id)
                    if participant.seriesMemberID == "registered" { XCTAssertEqual(participant.handicapIndex, 17.7) }
                }
                let segmentDocs = try await db.collection(Collections.rounds.name).document(roundID).collection("segments").getDocuments(source: .server)
                let segments = try segmentDocs.documents.map { try $0.data(as: RoundSegment.self) }
                let liveSegment = try XCTUnwrap(segments.first)
                let courseHoles = blue.holes.filter { holes.holeRange.holeNumbers.contains($0.number) }
                var scores: [ScoreEntry] = []
                for participant in participants {
                    for hole in courseHoles {
                        let score = ScoreEntry(id: ScoreEntry.makeID(hole: hole.number, segment: liveSegment.id, scoringUnit: participant.id),
                            holeNumber: hole.number, segmentID: liveSegment.id, groupID: participant.groupID ?? "",
                            scoringUnitID: participant.id, participantIDs: [participant.id], strokes: hole.par + 1,
                            entryID: user.id, parentID: roundID)
                        scores.append(try await score.post().get())
                    }
                }
                let savedScores = try await db.collection(Collections.rounds.name).document(roundID).collection("scores").getDocuments(source: .server).documents.map { try $0.data(as: ScoreEntry.self) }
                XCTAssertEqual(savedScores.count, 4 * holes.holeCount)
                let snapshot = RoundSnapshot(round: live, participants: participants, segments: segments, scoring: savedScores)
                let gross = ScoringEngine.computeSnapshotResult(snapshot: snapshot, segment: liveSegment, holes: courseHoles, basis: .gross)
                let net = ScoringEngine.computeSnapshotResult(snapshot: snapshot, segment: liveSegment, holes: courseHoles, basis: .net)
                for participant in participants {
                    let grossRow = try XCTUnwrap(gross.rows.first { $0.scoringUnitID == participant.id })
                    let netRow = try XCTUnwrap(net.rows.first { $0.scoringUnitID == participant.id })
                    XCTAssertEqual(grossRow.holesPlayed, holes.holeCount)
                    XCTAssertEqual(grossRow.total, Double(holes.holeCount))
                    XCTAssertEqual(netRow.total, Double(holes.holeCount - participant.lockedHandicapAllowance))
                }
                let sameName = try await db.collection(Collections.rounds.name).whereField("name", isEqualTo: draft.title).getDocuments(source: .server)
                XCTAssertEqual(sameName.documents.count, 1, "Repeated start must not create another live round")
                evidence.append(["case": label, "roundID": roundID, "seriesRoundID": planned.id,
                    "courseID": library.id, "providerReference": 27322, "teeID": blue.id,
                    "rating": expectedRating, "slope": expectedSlope, "par": holes == .full18 ? 72 : 36,
                    "participants": participants.count, "scores": savedScores.count,
                    "index17_7Strokes": expectedIndexStrokes, "basis": basis.rawValue,
                    "compactConfirmation": true, "savedCoursePath": savedPath, "duplicateCount": sameName.documents.count])
            }
        } catch {
            try await cleanup()
            try await verifyProtected()
            await AppData.shared.setUser(user)
            attachEvidence()
            throw error
        }
        try await cleanup()
        try await verifyProtected()
        await AppData.shared.setUser(user)
        attachEvidence()
    }

    private func selection(_ course: Course, _ tee: Tee, _ segment: HoleSegment) -> SeriesCourseSelection {
        .init(courseID: course.id, cachedName: course.prettyCourseName, defaultTeeBoxID: tee.id,
              defaultTeeName: tee.name, defaultTeeGender: tee.gender, holeSegment: segment)
    }
    private func cleanup() async throws {
        guard FirebaseApp.app()?.options.projectID == "hackers-compete-sandbox", let seriesID,
              seriesID == String(runID) + "-series" else { throw Failure.invalidScope }
        for title in titles {
            let docs = try await db.collection(Collections.rounds.name).whereField("name", isEqualTo: title).getDocuments(source: .server)
            for doc in docs.documents {
                let round = try doc.data(as: Round.self)
                guard round.createdBy == ownerID, round.name == title, title.hasPrefix(String(runID)) else { throw Failure.invalidScope }
                ownedRoundIDs.insert(doc.documentID)
            }
        }
        for roundID in ownedRoundIDs {
            let root = db.collection(Collections.rounds.name).document(roundID)
            for collection in RoundSubcollection.allCases { try await deleteChildren(root.collection(collection.rawValue)) }
            try await root.delete()
            deletedPaths.append(root.path)
            let deleted = try await root.getDocument(source: .server)
            XCTAssertFalse(deleted.exists)
            for collection in RoundSubcollection.allCases {
                let remaining = try await root.collection(collection.rawValue).getDocuments(source: .server)
                XCTAssertTrue(remaining.isEmpty)
            }
        }
        let root = db.collection("series").document(seriesID)
        for collection in SeriesSubcollection.allCases { try await deleteChildren(root.collection(collection.rawValue)) }
        try await root.delete()
        deletedPaths.append(root.path)
        let deleted = try await root.getDocument(source: .server)
        XCTAssertFalse(deleted.exists)
        for collection in SeriesSubcollection.allCases {
            let remaining = try await root.collection(collection.rawValue).getDocuments(source: .server)
            XCTAssertTrue(remaining.isEmpty)
        }
        if let temporaryPlayerID {
            guard temporaryPlayerID == String(runID) + "-registered" else { throw Failure.invalidScope }
            let player = db.collection("players").document(temporaryPlayerID)
            for name in ["personal-handicap-scores", "personal-handicap-history"] { try await deleteChildren(player.collection(name)) }
            try await player.delete()
            deletedPaths.append(player.path)
            let remaining = try await player.getDocument(source: .server)
            XCTAssertFalse(remaining.exists)
        }
        print("PR16_SANDBOX_CLEANUP_VERIFIED", seriesID, "rounds", ownedRoundIDs.count, "documents", deletedPaths.count)
    }
    private func deleteChildren(_ collection: CollectionReference) async throws {
        let docs = try await collection.getDocuments(source: .server)
        for doc in docs.documents { try await doc.reference.delete(); deletedPaths.append(doc.reference.path) }
    }
    private func verifyProtected() async throws {
        var changed: [String] = []
        for (path, before) in protected {
            let after = try await db.document(path).getDocument(source: .server).data()
            let equal = NSDictionary(dictionary: before).isEqual(to: after ?? [:])
            if !equal {
                changed.append(path)
                let keys = Set(before.keys).union(after?.keys.map { $0 } ?? [])
                print("PR16_SANDBOX_CHANGED_FIELDS", path, keys.filter {
                    !NSDictionary(dictionary: ["v": before[$0] ?? NSNull()]).isEqual(to: ["v": after?[$0] ?? NSNull()])
                }.sorted())
            }
            XCTAssertTrue(equal, "Existing record changed: \(path)")
        }
        if changed.isEmpty { print("PR16_SANDBOX_EXISTING_RECORDS_UNCHANGED", protected.count) }
    }
    private func attachEvidence() {
        let data = try! JSONSerialization.data(withJSONObject: ["project": "hackers-compete-sandbox", "runID": String(runID),
            "cases": evidence, "deletedPaths": deletedPaths, "protectedRecordsVerified": protected.count], options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "PR16-Live-Sandbox-Acceptance-Manifest"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class SandboxAcceptanceScreen {
    let window: UIWindow
    private let previous: UIWindow?
    init<V: View>(_ view: V) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previous = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: AnyView(view))
        window.makeKeyAndVisible()
        window.rootViewController?.view.frame = window.bounds
        window.rootViewController?.view.layoutIfNeeded()
        window.layoutIfNeeded()
    }
    func close() { window.isHidden = true; previous?.makeKeyAndVisible() }
    private func nodes() -> [NSObject] {
        var visited = Set<ObjectIdentifier>()
        func visit(_ object: NSObject, _ depth: Int = 0) -> [NSObject] {
            guard depth < 24, visited.insert(ObjectIdentifier(object)).inserted else { return [] }
            var result = [object]
            if let view = object as? UIView { result += view.subviews.flatMap { visit($0, depth + 1) } }
            let count = object.accessibilityElementCount()
            if count > 0 && count < 500 {
                for i in 0..<count { if let child = object.accessibilityElement(at: i) as? NSObject { result += visit(child, depth + 1) } }
            }
            return result
        }
        return visit(window)
    }
    var labels: [String] { nodes().compactMap(\.accessibilityLabel) }
    func waitForButton(_ label: String) async throws -> NSObject {
        for _ in 0..<150 {
            if let button = nodes().first(where: { $0.accessibilityLabel == label && $0.accessibilityTraits.contains(.button) }) { return button }
            try await Task.sleep(for: .milliseconds(100))
        }
        return try XCTUnwrap(nodes().first { $0.accessibilityLabel == label }, "Missing \(label): \(labels)")
    }
    func attach(to test: XCTestCase, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }
}
