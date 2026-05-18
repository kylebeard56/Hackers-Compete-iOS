//
//  SeriesHandicapHistoryTests.swift
//  HackersUnitTests
//

import Foundation
import Testing
@testable import Hackers

@Suite("Series handicap history")
@MainActor
struct SeriesHandicapHistoryTests {

    @Test("Legacy Firestore JSON decodes missing recorded_at, sort_order, caption")
    func legacyHandicapScoreDecode() throws {
        let json = """
        {
          "id": "h1",
          "member_id": "m1",
          "score": 42,
          "par": 36,
          "hole_segment": {"type":"front9"},
          "source": "baseline",
          "created_at": {"iso":"2024-01-01T00:00:00Z","unix":1704067200},
          "last_updated_at": {"iso":"2024-01-02T00:00:00Z","unix":1704153600},
          "parent_id": "s1"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(SeriesHandicapScore.self, from: data)

        #expect(decoded.id == "h1")
        #expect(decoded.memberID == "m1")
        #expect(decoded.score == 42)
        #expect(decoded.caption == nil)
        #expect(decoded.sortOrder == 0)
        #expect(decoded.recordedAt.unix == 1704067200)
        #expect(decoded.createdAt.unix == 1704067200)
        #expect(decoded.countsTowardHandicapIndex == true)
    }

    @Test("Baseline hole count maps front and back nine to 9 holes")
    func baselineHoleCountDisplayMapsLegacyNineHoleSegments() throws {
        let front = SeriesHandicapScore(holeSegment: .front9, source: .baseline)
        let back = SeriesHandicapScore(holeSegment: .back9, source: .baseline)
        let full = SeriesHandicapScore(holeSegment: .full18, source: .baseline)

        #expect(front.baselineStrokeBasis == .nineHole)
        #expect(back.baselineStrokeBasis == .nineHole)
        #expect(front.baselineHoleCountDisplayName == "9 holes")
        #expect(back.baselineHoleCountDisplayName == "9 holes")
        #expect(full.baselineStrokeBasis == .eighteenHole)
        #expect(full.baselineHoleCountDisplayName == "18 holes")
        #expect(SeriesHandicapStrokeBasis.nineHole.baselineStorageSegment == .front9)
        #expect(SeriesHandicapStrokeBasis.eighteenHole.baselineStorageSegment == .full18)
    }

    @Test("18-hole baseline score normalizes to 9-hole index basis")
    func eighteenHoleBaselineNormalizesForIndex() throws {
        let member = SeriesMember(
            id: "m1",
            userID: "u1",
            playerID: "p1",
            name: Name("Test", "Player"),
            role: .member,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )

        let recorded = Time(iso: "2024-01-01T00:00:00Z", unix: 100)
        let score = SeriesHandicapScore(
            id: "eighteen",
            memberID: "m1",
            score: 92,
            par: 72,
            holeSegment: .full18,
            source: .baseline,
            sourceRoundID: nil,
            caption: nil,
            recordedAt: recorded,
            sortOrder: 0,
            createdAt: recorded,
            lastUpdatedAt: recorded,
            parentID: "series1"
        )

        let viewModel = SeriesViewModel()
        viewModel.series = Series(id: "series1", commissionerUserID: "c1")
        viewModel.series.handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025)
        viewModel.members = [member]
        viewModel.handicapScores = [score]
        viewModel.recomputeAllHandicaps()

        let config = viewModel.series.handicapConfig.config.toConfig()
        let normalized = try #require(normalizedBaselineGrossForHandicapIndex(
            gross: 92,
            par: 72,
            defaultParForIndex: config.defaultParForIndex
        ))
        #expect(normalized == 46)

        let expected = computeHandicapIndex(
            samples: [HandicapScoreSample(id: "eighteen", gross: 46, recordedAt: recorded, sortOrder: 0)],
            config: config
        )
        #expect(viewModel.memberHandicaps["m1"]?.computedIndex == expected?.handicapIndex)
    }

    @Test("9-hole baseline score keeps existing gross index behavior")
    func nineHoleBaselineKeepsGrossForIndex() throws {
        let member = SeriesMember(
            id: "m1",
            userID: "u1",
            playerID: "p1",
            name: Name("Test", "Player"),
            role: .member,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )

        let recorded = Time(iso: "2024-01-01T00:00:00Z", unix: 100)
        let score = SeriesHandicapScore(
            id: "nine",
            memberID: "m1",
            score: 46,
            par: 36,
            holeSegment: .front9,
            source: .baseline,
            sourceRoundID: nil,
            caption: nil,
            recordedAt: recorded,
            sortOrder: 0,
            createdAt: recorded,
            lastUpdatedAt: recorded,
            parentID: "series1"
        )

        let viewModel = SeriesViewModel()
        viewModel.series = Series(id: "series1", commissionerUserID: "c1")
        viewModel.series.handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025)
        viewModel.members = [member]
        viewModel.handicapScores = [score]
        viewModel.recomputeAllHandicaps()

        let config = viewModel.series.handicapConfig.config.toConfig()
        let expected = computeHandicapIndex(
            samples: [HandicapScoreSample(id: "nine", gross: 46, recordedAt: recorded, sortOrder: 0)],
            config: config
        )
        #expect(viewModel.memberHandicaps["m1"]?.computedIndex == expected?.handicapIndex)
    }

    @Test("recomputeAllHandicaps uses same score ordering as computeHandicapIndex input")
    func recomputeMatchesSortedScoresForIndex() throws {
        let member = SeriesMember(
            id: "m1",
            userID: "u1",
            playerID: "p1",
            name: Name("Test", "Player"),
            role: .member,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )

        let tOld = Time(iso: "2024-01-01T00:00:00Z", unix: 100)
        let tNew = Time(iso: "2024-06-01T00:00:00Z", unix: 200)

        let scores: [SeriesHandicapScore] = [
            SeriesHandicapScore(
                id: "b",
                memberID: "m1",
                score: 48,
                par: 36,
                holeSegment: .front9,
                source: .baseline,
                sourceRoundID: nil,
                caption: nil,
                recordedAt: tNew,
                sortOrder: 0,
                createdAt: tNew,
                lastUpdatedAt: tNew,
                parentID: "series1"
            ),
            SeriesHandicapScore(
                id: "a",
                memberID: "m1",
                score: 40,
                par: 36,
                holeSegment: .front9,
                source: .baseline,
                sourceRoundID: nil,
                caption: nil,
                recordedAt: tOld,
                sortOrder: 0,
                createdAt: tOld,
                lastUpdatedAt: tOld,
                parentID: "series1"
            ),
        ]

        let viewModel = SeriesViewModel()
        viewModel.series = Series(id: "series1", commissionerUserID: "c1")
        viewModel.series.handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025)
        viewModel.members = [member]
        viewModel.handicapScores = scores
        viewModel.recomputeAllHandicaps()

        let samples = scores
            .filter { $0.memberID == member.id && $0.countsTowardHandicapIndex }
            .map { HandicapScoreSample(id: $0.id, gross: $0.score, recordedAt: $0.recordedAt, sortOrder: $0.sortOrder) }

        let config = viewModel.series.handicapConfig.config.toConfig()
        let expected = computeHandicapIndex(samples: samples, config: config)
        let got = viewModel.memberHandicaps["m1"]?.computedIndex

        #expect(got == expected?.handicapIndex)
        let sel = viewModel.memberHandicapScoreSelections["m1"]
        #expect(sel?.countingIDs == expected?.selectedSampleIDs)
        #expect(sel?.poolIDs == expected?.poolSampleIDs)
    }

    @Test("recomputeAllHandicaps ignores scores with countsTowardHandicapIndex false")
    func recomputeIgnoresUnofficialScores() throws {
        let member = SeriesMember(
            id: "m1",
            userID: "u1",
            playerID: "p1",
            name: Name("Test", "Player"),
            role: .member,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )

        let t1 = Time(iso: "2024-01-01T00:00:00Z", unix: 100)
        let t2 = Time(iso: "2024-06-01T00:00:00Z", unix: 200)

        let official = SeriesHandicapScore(
            id: "on",
            memberID: "m1",
            score: 40,
            par: 36,
            holeSegment: .front9,
            source: .baseline,
            sourceRoundID: nil,
            caption: nil,
            recordedAt: t1,
            sortOrder: 0,
            createdAt: t1,
            lastUpdatedAt: t1,
            parentID: "series1",
            countsTowardHandicapIndex: true
        )
        var unofficial = SeriesHandicapScore(
            id: "off",
            memberID: "m1",
            score: 30,
            par: 36,
            holeSegment: .front9,
            source: .baseline,
            sourceRoundID: nil,
            caption: "Low outlier",
            recordedAt: t2,
            sortOrder: 1,
            createdAt: t2,
            lastUpdatedAt: t2,
            parentID: "series1",
            countsTowardHandicapIndex: false
        )

        let viewModel = SeriesViewModel()
        viewModel.series = Series(id: "series1", commissionerUserID: "c1")
        viewModel.series.handicapConfig = SeriesHandicapConfig(isEnabled: true, config: .league2025)
        viewModel.members = [member]
        viewModel.handicapScores = [official, unofficial]
        viewModel.recomputeAllHandicaps()

        let samples = [official].map {
            HandicapScoreSample(id: $0.id, gross: $0.score, recordedAt: $0.recordedAt, sortOrder: $0.sortOrder)
        }
        let config = viewModel.series.handicapConfig.config.toConfig()
        let expected = computeHandicapIndex(samples: samples, config: config)
        #expect(viewModel.memberHandicaps["m1"]?.computedIndex == expected?.handicapIndex)

        unofficial.countsTowardHandicapIndex = true
        viewModel.handicapScores = [official, unofficial]
        viewModel.recomputeAllHandicaps()
        let bothSamples = [official, unofficial].map {
            HandicapScoreSample(id: $0.id, gross: $0.score, recordedAt: $0.recordedAt, sortOrder: $0.sortOrder)
        }
        let expectedBoth = computeHandicapIndex(samples: bothSamples, config: config)
        #expect(viewModel.memberHandicaps["m1"]?.computedIndex == expectedBoth?.handicapIndex)
    }

    @Test("Rolling pool uses last M scores by recordedAt; best-of selects within pool")
    func rollingPoolBestOfWithinWindow() throws {
        var cfg = HandicapComputationConfig.league2025
        cfg.gamesUsedRules = [.init(playedRange: 1...100, used: 2)]
        cfg.rollingPoolSize = 2
        cfg.scorePoolPolicy = .bestOfUsedCount
        cfg.minimumScoresForIndex = 1

        let t1 = Time(iso: "2024-01-01T00:00:00Z", unix: 1)
        let t2 = Time(iso: "2024-02-01T00:00:00Z", unix: 2)
        let t3 = Time(iso: "2024-03-01T00:00:00Z", unix: 3)
        let samples = [
            HandicapScoreSample(id: "old", gross: 70, recordedAt: t1, sortOrder: 0),
            HandicapScoreSample(id: "mid", gross: 80, recordedAt: t2, sortOrder: 1),
            HandicapScoreSample(id: "new", gross: 90, recordedAt: t3, sortOrder: 2),
        ]
        let result = try #require(computeHandicapIndex(samples: samples, config: cfg))
        #expect(result.poolSampleIDs == Set(["new", "mid"]))
        #expect(result.selectedSampleIDs == Set(["mid", "new"]))
        #expect(result.selectedBestScores.sorted() == [80, 90])
    }

    @Test("CommissionerGrossScoreDistributer bumps last holes when unscored pars sum below target")
    func grossDistributerRaisesTailHoles() throws {
        let holes = [
            Hole(number: 1, par: 4, yardage: 400, handicap: nil),
            Hole(number: 2, par: 4, yardage: 400, handicap: nil),
            Hole(number: 3, par: 4, yardage: 400, handicap: nil),
        ]
        let changes = try #require(
            CommissionerGrossScoreDistributer.correctionChanges(
                holes: holes,
                participantID: "part1",
                currentStrokes: { _ in nil },
                targetGross: 15
            )
        )

        let byHole = Dictionary(uniqueKeysWithValues: changes.map { ($0.holeNumber, $0.strokes) })
        #expect(byHole[1] == 4)
        #expect(byHole[2] == 4)
        #expect(byHole[3] == 7)
    }

    @Test("Series round score review CTA only unlocks for live rounds with a completed player")
    func scoreReviewGateRequiresLiveRoundWithCompletedPlayer() {
        let viewModel = SeriesViewModel()
        let completed = CompletedPlayer(
            playerID: "player1",
            playerDisplayName: nil,
            completedAt: .init(),
            type: .signedScorecard,
            scorecardStorageID: nil
        )

        let planned = SeriesRound(id: "planned", status: .planned, parentID: "series1")
        #expect(viewModel.canReviewScores(for: planned) == false)

        let lobby = SeriesRound(id: "lobby", status: .lobby, roundID: "round_lobby", parentID: "series1")
        viewModel.linkedRounds["round_lobby"] = Round(
            id: "round_lobby",
            status: .lobby,
            players: ["player1"],
            completedPlayers: [completed]
        )
        #expect(viewModel.canReviewScores(for: lobby) == false)

        let live = SeriesRound(id: "live", status: .live, roundID: "round_live", parentID: "series1")
        viewModel.linkedRounds["round_live"] = Round(
            id: "round_live",
            status: .live,
            players: ["player1"],
            completedPlayers: []
        )
        #expect(viewModel.canReviewScores(for: live) == false)

        viewModel.linkedRounds["round_live"] = Round(
            id: "round_live",
            status: .live,
            players: ["player1"],
            completedPlayers: [completed]
        )
        #expect(viewModel.canReviewScores(for: live) == true)

        let complete = SeriesRound(id: "complete", status: .complete, roundID: "round_complete", parentID: "series1")
        viewModel.linkedRounds["round_complete"] = Round(
            id: "round_complete",
            status: .complete,
            players: ["player1"],
            completedPlayers: [completed]
        )
        #expect(viewModel.canReviewScores(for: complete) == false)
    }

    @Test("Round outcome narrative sorts net leaderboard and includes markdown, handicaps, score highlights, team context, and bounce back")
    func roundOutcomeNarrativeIncludesRequiredRoundFacts() throws {
        let members = Self.outcomeMembers()
        let currentRound = SeriesRound(id: "series_round_2", title: "Week 2", index: 1, roundID: "round_2")
        let priorRound = SeriesRound(id: "series_round_1", title: "Week 1", index: 0, roundID: "round_1")
        let snapshot = Self.outcomeSnapshot(
            roundID: "round_2",
            scores: [
                "p_alice": [1: 4, 2: 3, 3: 4],
                "p_bob": [1: 5, 2: 4, 3: 3],
                "p_charlie": [1: 4, 2: 4, 3: 3],
            ],
            handicaps: ["p_alice": 2, "p_bob": 4, "p_charlie": 1]
        )
        let teams = [
            SeriesTeam(id: "team_1", name: "Team 1", index: 0, parentID: "series1"),
            SeriesTeam(id: "team_2", name: "Team 2", index: 1, parentID: "series1"),
        ]
        let pointAwards = [
            SeriesPointAward(
                id: "award_team_1",
                seriesRoundID: currentRound.id,
                awardTrack: .team,
                competitorType: .team,
                competitorID: "team_1",
                competitorName: "Team 1",
                profileKind: .winTieLoss,
                placement: 2,
                totalPoints: 0,
                parentID: "series1"
            ),
            SeriesPointAward(
                id: "award_team_2",
                seriesRoundID: currentRound.id,
                awardTrack: .team,
                competitorType: .team,
                competitorID: "team_2",
                competitorName: "Team 2",
                profileKind: .winTieLoss,
                placement: 1,
                totalPoints: 2,
                parentID: "series1"
            ),
        ]
        let standings = [
            SeriesStanding(
                id: SeriesStanding.standingID(for: .team, competitorID: "team_1"),
                awardTrack: .team,
                competitorType: .team,
                competitorID: "team_1",
                competitorName: "Team 1",
                totalPoints: 4,
                rank: 2,
                parentID: "series1"
            ),
            SeriesStanding(
                id: SeriesStanding.standingID(for: .team, competitorID: "team_2"),
                awardTrack: .team,
                competitorType: .team,
                competitorID: "team_2",
                competitorName: "Team 2",
                totalPoints: 5,
                rank: 1,
                parentID: "series1"
            ),
        ]
        let priorSnapshot = Self.outcomeSnapshot(
            roundID: "round_1",
            scores: [
                "p_alice": [1: 6, 2: 6, 3: 4],
                "p_bob": [1: 4, 2: 4, 3: 4],
            ],
            handicaps: ["p_alice": 2, "p_bob": 2]
        )

        let narrative = try #require(SeriesRoundOutcomeNarrativeBuilder.build(
            seriesRound: currentRound,
            snapshot: snapshot,
            priorRoundSnapshots: [.init(seriesRound: priorRound, snapshot: priorSnapshot)],
            members: members,
            handicapScores: [],
            memberHandicaps: [
                "m_alice": SeriesMemberHandicap(id: "m_alice", memberID: "m_alice", computedIndex: 5),
                "m_bob": SeriesMemberHandicap(id: "m_bob", memberID: "m_bob", computedIndex: 3.4),
            ],
            pointAwards: pointAwards,
            standings: standings,
            teams: teams
        ))

        let paragraph = narrative.paragraph
        #expect(paragraph.contains("**Week 2 is scored.**\n\n**Leaderboard (low-to-high net)**"))
        let bobRange = try #require(paragraph.range(of: "**1st - Bob Player**\nScore: -3 (Net 8 / Gross 12)\nHCP: 4 -> 3.4 next week"))
        let aliceRange = try #require(paragraph.range(of: "**2nd - Alice Player**\nScore: -2 (Net 9 / Gross 11)\nHCP: 2 -> 5 next week"))
        let charlieRange = try #require(paragraph.range(of: "**3rd - Charlie Player**\nScore: -1 (Net 10 / Gross 11)\nHCP: 1 -> unavailable next week"))
        #expect(bobRange.lowerBound < aliceRange.lowerBound)
        #expect(aliceRange.lowerBound < charlieRange.lowerBound)
        #expect(paragraph.contains("\n\n**Birdies and Eagles**\n**Alice Player** birdie on #2"))
        #expect(paragraph.contains("**Team context**"))
        #expect(paragraph.contains("**Team 2** moved into first after won"))
        #expect(paragraph.contains("Best round: **Bob Player** with net 8 (-3)."))
        #expect(paragraph.contains("Bounce-back player: **Alice Player**, improving 5 strokes from the prior Series round."))
        #expect(paragraph.contains("Strongest finish:"))
    }

    @Test("Round outcome narrative handles no birdies and no prior comparable round")
    func roundOutcomeNarrativeHandlesNoBirdiesAndNoPriorRound() throws {
        let narrative = try #require(SeriesRoundOutcomeNarrativeBuilder.build(
            seriesRound: SeriesRound(id: "series_round_1", title: "Week 1", index: 0, roundID: "round_1"),
            snapshot: Self.outcomeSnapshot(
                roundID: "round_1",
                scores: [
                    "p_alice": [1: 4, 2: 4, 3: 3],
                    "p_bob": [1: 5, 2: 4, 3: 4],
                ],
                handicaps: ["p_alice": 1, "p_bob": 2]
            ),
            priorRoundSnapshots: [],
            members: Self.outcomeMembers(),
            handicapScores: [],
            memberHandicaps: [:]
        ))

        #expect(narrative.paragraph.contains("No birdies or eagles were recorded."))
        #expect(!narrative.paragraph.contains("Bounce-back player"))
    }

    @Test("Round outcome narrative includes tied ordinal labels, team names, eagles, and absent player HCP")
    func roundOutcomeNarrativeIncludesTieTeamEagleAndAbsentSections() throws {
        let teams = [
            SeriesTeam(id: "team_2", name: "Team 2", index: 1, parentID: "series1")
        ]
        let narrative = try #require(SeriesRoundOutcomeNarrativeBuilder.build(
            seriesRound: SeriesRound(id: "series_round_1", title: "Week 1", index: 0, roundID: "round_1"),
            snapshot: Self.outcomeSnapshot(
                roundID: "round_1",
                scores: [
                    "p_alice": [1: 2, 2: 4, 3: 3],
                    "p_bob": [1: 4, 2: 4, 3: 3],
                    "p_charlie": [:],
                ],
                handicaps: ["p_alice": 0, "p_bob": 2, "p_charlie": 7],
                teamIDs: ["p_alice": "team_2", "p_bob": "team_2", "p_charlie": "team_2"],
                presenceStatuses: ["p_charlie": .noShow],
                handicapIndexes: ["p_alice": 3.2]
            ),
            priorRoundSnapshots: [],
            members: Self.outcomeMembers(),
            handicapScores: [],
            memberHandicaps: [
                "m_alice": SeriesMemberHandicap(id: "m_alice", memberID: "m_alice", computedIndex: 2.9),
                "m_charlie": SeriesMemberHandicap(id: "m_charlie", memberID: "m_charlie", computedIndex: 6.1),
            ],
            teams: teams
        ))

        let paragraph = narrative.paragraph
        #expect(paragraph.contains("**T-1st - Alice Player, Team 2**"))
        #expect(paragraph.contains("**T-1st - Bob Player, Team 2**"))
        #expect(paragraph.contains("HCP: 3.2 -> 2.9 next week"))
        #expect(paragraph.contains("**Alice Player** eagle-or-better on #1"))
        #expect(paragraph.contains("**Absent players**"))
        #expect(paragraph.contains("**Charlie Player** - HCP: 7 -> 6.1 next week"))
    }

    @Test("Course handicap outcome narrative shows integer course HCP current-to-next values")
    func roundOutcomeNarrativeUsesCourseHandicapLineWhenEnabled() throws {
        let narrative = try #require(SeriesRoundOutcomeNarrativeBuilder.build(
            seriesRound: SeriesRound(id: "series_round_1", title: "Week 1", index: 0, roundID: "round_course_hcp"),
            snapshot: Self.courseHandicapOutcomeSnapshot(),
            priorRoundSnapshots: [],
            members: Self.outcomeMembers(),
            handicapScores: [],
            memberHandicaps: [
                "m_alice": SeriesMemberHandicap(id: "m_alice", memberID: "m_alice", computedIndex: 6.1),
                "m_charlie": SeriesMemberHandicap(id: "m_charlie", memberID: "m_charlie", computedIndex: 8.2),
            ]
        ))

        let paragraph = narrative.paragraph
        #expect(paragraph.contains("Course HCP: 3 -> 4 next week"))
        #expect(paragraph.contains("**Charlie Player** - Course HCP: 7 -> 6 next week"))
        #expect(!paragraph.contains("HCP: 3.2 -> 6.1 next week"))
    }

    @Test("SeriesViewModel sync outcome narrative helper uses current view model state")
    func viewModelRoundOutcomeNarrativeUsesSeriesState() throws {
        let viewModel = SeriesViewModel()
        viewModel.members = Self.outcomeMembers()
        viewModel.memberHandicaps = [
            "m_alice": SeriesMemberHandicap(id: "m_alice", memberID: "m_alice", computedIndex: 4.6)
        ]
        let round = SeriesRound(id: "series_round_1", title: "Week 1", index: 0, roundID: "round_1")

        let narrative = try #require(viewModel.roundOutcomeNarrative(
            for: round,
            snapshot: Self.outcomeSnapshot(
                roundID: "round_1",
                scores: ["p_alice": [1: 4, 2: 3, 3: 3]],
                handicaps: ["p_alice": 2]
            )
        ))

        #expect(narrative.paragraph.contains("**1st - Alice Player**\nScore: -3 (Net 8 / Gross 10)\nHCP: 2 -> 4.6 next week"))
    }

    private static func outcomeMembers() -> [SeriesMember] {
        [
            outcomeMember(id: "m_alice", playerID: "p_alice", first: "Alice"),
            outcomeMember(id: "m_bob", playerID: "p_bob", first: "Bob"),
            outcomeMember(id: "m_charlie", playerID: "p_charlie", first: "Charlie"),
        ]
    }

    private static func outcomeMember(id: String, playerID: String, first: String) -> SeriesMember {
        SeriesMember(
            id: id,
            userID: "u_\(id)",
            playerID: playerID,
            name: Name(first, "Player"),
            role: .member,
            isActive: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: "series1"
        )
    }

    private static func courseHandicapOutcomeSnapshot() -> RoundSnapshot {
        let roundID = "round_course_hcp"
        let holes = (1...18).map { holeNumber in
            Hole(number: holeNumber, par: 4, yardage: 360, handicap: holeNumber)
        }
        let tee = Tee(
            id: "course_tee",
            name: "Member",
            gender: Gender.male.rawValue,
            totalHoles: 18,
            holes: holes,
            ratingFull: 70,
            slopeFull: 113,
            ratingFront: 34,
            slopeFront: 113,
            ratingBack: 36,
            slopeBack: 113
        )
        let participants = [
            RoundParticipant(
                id: "p_alice",
                playerID: "p_alice",
                name: Name("Alice", "Player"),
                teeBoxID: tee.id,
                adjustedHandicap: 3,
                handicapIndex: 3.2,
                seriesMemberID: "m_alice",
                parentID: roundID
            ),
            RoundParticipant(
                id: "p_charlie",
                playerID: "p_charlie",
                name: Name("Charlie", "Player"),
                teeBoxID: tee.id,
                adjustedHandicap: 7,
                handicapIndex: 7,
                seriesMemberID: "m_charlie",
                presenceStatus: .noShow,
                parentID: roundID
            ),
        ]
        let entries = (1...9).map { holeNumber in
            ScoreEntry(
                id: ScoreEntry.makeID(hole: holeNumber, segment: "segment", scoringUnit: "p_alice"),
                holeNumber: holeNumber,
                segmentID: "segment",
                scoringUnitID: "p_alice",
                participantIDs: ["p_alice"],
                strokes: 4,
                parentID: roundID
            )
        }

        return RoundSnapshot(
            round: Round(
                id: roundID,
                status: .complete,
                configuration: RoundConfiguration(
                    courses: [
                        CourseSegment(
                            courseInfo: CourseInfo(id: "course", name: "Test Course", totalHoles: 18, tees: [tee]),
                            holeRange: HoleRange(startHole: 1, endHole: 9),
                            defaultTee: tee.id
                        )
                    ],
                    handicapStrokeBasis: .nineHole,
                    handicapEntryFormat: .courseHandicap
                )
            ),
            participants: participants,
            segments: [RoundSegment(id: "segment", holeRange: HoleRange(startHole: 1, endHole: 9), parentID: roundID)],
            scoring: entries
        )
    }

    private static func outcomeSnapshot(
        roundID: String,
        scores: [String: [Int: Int]],
        handicaps: [String: Int],
        teamIDs: [String: String] = [:],
        presenceStatuses: [String: RoundParticipantPresenceStatus] = [:],
        handicapIndexes: [String: Double] = [:]
    ) -> RoundSnapshot {
        let tee = Tee(
            id: "tee",
            name: "Member",
            gender: Gender.male.rawValue,
            totalHoles: 3,
            holes: [
                Hole(number: 1, par: 4, yardage: 380, handicap: 1),
                Hole(number: 2, par: 4, yardage: 360, handicap: 2),
                Hole(number: 3, par: 3, yardage: 150, handicap: 3),
            ],
            ratingFull: 72,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        let participants = outcomeMembers().map { member in
            RoundParticipant(
                id: member.playerID ?? member.id,
                playerID: member.playerID,
                name: member.name,
                teeBoxID: tee.id,
                adjustedHandicap: handicaps[member.playerID ?? ""] ?? 0,
                handicapIndex: handicapIndexes[member.playerID ?? ""],
                seriesMemberID: member.id,
                teamID: teamIDs[member.playerID ?? ""],
                presenceStatus: presenceStatuses[member.playerID ?? ""],
                parentID: roundID
            )
        }
        let entries = scores.flatMap { participantID, holeScores in
            holeScores.map { holeNumber, strokes in
                ScoreEntry(
                    id: ScoreEntry.makeID(hole: holeNumber, segment: "segment", scoringUnit: participantID),
                    holeNumber: holeNumber,
                    segmentID: "segment",
                    scoringUnitID: participantID,
                    participantIDs: [participantID],
                    strokes: strokes,
                    parentID: roundID
                )
            }
        }

        return RoundSnapshot(
            round: Round(
                id: roundID,
                status: .complete,
                configuration: RoundConfiguration(
                    courses: [
                        CourseSegment(
                            courseInfo: CourseInfo(id: "course", name: "Test Course", totalHoles: 3, tees: [tee]),
                            holeRange: HoleRange(startHole: 1, endHole: 3),
                            defaultTee: tee.id
                        )
                    ],
                    handicapStrokeBasis: .nineHole
                )
            ),
            participants: participants,
            segments: [RoundSegment(id: "segment", holeRange: HoleRange(startHole: 1, endHole: 3), parentID: roundID)],
            scoring: entries
        )
    }
}
