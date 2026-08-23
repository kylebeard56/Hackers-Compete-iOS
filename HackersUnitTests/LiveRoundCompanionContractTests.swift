@testable import Hackers
import XCTest

final class LiveRoundCompanionContractTests: XCTestCase {
    @MainActor
    func testLiveActivityProgressCountsCompletedHoles() {
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.completionProgress(completed: 17, total: 18),
            17.0 / 18.0,
            accuracy: 0.0001
        )
        XCTAssertLessThan(
            RoundLiveActivityStateBuilder.completionProgress(completed: 17, total: 18),
            1
        )
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.completionProgress(completed: 18, total: 18),
            1
        )
    }

    @MainActor
    func testMatchupStandingIsPresentedFromCurrentUsersPerspective() {
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.matchupStanding(
                currentTotal: 5,
                opponentTotal: 7,
                isPointsFormat: false
            ),
            .init(label: "UP 2", detail: "2-stroke differential")
        )
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.matchupStanding(
                currentTotal: 7,
                opponentTotal: 5,
                isPointsFormat: false
            ),
            .init(label: "DOWN 2", detail: "2-stroke differential")
        )
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.matchupStanding(
                currentTotal: 2.5,
                opponentTotal: 2,
                isPointsFormat: true
            ),
            .init(label: "UP 0.5", detail: "0.5-point differential")
        )
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.matchupStanding(
                currentTotal: 4,
                opponentTotal: 4,
                isPointsFormat: false
            ),
            .init(label: "TIED", detail: "All square")
        )
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.matchupStanding(
                currentTotal: nil,
                opponentTotal: nil,
                isPointsFormat: false
            ),
            .init(label: "TBD", detail: "No scores entered")
        )
    }

    @MainActor
    func testLiveActivityUsesAReasonableRollingStaleWindow() {
        XCTAssertEqual(RoundLiveActivityManager.staleInterval, 20 * 60)
    }

    @MainActor
    func testFieldStandingSupportsLowestAndHighestWinsFormats() {
        let strokeCandidates: [RoundLiveActivityStateBuilder.FieldStandingCandidate] = [
            .init(id: "leader", value: -2),
            .init(id: "current", value: 0),
            .init(id: "tie", value: 0)
        ]
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.fieldStanding(
                candidates: strokeCandidates,
                currentID: "current",
                isHighestWins: false,
                unit: "stroke"
            ),
            .init(position: "T2", detail: "2 strokes back")
        )

        let pointCandidates: [RoundLiveActivityStateBuilder.FieldStandingCandidate] = [
            .init(id: "leader", value: 14),
            .init(id: "current", value: 11)
        ]
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.fieldStanding(
                candidates: pointCandidates,
                currentID: "current",
                isHighestWins: true,
                unit: "point"
            ),
            .init(position: "2", detail: "3 points back")
        )
    }

    @MainActor
    func testFieldStandingIdentifiesATiedLead() {
        let candidates: [RoundLiveActivityStateBuilder.FieldStandingCandidate] = [
            .init(id: "current", value: -3),
            .init(id: "co_leader", value: -3),
            .init(id: "third", value: -1)
        ]
        XCTAssertEqual(
            RoundLiveActivityStateBuilder.fieldStanding(
                candidates: candidates,
                currentID: "current",
                isHighestWins: false,
                unit: "stroke"
            ),
            .init(position: "T1", detail: "Tied for lead")
        )
    }

    func testLiveActivityStateDecodesWithoutNewOptionalTemplateFields() throws {
        let state = RoundLiveActivityAttributes.ContentState(
            phase: .live,
            roundTitle: "Legacy activity",
            holeLabel: "Hole 4 of 18",
            holeProgress: 3.0 / 18.0,
            hole: .init(
                number: 4,
                total: 18,
                completed: 3,
                remaining: 15,
                par: 4,
                yardage: 410
            ),
            personalScore: .init(title: "You", value: "+1", thru: "Thru 3"),
            teamScore: nil,
            matchup: nil,
            deepLinkURL: try XCTUnwrap(URL(string: "hackersgolf:///live-round?round_id=legacy")),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let decoded = try JSONDecoder().decode(
            RoundLiveActivityAttributes.ContentState.self,
            from: JSONEncoder().encode(state)
        )

        XCTAssertNil(decoded.formatLabel)
        XCTAssertNil(decoded.participantName)
        XCTAssertNil(decoded.competition)
        XCTAssertNil(decoded.grossScore)
        XCTAssertNil(decoded.isPersonalScoreCounting)
        XCTAssertNil(decoded.hole?.handicapStrokes)
        XCTAssertNil(decoded.hole?.currentScoreLabel)
    }

    func testMatchupSideDecodesWithoutCountingPlayers() throws {
        let side = RoundLiveActivityAttributes.MatchupSideSummary(
            title: "Red Team",
            score: "+2",
            winPercentage: 64,
            isCurrentUserSide: true
        )

        let decoded = try JSONDecoder().decode(
            RoundLiveActivityAttributes.MatchupSideSummary.self,
            from: JSONEncoder().encode(side)
        )

        XCTAssertNil(decoded.countingPlayers)
    }

    func testWatchSnapshotBinaryPropertyListRoundTrip() throws {
        let competition = WatchRoundSnapshot.Competition(
            kind: .matchup,
            title: "Matchups",
            formatLabel: "Best Ball · Net",
            summary: .init(
                label: "vs Blue Team",
                primary: "UP 2",
                secondary: "73% win",
                detail: "2-stroke differential"
            ),
            sections: [
                .init(
                    id: "match_1",
                    title: "Red Team vs Blue Team",
                    detail: "Red Team leads by 2 strokes",
                    isCurrentUserSection: true,
                    rows: [
                        .init(
                            id: "match_1:red",
                            position: nil,
                            title: "Red Team",
                            subtitle: "Kyle, Alex",
                            score: "+5",
                            thru: "Thru 8",
                            winPercentage: 73,
                            isCurrentUser: true
                        ),
                        .init(
                            id: "match_1:blue",
                            position: nil,
                            title: "Blue Team",
                            subtitle: "Jordan, Morgan",
                            score: "+7",
                            thru: "Thru 8",
                            winPercentage: 24,
                            isCurrentUser: false
                        )
                    ]
                )
            ]
        )
        let subject = WatchRoundSnapshot.Subject(
            id: "participant_1",
            title: "Kyle Beard",
            compactTitle: "Kyle B.",
            subtitle: "Your tee group",
            anchorParticipantID: "participant_1",
            teeGroupID: "group_1",
            holeUnits: [
                .init(
                    holeNumber: 1,
                    scoringUnitID: "participant_1",
                    participantIDs: ["participant_1"],
                    strokesReceived: 1
                )
            ]
        )
        let snapshot = WatchRoundSnapshot(
            revision: 42,
            roundID: "round_1",
            title: "Saturday Round",
            phase: .live,
            inputMode: .strokes,
            selectedHole: 1,
            holes: [.init(number: 1, par: 4, inputMinimum: 1, inputMaximum: 8)],
            subjects: [subject],
            scores: [
                .init(
                    holeNumber: 1,
                    scoringUnitID: "participant_1",
                    value: 5,
                    revision: "score:1"
                )
            ],
            competition: competition,
            additionalCompetitions: [competition],
            acknowledgedMutationIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!],
            generatedAt: Date(timeIntervalSince1970: 100)
        )

        let data = try WatchConnectivityContract.encode(snapshot)
        let decoded = try WatchConnectivityContract.decode(WatchRoundSnapshot.self, from: data)
        let legacyDecoded = try PropertyListDecoder().decode(
            LegacyWatchRoundSnapshotV1.self,
            from: data
        )

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.subjects.first?.unit(for: 1)?.scoringUnitID, "participant_1")
        XCTAssertEqual(decoded.score(for: "participant_1", holeNumber: 1)?.value, 5)
        XCTAssertEqual(decoded.subjects.first?.compactTitle, "Kyle B.")
        XCTAssertEqual(decoded.subjects.first?.unit(for: 1)?.strokesReceived, 1)
        XCTAssertEqual(decoded.holes.first?.inputMaximum, 8)
        XCTAssertEqual(decoded.competition?.summary.primary, "UP 2")
        XCTAssertEqual(decoded.competitions.count, 2)
        XCTAssertEqual(decoded.competition?.sections.first?.rows.first?.winPercentage, 73)
        XCTAssertNil(decoded.competition?.leaderboardVariants)
        XCTAssertNil(decoded.competition?.sections.first?.rows.first?.grossScore)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertTrue(WatchRoundSnapshot.supports(schemaVersion: 1))
        XCTAssertTrue(WatchRoundSnapshot.supports(schemaVersion: 2))
        XCTAssertFalse(WatchRoundSnapshot.supports(schemaVersion: 3))
        XCTAssertEqual(legacyDecoded.schemaVersion, 1)
        XCTAssertEqual(legacyDecoded.roundID, "round_1")
        XCTAssertEqual(legacyDecoded.holes.first?.par, 4)
    }

    private struct LegacyWatchRoundSnapshotV1: Decodable {
        struct Hole: Decodable {
            let number: Int
            let par: Int
        }

        let schemaVersion: Int
        let roundID: String
        let holes: [Hole]
    }

    func testWatchSnapshotDecodesLegacyPayloadWithoutCompetition() throws {
        let snapshot = WatchRoundSnapshot(
            revision: 1,
            roundID: "legacy_round",
            title: "Legacy Round",
            phase: .live,
            inputMode: .strokes,
            selectedHole: 1,
            holes: [.init(number: 1, par: 4)],
            subjects: [],
            scores: [],
            generatedAt: Date(timeIntervalSince1970: 100)
        )
        let encoded = try WatchConnectivityContract.encode(snapshot)
        var payload = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: encoded, format: nil) as? [String: Any]
        )
        payload.removeValue(forKey: "competition")
        let legacyData = try PropertyListSerialization.data(
            fromPropertyList: payload,
            format: .binary,
            options: 0
        )

        let decoded = try WatchConnectivityContract.decode(
            WatchRoundSnapshot.self,
            from: legacyData
        )

        XCTAssertNil(decoded.competition)
    }

    func testWatchCompetitionContractSupportsFieldStandings() throws {
        let competition = WatchRoundSnapshot.Competition(
            kind: .field,
            title: "Leaderboard",
            formatLabel: "Stroke Play · Gross",
            summary: .init(
                label: "Kyle",
                primary: "T3",
                secondary: "+5",
                detail: "4 strokes back · Thru 8"
            ),
            sections: [
                .init(
                    id: "field",
                    title: "Standings",
                    detail: nil,
                    isCurrentUserSection: false,
                    rows: [
                        .init(
                            id: "participant_1",
                            position: "T3",
                            title: "Kyle",
                            subtitle: nil,
                            score: "+5",
                            thru: "Thru 8",
                            winPercentage: nil,
                            isCurrentUser: true,
                            grossScore: "+9",
                            netScore: "+5",
                            handicapLabel: "HCP 12"
                        )
                    ]
                )
            ],
            leaderboardVariants: [
                .init(
                    id: "individual",
                    label: "Solo",
                    sections: [
                        .init(
                            id: "individual",
                            title: "Standings",
                            detail: nil,
                            isCurrentUserSection: false,
                            rows: [
                                .init(
                                    id: "participant_1",
                                    position: "T3",
                                    title: "Kyle",
                                    subtitle: nil,
                                    score: "+5",
                                    thru: "Thru 8",
                                    winPercentage: nil,
                                    isCurrentUser: true,
                                    grossScore: "+9",
                                    netScore: "+5",
                                    handicapLabel: "HCP 12"
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let decoded = try WatchConnectivityContract.decode(
            WatchRoundSnapshot.Competition.self,
            from: WatchConnectivityContract.encode(competition)
        )

        XCTAssertEqual(decoded.kind, .field)
        XCTAssertEqual(decoded.summary.primary, "T3")
        XCTAssertEqual(decoded.sections.first?.rows.first?.score, "+5")
        XCTAssertNil(decoded.sections.first?.rows.first?.winPercentage)
        XCTAssertEqual(decoded.sections.first?.rows.first?.grossScore, "+9")
        XCTAssertEqual(decoded.sections.first?.rows.first?.netScore, "+5")
        XCTAssertEqual(decoded.sections.first?.rows.first?.handicapLabel, "HCP 12")
        XCTAssertEqual(decoded.leaderboardVariants?.map(\.label), ["Solo"])
    }

    func testWatchCumulativeScoreUsesRelativeParUntilRoundIsComplete() {
        let subject = WatchRoundSnapshot.Subject(
            id: "p1",
            title: "Kyle",
            subtitle: "You",
            anchorParticipantID: "p1",
            teeGroupID: "group_1",
            holeUnits: [1, 2, 3, 4].map {
                .init(
                    holeNumber: $0,
                    scoringUnitID: "p1",
                    participantIDs: ["p1"],
                    strokesReceived: $0 == 4 ? 0 : 2
                )
            }
        )
        let snapshot = WatchRoundSnapshot(
            revision: 1,
            roundID: "round",
            title: "Course",
            phase: .live,
            inputMode: .strokes,
            selectedHole: 4,
            holes: [
                .init(number: 1, par: 4),
                .init(number: 2, par: 4),
                .init(number: 3, par: 5),
                .init(number: 4, par: 4)
            ],
            subjects: [subject],
            scores: []
        )
        let partialValues = [1: 8, 2: 8, 3: 8]

        XCTAssertEqual(
            snapshot.cumulativeScore(for: subject, basis: .gross) { _, hole in
                partialValues[hole]
            }.displayValue,
            "+11"
        )
        XCTAssertEqual(
            snapshot.cumulativeScore(for: subject, basis: .net) { _, hole in
                partialValues[hole]
            }.displayValue,
            "+5"
        )

        let completeValues = partialValues.merging([4: 6]) { _, replacement in replacement }
        XCTAssertEqual(
            snapshot.cumulativeScore(for: subject, basis: .gross) { _, hole in
                completeValues[hole]
            }.displayValue,
            "30"
        )
        XCTAssertEqual(
            snapshot.cumulativeScore(for: subject, basis: .net) { _, hole in
                completeValues[hole]
            }.displayValue,
            "24"
        )
    }

    @MainActor
    func testSelectedRoundStoreGreedilySelectsAndClearsEligibleRound() {
        let suiteName = "LiveRoundCompanionContractTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SelectedLiveRoundStore(defaults: defaults)

        store.reconcile(eligibleRoundIDs: ["round_b", "round_a"])
        XCTAssertEqual(store.roundID, "round_b")
        XCTAssertEqual(store.liveActivityRoundID, "round_b")

        store.reconcile(eligibleRoundIDs: ["round_a"])
        XCTAssertEqual(store.roundID, "round_a")
        XCTAssertEqual(store.liveActivityRoundID, "round_a")

        store.reconcile(eligibleRoundIDs: ["round_a", "round_b"])
        XCTAssertEqual(store.roundID, "round_a")

        store.reconcile(eligibleRoundIDs: [])
        XCTAssertNil(store.roundID)
    }

    @MainActor
    func testSelectedRoundStorePersistsOneRoundForWatchAndLiveActivity() {
        let suiteName = "LiveRoundCompanionPreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SelectedLiveRoundStore(defaults: defaults)
        XCTAssertNil(store.roundID)
        XCTAssertNil(store.liveActivityRoundID)

        store.select("watch_round")
        store.selectLiveActivity(roundID: "activity_round")

        let restored = SelectedLiveRoundStore(defaults: defaults)
        XCTAssertEqual(restored.roundID, "activity_round")
        XCTAssertEqual(restored.liveActivityRoundID, "activity_round")

        store.select(nil)
        XCTAssertNil(store.roundID)
        XCTAssertNil(store.liveActivityRoundID)
    }

    @MainActor
    func testSelectedRoundStoreMigratesEnabledLegacyActivity() {
        let suiteName = "LiveRoundCompanionMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("round_1", forKey: "selected_live_round_for_watch_v1")
        defaults.set(true, forKey: "live_round_activity_enabled_v1")

        let store = SelectedLiveRoundStore(defaults: defaults)
        XCTAssertEqual(store.roundID, "round_1")
        XCTAssertEqual(store.liveActivityRoundID, "round_1")
        XCTAssertNil(defaults.object(forKey: "live_round_activity_enabled_v1"))

        store.selectLiveActivity(roundID: nil)
        let restored = SelectedLiveRoundStore(defaults: defaults)
        XCTAssertNil(restored.roundID)
        XCTAssertNil(restored.liveActivityRoundID)
    }

    func testSubjectBuilderLimitsIndividualScoringToActualTeeGroup() throws {
        var snapshot = MockLiveRound2v2.snapshot
        snapshot.participants[3].groupID = "group_2"
        let projection = try RoundScoringSubjectBuilder().build(
            snapshot: snapshot,
            participantID: "participant_1",
            nameDisplayFormat: .firstInitialLastName,
            generatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(projection.roundID, MockLiveRound2v2.roundID)
        XCTAssertEqual(projection.subjects.map(\.anchorParticipantID), [
            "participant_1",
            "participant_2",
            "participant_3"
        ])
        XCTAssertEqual(projection.subjects.first?.subtitle, "You")
        XCTAssertEqual(projection.subjects.first?.title, "John Smith")
        XCTAssertEqual(projection.subjects.first?.compactTitle, "J. Smith")
        XCTAssertNotNil(projection.holes.first?.inputMinimum)
        XCTAssertNotNil(projection.holes.first?.inputMaximum)
        XCTAssertNotNil(projection.subjects.first?.holeUnits.first?.strokesReceived)
        XCTAssertEqual(projection.selectedHole, 1)
    }

    @MainActor
    func testWatchFieldProjectionIncludesLeaderboardGroupingAndScoreContext() throws {
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: MockLiveRound2v2.snapshot)

        let competitions = WatchCompetitionProjectionBuilder().build(
            viewModel: viewModel,
            participantID: "participant_1",
            nameDisplayFormat: .firstNameLastInitial
        )
        let field = try XCTUnwrap(competitions.first { $0.kind == .field })
        let variants = try XCTUnwrap(field.leaderboardVariants)
        let solo = try XCTUnwrap(variants.first { $0.id == "individual" })
        let team = try XCTUnwrap(variants.first { $0.id == "team" })
        let currentUser = try XCTUnwrap(
            solo.sections.flatMap(\.rows).first { $0.isCurrentUser }
        )

        XCTAssertEqual(variants.map(\.label), ["Solo", "Team"])
        XCTAssertEqual(Set(team.sections.map(\.title)), Set(["Red Team", "Blue Team"]))
        XCTAssertEqual(currentUser.handicapLabel, "HCP 5")
        XCTAssertNotNil(currentUser.grossScore)
        XCTAssertNotNil(currentUser.netScore)
    }

    @MainActor
    func testWatchFieldProjectionRemainsAvailableForMatchupCompetitionScope() throws {
        var snapshot = MockLiveRound2v2.snapshot
        snapshot.round.configuration.competitionScope = .matchup

        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)

        let competitions = WatchCompetitionProjectionBuilder().build(
            viewModel: viewModel,
            participantID: "participant_1",
            nameDisplayFormat: .firstNameLastInitial
        )
        let field = try XCTUnwrap(competitions.first { $0.kind == .field })
        let individual = try XCTUnwrap(
            field.leaderboardVariants?.first { $0.id == "individual" }
        )
        let rows = individual.sections.flatMap(\.rows)

        XCTAssertEqual(rows.count, snapshot.participants.count)
        XCTAssertTrue(rows.contains { $0.isCurrentUser })
        XCTAssertTrue(rows.allSatisfy { $0.grossScore != nil && $0.netScore != nil })
    }

    func testPresentationEqualityIgnoresTransportTimestamp() {
        let subject = WatchRoundSnapshot.Subject(
            id: "participant_1",
            title: "Kyle",
            subtitle: "You",
            anchorParticipantID: "participant_1",
            teeGroupID: "group_1",
            holeUnits: [
                .init(
                    holeNumber: 1,
                    scoringUnitID: "participant_1",
                    participantIDs: ["participant_1"]
                )
            ]
        )
        let makeSnapshot: (Date) -> WatchRoundSnapshot = { generatedAt in
            WatchRoundSnapshot(
                revision: 1,
                roundID: "round_1",
                title: "Saturday Round",
                phase: .live,
                inputMode: .strokes,
                selectedHole: 1,
                holes: [.init(number: 1, par: 4)],
                subjects: [subject],
                scores: [],
                generatedAt: generatedAt
            )
        }

        XCTAssertTrue(
            makeSnapshot(Date(timeIntervalSince1970: 1)).hasSamePresentation(
                as: makeSnapshot(Date(timeIntervalSince1970: 2))
            )
        )
    }

    func testLiveRoundDeepLinkAcceptsOnlyPopulatedRoundDestination() throws {
        let url = try XCTUnwrap(
            URL(string: "hackersgolfsandbox:///live-round?round_id=round_1&hole=7")
        )
        XCTAssertEqual(
            url.liveRoundDeepLinkPayload,
            LiveRoundDeepLinkPayload(roundID: "round_1", holeNumber: 7)
        )
        XCTAssertNil(URL(string: "hackersgolfsandbox:///live-round?round_id=%20")?.liveRoundDeepLinkPayload)
        XCTAssertNil(URL(string: "hackersgolfsandbox:///join?round_id=round_1")?.liveRoundDeepLinkPayload)
    }

    @MainActor
    func testProcessedMutationStorePersistsIdempotentAcceptedAcknowledgement() {
        let suiteName = "LiveRoundCompanionMutationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let mutationID = UUID()
        let acknowledgement = WatchScoreAcknowledgement(
            id: mutationID,
            roundID: "round_1",
            status: .accepted,
            canonicalValue: 4,
            canonicalRevision: "score:1",
            errorCategory: nil,
            message: nil,
            acknowledgedAt: Date(timeIntervalSince1970: 100)
        )
        let store = ProcessedWatchMutationStore(defaults: defaults)

        store.insert(acknowledgement)
        store.insert(acknowledgement)

        XCTAssertEqual(store.acknowledgement(for: mutationID), acknowledgement)
        XCTAssertEqual(store.acceptedMutationIDs(for: "round_1"), [mutationID])
        XCTAssertEqual(
            ProcessedWatchMutationStore(defaults: defaults).acknowledgement(for: mutationID),
            acknowledgement
        )
    }

    func testValidatorRejectsMutationBasedOnStaleScoreRevision() throws {
        var snapshot = MockLiveRound2v2.snapshot
        snapshot.scoring = [
            ScoreEntry(
                id: ScoreEntry.makeID(hole: 1, segment: "seg0", scoringUnit: "participant_1"),
                holeNumber: 1,
                segmentID: "seg0",
                groupID: "group_1",
                scoringUnitID: "participant_1",
                participantIDs: ["participant_1"],
                strokes: 4,
                entryMode: .strokes,
                entryID: "participant_1",
                createdAt: Time(iso: "2026-08-15T12:00:00Z", unix: 1_000),
                lastUpdatedAt: Time(iso: "2026-08-15T12:01:00Z", unix: 1_001),
                parentID: snapshot.round.id
            )
        ]
        let mutation = WatchScoreMutation(
            deviceSequence: 1,
            roundID: snapshot.round.id,
            holeNumber: 1,
            scoringUnitID: "participant_1",
            participantIDs: ["participant_1"],
            anchorParticipantID: "participant_1",
            operation: .set(5),
            observedScoreRevision: nil
        )

        XCTAssertThrowsError(
            try RoundScoreCommandValidator().validate(
                mutation,
                snapshot: snapshot,
                participantID: "participant_1"
            )
        ) { error in
            guard case RoundScoreCommandValidator.ValidationError.staleScore(let value, let revision) = error else {
                return XCTFail("Expected stale score, got \(error)")
            }
            XCTAssertEqual(value, 4)
            XCTAssertEqual(revision, "h1_sseg0_uparticipant_1:1001.0")
        }
    }
}
