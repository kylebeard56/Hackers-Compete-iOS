@testable import Hackers
import XCTest

@MainActor
final class SeriesPhase0BehaviorTests: XCTestCase {
    private struct StandingSnapshot: Equatable {
        let track: SeriesAwardTrack
        let competitorID: String
        let points: Double
        let rounds: Int
        let wins: Int
        let topThrees: Int
        let lastPlacement: Int?
        let bestPlacement: Int?
        let rank: Int?

        init(_ standing: SeriesStanding) {
            track = standing.awardTrack
            competitorID = standing.competitorID
            points = standing.totalPoints
            rounds = standing.roundsCounted
            wins = standing.wins
            topThrees = standing.topThrees
            lastPlacement = standing.lastPlacement
            bestPlacement = standing.bestPlacement
            rank = standing.rank
        }
    }

    func testBestTwoNineHoleSettingsRoundTripWithoutLosingSelections() throws {
        let settings = SeriesBehaviorFixtures.bestTwoNineHoleSettings
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SeriesSettings.self, from: data)
        let dictionary = try settings.toDictionary()

        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(dictionary["experience_preset"] as? String, "league")
        XCTAssertEqual(dictionary["default_team_scoring_profile_id"] as? String, "team_placement")
        XCTAssertEqual(dictionary["default_individual_scoring_profile_id"] as? String, "individual_placement")
        XCTAssertEqual(dictionary["use_teams"] as? Bool, true)
        XCTAssertEqual(dictionary["use_team_standings"] as? Bool, true)
        XCTAssertEqual(dictionary["use_individual_standings"] as? Bool, true)
        XCTAssertEqual(dictionary["substitutes_score"] as? Bool, true)
        XCTAssertEqual(dictionary["default_scheduled_tee_time_minutes_from_midnight"] as? Int, 1_020)
        XCTAssertEqual(dictionary["recurring_play_weekdays"] as? [Int], [5])
    }

    func testConfiguredRoundRoundTripPreservesLeagueAndRoundSelections() throws {
        let round = SeriesBehaviorFixtures.configuredRound
        let data = try JSONEncoder().encode(round)
        let decoded = try JSONDecoder().decode(SeriesRound.self, from: data)
        let config = decoded.roundConfig

        XCTAssertEqual(decoded.id, round.id)
        XCTAssertEqual(decoded.courseOverride, round.courseOverride)
        XCTAssertEqual(decoded.teamScoringProfileID, "team_placement")
        XCTAssertEqual(decoded.individualScoringProfileID, "individual_placement")
        XCTAssertEqual(config, SeriesBehaviorFixtures.bestTwoNineHoleConfiguration)
        XCTAssertEqual(config.teamScoring, .init(mode: .bestN, count: 2, scope: .perRound))
        XCTAssertEqual(config.scoreBasisOverride, .gross)
        XCTAssertEqual(config.handicapStrokeBasis, .nineHole)
        XCTAssertEqual(config.handicapNormalizationMode, .field)
        XCTAssertFalse(config.allowCourseOverride)
        XCTAssertFalse(config.allowFormatOverride)
        XCTAssertFalse(config.allowLobbyBackPropagation)
    }

    func testGoldenStandingsProjectionLocksCurrentRankingBehavior() {
        let standings = SeriesViewModel.computedStandings(
            from: SeriesBehaviorFixtures.goldenAwards,
            seriesID: SeriesBehaviorFixtures.seriesID,
            sort: SeriesViewModel.standingsSort
        )
        let snapshots = standings.map(StandingSnapshot.init)

        XCTAssertEqual(snapshots, [
            StandingSnapshot(
                SeriesStanding(
                    awardTrack: .team,
                    competitorID: "red",
                    totalPoints: 27,
                    roundsCounted: 3,
                    wins: 2,
                    topThrees: 3,
                    lastPlacement: 1,
                    bestPlacement: 1,
                    rank: 1
                )
            ),
            StandingSnapshot(
                SeriesStanding(
                    awardTrack: .team,
                    competitorID: "blue",
                    totalPoints: 27,
                    roundsCounted: 3,
                    wins: 1,
                    topThrees: 3,
                    lastPlacement: 2,
                    bestPlacement: 1,
                    rank: 2
                )
            ),
            StandingSnapshot(
                SeriesStanding(
                    awardTrack: .team,
                    competitorID: "green",
                    totalPoints: 18,
                    roundsCounted: 3,
                    wins: 0,
                    topThrees: 3,
                    lastPlacement: 3,
                    bestPlacement: 3,
                    rank: 3
                )
            ),
            StandingSnapshot(
                SeriesStanding(
                    awardTrack: .individual,
                    competitorID: "alice",
                    totalPoints: 15,
                    roundsCounted: 2,
                    wins: 1,
                    topThrees: 2,
                    lastPlacement: 1,
                    bestPlacement: 1,
                    rank: 1
                )
            ),
            StandingSnapshot(
                SeriesStanding(
                    awardTrack: .individual,
                    competitorID: "bailey",
                    totalPoints: 14,
                    roundsCounted: 2,
                    wins: 1,
                    topThrees: 2,
                    lastPlacement: 3,
                    bestPlacement: 1,
                    rank: 2
                )
            ),
        ])
    }

    func testLargeLeagueStandingsProjectionBaseline() {
        let awards = SeriesBehaviorFixtures.largeLeagueAwards()
        var result: [SeriesStanding] = []

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            result = SeriesViewModel.computedStandings(
                from: awards,
                seriesID: SeriesBehaviorFixtures.seriesID,
                sort: SeriesViewModel.standingsSort
            )
        }

        XCTAssertEqual(awards.count, 640)
        XCTAssertEqual(result.count, 16)
        XCTAssertEqual(Set(result.map(\.roundsCounted)), [40])
    }

    func testPerformanceClockUsesMonotonicElapsedTime() {
        let clock = ContinuousClock()
        let start = clock.now
        let end = start.advanced(by: .milliseconds(125))

        XCTAssertEqual(SeriesPerformanceRecorder.elapsedMilliseconds(since: start, endingAt: end), 125)
    }
}
