import Security
import SwiftUI
import UIKit
import XCTest
@testable import Hackers

/// Local fixtures for the reported series start problems. No Firebase writes,
/// authentication, customer trips, personal profiles or application code are modified.
@MainActor
final class SeriesRoundStartAuditTests: XCTestCase {
    func testSimulatorKeychainCanStoreItsOwnTemporaryCredential() {
        let key: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Hackers.SeriesStartAudit." + UUID().uuidString,
            kSecAttrAccount: "temporary-signing-probe"
        ]
        var item = key
        item[kSecValueData] = Data("test-only".utf8)
        defer { SecItemDelete(key as CFDictionary) }
        XCTAssertEqual(SecItemAdd(item as CFDictionary, nil), errSecSuccess,
                       "Google Sign-In also needs the simulator app's own keychain access")
    }

    func testOffModeReportsAllSevenMissingIndexesBeforeRoundCreation() {
        assertSevenMissing(.off)
    }

    func testFixedModeReportsAllSevenMissingIndexesBeforeRoundCreation() {
        assertSevenMissing(.fixed)
    }

    func testDynamicModeReportsAllSevenMissingIndexesBeforeRoundCreation() {
        assertSevenMissing(.dynamic)
    }

    func testOffModePrefillsSavedPersonalIndexesWithoutTouchingProfilesOrSeriesHistory() throws {
        let vm = model(.off)
        let profiles = try members().map { member in
            var profile = Player(id: member.playerID!, userID: member.userID, name: member.name)
            profile.personalHandicap = try .init(manual: .init(value: 17.7, source: .manual))
            return profile
        }
        let originalProfiles = profiles
        vm.applyPersonalRoundHandicapDefaults(from: profiles)
        let round = plannedRound()
        let drafts = Dictionary(uniqueKeysWithValues: vm.members.map {
            ($0.id, vm.handicapDraft(for: $0, round: round, course: course()))
        })
        let candidate = try SeriesRoundHandicapSetup.applying(drafts: drafts, to: round)
        XCTAssertTrue(SeriesRoundHandicapSetup.issues(series: vm.series, round: candidate,
            members: vm.members, handicaps: [:], course: course()).isEmpty)
        XCTAssertEqual(candidate.handicapInputs.count, 7)
        XCTAssertEqual(profiles, originalProfiles)
        XCTAssertTrue(vm.handicapOverrides.isEmpty)
        XCTAssertTrue(vm.handicapScores.isEmpty)
    }

    func testMissingManualStrokeInputMustRemainUnresolvedInsteadOfBecomingZero() {
        let payload = participants(model(.off), format: .strokes)
        XCTAssertEqual(payload.count, 7)
        XCTAssertTrue(payload.allSatisfy { $0.handicapResolution?.effectiveStrokes == nil },
            "Missing manual strokes are currently seeded as resolved zero for all seven players")
    }

    func testRosterCommissionerMustBeRecognizedBeforePrimaryPlayerLoads() {
        let vm = model(.off)
        vm.currentUserID = "user1"
        vm.currentPlayerID = nil
        vm.members[0].role = .commissioner
        XCTAssertTrue(vm.isCommissioner, "Authenticated roster commissioner is hidden until primary player ID loads")
    }

    func testOwnerAndLoadedCommissionerPermissionsAndNonCommissionerDenial() {
        let vm = model(.off)
        XCTAssertTrue(vm.isCommissioner)
        vm.currentUserID = "user1"
        vm.currentPlayerID = "player1"
        XCTAssertFalse(vm.isCommissioner)
        vm.members[0].role = .commissioner
        XCTAssertTrue(vm.isCommissioner)
        vm.members[0].isActive = false
        XCTAssertFalse(vm.isCommissioner)
        vm.currentUserID = nil
        XCTAssertFalse(vm.isCommissioner)
    }

    func testOwnerHandicapAccessIsNotGatedByTripStateOrRoundMode() {
        for mode in SeriesHandicapMode.allCases {
            let vm = model(mode)
            for state in [SeriesStatus.draft, .active, .completed] {
                vm.series.status = state
                XCTAssertTrue(vm.isCommissioner)
            }
        }
    }

    func testOffFixedDynamicSettingsSurviveSerializedReloadWithoutChangingRules() throws {
        for mode in SeriesHandicapMode.allCases {
            var series = model(mode).series
            series.handicapConfig.config.maximumHandicap = 21
            series.handicapConfig.strokeBasis = .nineHole
            let config = series.handicapConfig
            let reopened = try JSONDecoder().decode(Series.self, from: JSONEncoder().encode(series))
            XCTAssertEqual(reopened.handicapConfig, config)
            XCTAssertEqual(reopened.handicapConfig.mode, mode)
            XCTAssertEqual(reopened.handicapConfig.config.maximumHandicap, 21)
            XCTAssertEqual(reopened.handicapConfig.mode.allowsAccrual, mode == .dynamic)
        }
    }

    func testExistingSeriesValuesAndPerPlayerTeesStillResolveNineAndEighteenHoles() {
        for segment in [HoleSegment.front9, .full18] {
            let vm = model(.fixed)
            vm.members[1].defaultTeeBoxID = "blue"
            vm.memberHandicaps = Dictionary(uniqueKeysWithValues: vm.members.map {
                ($0.id, SeriesMemberHandicap(memberID: $0.id, computedIndex: 18))
            })
            let payload = participants(vm, format: .courseHandicap, segment: segment)
            XCTAssertEqual(payload[0].adjustedHandicap, segment == .full18 ? 18 : 9)
            XCTAssertEqual(payload[1].adjustedHandicap, segment == .full18 ? 22 : 11)
            XCTAssertEqual(payload[1].teeBoxID, "blue")
            XCTAssertEqual(payload[0].handicapIndex, 18)
            XCTAssertEqual(payload[0].handicapSnapshot?.handicapStrokeBasis, .eighteenHole)
            XCTAssertEqual(payload[0].handicapSnapshot?.source, .league)
        }
    }

    func testExistingManualSeriesStrokesRemainAuthoritativeAndCapped() {
        let vm = model(.fixed)
        vm.memberHandicaps = Dictionary(uniqueKeysWithValues: vm.members.map {
            ($0.id, SeriesMemberHandicap(memberID: $0.id, overrideIndex: 30, isOverridden: true))
        })
        let payload = participants(vm, format: .strokes, maximum: 21)
        XCTAssertEqual(payload.map(\.adjustedHandicap), Array(repeating: 21, count: 7))
        XCTAssertTrue(payload.allSatisfy { $0.handicapIndex == nil })
        XCTAssertTrue(vm.memberHandicaps.values.allSatisfy { $0.overrideIndex == 30 })
    }

    func testRealSettingsScreenExposesAndSwitchesAllThreeModes() async throws {
        let vm = model(.off)
        let screen = try SeriesAuditHostedScreen(SeriesHandicapSettingsView(viewModel: vm))
        defer { screen.close() }
        try await Task.sleep(for: .milliseconds(400))
        for mode in [SeriesHandicapMode.fixed, .dynamic, .off] {
            let button = try await screen.waitForButton(mode.displayName)
            XCTAssertTrue(button.accessibilityActivate())
            try await Task.sleep(for: .milliseconds(350))
            let labels = screen.labels
            XCTAssertTrue(labels.contains("Off") && labels.contains("Fixed") && labels.contains("Dynamic"))
            XCTAssertEqual(labels.contains("CONFIGURATION"), mode.isEnabled)
            XCTAssertNotNil(try screen.button("Save"))
            screen.attach(to: self, name: "Series-Handicap-Settings-\(mode.rawValue)")
        }
        // Selecting without Save must not modify persisted series data. The real
        // Save is deliberately not invoked: it would call authenticated Firebase.
        XCTAssertEqual(vm.series.handicapConfig.mode, .off)
    }

    func testSevenPlayersResolveWithMixedPersonalIndexAndManualStrokesInEveryMode() throws {
        for mode in SeriesHandicapMode.allCases {
            let vm = model(mode)
            var round = plannedRound()
            round.handicapInputs = Dictionary(uniqueKeysWithValues: vm.members.enumerated().map { i, member in
                (member.id, SeriesRoundHandicapInput(method: i.isMultiple(of: 2) ? .personalIndex : .strokes,
                                                     value: i.isMultiple(of: 2) ? 17.7 : 12, teeBoxID: "white"))
            })
            XCTAssertTrue(SeriesRoundHandicapSetup.issues(series: vm.series, round: round, members: vm.members,
                handicaps: vm.memberHandicaps, course: course()).isEmpty)
            let payload = participants(vm, format: .courseHandicap, inputs: round.handicapInputs)
            XCTAssertEqual(payload.count, 7)
            for (i, participant) in payload.enumerated() {
                XCTAssertEqual(participant.handicapSnapshot?.source, .roundSetup)
                XCTAssertEqual(participant.adjustedHandicap, i.isMultiple(of: 2) ? 18 : 12)
                XCTAssertEqual(participant.handicapIndex, i.isMultiple(of: 2) ? 17.7 : nil)
                XCTAssertEqual(participant.handicapResolution?.entryFormat, i.isMultiple(of: 2) ? .courseHandicap : .strokes)
                XCTAssertEqual(participant.handicapSnapshot?.selectedHandicapScoreIDs, [])
            }
            let reloaded = try JSONDecoder().decode(SeriesRound.self, from: JSONEncoder().encode(round))
            XCTAssertEqual(reloaded.handicapInputs, round.handicapInputs)
        }
    }

    func testPersonalIndexAlwaysUsesEighteenHoleBasisWhenSeriesUsesNineHoleIndex() {
        let vm = model(.dynamic)
        vm.series.handicapConfig.strokeBasis = .nineHole
        for segment in [HoleSegment.front9, .full18] {
            let payload = participants(vm, format: .courseHandicap, segment: segment,
                inputs: ["m1": .init(method: .personalIndex, value: 18, teeBoxID: "white")])
            XCTAssertEqual(payload[0].adjustedHandicap, segment == .front9 ? 9 : 18)
            XCTAssertEqual(payload[0].handicapIndex, 18)
            XCTAssertEqual(payload[0].handicapSnapshot?.calculation?.indexBasis, .eighteenHole)
        }
    }

    func testPartialResolutionListsOnlyRemainingPlayersAndNeverInfersZero() {
        let vm = model(.off)
        var round = plannedRound()
        round.handicapInputs = ["m1": .init(method: .strokes, value: 0, teeBoxID: "white"),
                                "m7": .init(method: .personalIndex, value: 12.4, teeBoxID: "blue")]
        let issues = SeriesRoundHandicapSetup.issues(series: vm.series, round: round, members: vm.members,
            handicaps: [:], course: course())
        XCTAssertEqual(Set(issues.map(\.memberID)), Set(["m2", "m3", "m4", "m5", "m6"]))
        let payload = participants(vm, format: .courseHandicap, inputs: round.handicapInputs)
        XCTAssertEqual(payload[0].handicapResolution?.effectiveStrokes, 0, "Explicit scratch is resolved")
        XCTAssertNil(payload[1].handicapResolution?.effectiveStrokes, "Missing input remains unresolved")
        XCTAssertEqual(payload[6].teeBoxID, "blue")
        XCTAssertNotNil(payload[6].handicapIndex, "Offline player uses the same round-only path")
    }

    func testManualStrokesCannotBypassSelectedTeeOrPlayableHoleData() {
        let vm = model(.off)
        var round = plannedRound()
        round.handicapInputs["m1"] = .init(method: .strokes, value: 12, teeBoxID: "missing")
        XCTAssertFalse(SeriesRoundHandicapSetup.issues(series: vm.series, round: round,
            members: [vm.members[0]], handicaps: [:], course: course()).isEmpty)
        round.handicapInputs["m1"]?.teeBoxID = "white"
        var invalid = course()
        invalid.courseInfo.tees[0] = Tee(id: "white", name: "White", gender: "male", totalHoles: 18,
            holes: Array(invalid.courseInfo.tees[0].holes.dropLast()), ratingFull: 72, slopeFull: 113,
            ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        XCTAssertFalse(SeriesRoundHandicapSetup.issues(series: vm.series, round: round,
            members: [vm.members[0]], handicaps: [:], course: invalid).isEmpty)
    }

    func testInvalidAndCancelledDraftPreservesLastSavedInputAndTypedText() throws {
        var round = plannedRound()
        round.handicapInputs["m1"] = .init(method: .personalIndex, value: 17.7, teeBoxID: "white")
        var draft = SeriesRoundHandicapDraft(input: round.handicapInputs["m1"], teeBoxID: "white")
        draft.text = "oops"
        XCTAssertThrowsError(try SeriesRoundHandicapSetup.applying(drafts: ["m1": draft], to: round))
        XCTAssertEqual(round.handicapInputs["m1"]?.value, 17.7)
        XCTAssertEqual(draft.text, "oops")
        draft.method = .strokes
        draft.text = "12.5"
        XCTAssertNil(draft.input)
        draft.text = "12"
        XCTAssertEqual(try SeriesRoundHandicapSetup.applying(drafts: ["m1": draft], to: round).handicapInputs["m1"]?.method, .strokes)
    }

    func testSaveFailureRetainsDraftAndSuccessfulRetryPersistsRoundOnlyValues() async throws {
        var writes = 0
        let vm = model(.off, saveRound: { round in
            writes += 1
            return writes == 1 ? .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) : .success(round)
        })
        let original = plannedRound()
        vm.rounds = [original]
        var draft = SeriesRoundHandicapDraft(teeBoxID: "white")
        draft.text = "17.7"
        vm.roundHandicapDrafts[original.id] = ["m7": draft]
        let candidate = try SeriesRoundHandicapSetup.applying(drafts: vm.roundHandicapDrafts[original.id]!, to: original)
        let failed = await vm.saveRoundHandicapSetup(candidate)
        XCTAssertFalse(failed)
        XCTAssertEqual(vm.roundHandicapDrafts[original.id]?["m7"]?.text, "17.7")
        XCTAssertTrue(vm.rounds[0].handicapInputs.isEmpty)
        XCTAssertNotNil(vm.handicapSetupErrorMessage)
        let retried = await vm.saveRoundHandicapSetup(candidate)
        XCTAssertTrue(retried)
        XCTAssertNil(vm.roundHandicapDrafts[original.id])
        XCTAssertEqual(vm.rounds[0].handicapInputs["m7"]?.value, 17.7)
        XCTAssertTrue(vm.handicapOverrides.isEmpty)
        XCTAssertTrue(vm.handicapScores.isEmpty)
        XCTAssertEqual(vm.series.handicapConfig.mode, .off)
        let reopened = try JSONDecoder().decode(SeriesRound.self, from: JSONEncoder().encode(vm.rounds[0]))
        let newVM = model(.off)
        newVM.rounds = [reopened]
        XCTAssertEqual(newVM.handicapDraft(for: newVM.members[6], round: reopened, course: course()).text, "17.7")
    }

    func testNonCommissionerAndStartedRoundCannotSaveOverrides() async {
        var writes = 0
        let vm = model(.off, saveRound: { writes += 1; return .success($0) })
        var round = plannedRound()
        round.handicapInputs["m1"] = .init(method: .strokes, value: 8, teeBoxID: "white")
        vm.rounds = [round]
        vm.currentUserID = "user1"
        vm.currentPlayerID = "player1"
        let denied = await vm.saveRoundHandicapSetup(round)
        XCTAssertFalse(denied)
        vm.currentUserID = "owner"
        vm.rounds[0].roundID = "already-linked"
        vm.rounds[0].status = .live
        let frozen = await vm.saveRoundHandicapSetup(round)
        XCTAssertFalse(frozen)
        XCTAssertEqual(writes, 0)
    }

    func testSettingsSaveFailureDoesNotChangeCommittedModeAndRetrySurvivesReload() async throws {
        for mode in SeriesHandicapMode.allCases {
            var writes = 0
            let vm = model(.off, saveSeries: { series in
                writes += 1
                return writes == 1 ? .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) : .success(series)
            })
            var config = vm.series.handicapConfig
            config.mode = mode
            let failed = await vm.saveHandicapSettings(config)
            XCTAssertFalse(failed)
            XCTAssertEqual(vm.series.handicapConfig.mode, .off)
            XCTAssertNotNil(vm.handicapSettingsErrorMessage)
            let saved = await vm.saveHandicapSettings(config)
            XCTAssertTrue(saved)
            let reopened = try JSONDecoder().decode(Series.self, from: JSONEncoder().encode(vm.series))
            XCTAssertEqual(reopened.handicapConfig, config)
        }
    }

    func testNonCommissionerCannotSaveSettings() async {
        var writes = 0
        let vm = model(.off, saveSeries: { writes += 1; return .success($0) })
        vm.currentUserID = "user1"
        let saved = await vm.saveHandicapSettings(.init(mode: .fixed))
        XCTAssertFalse(saved)
        XCTAssertEqual(writes, 0)
    }

    func testRoundSetupChangesInvalidateRealtimeStateWithoutChangingStandingsInputs() {
        let original = plannedRound()
        var edited = original
        edited.handicapInputs["m1"] = .init(method: .strokes, value: 8, teeBoxID: "white")
        let plan = SeriesRuntimeSubscriptionPolicy.invalidationPlan(previous: [original], updated: [edited], attendanceEnabled: false)
        XCTAssertTrue(plan.hasSemanticChanges)
        XCTAssertFalse(plan.shouldResolveStandings)
    }

    func testLiveSyncCannotOverwriteFrozenRoundOnlyAllowanceOrTee() throws {
        let vm = model(.fixed)
        let input: [String: SeriesRoundHandicapInput] = ["m1": .init(method: .personalIndex, value: 18, teeBoxID: "blue")]
        let original = try XCTUnwrap(participants(vm, format: .courseHandicap, inputs: input).first)
        let changed = ["m1": SeriesMemberHandicap(memberID: "m1", computedIndex: 2)]
        let updated = SeriesRoundSyncPlanning.participantsWithPlayerDataSync(
            participants: [original], roundID: "audit-round", participatingMembers: [vm.members[0]],
            teamLinks: [:], memberAssignments: [:], handicaps: changed, courseSegment: course(),
            handicapEntryFormat: .courseHandicap, handicapStrokeBasis: .eighteenHole,
            preserveFrozenRoundSetup: true, hostPlayerID: nil, preserveManualHandicapEdits: false)
        XCTAssertEqual(updated[0].handicapSnapshot, original.handicapSnapshot)
        XCTAssertEqual(updated[0].handicapResolution, original.handicapResolution)
        XCTAssertEqual(updated[0].teeBoxID, "blue")
        XCTAssertEqual(updated[0].adjustedHandicap, 22)
    }

    func testAtomicSetupUpdateRejectsStartedAndStaleRoundsAndPreservesPlanning() throws {
        let original = plannedRound()
        var draft = original
        draft.handicapInputs["m1"] = .init(method: .strokes, value: 8, teeBoxID: "white")
        var current = original
        current.roundID = "linked"
        current.status = .live
        XCTAssertThrowsError(try SeriesRoundHandicapSetup.updating(current, from: draft))
        current = original
        current.lastUpdatedAt = Time(for: Date(timeIntervalSince1970: original.lastUpdatedAt.unix + 10))
        XCTAssertThrowsError(try SeriesRoundHandicapSetup.updating(current, from: draft))
        current = original
        current.notes = "Keep unrelated planning"
        let updated = try SeriesRoundHandicapSetup.updating(current, from: draft)
        XCTAssertEqual(updated.notes, current.notes)
        XCTAssertEqual(updated.status, .planned)
        XCTAssertEqual(updated.handicapInputs["m1"]?.value, 8)
    }

    func testRealSettingsSaveKeepsSelectionOnFailureThenSavesOnRetry() async throws {
        var saves = 0
        let vm = model(.off, saveSeries: {
            saves += 1
            return saves == 1 ? .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) : .success($0)
        })
        let screen = try SeriesAuditHostedScreen(SeriesHandicapSettingsView(viewModel: vm))
        defer { screen.close() }
        screen.attach(to: self, name: "Series-Settings-Before-Interaction")
        let fixedButton = try await screen.waitForButton("Fixed")
        XCTAssertTrue(fixedButton.accessibilityActivate())
        try await Task.sleep(for: .milliseconds(250))
        let saveButton = try await screen.waitForButton("Save")
        XCTAssertTrue(saveButton.accessibilityActivate())
        for _ in 0..<30 { if saves == 1 { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(vm.series.handicapConfig.mode, .off)
        XCTAssertNotNil(vm.handicapSettingsErrorMessage)
        let retrySaveButton = try await screen.waitForButton("Save")
        XCTAssertTrue(retrySaveButton.accessibilityActivate())
        for _ in 0..<30 { if saves == 2 { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(saves, 2)
        XCTAssertEqual(vm.series.handicapConfig.mode, .fixed, "Failure must retain the selected Fixed draft")
        screen.close()
        let reopened = try SeriesAuditHostedScreen(SeriesHandicapSettingsView(viewModel: vm))
        defer { reopened.close() }
        _ = try await reopened.waitForButton("Fixed")
        XCTAssertTrue(reopened.labels.contains("CONFIGURATION"))
        reopened.attach(to: self, name: "Series-Settings-Fixed-Reopened")
    }

    func testRosterShowsDiscoverableHandicapSettingsForCommissioner() async throws {
        let vm = model(.off)
        let screen = try SeriesAuditHostedScreen(SeriesRosterView(viewModel: vm,
            palette: .init(theme: .primary, scheme: .light)))
        defer { screen.close() }
        let button = try await screen.waitForButton("Handicap Settings · Off")
        XCTAssertGreaterThanOrEqual(button.accessibilityFrame.height, 44)
        screen.attach(to: self, name: "Series-Roster-Visible-Handicap-Settings")
        XCTAssertTrue(button.accessibilityActivate())
        _ = try await screen.waitForButton("Fixed")
        screen.attach(to: self, name: "Series-Roster-Opened-Handicap-Settings")
    }

    func testReviewScreenShowsMissingPlayerAndAcceptsPartialSaveWithoutCreatingRound() async throws {
        var saves: [SeriesRound] = []
        let vm = model(.off, saveRound: { saves.append($0); return .success($0) })
        let round = plannedRound()
        vm.rounds = [round]
        var draft = SeriesRoundHandicapDraft(teeBoxID: "white")
        draft.text = "17.7"
        vm.roundHandicapDrafts[round.id] = ["m1": draft]
        var created: String?
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapReviewView(viewModel: vm,
            seriesRound: round, course: course(), onRoundCreated: { created = $0 }))
        defer { screen.close() }
        _ = try await screen.waitForButton("Edit Handicaps")
        screen.attach(to: self, name: "Series-Review-Partial-Seven-Players")
        XCTAssertTrue(screen.labels.contains { $0.contains("Index 17.7 → 18 strokes") })
        screen.scrollToBottom()
        let startButton = try await screen.waitForButton("Start Round")
        XCTAssertTrue(startButton.accessibilityTraits.contains(.notEnabled))
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(created)
        XCTAssertTrue(saves.isEmpty, "Start must revalidate before any persistence or creation")
        let saveEntriesButton = try await screen.waitForButton("Save Entries")
        XCTAssertTrue(saveEntriesButton.accessibilityActivate())
        for _ in 0..<30 { if !saves.isEmpty { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(saves.count, 1)
        XCTAssertEqual(saves.first?.handicapInputs["m1"]?.value, 17.7)
        XCTAssertEqual(saves.first?.handicapInputs.count, 1)
        XCTAssertNil(created)
    }

    func testMixedInputsUsePlayedHoleBasisWithoutChangingLegacySeriesStrokeAllocation() throws {
        let vm = model(.fixed)
        var round = plannedRound()
        round.roundConfig.handicapEntryFormat = .strokes
        round.roundConfig.handicapStrokeBasis = .nineHole
        round.handicapInputs = ["m1": .init(method: .strokes, value: 13, teeBoxID: "white"),
                                "m2": .init(method: .personalIndex, value: 18, teeBoxID: "white")]
        vm.memberHandicaps["m3"] = .init(memberID: "m3", computedIndex: 8)
        let payload = SeriesRoundCreationMapping.buildParticipantPayloads(
            members: Array(vm.members.prefix(3)), roundID: round.id, teamMappings: [:], memberAssignments: [:],
            handicaps: vm.memberHandicaps, courseSegment: course(), handicapEntryFormat: .strokes,
            handicapStrokeBasis: .nineHole, roundHandicapInputs: round.handicapInputs,
            roundScoringStrokeBasis: .nineHole, hostPlayerID: nil)
        let configuration = SeriesRoundCreationMapping.roundConfiguration(series: vm.series, seriesRound: round,
            courseSegment: course(), competitionScope: .field)
        let basis = configuration.resolvedHandicapStrokeBasis(holeCount: 18)
        XCTAssertEqual(basis, .eighteenHole)
        XCTAssertEqual(payload.map(\.adjustedHandicap), [13, 18, 16])
        let expected = [13, 18, 16]
        let holes = course().courseInfo.tees[0].holes
        for (i, participant) in payload.enumerated() {
            let allocated = holes.reduce(0) { total, hole in
                total + ScoringEngine.strokesReceived(handicap: participant.adjustedHandicap,
                    holeNumber: hole.number, holes: holes, playedHoleNumbers: Array(1...18),
                    useHandicaps: true, handicapStrokeBasis: basis)
            }
            XCTAssertEqual(allocated, expected[i])
            XCTAssertEqual(72 - allocated, 72 - expected[i], "Net totals must reflect the exact saved round allowance")
        }
        XCTAssertEqual(vm.memberHandicaps["m3"]?.computedIndex, 8)
    }

    func testUnfinishedEntrySurvivesLeavingSeriesAndIsIsolatedByAccount() throws {
        let suite = "SeriesHandicapDraftTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = SeriesViewModel(handicapDraftDefaults: defaults)
        vm.series = model(.off).series
        vm.currentUserID = "owner"
        vm.members = members()
        let round = plannedRound()
        vm.rounds = [round]
        var draft = SeriesRoundHandicapDraft(teeBoxID: "blue")
        draft.text = "unfinished 17."
        vm.setHandicapDraft(draft, memberID: "m7", roundID: round.id)
        let reopened = SeriesViewModel(handicapDraftDefaults: defaults)
        reopened.series = vm.series
        reopened.members = members()
        reopened.currentUserID = "owner"
        XCTAssertEqual(reopened.handicapDraft(for: reopened.members[6], round: round, course: course()), draft)
        reopened.currentUserID = "another-account"
        XCTAssertTrue(reopened.handicapDraft(for: reopened.members[6], round: round, course: course()).text.isEmpty)
    }

    func testRoundSetupHandicapBadgeOpensSettingsForNewAndExistingRound() async throws {
        for existingRound in [false, true] {
            var saves = 0
            let vm = model(.off, saveSeries: { saves += 1; return .success($0) })
            let round = plannedRound()
            vm.rounds = [round]
            let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapParticipationCard(
                viewModel: vm, seriesRound: existingRound ? round : nil,
                selectedTemplateID: FormatTemplateRegistry.strokePlay.id,
                countsTowardHandicapPool: .constant(true), excludedHandicapMemberIDs: .constant(["m2"])))
            defer { screen.close() }
            let settings = try await screen.waitForButton("Handicap Settings · Off")
            XCTAssertGreaterThanOrEqual(settings.accessibilityFrame.height, 44)
            XCTAssertTrue(settings.accessibilityActivate())
            let fixed = try await screen.waitForButton("Fixed")
            XCTAssertTrue(fixed.accessibilityActivate())
            let save = try await screen.waitForButton("Save")
            XCTAssertTrue(save.accessibilityActivate())
            _ = try await screen.waitForButton("Handicap Settings · Fixed")
            XCTAssertEqual(saves, 1)
            XCTAssertEqual(vm.series.handicapConfig.mode, .fixed)
            XCTAssertEqual(vm.rounds, [round], "Changing series mode must preserve the round draft and not start it")
            screen.attach(to: self, name: existingRound ? "Edit-Round-Handicap-Badge-Enabled" : "New-Round-Handicap-Badge-Enabled")
            screen.close()
        }
    }

    func testRoundSetupHandicapBadgeRemainsReadOnlyForNonCommissioner() async throws {
        let vm = model(.off)
        vm.currentUserID = "user1"
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapParticipationCard(
            viewModel: vm, seriesRound: plannedRound(), selectedTemplateID: FormatTemplateRegistry.strokePlay.id,
            countsTowardHandicapPool: .constant(true), excludedHandicapMemberIDs: .constant([])))
        defer { screen.close() }
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(screen.labels.contains("SERIES HANDICAPS"))
        XCTAssertTrue(screen.labels.contains("OFF"))
        XCTAssertFalse(screen.labels.contains("Handicap Settings · Off"))
        XCTAssertEqual(vm.series.handicapConfig.mode, .off)
    }

    func testReviewShowsPlayerIndexAlongsideCourseHandicapAndStrokes() async throws {
        let vm = model(.fixed)
        vm.members = [vm.members[0]]
        vm.memberHandicaps = ["m1": .init(memberID: "m1", overrideIndex: 17.7, isOverridden: true)]
        let round = plannedRound()
        vm.rounds = [round]
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapReviewView(viewModel: vm,
            seriesRound: round, course: course(), onRoundCreated: { _ in XCTFail("Review must not create a round") }))
        defer { screen.close() }
        _ = try await screen.waitForButton("Handicap Settings")
        screen.scrollToBottom()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(screen.labels.contains("Index 17.7 → 18 strokes"))
        XCTAssertFalse(screen.labels.contains { $0.contains("Course HCP 18 · Strokes Received 18") })
        screen.attach(to: self, name: "Series-Review-Index-Course-HCP-Strokes")
    }

    func testReviewNeverDisplaysLegacyStrokeAllowanceAsAnIndex() async throws {
        let vm = model(.fixed)
        vm.members = [vm.members[0]]
        vm.series.handicapConfig.entryFormat = .strokes
        vm.memberHandicaps = ["m1": .init(memberID: "m1", overrideIndex: 17.7, isOverridden: true)]
        var round = plannedRound()
        round.roundConfig.handicapEntryFormat = .strokes
        vm.rounds = [round]
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapReviewView(viewModel: vm,
            seriesRound: round, course: course(), onRoundCreated: { _ in XCTFail("Review must not create a round") }))
        defer { screen.close() }
        _ = try await screen.waitForButton("Handicap Settings")
        screen.scrollToBottom()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(screen.labels.contains("18 strokes · Series"))
        XCTAssertFalse(screen.labels.contains { $0.contains("Index 17.7") })
    }

    func testEveryoneReadyUsesCompactConfirmationAndOptionalEditor() async throws {
        let vm = model(.fixed)
        vm.members = Array(vm.members.prefix(3)) + [vm.members[6]]
        vm.memberHandicaps = Dictionary(uniqueKeysWithValues: vm.members.map {
            ($0.id, .init(memberID: $0.id, computedIndex: 17))
        })
        var round = plannedRound()
        round.handicapInputs["m3"] = .init(method: .strokes, value: 12, teeBoxID: "white")
        round.handicapInputs["m7"] = .init(method: .personalIndex, value: 8, teeBoxID: "white")
        vm.rounds = [round]
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapReviewView(viewModel: vm,
            seriesRound: round, course: course(), onRoundCreated: { _ in XCTFail("No start was requested") }))
        defer { screen.close() }
        _ = try await screen.waitForButton("Edit Handicaps")
        XCTAssertTrue(screen.labels.contains("Ready to Start"))
        XCTAssertTrue(screen.labels.contains("4 of 4 players ready"))
        XCTAssertFalse(screen.labels.contains { $0.hasPrefix("Entry method") })
        XCTAssertFalse(screen.hasIdentifier("series.handicap.m2.value"))
        XCTAssertFalse(screen.labels.contains("Save Entries"))
        let start = try await screen.waitForButton("Start Round")
        XCTAssertFalse(start.accessibilityTraits.contains(.notEnabled))
        screen.attach(to: self, name: "Streamlined-Ready-Confirmation")
        XCTAssertTrue(try screen.button("Edit Player 1").accessibilityActivate())
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(screen.labels.contains("Done editing Player 1"))
        XCTAssertEqual(screen.labels.filter { $0.hasPrefix("Entry method") }.count, 1)
        screen.attach(to: self, name: "Streamlined-Optional-Player-Editor")
    }

    func testOnlyMissingOfflinePlayerExpandsAndReadinessUpdatesInline() async throws {
        let vm = model(.off)
        vm.members = [vm.members[0], vm.members[6]]
        var round = plannedRound()
        round.handicapInputs["m1"] = .init(method: .strokes, value: 12, teeBoxID: "white")
        vm.rounds = [round]
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapReviewView(viewModel: vm,
            seriesRound: round, course: course(), onRoundCreated: { _ in XCTFail("Incomplete setup must not start") }))
        defer { screen.close() }
        _ = try await screen.waitForButton("Edit Handicaps")
        XCTAssertTrue(screen.labels.contains("Handicap Setup Needed"))
        XCTAssertTrue(screen.labels.contains("1 of 2 players need attention"))
        XCTAssertFalse(screen.hasIdentifier("series.handicap.m1.method"))
        let field = try screen.field("series.handicap.m7.value")
        field.text = "0.0"
        field.sendActions(for: .editingChanged)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(vm.handicapReadiness(for: round, course: course()).isReady)
        XCTAssertTrue(screen.labels.contains("Ready to Start"))
        XCTAssertTrue(screen.labels.contains("Index 0.0 → 0 strokes"))
        XCTAssertEqual(vm.rounds[0].handicapInputs.count, 1, "Typing is round-local draft state")
        screen.attach(to: self, name: "Streamlined-Missing-Player-Resolved-Inline")
    }

    func testReadinessUsesMixedSavedInputsZerosAndSelectedTeesInEverySeriesMode() throws {
        for mode in SeriesHandicapMode.allCases {
            let vm = model(mode)
            for segment in [HoleSegment.front9, .back9, .full18] {
                var round = plannedRound()
                round.handicapInputs = Dictionary(uniqueKeysWithValues: vm.members.enumerated().map { i, member in
                    (member.id, .init(method: i.isMultiple(of: 2) ? .personalIndex : .strokes,
                                     value: i < 2 ? 0 : 18, teeBoxID: i == 6 ? "blue" : "white"))
                })
                let reopened = try JSONDecoder().decode(SeriesRound.self, from: JSONEncoder().encode(round))
                let ready = vm.handicapReadiness(for: reopened, course: course(segment))
                XCTAssertTrue(ready.isReady)
                XCTAssertEqual(ready.readyCount, 7)
                XCTAssertEqual(ready.players[0].strokes, 0)
                XCTAssertEqual(ready.players[1].strokes, 0)
                XCTAssertEqual(ready.players[0].source, "Personal Index")
                XCTAssertEqual(ready.players[1].source, "Manual Strokes")
                XCTAssertEqual(ready.players[6].resolution.tee?.id, "blue")
                XCTAssertEqual(ready.players[6].strokes, segment == .full18 ? 22 : 11)
                XCTAssertEqual(reopened.handicapInputs, round.handicapInputs)
            }
        }
    }

    func testTeeDataIssuesAreSeparateFromMissingIndexAndManualStrokesNeedNoRatings() {
        let vm = model(.off)
        vm.members = Array(vm.members.prefix(2))
        var round = plannedRound()
        round.handicapInputs = ["m1": .init(method: .personalIndex, value: 0, teeBoxID: "white"),
                                "m2": .init(method: .strokes, value: 0, teeBoxID: "white")]
        for rating in [0.0, Double.nan] {
            var invalidCourse = course()
            let tee = invalidCourse.courseInfo.tees[0]
            invalidCourse.courseInfo.tees[0] = Tee(id: tee.id, name: tee.name, gender: tee.gender,
                totalHoles: tee.totalHoles, holes: tee.holes, ratingFull: rating, slopeFull: 0,
                ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
            let ready = vm.handicapReadiness(for: round, course: invalidCourse)
            XCTAssertEqual(ready.affectedMemberIDs, ["m1"])
            XCTAssertTrue(ready.players[0].issueSummary.contains("tee data"))
            XCTAssertFalse(ready.players[0].issueSummary.contains("Enter a valid"))
            XCTAssertEqual(Set(ready.players[0].issue?.missingFields ?? []), ["course rating", "slope rating"])
            XCTAssertTrue(ready.players[1].isReady, "Manual strokes require playable holes, not rating/slope")
        }
        var missingTee = round
        missingTee.handicapInputs["m2"]?.teeBoxID = "deleted-tee"
        XCTAssertEqual(vm.handicapReadiness(for: missingTee, course: course()).affectedMemberIDs, ["m2"])
    }

    func testGrossBasisPreservesUpstreamOptionalHandicapPreflightAndNetRequiresInput() {
        let vm = model(.off)
        vm.members = [vm.members[0]]
        var round = plannedRound()
        round.roundConfig.handicapEntryFormat = .strokes
        round.roundConfig.scoreBasisOverride = .gross
        var ready = vm.handicapReadiness(for: round, course: course())
        XCTAssertTrue(ready.isReady)
        XCTAssertNil(ready.players[0].strokes, "Absent optional handicaps must never be represented as zero")
        XCTAssertEqual(ready.players[0].summary, "No handicap set · Gross scoring")
        var invalidCourse = course()
        invalidCourse.courseInfo.tees = []
        XCTAssertTrue(vm.handicapReadiness(for: round, course: invalidCourse).isReady,
            "Gross competition must preserve the upstream rule that optional handicap metadata does not block start")
        round.roundConfig.scoreBasisOverride = .net
        ready = vm.handicapReadiness(for: round, course: course())
        XCTAssertFalse(ready.isReady)
        XCTAssertTrue(ready.players[0].issueSummary.contains("Enter a valid"))
    }

    func testInvalidDraftCannotReuseSavedAllowanceOrOverwriteItOnReopen() {
        let vm = model(.fixed)
        vm.members = [vm.members[0]]
        var round = plannedRound()
        round.handicapInputs["m1"] = .init(method: .strokes, value: 12, teeBoxID: "blue")
        var draft = vm.handicapDraft(for: vm.members[0], round: round, course: course())
        draft.text = "oops"
        vm.setHandicapDraft(draft, memberID: "m1", roundID: round.id)
        XCTAssertEqual(vm.handicapReadiness(for: round, course: course()).affectedMemberIDs, ["m1"])
        XCTAssertEqual(vm.handicapDraft(for: vm.members[0], round: round, course: course()), draft)
        XCTAssertEqual(round.handicapInputs["m1"]?.value, 12)
        XCTAssertEqual(round.handicapInputs["m1"]?.teeBoxID, "blue")
        // Clear this test's persistent draft; persistence isolation is exercised separately.
        vm.roundHandicapDrafts = [:]
    }

    func testReadySeriesStrokeSummaryShowsPlayedHoleAllowanceWithoutInventingIndex() {
        let vm = model(.fixed)
        vm.members = [vm.members[0]]
        vm.memberHandicaps["m1"] = .init(memberID: "m1", computedIndex: 18)
        var round = plannedRound()
        round.roundConfig.handicapEntryFormat = .strokes
        round.roundConfig.handicapStrokeBasis = .eighteenHole
        let ready = vm.handicapReadiness(for: round, course: course(.front9))
        XCTAssertEqual(ready.players[0].summary, "9 strokes · Series")
        XCTAssertNil(ready.players[0].maximumSummary)
    }

    func testReadySummaryPreservesOriginalIndexAndAppliedMaximum() {
        let vm = model(.fixed)
        vm.members = [vm.members[0]]
        vm.series.handicapConfig.config.maximumHandicap = 21
        vm.memberHandicaps["m1"] = .init(memberID: "m1", computedIndex: 30)
        let ready = vm.handicapReadiness(for: plannedRound(), course: course())
        XCTAssertEqual(ready.players[0].summary, "Index 30.0 → 21 strokes")
        XCTAssertTrue(ready.players[0].maximumSummary?.contains("Original Index 30.0") == true)
        XCTAssertTrue(ready.players[0].maximumSummary?.contains("maximum 21") == true)
    }

    func testBusyStartedAndCompletedRoundsRejectSetupAndDuplicateStartBeforeAnyWrites() async {
        var writes = 0
        let vm = model(.fixed, saveRound: { writes += 1; return .success($0) })
        let round = plannedRound()
        vm.rounds = [round]
        vm.creatingRoundID = round.id
        let busySave = await vm.saveRoundHandicapSetup(round)
        let duplicate = await vm.createLiveRound(from: round, courseSegment: course())
        XCTAssertFalse(busySave)
        XCTAssertNil(duplicate)
        XCTAssertEqual(vm.creatingRoundID, round.id)
        vm.creatingRoundID = nil
        for status in [SeriesRoundStatus.live, .complete] {
            vm.rounds[0].status = status
            vm.rounds[0].roundID = "existing-round"
            let saved = await vm.saveRoundHandicapSetup(round)
            let created = await vm.createLiveRound(from: round, courseSegment: course())
            XCTAssertFalse(saved)
            XCTAssertNil(created)
        }
        XCTAssertEqual(writes, 0)
    }

    func testReadinessRespectsSubstitutionAndAttendanceExclusions() {
        let vm = model(.off)
        vm.members = [vm.members[0], vm.members[1], vm.members[6]]
        vm.members[2].role = .substitute
        vm.series.settings.isAttendanceEnabled = true
        var round = plannedRound()
        round.plannedTeeGroups = [.init(id: "sub-group", seats: [
            .init(memberID: "m7", teeOrder: 1, isSubstitute: true, substituteForSeriesMemberID: "m1")
        ])]
        round.handicapInputs["m7"] = .init(method: .strokes, value: 12, teeBoxID: "white")
        vm.attendanceByRound[round.id] = [
            .init(memberID: "m1", status: SeriesRoundAttendanceStatus.no.rawValue),
            .init(memberID: "m2", status: SeriesRoundAttendanceStatus.no.rawValue)
        ]
        let ready = vm.handicapReadiness(for: round, course: course())
        XCTAssertEqual(ready.players.map(\.id), ["m7"])
        XCTAssertTrue(ready.isReady)
    }

    func testStaleSetupCannotReplaceSavedCourseOrScoringOptions() async {
        var writes = 0
        let vm = model(.fixed, saveRound: { writes += 1; return .success($0) })
        let stale = plannedRound()
        var current = stale
        current.lastUpdatedAt = Time(for: Date(timeIntervalSince1970: stale.lastUpdatedAt.unix + 10))
        current.roundConfig.scoreBasisOverride = .gross
        current.courseOverride = .init(courseID: "chosen-course", cachedName: "Chosen Course",
            defaultTeeBoxID: "blue", holeSegment: .back9)
        vm.rounds = [current]
        let saved = await vm.saveRoundHandicapSetup(stale)
        XCTAssertFalse(saved)
        XCTAssertEqual(writes, 0)
        XCTAssertEqual(vm.rounds, [current])
    }

    func testSavedAndNewCoursePathsBothPresentCompactReadyConfirmation() async throws {
        for savedCourse in [true, false] {
            let vm = model(.off)
            vm.members = [vm.members[0]]
            var round = plannedRound()
            round.handicapInputs["m1"] = .init(method: .personalIndex, value: 18, teeBoxID: "blue")
            vm.rounds = [round]
            let selectedCourse = course(.back9)
            if savedCourse { vm.roundSetupCourses[round.id] = selectedCourse }
            let selection = CourseSelectionViewModel()
            let app = AppSession(restoresAuthentication: false)
            let screen = try SeriesAuditHostedScreen(CourseSelectionForSeriesRoundSheet(
                viewModel: vm, seriesRound: round, reviewSavedCourse: savedCourse,
                courseViewModel: selection, onRoundCreated: { _ in XCTFail("Confirmation must await Start") })
                .environmentObject(app).environmentObject(LocationService()).environmentObject(RoundSession()))
            defer { screen.close() }
            if !savedCourse {
                for _ in 0..<30 {
                    if selection.onSetSeriesRoundCourse != nil { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let choose = try XCTUnwrap(selection.onSetSeriesRoundCourse)
                choose(selectedCourse)
            }
            _ = try await screen.waitForButton("Edit Handicaps")
            XCTAssertTrue(screen.labels.contains("Ready to Start"))
            XCTAssertTrue(screen.labels.contains("Audit Course · 9 Holes"))
            XCTAssertTrue(screen.labels.contains("Index 18.0 → 11 strokes"))
            XCTAssertFalse(screen.labels.contains { $0.hasPrefix("Entry method") })
            XCTAssertEqual(vm.roundSetupCourses[round.id], selectedCourse)
            XCTAssertEqual(vm.rounds[0], round)
            screen.attach(to: self, name: savedCourse ? "Streamlined-Saved-Course" : "Streamlined-New-Course")
            screen.close()
        }
    }

    func testFieldNormalizedSummaryLabelsCourseHandicapAndActualStrokesSeparately() {
        let vm = model(.fixed)
        vm.series.settings.isAttendanceEnabled = false
        vm.members = Array(vm.members.prefix(2))
        vm.memberHandicaps = ["m1": .init(memberID: "m1", computedIndex: 12),
                              "m2": .init(memberID: "m2", computedIndex: 18)]
        var round = plannedRound()
        round.roundConfig.handicapNormalizationMode = .field
        let ready = vm.handicapReadiness(for: round, course: course())
        XCTAssertEqual(ready.players.map(\.strokes), [0, 6])
        XCTAssertEqual(ready.players[1].summary, "Index 18.0 → 6 strokes")
        XCTAssertTrue(ready.players[1].allocationSummary?.contains("Course Handicap 18") == true)
        XCTAssertTrue(ready.players[1].allocationSummary?.contains("field normalization") == true)
        XCTAssertEqual(vm.memberHandicaps["m2"]?.computedIndex, 18)
    }

    func testInvalidTextRetainsSelectedTeeValidationAndManualSource() {
        let vm = model(.off)
        vm.members = [vm.members[0]]
        var draft = SeriesRoundHandicapDraft(teeBoxID: "deleted-tee")
        draft.method = .strokes
        draft.text = "oops"
        let ready = SeriesRoundHandicapSetup.readiness(series: vm.series, round: plannedRound(),
            members: vm.members, handicaps: [:], course: course(), drafts: ["m1": draft])
        XCTAssertFalse(ready.isReady)
        XCTAssertEqual(ready.players[0].source, "Manual Strokes")
        XCTAssertTrue(ready.players[0].issueSummary.contains("Enter a valid"))
        XCTAssertTrue(ready.players[0].issueSummary.contains("tee data"))
        XCTAssertNil(ready.players[0].strokes)
    }

    func testCompactConfirmationSaveKeepsCustomInputsCourseAndInheritedScoringBasis() async throws {
        var saves: [SeriesRound] = []
        let vm = model(.fixed, saveRound: { saves.append($0); return .success($0) })
        vm.members = [vm.members[0]]
        var round = plannedRound()
        round.roundConfig.scoreBasisOverride = nil
        round.handicapInputs["m1"] = .init(method: .strokes, value: 12, teeBoxID: "blue")
        round.courseOverride = .init(courseID: "course", cachedName: "Audit Course",
            defaultTeeBoxID: "white", defaultTeeName: "White", defaultTeeGender: "male", holeSegment: .back9)
        vm.rounds = [round]
        let screen = try SeriesAuditHostedScreen(SeriesRoundHandicapReviewView(viewModel: vm,
            seriesRound: round, course: course(.back9), onRoundCreated: { _ in XCTFail("Save must not start") }))
        defer { screen.close() }
        let edit = try await screen.waitForButton("Edit Handicaps")
        XCTAssertTrue(edit.accessibilityActivate())
        try await Task.sleep(for: .milliseconds(200))
        screen.scrollToBottom()
        let save = try await screen.waitForButton("Save Entries")
        XCTAssertTrue(save.accessibilityActivate())
        for _ in 0..<30 { if !saves.isEmpty { break }; try await Task.sleep(for: .milliseconds(100)) }
        let saved = try XCTUnwrap(saves.first)
        XCTAssertEqual(saved.handicapInputs, round.handicapInputs)
        XCTAssertEqual(saved.courseOverride, round.courseOverride)
        XCTAssertNil(saved.roundConfig.scoreBasisOverride, "An untouched inherited basis must remain inherited")
    }

    private func plannedRound() -> SeriesRound {
        SeriesRound(id: "audit-round", roundConfig: .init(scoreBasisOverride: .net,
            handicapEntryFormat: .courseHandicap), parentID: "audit-trip")
    }

    private func assertSevenMissing(_ mode: SeriesHandicapMode, file: StaticString = #filePath, line: UInt = #line) {
        let vm = model(mode)
        vm.recomputeAllHandicaps()
        let issues = SeriesCourseHandicapResolver.validationIssues(
            members: vm.members, handicaps: vm.memberHandicaps, courseSegment: course(),
            entryFormat: .courseHandicap, handicapStrokeBasis: vm.series.handicapConfig.strokeBasis,
            maximumHandicap: mode.isEnabled ? vm.series.handicapConfig.config.maximumHandicap : nil)
        XCTAssertEqual(issues.count, 7, file: file, line: line)
        XCTAssertEqual(Set(issues.map(\.memberID)), Set(vm.members.map(\.id)), file: file, line: line)
        XCTAssertTrue(issues.allSatisfy { $0.missingFields == ["handicap index"] }, file: file, line: line)
        let alert = SeriesRoundCreationFailure.invalidCourseHandicaps(issues).message
        XCTAssertTrue(vm.members.allSatisfy { alert.contains($0.name.fullName) }, file: file, line: line)
        XCTAssertEqual(vm.members.filter(\.isOffline).count, 3, file: file, line: line)
    }

    private func model(_ mode: SeriesHandicapMode,
                       saveSeries: ((Series) async -> Result<Series, Error>)? = nil,
                       saveRound: ((SeriesRound) async -> Result<SeriesRound, Error>)? = nil) -> SeriesViewModel {
        let defaults = UserDefaults(suiteName: "SeriesStartAudit." + UUID().uuidString)!
        let vm = SeriesViewModel(persistHandicapSettings: saveSeries, persistRoundHandicaps: saveRound,
                                 handicapDraftDefaults: defaults)
        var settings = SeriesSettings(experiencePreset: .trip, useTeams: false)
        settings.handicapConfig = .init(mode: mode, strokeBasis: .eighteenHole, entryFormat: .courseHandicap)
        vm.series = Series(id: "audit-trip", name: "Andrew's golf trip — local fixture", commissionerUserID: "owner", settings: settings)
        vm.currentUserID = "owner"
        vm.members = members()
        return vm
    }

    private func members() -> [SeriesMember] {
        (1...7).map {
            SeriesMember(id: "m\($0)", userID: $0 <= 4 ? "user\($0)" : nil,
                         playerID: "player\($0)", name: Name("Player \($0)"), parentID: "audit-trip")
        }
    }

    private func participants(_ vm: SeriesViewModel, format: HandicapEntryFormat,
                              segment: HoleSegment = .full18, maximum: Int? = nil,
                              inputs: [String: SeriesRoundHandicapInput] = [:]) -> [RoundParticipant] {
        SeriesRoundCreationMapping.buildParticipantPayloads(
            members: vm.members, roundID: "audit-round", teamMappings: [:], memberAssignments: [:],
            handicaps: vm.memberHandicaps, maximumHandicap: maximum, courseSegment: course(segment),
            handicapEntryFormat: format, handicapStrokeBasis: .eighteenHole, roundHandicapInputs: inputs, hostPlayerID: nil)
    }

    private func course(_ segment: HoleSegment = .full18) -> CourseSegment {
        let holes = (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) }
        let white = Tee(id: "white", name: "White", gender: "male", totalHoles: 18,
                        holes: holes, ratingFull: 72, slopeFull: 113,
                        ratingFront: 36, slopeFront: 113, ratingBack: 36, slopeBack: 113)
        let blue = Tee(id: "blue", name: "Blue", gender: "male", totalHoles: 18,
                       holes: holes, ratingFull: 74, slopeFull: 125,
                       ratingFront: 37, slopeFront: 125, ratingBack: 37, slopeBack: 125)
        return CourseSegment(courseInfo: .init(id: "course", name: "Audit Course", totalHoles: 18, tees: [white, blue]),
                             holeRange: segment.holeRange, defaultTee: "white")
    }
}

@MainActor
private final class SeriesAuditHostedScreen {
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
        window.rootViewController?.view.frame = window.bounds
        window.rootViewController?.view.layoutIfNeeded()
        window.layoutIfNeeded()
    }
    func close() { window.isHidden = true; previous?.makeKeyAndVisible() }
    private func nodes() -> [NSObject] {
        var visited: Set<ObjectIdentifier> = []
        func visit(_ object: NSObject, _ depth: Int = 0) -> [NSObject] {
            guard depth < 24, visited.insert(ObjectIdentifier(object)).inserted else { return [] }
            var result = [object]
            if let view = object as? UIView { result += view.subviews.flatMap { visit($0, depth + 1) } }
            let count = object.accessibilityElementCount()
            if count > 0 && count < 500 {
                for i in 0..<count {
                    if let child = object.accessibilityElement(at: i) as? NSObject { result += visit(child, depth + 1) }
                }
            }
            return result
        }
        return visit(window)
    }
    var labels: [String] { nodes().compactMap(\.accessibilityLabel) }
    func hasIdentifier(_ id: String) -> Bool { nodes().contains { ($0 as? UIAccessibilityIdentification)?.accessibilityIdentifier == id } }
    func field(_ id: String) throws -> UITextField {
        try XCTUnwrap(nodes().compactMap { $0 as? UITextField }.first { $0.accessibilityIdentifier == id })
    }
    func waitForButton(_ label: String) async throws -> NSObject {
        for _ in 0..<40 {
            if let button = nodes().first(where: { $0.accessibilityLabel == label && $0.accessibilityTraits.contains(.button) }) { return button }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("UI host: bounds=\(window.bounds), subviews=\(window.subviews.count), scene=\(String(describing: window.windowScene?.activationState)), attached=\(host.view.window != nil)")
        return try button(label)
    }
    func button(_ label: String) throws -> NSObject {
        try XCTUnwrap(nodes().first { $0.accessibilityLabel == label && $0.accessibilityTraits.contains(.button) }, "Missing button \(label). Labels: \(labels.joined(separator: " | "))")
    }
    func scrollToBottom() {
        func scrolls(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrolls)
        }
        for scroll in scrolls(window) where scroll.contentSize.height > scroll.bounds.height {
            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
        }
        window.layoutIfNeeded()
    }
    func attach(to test: XCTestCase, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }
}
