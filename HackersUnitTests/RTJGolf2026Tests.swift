//
//  RTJGolf2026Tests.swift
//  HackersUnitTests
//
//  Created by Codex on 4/6/26.
//

@testable import Hackers
import XCTest

final class RTJGolf2026Tests: XCTestCase {

    private enum TeamSide: String {
        case a
        case b

        var teamID: String {
            switch self {
            case .a: return "team_a"
            case .b: return "team_b"
            }
        }
    }

    private struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed == 0 ? 0xA5A5A5A5A5A5A5A5 : seed
        }

        mutating func next() -> UInt64 {
            state = 6364136223846793005 &* state &+ 1442695040888963407
            return state
        }

        mutating func nextInt(in range: ClosedRange<Int>) -> Int {
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            let value = next() % span
            return range.lowerBound + Int(value)
        }

        mutating func shuffle<T>(_ items: [T]) -> [T] {
            var copy = items
            guard copy.count > 1 else { return copy }
            for index in stride(from: copy.count - 1, through: 1, by: -1) {
                let swapIndex = Int(next() % UInt64(index + 1))
                if swapIndex != index {
                    copy.swapAt(index, swapIndex)
                }
            }
            return copy
        }
    }

    private struct ScenarioPlayer: Hashable {
        let id: String
        let fullName: String
        let handicap: Int
        let teamSide: TeamSide
    }

    private struct Partnership {
        let id: String
        let side: TeamSide
        let teamID: String
        let teeGroupID: String
        let memberIDs: [String]
        let label: String
    }

    private struct MatchFixture {
        let id: String
        let leftOwnerID: String
        let rightOwnerID: String
        let leftWins: Int
        let rightWins: Int

        var holeCount: Int { leftWins + rightWins }
    }

    private struct RoundFixture {
        let roundNumber: Int
        let name: String
        let seriesConfig: SeriesRoundConfiguration
        let roundConfig: RoundConfiguration
        let holes: [Hole]
        let teams: [RoundTeam]
        let participants: [RoundParticipant]
        let scoringGroups: [RoundScoringGroup]
        let fieldSegment: RoundSegment
        let matchupSegment: RoundSegment
        let fieldTemplate: GameTemplate
        let matchupTemplate: GameTemplate
        let scores: [ScoreEntry]
        let matchFixtures: [MatchFixture]
        let ownerTeamIDs: [String: String]
        let scoringUnitHandicaps: [String: Int]
    }

    private struct ScenarioFixture {
        let players: [ScenarioPlayer]
        let teamA: [ScenarioPlayer]
        let teamB: [ScenarioPlayer]
        let rounds: [RoundFixture]
    }

    private struct RoundPointSummary {
        let ownerPoints: [String: Double]
        let teamPoints: [String: Double]
        let matchupPoints: [String: [String: Double]]

        var totalPoints: Double {
            ownerPoints.values.reduce(0, +)
        }
    }

    private let holePars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 4, 5]
    private let holeHandicaps = [7, 3, 15, 1, 9, 17, 5, 11, 13, 8, 16, 2, 10, 4, 18, 6, 12, 14]
    private let baseSeed: UInt64 = 0x52544A_32303236

    func testSeededSetup_balancesTeams_andBuildsRoundStructures() {
        let fixture = makeScenarioFixture()

        XCTAssertEqual(fixture.players.count, 16)
        XCTAssertEqual(fixture.teamA.count, 8)
        XCTAssertEqual(fixture.teamB.count, 8)
        XCTAssertTrue(fixture.players.allSatisfy { (0...21).contains($0.handicap) })

        let teamATotal = fixture.teamA.map(\.handicap).reduce(0, +)
        let teamBTotal = fixture.teamB.map(\.handicap).reduce(0, +)
        XCTAssertLessThanOrEqual(abs(teamATotal - teamBTotal), 3, "Balanced split should keep handicap totals close")

        XCTAssertEqual(fixture.rounds.count, 4)

        for round in fixture.rounds.prefix(3) {
            XCTAssertEqual(round.seriesConfig.scoreOwnerScope, .partnership)
            XCTAssertEqual(round.roundConfig.scoreOwnerScope, .partnership)
            XCTAssertEqual(round.seriesConfig.competitionScope, .matchup)
            XCTAssertEqual(round.roundConfig.resolvedCompetitionScope, .matchup)
            XCTAssertEqual(round.matchFixtures.count, 4)
            XCTAssertEqual(round.scoringGroups.count, 8)
            XCTAssertEqual(Set(round.scoringGroups.map(\.teeGroupID)).count, 4)
            XCTAssertEqual(round.scores.count, round.roundNumber == 2 ? 144 : 288)
        }

        let round4 = tryUnwrap(fixture.rounds.last)
        XCTAssertEqual(round4.seriesConfig.scoreOwnerScope, .individual)
        XCTAssertEqual(round4.roundConfig.scoreOwnerScope, .individual)
        XCTAssertEqual(round4.matchFixtures.count, 8)
        XCTAssertEqual(Set(round4.participants.compactMap(\.groupID)).count, 4)
        XCTAssertEqual(round4.scores.count, 288)
    }

    func testRound1_betterBall_aggregateRoundTotal_awardsExact40PointMatchups() {
        let round = makeScenarioFixture().rounds[0]
        let summary = computeAggregateRoundWinnerPoints(round)

        XCTAssertEqual(summary.matchupPoints["r1_m1"], ["r1_a1": 40, "r1_b1": 0])
        XCTAssertEqual(summary.matchupPoints["r1_m2"], ["r1_a2": 0, "r1_b2": 40])
        XCTAssertEqual(summary.matchupPoints["r1_m3"], ["r1_a3": 40, "r1_b3": 0])
        XCTAssertEqual(summary.matchupPoints["r1_m4"], ["r1_a4": 0, "r1_b4": 40])
        XCTAssertEqual(summary.teamPoints["team_a"], 80)
        XCTAssertEqual(summary.teamPoints["team_b"], 80)
        XCTAssertEqual(summary.totalPoints, 160)
        XCTAssertEqual(round.seriesConfig.scoreOwnerScope, .partnership)
        XCTAssertEqual(round.roundConfig.scoreOwnerScope, .partnership)
    }

    func testRound1_betterBall_holeByHolePlusBonus_awardsExpectedTotals() {
        let round = makeScenarioFixture().rounds[0]
        let summary = computeHoleByHolePoints(round, matchWinnerBonus: 4)

        XCTAssertEqual(summary.matchupPoints["r1_m1"], ["r1_a1": 26, "r1_b1": 14])
        XCTAssertEqual(summary.matchupPoints["r1_m2"], ["r1_a2": 16, "r1_b2": 24])
        XCTAssertEqual(summary.matchupPoints["r1_m3"], ["r1_a3": 28, "r1_b3": 12])
        XCTAssertEqual(summary.matchupPoints["r1_m4"], ["r1_a4": 14, "r1_b4": 26])
        XCTAssertEqual(summary.teamPoints["team_a"], 84)
        XCTAssertEqual(summary.teamPoints["team_b"], 76)
        XCTAssertEqual(summary.totalPoints, 160)
        XCTAssertTrue(round.scores.allSatisfy { $0.scoringUnitID.hasPrefix("p_") })
    }

    func testRound2_captainsChoice_scrambleHandicaps_areStable_andSharedScoresStayPairScoped() {
        let round = makeScenarioFixture().rounds[1]

        XCTAssertEqual(round.scoringGroups.count, 8)
        XCTAssertEqual(round.scores.count, 144)
        XCTAssertTrue(round.scores.allSatisfy { $0.scoringUnitID.hasPrefix("r2_") })

        let expectedDiluted: [String: Int] = [
            "r2_a1": 6,
            "r2_a2": 8,
            "r2_a3": 5,
            "r2_a4": 10,
            "r2_b1": 8,
            "r2_b2": 8,
            "r2_b3": 10,
            "r2_b4": 4,
        ]
        XCTAssertEqual(round.scoringUnitHandicaps, expectedDiluted)

        let result = ScoringEngine.computeWithPipeline(
            scores: round.scores,
            participants: round.participants,
            teams: round.teams,
            segment: round.fieldSegment,
            holes: round.holes,
            basis: .net,
            template: round.fieldTemplate,
            scoreOwnerScope: round.roundConfig.scoreOwnerScope,
            scoringGroups: round.scoringGroups
        )

        XCTAssertEqual(result.rows.count, 8)
        XCTAssertTrue(result.rows.allSatisfy { $0.owner == .scoreOwner })
        XCTAssertTrue(result.rows.allSatisfy { $0.participantIDs.count == 2 })
        XCTAssertFalse(result.rows.contains { $0.owner == .team && $0.participantIDs.count == 8 })
    }

    func testRound2_captainsChoice_aggregateRoundTotal_awardsExact40PointMatchups() {
        let round = makeScenarioFixture().rounds[1]
        let summary = computeAggregateRoundWinnerPoints(round)

        XCTAssertEqual(summary.matchupPoints["r2_m1"], ["r2_a1": 40, "r2_b1": 0])
        XCTAssertEqual(summary.matchupPoints["r2_m2"], ["r2_a2": 40, "r2_b2": 0])
        XCTAssertEqual(summary.matchupPoints["r2_m3"], ["r2_a3": 0, "r2_b3": 40])
        XCTAssertEqual(summary.matchupPoints["r2_m4"], ["r2_a4": 0, "r2_b4": 40])
        XCTAssertEqual(summary.teamPoints["team_a"], 80)
        XCTAssertEqual(summary.teamPoints["team_b"], 80)
        XCTAssertEqual(summary.totalPoints, 160)
    }

    func testRound2_captainsChoice_holeByHolePlusBonus_awardsExpectedTotals() {
        let round = makeScenarioFixture().rounds[1]
        let summary = computeHoleByHolePoints(round, matchWinnerBonus: 4)

        XCTAssertEqual(summary.matchupPoints["r2_m1"], ["r2_a1": 24, "r2_b1": 16])
        XCTAssertEqual(summary.matchupPoints["r2_m2"], ["r2_a2": 30, "r2_b2": 10])
        XCTAssertEqual(summary.matchupPoints["r2_m3"], ["r2_a3": 16, "r2_b3": 24])
        XCTAssertEqual(summary.matchupPoints["r2_m4"], ["r2_a4": 14, "r2_b4": 26])
        XCTAssertEqual(summary.teamPoints["team_a"], 84)
        XCTAssertEqual(summary.teamPoints["team_b"], 76)
        XCTAssertEqual(summary.totalPoints, 160)
    }

    func testRound3_shamble_aggregateRoundTotal_awardsExact40PointMatchups() {
        let round = makeScenarioFixture().rounds[2]
        let summary = computeAggregateRoundWinnerPoints(round)

        XCTAssertEqual(summary.matchupPoints["r3_m1"], ["r3_a1": 0, "r3_b1": 40])
        XCTAssertEqual(summary.matchupPoints["r3_m2"], ["r3_a2": 40, "r3_b2": 0])
        XCTAssertEqual(summary.matchupPoints["r3_m3"], ["r3_a3": 0, "r3_b3": 40])
        XCTAssertEqual(summary.matchupPoints["r3_m4"], ["r3_a4": 40, "r3_b4": 0])
        XCTAssertEqual(summary.teamPoints["team_a"], 80)
        XCTAssertEqual(summary.teamPoints["team_b"], 80)
        XCTAssertEqual(summary.totalPoints, 160)
        XCTAssertTrue(round.scores.allSatisfy { $0.scoringUnitID.hasPrefix("p_") })
    }

    func testRound3_shamble_holeByHolePlusBonus_awardsExpectedTotals() {
        let round = makeScenarioFixture().rounds[2]
        let summary = computeHoleByHolePoints(round, matchWinnerBonus: 4)

        XCTAssertEqual(summary.matchupPoints["r3_m1"], ["r3_a1": 12, "r3_b1": 28])
        XCTAssertEqual(summary.matchupPoints["r3_m2"], ["r3_a2": 26, "r3_b2": 14])
        XCTAssertEqual(summary.matchupPoints["r3_m3"], ["r3_a3": 16, "r3_b3": 24])
        XCTAssertEqual(summary.matchupPoints["r3_m4"], ["r3_a4": 24, "r3_b4": 16])
        XCTAssertEqual(summary.teamPoints["team_a"], 78)
        XCTAssertEqual(summary.teamPoints["team_b"], 82)
        XCTAssertEqual(summary.totalPoints, 160)
    }

    func testRound4_matchPlaySingles_holeByHolePlusBonus_awardsExpectedTotals() {
        let round = makeScenarioFixture().rounds[3]
        let summary = computeHoleByHolePoints(round, matchWinnerBonus: 2)

        for fixture in round.matchFixtures {
            let leftPoints = Double(fixture.leftWins + (fixture.leftWins > fixture.rightWins ? 2 : 0))
            let rightPoints = Double(fixture.rightWins + (fixture.rightWins > fixture.leftWins ? 2 : 0))
            XCTAssertEqual(
                summary.matchupPoints[fixture.id],
                [
                    fixture.leftOwnerID: leftPoints,
                    fixture.rightOwnerID: rightPoints,
                ]
            )
        }

        XCTAssertEqual(summary.teamPoints["team_a"], 90)
        XCTAssertEqual(summary.teamPoints["team_b"], 70)
        XCTAssertEqual(summary.totalPoints, 160)
        XCTAssertTrue(round.scoringGroups.isEmpty)
    }

    func testTripRollup_aggregateOptionForRoundsOneToThree_plusSinglesTotals640() {
        let rounds = makeScenarioFixture().rounds
        let r1 = computeAggregateRoundWinnerPoints(rounds[0])
        let r2 = computeAggregateRoundWinnerPoints(rounds[1])
        let r3 = computeAggregateRoundWinnerPoints(rounds[2])
        let r4 = computeHoleByHolePoints(rounds[3], matchWinnerBonus: 2)

        let totalA = (r1.teamPoints["team_a"] ?? 0) + (r2.teamPoints["team_a"] ?? 0) + (r3.teamPoints["team_a"] ?? 0) + (r4.teamPoints["team_a"] ?? 0)
        let totalB = (r1.teamPoints["team_b"] ?? 0) + (r2.teamPoints["team_b"] ?? 0) + (r3.teamPoints["team_b"] ?? 0) + (r4.teamPoints["team_b"] ?? 0)

        XCTAssertEqual(totalA, 330)
        XCTAssertEqual(totalB, 310)
        XCTAssertEqual(totalA + totalB, 640)
    }

    func testTripRollup_holeByHoleOptionForRoundsOneToThree_plusSinglesTotals640() {
        let rounds = makeScenarioFixture().rounds
        let r1 = computeHoleByHolePoints(rounds[0], matchWinnerBonus: 4)
        let r2 = computeHoleByHolePoints(rounds[1], matchWinnerBonus: 4)
        let r3 = computeHoleByHolePoints(rounds[2], matchWinnerBonus: 4)
        let r4 = computeHoleByHolePoints(rounds[3], matchWinnerBonus: 2)

        let totalA = (r1.teamPoints["team_a"] ?? 0) + (r2.teamPoints["team_a"] ?? 0) + (r3.teamPoints["team_a"] ?? 0) + (r4.teamPoints["team_a"] ?? 0)
        let totalB = (r1.teamPoints["team_b"] ?? 0) + (r2.teamPoints["team_b"] ?? 0) + (r3.teamPoints["team_b"] ?? 0) + (r4.teamPoints["team_b"] ?? 0)

        XCTAssertEqual(totalA, 336)
        XCTAssertEqual(totalB, 304)
        XCTAssertEqual(totalA + totalB, 640)
    }

    // MARK: - Scenario

    private func makeScenarioFixture() -> ScenarioFixture {
        let generatedPlayers = generatedPlayers()
        let split = balancedTeams(players: generatedPlayers)

        let teamA = split.a.enumerated().map { index, player in
            ScenarioPlayer(
                id: "p_a_\(index + 1)",
                fullName: player.fullName,
                handicap: player.handicap,
                teamSide: .a
            )
        }
        let teamB = split.b.enumerated().map { index, player in
            ScenarioPlayer(
                id: "p_b_\(index + 1)",
                fullName: player.fullName,
                handicap: player.handicap,
                teamSide: .b
            )
        }

        return ScenarioFixture(
            players: teamA + teamB,
            teamA: teamA,
            teamB: teamB,
            rounds: [
                buildPartnershipRound(
                    roundNumber: 1,
                    name: "Better Ball",
                    teamA: teamA,
                    teamB: teamB,
                    seed: baseSeed ^ 0x1010,
                    fieldTemplate: FormatTemplateRegistry.bestBall,
                    matchupTemplate: FormatTemplateRegistry.bestBallMatchup,
                    matchWinCounts: [(11, 7), (8, 10), (12, 6), (7, 11)],
                    scoreBuilder: buildIndividualPartnershipScores
                ),
                buildPartnershipRound(
                    roundNumber: 2,
                    name: "Captain's Choice",
                    teamA: teamA,
                    teamB: teamB,
                    seed: baseSeed ^ 0x2020,
                    fieldTemplate: FormatTemplateRegistry.captainsChoice,
                    matchupTemplate: captainsChoiceMatchupTemplate(),
                    matchWinCounts: [(10, 8), (13, 5), (8, 10), (7, 11)],
                    scoreBuilder: buildSharedPartnershipScores
                ),
                buildPartnershipRound(
                    roundNumber: 3,
                    name: "Shamble",
                    teamA: teamA,
                    teamB: teamB,
                    seed: baseSeed ^ 0x3030,
                    fieldTemplate: FormatTemplateRegistry.bestBall,
                    matchupTemplate: FormatTemplateRegistry.bestBallMatchup,
                    matchWinCounts: [(6, 12), (11, 7), (8, 10), (10, 8)],
                    scoreBuilder: buildIndividualPartnershipScores
                ),
                buildSinglesRound(teamA: teamA, teamB: teamB)
            ]
        )
    }

    private func generatedPlayers() -> [(fullName: String, handicap: Int)] {
        let names = [
            "Patrick O'Meara",
            "Matt Henry",
            "Scott Sternstein",
            "Mat Lyon",
            "Corey McCann",
            "Tommy Repik",
            "Michael Martin",
            "Connor Halloran",
            "Sam Collop",
            "Connor Budka",
            "Mark O'Meara",
            "Jordan Hensberger",
            "Peyton Vitter",
            "Andrew McCartney",
            "Matt Kepic",
            "Kyle Beard",
        ]

        var rng = SeededGenerator(seed: baseSeed)
        return names.map { (fullName: $0, handicap: rng.nextInt(in: 0...21)) }
    }

    private func balancedTeams(players: [(fullName: String, handicap: Int)]) -> (a: [(fullName: String, handicap: Int)], b: [(fullName: String, handicap: Int)]) {
        var rng = SeededGenerator(seed: baseSeed ^ 0xBADA55)
        let shuffled = rng.shuffle(players)
        let ordered = shuffled.enumerated().sorted { lhs, rhs in
            if lhs.element.handicap != rhs.element.handicap {
                return lhs.element.handicap > rhs.element.handicap
            }
            return lhs.offset < rhs.offset
        }.map(\.element)

        var teamA: [(fullName: String, handicap: Int)] = []
        var teamB: [(fullName: String, handicap: Int)] = []
        var totalA = 0
        var totalB = 0

        for player in ordered {
            if teamA.count == 8 {
                teamB.append(player)
                totalB += player.handicap
                continue
            }
            if teamB.count == 8 {
                teamA.append(player)
                totalA += player.handicap
                continue
            }

            if totalA <= totalB {
                teamA.append(player)
                totalA += player.handicap
            } else {
                teamB.append(player)
                totalB += player.handicap
            }
        }

        return (
            a: teamA.sorted { $0.fullName < $1.fullName },
            b: teamB.sorted { $0.fullName < $1.fullName }
        )
    }

    private func buildPartnershipRound(
        roundNumber: Int,
        name: String,
        teamA: [ScenarioPlayer],
        teamB: [ScenarioPlayer],
        seed: UInt64,
        fieldTemplate: GameTemplate,
        matchupTemplate: GameTemplate,
        matchWinCounts: [(Int, Int)],
        scoreBuilder: (
            [Partnership],
            [ScenarioPlayer],
            [Hole],
            String,
            [MatchFixture],
            [String: Int]
        ) -> [ScoreEntry]
    ) -> RoundFixture {
        let holes = makeHoles()
        let teams = makeTeams()
        let pairings = makePartnerships(roundNumber: roundNumber, teamA: teamA, teamB: teamB, seed: seed)
        let participants = makeParticipants(roundNumber: roundNumber, teamA: teamA, teamB: teamB, pairings: pairings)
        let scoringGroups = pairings.map { pairing in
            RoundScoringGroup(
                id: pairing.id,
                teamID: pairing.teamID,
                teeGroupID: pairing.teeGroupID,
                kind: .partnership,
                memberIDs: pairing.memberIDs,
                label: pairing.label,
                parentID: "round_\(roundNumber)"
            )
        }
        let matchFixtures = (0..<4).map { index in
            MatchFixture(
                id: "r\(roundNumber)_m\(index + 1)",
                leftOwnerID: "r\(roundNumber)_a\(index + 1)",
                rightOwnerID: "r\(roundNumber)_b\(index + 1)",
                leftWins: matchWinCounts[index].0,
                rightWins: matchWinCounts[index].1
            )
        }
        let ownerTeamIDs = Dictionary(uniqueKeysWithValues: pairings.map { ($0.id, $0.teamID) })
        let scoringUnitHandicaps = partnershipHandicapMap(for: pairings, players: teamA + teamB, usesScrambleAllowance: roundNumber == 2)

        let fieldSegment = RoundSegment(
            id: "seg1",
            roundID: "round_\(roundNumber)",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            gameFormat: .strokePlay,
            templateID: fieldTemplate.id,
            scoringUnits: roundNumber == 2 ? sharedPartnershipScoringUnits(for: pairings, players: teamA + teamB) : [],
            competitionScope: .field,
            parentID: "round_\(roundNumber)"
        )
        let matchupSegment = RoundSegment(
            id: "seg1",
            roundID: "round_\(roundNumber)",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            gameFormat: .strokePlay,
            templateID: matchupTemplate.id,
            scoringUnits: roundNumber == 2 ? sharedPartnershipScoringUnits(for: pairings, players: teamA + teamB) : [],
            matchups: matchFixtures.map { fixture in
                TeamMatchup(
                    id: fixture.id,
                    teamIDs: [],
                    scoreOwnerIDs: [fixture.leftOwnerID, fixture.rightOwnerID],
                    scoreOwnerScope: .partnership,
                    mode: .scoreOwner
                )
            },
            competitionScope: .matchup,
            parentID: "round_\(roundNumber)"
        )

        let seriesConfig = SeriesRoundConfiguration(
            formatTemplateID: fieldTemplate.id,
            competitionScope: .matchup,
            scoreOwnerScope: .partnership,
            matchupScoringStyle: .holeByHolePoints,
            holeWinPoints: 2,
            matchWinnerBonusPoints: 4,
            matchTiePolicy: .half,
            matchupMode: .teamVsTeam,
            teamAssignmentMode: .seriesTeams,
            teeGroupMode: .auto,
            scoreBasisOverride: .net
        )
        let roundConfig = RoundConfiguration(
            primaryFormat: .strokePlay,
            competitionScope: .matchup,
            scoreOwnerScope: .partnership,
            matchupScoringStyle: .holeByHolePoints,
            holeWinPoints: 2,
            matchWinnerBonusPoints: 4,
            matchTiePolicy: .half
        )

        let scores = scoreBuilder(
            pairings,
            teamA + teamB,
            holes,
            "round_\(roundNumber)",
            matchFixtures,
            scoringUnitHandicaps
        )

        return RoundFixture(
            roundNumber: roundNumber,
            name: name,
            seriesConfig: seriesConfig,
            roundConfig: roundConfig,
            holes: holes,
            teams: teams,
            participants: participants,
            scoringGroups: scoringGroups,
            fieldSegment: fieldSegment,
            matchupSegment: matchupSegment,
            fieldTemplate: fieldTemplate,
            matchupTemplate: matchupTemplate,
            scores: scores,
            matchFixtures: matchFixtures,
            ownerTeamIDs: ownerTeamIDs,
            scoringUnitHandicaps: scoringUnitHandicaps
        )
    }

    private func buildSinglesRound(teamA: [ScenarioPlayer], teamB: [ScenarioPlayer]) -> RoundFixture {
        let holes = makeHoles()
        let teams = makeTeams()
        var rngA = SeededGenerator(seed: baseSeed ^ 0x4041)
        var rngB = SeededGenerator(seed: baseSeed ^ 0x4042)
        let orderedA = rngA.shuffle(teamA)
        let orderedB = rngB.shuffle(teamB)

        var participants: [RoundParticipant] = []
        var matchFixtures: [MatchFixture] = []
        var ownerTeamIDs: [String: String] = [:]
        let winCounts = [(12, 6), (11, 7), (8, 10), (10, 8), (7, 11), (13, 5), (8, 10), (11, 7)]

        for groupIndex in 0..<4 {
            let teeGroupID = "r4_g\(groupIndex + 1)"
            let a1 = orderedA[groupIndex * 2]
            let a2 = orderedA[groupIndex * 2 + 1]
            let b1 = orderedB[groupIndex * 2]
            let b2 = orderedB[groupIndex * 2 + 1]

            let groupPlayers = [(a1, 1), (a2, 2), (b1, 3), (b2, 4)]
            for (player, teeOrder) in groupPlayers {
                participants.append(
                    RoundParticipant(
                        id: player.id,
                        name: Name(player.fullName),
                        originalHandicap: player.handicap,
                        adjustedHandicap: player.handicap,
                        teamID: player.teamSide.teamID,
                        groupID: teeGroupID,
                        teeOrder: teeOrder,
                        parentID: "round_4"
                    )
                )
                ownerTeamIDs[player.id] = player.teamSide.teamID
            }

            let firstMatchIndex = groupIndex * 2
            matchFixtures.append(
                MatchFixture(
                    id: "r4_m\(firstMatchIndex + 1)",
                    leftOwnerID: a1.id,
                    rightOwnerID: b1.id,
                    leftWins: winCounts[firstMatchIndex].0,
                    rightWins: winCounts[firstMatchIndex].1
                )
            )
            matchFixtures.append(
                MatchFixture(
                    id: "r4_m\(firstMatchIndex + 2)",
                    leftOwnerID: a2.id,
                    rightOwnerID: b2.id,
                    leftWins: winCounts[firstMatchIndex + 1].0,
                    rightWins: winCounts[firstMatchIndex + 1].1
                )
            )
        }

        let fieldSegment = RoundSegment(
            id: "seg1",
            roundID: "round_4",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            gameFormat: .strokePlay,
            templateID: FormatTemplateRegistry.strokePlay.id,
            competitionScope: .field,
            parentID: "round_4"
        )
        let matchupSegment = RoundSegment(
            id: "seg1",
            roundID: "round_4",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            gameFormat: .strokePlay,
            templateID: FormatTemplateRegistry.matchPlayIndividual.id,
            matchups: matchFixtures.map { fixture in
                TeamMatchup(
                    id: fixture.id,
                    teamIDs: [],
                    participantIDs: [fixture.leftOwnerID, fixture.rightOwnerID],
                    mode: .individual
                )
            },
            competitionScope: .matchup,
            parentID: "round_4"
        )
        let seriesConfig = SeriesRoundConfiguration(
            formatTemplateID: FormatTemplateRegistry.matchPlayIndividual.id,
            competitionScope: .matchup,
            scoreOwnerScope: .individual,
            matchupScoringStyle: .holeByHolePoints,
            holeWinPoints: 1,
            matchWinnerBonusPoints: 2,
            matchTiePolicy: .half,
            matchupMode: .individualVsIndividual,
            teamAssignmentMode: .seriesTeams,
            teeGroupMode: .auto,
            scoreBasisOverride: .net
        )
        let roundConfig = RoundConfiguration(
            primaryFormat: .strokePlay,
            competitionScope: .matchup,
            scoreOwnerScope: .individual,
            matchupScoringStyle: .holeByHolePoints,
            holeWinPoints: 1,
            matchWinnerBonusPoints: 2,
            matchTiePolicy: .half
        )
        let scores = buildSinglesScores(
            participants: participants,
            holes: holes,
            parentID: "round_4",
            matchFixtures: matchFixtures
        )

        return RoundFixture(
            roundNumber: 4,
            name: "Match Play Singles",
            seriesConfig: seriesConfig,
            roundConfig: roundConfig,
            holes: holes,
            teams: teams,
            participants: participants,
            scoringGroups: [],
            fieldSegment: fieldSegment,
            matchupSegment: matchupSegment,
            fieldTemplate: FormatTemplateRegistry.strokePlay,
            matchupTemplate: FormatTemplateRegistry.matchPlayIndividual,
            scores: scores,
            matchFixtures: matchFixtures,
            ownerTeamIDs: ownerTeamIDs,
            scoringUnitHandicaps: [:]
        )
    }

    // MARK: - Score Builders

    private func buildIndividualPartnershipScores(
        pairings: [Partnership],
        players: [ScenarioPlayer],
        holes: [Hole],
        parentID: String,
        matchFixtures: [MatchFixture],
        _: [String: Int]
    ) -> [ScoreEntry] {
        let playerMap = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        let pairingMap = Dictionary(uniqueKeysWithValues: pairings.map { ($0.id, $0) })
        let patternByMatch = Dictionary(uniqueKeysWithValues: matchFixtures.map { ($0.id, distributedWinnerPattern(leftWins: $0.leftWins, rightWins: $0.rightWins)) })

        var entries: [ScoreEntry] = []

        for fixture in matchFixtures {
            let leftPair = tryUnwrap(pairingMap[fixture.leftOwnerID])
            let rightPair = tryUnwrap(pairingMap[fixture.rightOwnerID])
            let pattern = tryUnwrap(patternByMatch[fixture.id])

            for (holeIndex, hole) in holes.enumerated() {
                let leftTarget = pattern[holeIndex] == .a ? -1 : 0
                let rightTarget = pattern[holeIndex] == .b ? -1 : 0

                entries.append(contentsOf: individualEntries(for: leftPair, targetScoreToPar: leftTarget, hole: hole, parentID: parentID, playerMap: playerMap))
                entries.append(contentsOf: individualEntries(for: rightPair, targetScoreToPar: rightTarget, hole: hole, parentID: parentID, playerMap: playerMap))
            }
        }

        return entries
    }

    private func buildSharedPartnershipScores(
        pairings: [Partnership],
        players: [ScenarioPlayer],
        holes: [Hole],
        parentID: String,
        matchFixtures: [MatchFixture],
        dilutedHandicaps: [String: Int]
    ) -> [ScoreEntry] {
        let pairingMap = Dictionary(uniqueKeysWithValues: pairings.map { ($0.id, $0) })
        let patternByMatch = Dictionary(uniqueKeysWithValues: matchFixtures.map { ($0.id, distributedWinnerPattern(leftWins: $0.leftWins, rightWins: $0.rightWins)) })

        var entries: [ScoreEntry] = []
        for fixture in matchFixtures {
            let leftPair = tryUnwrap(pairingMap[fixture.leftOwnerID])
            let rightPair = tryUnwrap(pairingMap[fixture.rightOwnerID])
            let pattern = tryUnwrap(patternByMatch[fixture.id])

            for (holeIndex, hole) in holes.enumerated() {
                let leftTarget = pattern[holeIndex] == .a ? -1 : 0
                let rightTarget = pattern[holeIndex] == .b ? -1 : 0

                entries.append(sharedEntry(
                    scoringUnitID: leftPair.id,
                    participantIDs: leftPair.memberIDs,
                    groupID: leftPair.teeGroupID,
                    hole: hole,
                    targetScoreToPar: leftTarget,
                    handicap: tryUnwrap(dilutedHandicaps[leftPair.id]),
                    parentID: parentID
                ))
                entries.append(sharedEntry(
                    scoringUnitID: rightPair.id,
                    participantIDs: rightPair.memberIDs,
                    groupID: rightPair.teeGroupID,
                    hole: hole,
                    targetScoreToPar: rightTarget,
                    handicap: tryUnwrap(dilutedHandicaps[rightPair.id]),
                    parentID: parentID
                ))
            }
        }

        _ = players
        return entries
    }

    private func buildSinglesScores(
        participants: [RoundParticipant],
        holes: [Hole],
        parentID: String,
        matchFixtures: [MatchFixture]
    ) -> [ScoreEntry] {
        let participantMap = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let patternByMatch = Dictionary(uniqueKeysWithValues: matchFixtures.map { ($0.id, distributedWinnerPattern(leftWins: $0.leftWins, rightWins: $0.rightWins)) })

        var entries: [ScoreEntry] = []
        for fixture in matchFixtures {
            let left = tryUnwrap(participantMap[fixture.leftOwnerID])
            let right = tryUnwrap(participantMap[fixture.rightOwnerID])
            let pattern = tryUnwrap(patternByMatch[fixture.id])

            for (holeIndex, hole) in holes.enumerated() {
                let leftTarget = pattern[holeIndex] == .a ? -1 : 0
                let rightTarget = pattern[holeIndex] == .b ? -1 : 0

                entries.append(singleEntry(for: left, targetScoreToPar: leftTarget, hole: hole, parentID: parentID))
                entries.append(singleEntry(for: right, targetScoreToPar: rightTarget, hole: hole, parentID: parentID))
            }
        }

        return entries
    }

    // MARK: - Scoring

    private func computeAggregateRoundWinnerPoints(_ round: RoundFixture) -> RoundPointSummary {
        let basis: ScoreBasis = .net
        let result = ScoringEngine.computeWithPipeline(
            scores: round.scores,
            participants: round.participants,
            teams: round.teams,
            segment: round.fieldSegment,
            holes: round.holes,
            basis: basis,
            template: round.fieldTemplate,
            scoreOwnerScope: round.roundConfig.scoreOwnerScope,
            scoringGroups: round.scoringGroups
        )

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0.total) })
        var ownerPoints: [String: Double] = [:]
        var matchupPoints: [String: [String: Double]] = [:]

        for fixture in round.matchFixtures {
            let left = tryUnwrap(rowMap[fixture.leftOwnerID])
            let right = tryUnwrap(rowMap[fixture.rightOwnerID])
            let leftPoints: Double
            let rightPoints: Double
            if left < right {
                leftPoints = 40
                rightPoints = 0
            } else if right < left {
                leftPoints = 0
                rightPoints = 40
            } else {
                leftPoints = 20
                rightPoints = 20
            }
            ownerPoints[fixture.leftOwnerID] = leftPoints
            ownerPoints[fixture.rightOwnerID] = rightPoints
            matchupPoints[fixture.id] = [
                fixture.leftOwnerID: leftPoints,
                fixture.rightOwnerID: rightPoints,
            ]
        }

        return RoundPointSummary(
            ownerPoints: ownerPoints,
            teamPoints: rollUpTeamPoints(ownerPoints: ownerPoints, ownerTeamIDs: round.ownerTeamIDs),
            matchupPoints: matchupPoints
        )
    }

    private func computeHoleByHolePoints(_ round: RoundFixture, matchWinnerBonus: Double) -> RoundPointSummary {
        let result = ScoringEngine.computeWithPipeline(
            scores: round.scores,
            participants: round.participants,
            teams: round.teams,
            segment: round.matchupSegment,
            holes: round.holes,
            basis: .net,
            template: round.matchupTemplate,
            scoreOwnerScope: round.roundConfig.scoreOwnerScope,
            scoringGroups: round.scoringGroups,
            perHoleWinPoints: round.roundConfig.resolvedHoleWinPoints
        )

        var ownerPoints: [String: Double] = [:]
        var matchupPoints: [String: [String: Double]] = [:]

        for matchupResult in result.matchupResults {
            let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0.total) })
            let leftID = matchupResult.matchup.pairingIDs()[0]
            let rightID = matchupResult.matchup.pairingIDs()[1]

            var leftPoints = tryUnwrap(rowMap[leftID])
            var rightPoints = tryUnwrap(rowMap[rightID])

            if leftPoints > rightPoints {
                leftPoints += matchWinnerBonus
            } else if rightPoints > leftPoints {
                rightPoints += matchWinnerBonus
            }

            ownerPoints[leftID] = leftPoints
            ownerPoints[rightID] = rightPoints
            matchupPoints[matchupResult.matchup.id] = [
                leftID: leftPoints,
                rightID: rightPoints,
            ]
        }

        return RoundPointSummary(
            ownerPoints: ownerPoints,
            teamPoints: rollUpTeamPoints(ownerPoints: ownerPoints, ownerTeamIDs: round.ownerTeamIDs),
            matchupPoints: matchupPoints
        )
    }

    // MARK: - Helpers

    private func makeHoles() -> [Hole] {
        (0..<18).map { index in
            Hole(
                number: index + 1,
                par: holePars[index],
                yardage: 350 + (index * 10),
                handicap: holeHandicaps[index]
            )
        }
    }

    private func makeTeams() -> [RoundTeam] {
        [
            RoundTeam(id: "team_a", name: "Team A", color: "red", index: 0, createdAt: .init(), parentID: "round"),
            RoundTeam(id: "team_b", name: "Team B", color: "blue", index: 1, createdAt: .init(), parentID: "round"),
        ]
    }

    private func makePartnerships(
        roundNumber: Int,
        teamA: [ScenarioPlayer],
        teamB: [ScenarioPlayer],
        seed: UInt64
    ) -> [Partnership] {
        var rngA = SeededGenerator(seed: seed ^ 0xAAA1)
        var rngB = SeededGenerator(seed: seed ^ 0xBBB2)
        let shuffledA = rngA.shuffle(teamA)
        let shuffledB = rngB.shuffle(teamB)

        var result: [Partnership] = []
        for index in 0..<4 {
            let groupID = "r\(roundNumber)_g\(index + 1)"
            let pairAPlayers = Array(shuffledA[(index * 2)...(index * 2 + 1)]).sorted { $0.fullName < $1.fullName }
            let pairBPlayers = Array(shuffledB[(index * 2)...(index * 2 + 1)]).sorted { $0.fullName < $1.fullName }

            result.append(
                Partnership(
                    id: "r\(roundNumber)_a\(index + 1)",
                    side: .a,
                    teamID: TeamSide.a.teamID,
                    teeGroupID: groupID,
                    memberIDs: pairAPlayers.map(\.id),
                    label: pairAPlayers.map(\.fullName).joined(separator: " + ")
                )
            )
            result.append(
                Partnership(
                    id: "r\(roundNumber)_b\(index + 1)",
                    side: .b,
                    teamID: TeamSide.b.teamID,
                    teeGroupID: groupID,
                    memberIDs: pairBPlayers.map(\.id),
                    label: pairBPlayers.map(\.fullName).joined(separator: " + ")
                )
            )
        }
        return result
    }

    private func makeParticipants(
        roundNumber: Int,
        teamA: [ScenarioPlayer],
        teamB: [ScenarioPlayer],
        pairings: [Partnership]
    ) -> [RoundParticipant] {
        let playerMap = Dictionary(uniqueKeysWithValues: (teamA + teamB).map { ($0.id, $0) })
        var assignments: [(ScenarioPlayer, String, Int)] = []

        for index in 0..<4 {
            let pairA = tryUnwrap(pairings.first(where: { $0.id == "r\(roundNumber)_a\(index + 1)" }))
            let pairB = tryUnwrap(pairings.first(where: { $0.id == "r\(roundNumber)_b\(index + 1)" }))

            for (offset, memberID) in pairA.memberIDs.enumerated() {
                assignments.append((tryUnwrap(playerMap[memberID]), pairA.teeGroupID, offset + 1))
            }
            for (offset, memberID) in pairB.memberIDs.enumerated() {
                assignments.append((tryUnwrap(playerMap[memberID]), pairB.teeGroupID, offset + 3))
            }
        }

        return assignments.map { player, groupID, teeOrder in
            RoundParticipant(
                id: player.id,
                name: Name(player.fullName),
                originalHandicap: player.handicap,
                adjustedHandicap: player.handicap,
                teamID: player.teamSide.teamID,
                groupID: groupID,
                teeOrder: teeOrder,
                parentID: "round_\(roundNumber)"
            )
        }
    }

    private func partnershipHandicapMap(
        for pairings: [Partnership],
        players: [ScenarioPlayer],
        usesScrambleAllowance: Bool
    ) -> [String: Int] {
        let playerMap = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: pairings.map { pairing in
            let handicaps = pairing.memberIDs.compactMap { playerMap[$0]?.handicap }.sorted()
            let value: Int
            if usesScrambleAllowance {
                let low = Double(handicaps[0])
                let high = Double(handicaps[1])
                value = Int((low * 0.35 + high * 0.15).rounded())
            } else {
                value = Int((Double(handicaps.reduce(0, +)) / Double(handicaps.count)).rounded())
            }
            return (pairing.id, value)
        })
    }

    private func sharedPartnershipScoringUnits(for pairings: [Partnership], players: [ScenarioPlayer]) -> [ScoringUnit] {
        let playerMap = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        return pairings.map { pairing in
            let handicaps = pairing.memberIDs.compactMap { playerMap[$0]?.handicap }.sorted()
            let lowID = pairing.memberIDs.min(by: { (playerMap[$0]?.handicap ?? 0) < (playerMap[$1]?.handicap ?? 0) }) ?? pairing.memberIDs[0]
            let highID = pairing.memberIDs.first(where: { $0 != lowID }) ?? pairing.memberIDs[0]
            let low = Double(handicaps[0])
            let high = Double(handicaps[1])
            return ScoringUnit(
                id: pairing.id,
                owner: .scoreOwner,
                ownerIDs: pairing.memberIDs,
                scoringMethod: .aggregate,
                handicapAdjustments: [
                    lowID: low * 0.35,
                    highID: high * 0.15,
                ]
            )
        }
    }

    private func captainsChoiceMatchupTemplate() -> GameTemplate {
        GameTemplate(
            id: "captains_choice_matchup",
            name: "Captain's Choice Matchup",
            description: "Two-man scramble matchups scored hole-by-hole.",
            icon: "e533",
            category: .team,
            aliases: ["scramble_matchup"],
            inputMode: .strokes,
            subject: .competitionSide,
            scoreSource: .shared,
            competitionScope: .matchup,
            pipeline: [
                .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half))
            ],
            leaderboardSort: .highestWins,
            requirements: TemplateRequirements(
                teamSize: .exact(2),
                requiresTeams: true,
                requiresMatchups: true,
                requiresHandicaps: false,
                defaultHandicapConfig: .individualStrokePlay,
                defaultMaxScoreOverPar: .quad,
                defaultScoreBasis: .gross
            )
        )
    }

    private func individualEntries(
        for pairing: Partnership,
        targetScoreToPar: Int,
        hole: Hole,
        parentID: String,
        playerMap: [String: ScenarioPlayer]
    ) -> [ScoreEntry] {
        pairing.memberIDs.enumerated().map { index, memberID in
            let player = tryUnwrap(playerMap[memberID])
            let adjustedTarget = index == (hole.number % 2) ? targetScoreToPar : targetScoreToPar + 1
            let participant = RoundParticipant(
                id: player.id,
                name: Name(player.fullName),
                originalHandicap: player.handicap,
                adjustedHandicap: player.handicap,
                teamID: player.teamSide.teamID,
                groupID: pairing.teeGroupID,
                parentID: parentID
            )
            return singleEntry(for: participant, targetScoreToPar: adjustedTarget, hole: hole, parentID: parentID)
        }
    }

    private func sharedEntry(
        scoringUnitID: String,
        participantIDs: [String],
        groupID: String,
        hole: Hole,
        targetScoreToPar: Int,
        handicap: Int,
        parentID: String
    ) -> ScoreEntry {
        let received = ScoringEngine.strokesReceived(
            handicap: handicap,
            holeHandicap: hole.handicap,
            useHandicaps: true
        )
        let strokes = max(1, hole.par + targetScoreToPar + received)
        return ScoreEntry(
            id: ScoreEntry.makeID(hole: hole.number, segment: "seg1", scoringUnit: scoringUnitID),
            holeNumber: hole.number,
            segmentID: "seg1",
            groupID: groupID,
            scoringUnitID: scoringUnitID,
            participantIDs: participantIDs,
            strokes: strokes,
            pickedUp: false,
            entryID: participantIDs.first ?? scoringUnitID,
            parentID: parentID
        )
    }

    private func singleEntry(
        for participant: RoundParticipant,
        targetScoreToPar: Int,
        hole: Hole,
        parentID: String
    ) -> ScoreEntry {
        let received = ScoringEngine.strokesReceived(
            handicap: participant.adjustedHandicap,
            holeHandicap: hole.handicap,
            useHandicaps: true
        )
        let strokes = max(1, hole.par + targetScoreToPar + received)
        return ScoreEntry(
            id: ScoreEntry.makeID(hole: hole.number, segment: "seg1", scoringUnit: participant.id),
            holeNumber: hole.number,
            segmentID: "seg1",
            groupID: participant.groupID ?? "",
            scoringUnitID: participant.id,
            participantIDs: [participant.id],
            strokes: strokes,
            pickedUp: false,
            entryID: participant.id,
            parentID: parentID
        )
    }

    private func distributedWinnerPattern(leftWins: Int, rightWins: Int) -> [TeamSide] {
        precondition(leftWins + rightWins == 18)
        return Array(repeating: TeamSide.a, count: leftWins) + Array(repeating: TeamSide.b, count: rightWins)
    }

    private func rollUpTeamPoints(ownerPoints: [String: Double], ownerTeamIDs: [String: String]) -> [String: Double] {
        ownerPoints.reduce(into: [:]) { partial, entry in
            guard let teamID = ownerTeamIDs[entry.key] else { return }
            partial[teamID, default: 0] += entry.value
        }
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected value to be present", file: file, line: line)
            fatalError("Unexpected nil")
        }
        return value
    }
}
