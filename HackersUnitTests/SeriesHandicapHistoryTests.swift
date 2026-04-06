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
            .filter { $0.memberID == member.id }
            .map { HandicapScoreSample(id: $0.id, gross: $0.score, recordedAt: $0.recordedAt, sortOrder: $0.sortOrder) }

        let config = viewModel.series.handicapConfig.config.toConfig()
        let expected = computeHandicapIndex(samples: samples, config: config)
        let got = viewModel.memberHandicaps["m1"]?.computedIndex

        #expect(got == expected?.handicapIndex)
        let sel = viewModel.memberHandicapScoreSelections["m1"]
        #expect(sel?.countingIDs == expected?.selectedSampleIDs)
        #expect(sel?.poolIDs == expected?.poolSampleIDs)
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
}
