//
//  CompetitionScopeTests.swift
//  HackersTests
//
//  Created by Kyle Beard on 3/8/26.
//

@testable import Hackers
import XCTest

final class CompetitionScopeTests: XCTestCase {

    // MARK: - Fixtures

    private func makeParticipant(
        id: String, name: String, handicap: Int = 0,
        teamID: String? = nil, groupID: String? = nil,
        presenceStatus: RoundParticipantPresenceStatus? = nil
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            name: Name(name, "Test"),
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID,
            presenceStatus: presenceStatus
        )
    }

    private func makeHoles(count: Int = 18) -> [Hole] {
        let pars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 4, 5]
        let handicaps = [7, 3, 15, 1, 9, 17, 5, 11, 13, 8, 16, 2, 10, 4, 18, 6, 12, 14]
        return (0..<count).map { i in
            Hole(number: i + 1, par: pars[i % pars.count], yardage: 350 + i * 10, handicap: handicaps[i % handicaps.count])
        }
    }

    private func makeSegment(
        holeRange: HoleRange = HoleRange(startHole: 1, endHole: 18),
        matchups: [TeamMatchup]? = nil,
        competitionScope: CompetitionScope? = nil
    ) -> RoundSegment {
        RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: holeRange,
            matchups: matchups,
            competitionScope: competitionScope
        )
    }

    private func makeScore(pid: String, hole: Int, strokes: Int, seg: String = "seg1") -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: hole, segment: seg, scoringUnit: pid),
            holeNumber: hole,
            segmentID: seg,
            scoringUnitID: pid,
            participantIDs: [pid],
            strokes: strokes,
            pickedUp: false,
            entryID: pid,
            parentID: "round1"
        )
    }

    private func makeSharedScore(
        unitID: String,
        participantIDs: [String],
        hole: Int,
        strokes: Int,
        seg: String = "seg1"
    ) -> ScoreEntry {
        ScoreEntry(
            id: ScoreEntry.makeID(hole: hole, segment: seg, scoringUnit: unitID),
            holeNumber: hole,
            segmentID: seg,
            scoringUnitID: unitID,
            participantIDs: participantIDs,
            strokes: strokes,
            pickedUp: false,
            entryID: participantIDs.first ?? unitID,
            parentID: "round1"
        )
    }

    private func makeLiveMatchupViewModelSnapshot(
        participants: [RoundParticipant],
        teams: [RoundTeam] = [],
        segment: RoundSegment,
        scores: [ScoreEntry],
        template: GameTemplate = FormatTemplateRegistry.strokePlayMatchupIndividual
    ) -> RoundSnapshot {
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: template.requirements.requiresTeams,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: template),
            competitionScope: .matchup,
            matchupResolutionStyle: .roundAggregate
        )
        return RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            segments: [segment],
            scoring: scores
        )
    }

    // MARK: - Live Matchup Result Chips

    @MainActor
    func testLiveMatchupChipShowsLeaderUntilAllMatchupScoresAreEntered() throws {
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
        ]
        let matchup = TeamMatchup(
            id: "m1",
            teamIDs: [],
            participantIDs: ["p1", "p2"],
            mode: .individual
        )
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 18),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let snapshot = makeLiveMatchupViewModelSnapshot(
            participants: participants,
            segment: segment,
            scores: [
                makeScore(pid: "p1", hole: 1, strokes: 3),
                makeScore(pid: "p2", hole: 1, strokes: 5),
            ]
        )
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Alice vs Bob", rows: [])

        XCTAssertFalse(viewModel.isLiveMatchupFullyScored(section))
        XCTAssertEqual(viewModel.liveMatchupResultChipTitle(for: "p1", in: section), "Leader")
        XCTAssertNil(viewModel.liveMatchupResultChipTitle(for: "p2", in: section))
    }

    @MainActor
    func testLiveMatchupChipShowsWinnerAfterAllMatchupScoresAreEntered() throws {
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
        ]
        let matchup = TeamMatchup(
            id: "m1",
            teamIDs: [],
            participantIDs: ["p1", "p2"],
            mode: .individual
        )
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let snapshot = makeLiveMatchupViewModelSnapshot(
            participants: participants,
            segment: segment,
            scores: [
                makeScore(pid: "p1", hole: 1, strokes: 3),
                makeScore(pid: "p1", hole: 2, strokes: 4),
                makeScore(pid: "p2", hole: 1, strokes: 5),
                makeScore(pid: "p2", hole: 2, strokes: 5),
            ]
        )
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: snapshot)
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Alice vs Bob", rows: [])

        XCTAssertTrue(viewModel.isLiveMatchupFullyScored(section))
        XCTAssertEqual(viewModel.liveMatchupResultChipTitle(for: "p1", in: section), "Winner")
        XCTAssertNil(viewModel.liveMatchupResultChipTitle(for: "p2", in: section))
    }

    @MainActor
    func testLiveMatchupChipShowsTieOnlyAfterAllMatchupScoresAreEntered() throws {
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
        ]
        let matchup = TeamMatchup(
            id: "m1",
            teamIDs: [],
            participantIDs: ["p1", "p2"],
            mode: .individual
        )
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let viewModel = LiveRoundViewModel()
        viewModel.set(snapshot: makeLiveMatchupViewModelSnapshot(
            participants: participants,
            segment: segment,
            scores: [
                makeScore(pid: "p1", hole: 1, strokes: 4),
                makeScore(pid: "p1", hole: 2, strokes: 5),
                makeScore(pid: "p2", hole: 1, strokes: 4),
                makeScore(pid: "p2", hole: 2, strokes: 5),
            ]
        ))
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Alice vs Bob", rows: [])

        XCTAssertTrue(viewModel.isLiveMatchupFullyScored(section))
        XCTAssertEqual(viewModel.liveMatchupResultChipTitle(for: "p1", in: section), "Tie")
        XCTAssertEqual(viewModel.liveMatchupResultChipTitle(for: "p2", in: section), "Tie")
    }

    @MainActor
    func testLiveMatchupCompletionCountsSharedSideScoresOncePerHole() throws {
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dana", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchup = TeamMatchup(id: "m1", teamIDs: ["t1", "t2"], mode: .team)
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Team 1 vs Team 2", rows: [])
        let viewModel = LiveRoundViewModel()

        viewModel.set(snapshot: makeLiveMatchupViewModelSnapshot(
            participants: participants,
            teams: teams,
            segment: segment,
            scores: [
                makeSharedScore(unitID: "t1", participantIDs: ["p1", "p2"], hole: 1, strokes: 4),
                makeSharedScore(unitID: "t1", participantIDs: ["p1", "p2"], hole: 2, strokes: 4),
                makeSharedScore(unitID: "t2", participantIDs: ["p3", "p4"], hole: 1, strokes: 5),
            ],
            template: FormatTemplateRegistry.captainsChoice
        ))
        XCTAssertFalse(viewModel.isLiveMatchupFullyScored(section))

        viewModel.set(snapshot: makeLiveMatchupViewModelSnapshot(
            participants: participants,
            teams: teams,
            segment: segment,
            scores: [
                makeSharedScore(unitID: "t1", participantIDs: ["p1", "p2"], hole: 1, strokes: 4),
                makeSharedScore(unitID: "t1", participantIDs: ["p1", "p2"], hole: 2, strokes: 4),
                makeSharedScore(unitID: "t2", participantIDs: ["p3", "p4"], hole: 1, strokes: 5),
                makeSharedScore(unitID: "t2", participantIDs: ["p3", "p4"], hole: 2, strokes: 5),
            ],
            template: FormatTemplateRegistry.captainsChoice
        ))
        XCTAssertTrue(viewModel.isLiveMatchupFullyScored(section))
    }

    // MARK: - Field Scope: Best Ball (4 teams, all compete on one leaderboard)

    func testFieldScope_BestBall_4Teams() {
        let holes = makeHoles(count: 4)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
            makeParticipant(id: "p5", name: "Eve", teamID: "t3"),
            makeParticipant(id: "p6", name: "Frank", teamID: "t3"),
            makeParticipant(id: "p7", name: "Grace", teamID: "t4"),
            makeParticipant(id: "p8", name: "Hank", teamID: "t4"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
            RoundTeam(id: "t3", name: "Team 3", color: "green", index: 2, createdAt: .init()),
            RoundTeam(id: "t4", name: "Team 4", color: "purple", index: 3, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 4))
        let template = FormatTemplateRegistry.bestBall

        // Pars: 4, 4, 3, 4
        // Team 1: Alice=3,4,3,4 Bob=5,5,4,5 → best=3,4,3,4 → -1+0+0+0 = -1
        // Team 2: Charlie=4,3,2,5 Dave=5,4,3,4 → best=4,3,2,4 → 0-1-1+0 = -2
        // Team 3: Eve=5,5,4,5 Frank=4,4,3,5 → best=4,4,3,5 → 0+0+0+1 = +1
        // Team 4: Grace=3,3,2,3 Hank=6,6,5,6 → best=3,3,2,3 → -1-1-1-1 = -4
        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: 3), makeScore(pid: "p1", hole: 2, strokes: 4),
            makeScore(pid: "p1", hole: 3, strokes: 3), makeScore(pid: "p1", hole: 4, strokes: 4),
            makeScore(pid: "p2", hole: 1, strokes: 5), makeScore(pid: "p2", hole: 2, strokes: 5),
            makeScore(pid: "p2", hole: 3, strokes: 4), makeScore(pid: "p2", hole: 4, strokes: 5),
            makeScore(pid: "p3", hole: 1, strokes: 4), makeScore(pid: "p3", hole: 2, strokes: 3),
            makeScore(pid: "p3", hole: 3, strokes: 2), makeScore(pid: "p3", hole: 4, strokes: 5),
            makeScore(pid: "p4", hole: 1, strokes: 5), makeScore(pid: "p4", hole: 2, strokes: 4),
            makeScore(pid: "p4", hole: 3, strokes: 3), makeScore(pid: "p4", hole: 4, strokes: 4),
            makeScore(pid: "p5", hole: 1, strokes: 5), makeScore(pid: "p5", hole: 2, strokes: 5),
            makeScore(pid: "p5", hole: 3, strokes: 4), makeScore(pid: "p5", hole: 4, strokes: 5),
            makeScore(pid: "p6", hole: 1, strokes: 4), makeScore(pid: "p6", hole: 2, strokes: 4),
            makeScore(pid: "p6", hole: 3, strokes: 3), makeScore(pid: "p6", hole: 4, strokes: 5),
            makeScore(pid: "p7", hole: 1, strokes: 3), makeScore(pid: "p7", hole: 2, strokes: 3),
            makeScore(pid: "p7", hole: 3, strokes: 2), makeScore(pid: "p7", hole: 4, strokes: 3),
            makeScore(pid: "p8", hole: 1, strokes: 6), makeScore(pid: "p8", hole: 2, strokes: 6),
            makeScore(pid: "p8", hole: 3, strokes: 5), makeScore(pid: "p8", hole: 4, strokes: 6),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: template
        )

        XCTAssertEqual(result.rows.count, 4, "Field scope should produce 4 team rows")
        XCTAssertTrue(result.matchupResults.isEmpty, "Field scope should have no matchup results")

        let rowMap = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["t1"]!.total, -1, accuracy: 0.01, "Team 1 best ball should be -1")
        XCTAssertEqual(rowMap["t2"]!.total, -2, accuracy: 0.01, "Team 2 best ball should be -2")
        XCTAssertEqual(rowMap["t3"]!.total, 1, accuracy: 0.01, "Team 3 best ball should be +1")
        XCTAssertEqual(rowMap["t4"]!.total, -4, accuracy: 0.01, "Team 4 best ball should be -4")
    }

    // MARK: - Matchup Scope: Best Ball, 2 matchups

    func testMatchupScope_BestBall_2Matchups() {
        let holes = makeHoles(count: 4)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
            makeParticipant(id: "p5", name: "Eve", teamID: "t3"),
            makeParticipant(id: "p6", name: "Frank", teamID: "t3"),
            makeParticipant(id: "p7", name: "Grace", teamID: "t4"),
            makeParticipant(id: "p8", name: "Hank", teamID: "t4"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
            RoundTeam(id: "t3", name: "Team 3", color: "green", index: 2, createdAt: .init()),
            RoundTeam(id: "t4", name: "Team 4", color: "purple", index: 3, createdAt: .init()),
        ]
        let matchups = [
            TeamMatchup(id: "m1", teamIDs: ["t1", "t2"]),
            TeamMatchup(id: "m2", teamIDs: ["t3", "t4"]),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 4), matchups: matchups, competitionScope: .matchup)
        let template = FormatTemplateRegistry.bestBallMatchup

        // Pars: 4, 4, 3, 4
        // Matchup 1 (t1 vs t2):
        //   t1 best ball: 3,4,3,4 → -1,0,0,0
        //   t2 best ball: 4,3,2,4 → 0,-1,-1,0
        //   Hole 1: t1 wins (lower is better: -1 < 0) → t1=1, t2=0
        //   Hole 2: t2 wins (0 > -1) → t1=0, t2=1
        //   Hole 3: t2 wins (0 > -1) → t1=0, t2=1
        //   Hole 4: tie (0 == 0) → t1=0.5, t2=0.5
        //   Total: t1=1.5, t2=2.5
        //
        // Matchup 2 (t3 vs t4):
        //   t3 best ball: 4,4,3,5 → 0,0,0,+1
        //   t4 best ball: 3,3,2,3 → -1,-1,-1,-1
        //   Hole 1: t4 wins (-1 < 0) → t3=0, t4=1
        //   Hole 2: t4 wins (-1 < 0) → t3=0, t4=1
        //   Hole 3: t4 wins (-1 < 0) → t3=0, t4=1
        //   Hole 4: t4 wins (-1 < +1) → t3=0, t4=1
        //   Total: t3=0, t4=4

        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: 3), makeScore(pid: "p1", hole: 2, strokes: 4),
            makeScore(pid: "p1", hole: 3, strokes: 3), makeScore(pid: "p1", hole: 4, strokes: 4),
            makeScore(pid: "p2", hole: 1, strokes: 5), makeScore(pid: "p2", hole: 2, strokes: 5),
            makeScore(pid: "p2", hole: 3, strokes: 4), makeScore(pid: "p2", hole: 4, strokes: 5),
            makeScore(pid: "p3", hole: 1, strokes: 4), makeScore(pid: "p3", hole: 2, strokes: 3),
            makeScore(pid: "p3", hole: 3, strokes: 2), makeScore(pid: "p3", hole: 4, strokes: 5),
            makeScore(pid: "p4", hole: 1, strokes: 5), makeScore(pid: "p4", hole: 2, strokes: 4),
            makeScore(pid: "p4", hole: 3, strokes: 3), makeScore(pid: "p4", hole: 4, strokes: 4),
            makeScore(pid: "p5", hole: 1, strokes: 5), makeScore(pid: "p5", hole: 2, strokes: 5),
            makeScore(pid: "p5", hole: 3, strokes: 4), makeScore(pid: "p5", hole: 4, strokes: 5),
            makeScore(pid: "p6", hole: 1, strokes: 4), makeScore(pid: "p6", hole: 2, strokes: 4),
            makeScore(pid: "p6", hole: 3, strokes: 3), makeScore(pid: "p6", hole: 4, strokes: 5),
            makeScore(pid: "p7", hole: 1, strokes: 3), makeScore(pid: "p7", hole: 2, strokes: 3),
            makeScore(pid: "p7", hole: 3, strokes: 2), makeScore(pid: "p7", hole: 4, strokes: 3),
            makeScore(pid: "p8", hole: 1, strokes: 6), makeScore(pid: "p8", hole: 2, strokes: 6),
            makeScore(pid: "p8", hole: 3, strokes: 5), makeScore(pid: "p8", hole: 4, strokes: 6),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: template
        )

        XCTAssertEqual(result.matchupResults.count, 2, "Should have 2 matchup results")
        XCTAssertEqual(result.rows.count, 4, "Should have 4 total team rows across matchups")

        let m1 = result.matchupResults.first { $0.matchup.id == "m1" }!
        let m1Map = Dictionary(uniqueKeysWithValues: m1.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(m1Map["t1"]?.total ?? 0, 1.5, accuracy: 0.01, "Matchup 1: Team 1 should have 1.5 pts")
        XCTAssertEqual(m1Map["t2"]?.total ?? 0, 2.5, accuracy: 0.01, "Matchup 1: Team 2 should have 2.5 pts")

        let m2 = result.matchupResults.first { $0.matchup.id == "m2" }!
        let m2Map = Dictionary(uniqueKeysWithValues: m2.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(m2Map["t3"]?.total ?? 0, 0, accuracy: 0.01, "Matchup 2: Team 3 should have 0 pts")
        XCTAssertEqual(m2Map["t4"]?.total ?? 0, 4, accuracy: 0.01, "Matchup 2: Team 4 should have 4 pts")
    }

    // MARK: - Matchup Scope: Best 2 of 4, cross-team matchups with unequal tee groups

    func testMatchupScope_Best2of4_CrossTeamUnequalGroups() {
        let holes = makeHoles(count: 4)

        // 2 teams of 4, but split across unequal tee groups:
        // Group A (3 players): t1-p1, t1-p2, t2-p3
        // Group B (5 players): t1-p4, t1-p5, t2-p6, t2-p7, t2-p8
        // (intentionally lopsided to verify scoring doesn't depend on tee group balance)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1", groupID: "gA"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1", groupID: "gA"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t1", groupID: "gB"),
            makeParticipant(id: "p5", name: "Eve", teamID: "t1", groupID: "gB"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2", groupID: "gA"),
            makeParticipant(id: "p6", name: "Frank", teamID: "t2", groupID: "gB"),
            makeParticipant(id: "p7", name: "Grace", teamID: "t2", groupID: "gB"),
            makeParticipant(id: "p8", name: "Hank", teamID: "t2", groupID: "gB"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 4), matchups: matchups, competitionScope: .matchup)
        var template = FormatTemplateRegistry.bestBallMatchup
        template.pipeline = [
            .select(RankSelection(includeRanks: [1, 2])),
            .compare(ComparisonRule(mode: .matchPlay, tiePolicy: .half))
        ]

        // Pars: 4, 4, 3, 4
        // Team 1 (4 players): Alice, Bob, Dave, Eve
        //   Hole 1: Alice=3, Bob=5, Dave=4, Eve=6 → sorted: 3,4,5,6 → best2: 3+4=-1+0=-1
        //   Hole 2: Alice=4, Bob=3, Dave=5, Eve=4 → sorted: 3,4,4,5 → best2: 3+4=-1+0=-1
        //   Hole 3: Alice=3, Bob=4, Dave=2, Eve=5 → sorted: 2,3,4,5 → best2: 2+3=-1+0=-1
        //   Hole 4: Alice=5, Bob=4, Dave=4, Eve=5 → sorted: 4,4,5,5 → best2: 4+4=0+0=0
        //   Per-hole best2 to par: -1, -1, -1, 0
        //
        // Team 2 (4 players): Charlie, Frank, Grace, Hank
        //   Hole 1: Charlie=4, Frank=4, Grace=3, Hank=5 → sorted: 3,4,4,5 → best2: 3+4=-1+0=-1
        //   Hole 2: Charlie=5, Frank=3, Grace=4, Hank=5 → sorted: 3,4,5,5 → best2: 3+4=-1+0=-1
        //   Hole 3: Charlie=3, Frank=4, Grace=3, Hank=4 → sorted: 3,3,4,4 → best2: 3+3=0+0=0
        //   Hole 4: Charlie=4, Frank=5, Grace=4, Hank=6 → sorted: 4,4,5,6 → best2: 4+4=0+0=0
        //   Per-hole best2 to par: -1, -1, 0, 0
        //
        // Match play comparison (best 2 of 4 per team, then compare):
        //   Hole 1: t1=-1, t2=-1 → tie → 0.5 each
        //   Hole 2: t1=-1, t2=-1 → tie → 0.5 each
        //   Hole 3: t1=-1, t2=0 → t1 wins → t1=1, t2=0
        //   Hole 4: t1=0, t2=0 → tie → 0.5 each
        //   Total: t1=2.5, t2=1.5
        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: 3), makeScore(pid: "p1", hole: 2, strokes: 4),
            makeScore(pid: "p1", hole: 3, strokes: 3), makeScore(pid: "p1", hole: 4, strokes: 5),
            makeScore(pid: "p2", hole: 1, strokes: 5), makeScore(pid: "p2", hole: 2, strokes: 3),
            makeScore(pid: "p2", hole: 3, strokes: 4), makeScore(pid: "p2", hole: 4, strokes: 4),
            makeScore(pid: "p4", hole: 1, strokes: 4), makeScore(pid: "p4", hole: 2, strokes: 5),
            makeScore(pid: "p4", hole: 3, strokes: 2), makeScore(pid: "p4", hole: 4, strokes: 4),
            makeScore(pid: "p5", hole: 1, strokes: 6), makeScore(pid: "p5", hole: 2, strokes: 4),
            makeScore(pid: "p5", hole: 3, strokes: 5), makeScore(pid: "p5", hole: 4, strokes: 5),
            makeScore(pid: "p3", hole: 1, strokes: 4), makeScore(pid: "p3", hole: 2, strokes: 5),
            makeScore(pid: "p3", hole: 3, strokes: 3), makeScore(pid: "p3", hole: 4, strokes: 4),
            makeScore(pid: "p6", hole: 1, strokes: 4), makeScore(pid: "p6", hole: 2, strokes: 3),
            makeScore(pid: "p6", hole: 3, strokes: 4), makeScore(pid: "p6", hole: 4, strokes: 5),
            makeScore(pid: "p7", hole: 1, strokes: 3), makeScore(pid: "p7", hole: 2, strokes: 4),
            makeScore(pid: "p7", hole: 3, strokes: 3), makeScore(pid: "p7", hole: 4, strokes: 4),
            makeScore(pid: "p8", hole: 1, strokes: 5), makeScore(pid: "p8", hole: 2, strokes: 5),
            makeScore(pid: "p8", hole: 3, strokes: 4), makeScore(pid: "p8", hole: 4, strokes: 6),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: template
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        let m1 = result.matchupResults[0]
        XCTAssertEqual(m1.matchup.id, "m1")
        XCTAssertEqual(m1.rows.count, 2)

        let rowMap = Dictionary(uniqueKeysWithValues: m1.rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(rowMap["t1"]?.total ?? 0, 2.5, accuracy: 0.01, "Team 1 should win 2.5-1.5")
        XCTAssertEqual(rowMap["t2"]?.total ?? 0, 1.5, accuracy: 0.01, "Team 2 should lose 1.5-2.5")
    }

    func testRoundAwardsMatchupScoreLabels_UseBestNPerRoundTeamTotals() throws {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Colton", teamID: "t1"),
            makeParticipant(id: "p2", name: "Aaron", teamID: "t1"),
            makeParticipant(id: "p3", name: "John", teamID: "t10"),
            makeParticipant(id: "p4", name: "Blake", teamID: "t10"),
            makeParticipant(id: "p5", name: "Dongjai", teamID: "t10"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t10", name: "Team 10", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "t10"])]
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: matchups,
            competitionScope: .matchup
        )

        // Player totals: Team 1 = +3, +3; Team 10 = +4, +5, +6.
        // Best 2 per round should display team totals of +6 and +9, not the best player scores +3 and +4.
        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: holes[0].par + 1),
            makeScore(pid: "p1", hole: 2, strokes: holes[1].par + 2),
            makeScore(pid: "p2", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p2", hole: 2, strokes: holes[1].par + 1),
            makeScore(pid: "p3", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p3", hole: 2, strokes: holes[1].par + 2),
            makeScore(pid: "p4", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p4", hole: 2, strokes: holes[1].par + 3),
            makeScore(pid: "p5", hole: 1, strokes: holes[0].par + 3),
            makeScore(pid: "p5", hole: 2, strokes: holes[1].par + 3),
        ]

        let result = ScoringEngine.computeWithTeamScoring(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate,
            resolvedCompetitionScope: .matchup
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        let rowMap = Dictionary(uniqueKeysWithValues: result.matchupResults[0].rows.map { ($0.scoringUnitID, $0) })
        let team1 = try XCTUnwrap(rowMap["t1"])
        let team10 = try XCTUnwrap(rowMap["t10"])

        XCTAssertEqual(team1.total, 6, accuracy: 0.01)
        XCTAssertEqual(team10.total, 9, accuracy: 0.01)
        XCTAssertEqual(team1.countingParticipantIDs, ["p1", "p2"])
        XCTAssertEqual(team10.countingParticipantIDs, ["p3", "p4"])
        XCTAssertEqual(SeriesViewModel.matchupScoreDisplayLabel(for: team1, highestWins: false), "+6")
        XCTAssertEqual(SeriesViewModel.matchupScoreDisplayLabel(for: team10, highestWins: false), "+9")
    }

    func testTeamMatchupBestNPerRoundIgnoresNoShowsWhenAttendanceIsEnabled() throws {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "t4a", name: "Dan", handicap: 1, teamID: "team4"),
            makeParticipant(id: "t4b", name: "Andrew", handicap: 1, teamID: "team4"),
            makeParticipant(id: "t6a", name: "Ryan", handicap: 3, teamID: "team6"),
            makeParticipant(id: "t6b", name: "Gregory", handicap: 1, teamID: "team6"),
            makeParticipant(id: "t6_no_show_1", name: "Jason", handicap: 8, teamID: "team6", presenceStatus: .noShow),
            makeParticipant(id: "t6_no_show_2", name: "Tyler", handicap: 8, teamID: "team6", presenceStatus: .noShow),
        ]
        let teams = [
            RoundTeam(id: "team4", name: "Team 4", color: "purple", index: 3, createdAt: .init()),
            RoundTeam(id: "team6", name: "Team 6", color: "blue", index: 5, createdAt: .init()),
        ]
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [TeamMatchup(id: "m1", teamIDs: ["team4", "team6"])],
            competitionScope: .matchup
        )
        var configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: .net,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlay),
            competitionScope: .matchup,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate
        )
        configuration.attendanceConfirmationEnabled = true

        let scores = [
            makeScore(pid: "t4a", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "t4a", hole: 2, strokes: holes[1].par + 1),
            makeScore(pid: "t4b", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "t4b", hole: 2, strokes: holes[1].par + 1),
            makeScore(pid: "t6a", hole: 1, strokes: holes[0].par + 4),
            makeScore(pid: "t6a", hole: 2, strokes: holes[1].par + 2),
            makeScore(pid: "t6b", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "t6b", hole: 2, strokes: holes[1].par + 1),
        ]
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            segments: [segment],
            scoring: scores
        )

        let result = ScoringEngine.computeSnapshotResult(
            snapshot: snapshot,
            segment: segment,
            holes: holes,
            basis: .net
        )
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
        let team4 = try XCTUnwrap(rowMap["team4"])
        let team6 = try XCTUnwrap(rowMap["team6"])

        XCTAssertEqual(team4.total, 6, accuracy: 0.01)
        XCTAssertEqual(team6.total, 9, accuracy: 0.01)
        XCTAssertEqual(team4.countingParticipantIDs, ["t4a", "t4b"])
        XCTAssertEqual(Set(team6.countingParticipantIDs), Set(["t6a", "t6b"]))
        XCTAssertFalse(team6.participantIDs.contains("t6_no_show_1"))
        XCTAssertFalse(team6.participantIDs.contains("t6_no_show_2"))
        XCTAssertEqual(matchupResult.minimumCountStatus?.sideStatus(for: "team6")?.availableParticipantCount, nil)
    }

    func testSeriesScoringResultUsesTeamAggregatesForTeamMatchupsWhenScoringGroupsExist() throws {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Colton", teamID: "t1"),
            makeParticipant(id: "p2", name: "Aaron", teamID: "t1"),
            makeParticipant(id: "p3", name: "John", teamID: "t10"),
            makeParticipant(id: "p4", name: "Blake", teamID: "t10"),
            makeParticipant(id: "p5", name: "Dongjai", teamID: "t10"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t10", name: "Team 10", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            RoundScoringGroup(id: "pair_t1", teamID: "t1", kind: .partnership, memberIDs: ["p1", "p2"], label: "Team 1 Pair"),
            RoundScoringGroup(id: "pair_t10a", teamID: "t10", kind: .partnership, memberIDs: ["p3", "p4"], label: "Team 10 Pair A"),
            RoundScoringGroup(id: "pair_t10b", teamID: "t10", kind: .partnership, memberIDs: ["p5"], label: "Team 10 Pair B"),
        ]
        let matchup = TeamMatchup(id: "m1", teamIDs: ["t1", "t10"])
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: .individual
        )
        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: holes[0].par + 1),
            makeScore(pid: "p1", hole: 2, strokes: holes[1].par + 2),
            makeScore(pid: "p2", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p2", hole: 2, strokes: holes[1].par + 1),
            makeScore(pid: "p3", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p3", hole: 2, strokes: holes[1].par + 2),
            makeScore(pid: "p4", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p4", hole: 2, strokes: holes[1].par + 3),
            makeScore(pid: "p5", hole: 1, strokes: holes[0].par + 3),
            makeScore(pid: "p5", hole: 2, strokes: holes[1].par + 3),
        ]
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: scores
        )

        XCTAssertTrue(SeriesViewModel.shouldUseTeamAggregateScoring(snapshot: snapshot, segment: segment))

        let result = SeriesViewModel.buildScoringResult(from: snapshot, segment: segment)
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let rowMap = Dictionary(uniqueKeysWithValues: matchupResult.rows.map { ($0.scoringUnitID, $0) })
        let team1 = try XCTUnwrap(rowMap["t1"])
        let team10 = try XCTUnwrap(rowMap["t10"])

        XCTAssertEqual(team1.total, 6, accuracy: 0.01)
        XCTAssertEqual(team10.total, 9, accuracy: 0.01)
        XCTAssertEqual(team1.countingParticipantIDs, ["p1", "p2"])
        XCTAssertEqual(team10.countingParticipantIDs, ["p3", "p4"])
    }

    func testSeriesScoringResultProjectsPartialBestNPerRoundStandings() throws {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Colton", teamID: "t1"),
            makeParticipant(id: "p2", name: "Aaron", teamID: "t1"),
            makeParticipant(id: "p3", name: "John", teamID: "t10"),
            makeParticipant(id: "p4", name: "Blake", teamID: "t10"),
            makeParticipant(id: "p5", name: "Dongjai", teamID: "t10"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t10", name: "Team 10", color: "blue", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            RoundScoringGroup(id: "pair_t1", teamID: "t1", kind: .partnership, memberIDs: ["p1", "p2"]),
            RoundScoringGroup(id: "pair_t10", teamID: "t10", kind: .partnership, memberIDs: ["p3", "p4"]),
        ]
        let matchup = TeamMatchup(id: "m1", teamIDs: ["t1", "t10"])
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate,
            scoreOwnerScope: .individual
        )
        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: holes[0].par + 1),
            makeScore(pid: "p2", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "p3", hole: 1, strokes: holes[0].par + 4),
            makeScore(pid: "p4", hole: 1, strokes: holes[0].par + 5),
            makeScore(pid: "p5", hole: 1, strokes: holes[0].par + 6),
        ]
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: scores
        )
        let result = SeriesViewModel.buildScoringResult(from: snapshot, segment: segment)
        let matchupResult = try XCTUnwrap(result.matchupResults.first)
        let presentation = MatchupResultPresentationBuilder.build(
            snapshot: snapshot,
            result: result,
            matchupResult: matchupResult
        )

        XCTAssertEqual(presentation.winningSideID, "t1")
        XCTAssertEqual(presentation.side(id: "t1")?.total ?? 0, 3, accuracy: 0.01)
        XCTAssertEqual(presentation.side(id: "t10")?.total ?? 0, 9, accuracy: 0.01)
        XCTAssertEqual(presentation.side(id: "t1")?.scoreLabel, "+3")
        XCTAssertEqual(presentation.side(id: "t10")?.scoreLabel, "+9")
        XCTAssertTrue(presentation.side(id: "t1")?.isParticipantActive(participants[0]) == true)
        XCTAssertTrue(presentation.side(id: "t1")?.isParticipantActive(participants[1]) == true)
        XCTAssertTrue(presentation.side(id: "t10")?.isParticipantActive(participants[2]) == true)
        XCTAssertTrue(presentation.side(id: "t10")?.isParticipantActive(participants[3]) == true)
        XCTAssertTrue(presentation.side(id: "t10")?.isParticipantActive(participants[4]) == false)
    }

    func testMatchupPresentationUsesEngineAggregateTotalsForBestNPerRound() throws {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "purple1", name: "Gavin", teamID: "purple"),
            makeParticipant(id: "purple2", name: "Aristotle", teamID: "purple"),
            makeParticipant(id: "purple3", name: "Andrew", teamID: "purple"),
            makeParticipant(id: "purple4", name: "Evan", teamID: "purple"),
            makeParticipant(id: "red1", name: "Colton", teamID: "red"),
            makeParticipant(id: "red2", name: "Aaron", teamID: "red"),
            makeParticipant(id: "red3", name: "Karis", teamID: "red"),
            makeParticipant(id: "red4", name: "Abby", teamID: "red"),
        ]
        let teams = [
            RoundTeam(id: "purple", name: "Team 9", color: "purple", index: 0, createdAt: .init()),
            RoundTeam(id: "red", name: "Team 1", color: "red", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["red", "purple"])]
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: matchups,
            competitionScope: .matchup
        )
        let teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
        let scores = [
            makeScore(pid: "purple1", hole: 1, strokes: holes[0].par - 2),
            makeScore(pid: "purple1", hole: 2, strokes: holes[1].par - 1),
            makeScore(pid: "purple2", hole: 1, strokes: holes[0].par),
            makeScore(pid: "purple2", hole: 2, strokes: holes[1].par + 1),
            makeScore(pid: "purple3", hole: 1, strokes: holes[0].par + 2),
            makeScore(pid: "purple3", hole: 2, strokes: holes[1].par + 3),
            makeScore(pid: "purple4", hole: 1, strokes: holes[0].par + 3),
            makeScore(pid: "purple4", hole: 2, strokes: holes[1].par + 4),
            makeScore(pid: "red1", hole: 1, strokes: holes[0].par + 1),
            makeScore(pid: "red1", hole: 2, strokes: holes[1].par + 1),
            makeScore(pid: "red2", hole: 1, strokes: holes[0].par + 5),
            makeScore(pid: "red2", hole: 2, strokes: holes[1].par + 5),
            makeScore(pid: "red3", hole: 1, strokes: holes[0].par + 7),
            makeScore(pid: "red3", hole: 2, strokes: holes[1].par + 7),
            makeScore(pid: "red4", hole: 1, strokes: holes[0].par + 8),
            makeScore(pid: "red4", hole: 2, strokes: holes[1].par + 8),
        ]

        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: teamScoring,
            matchupResolutionStyle: .roundAggregate
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            segments: [segment],
            scoring: scores
        )
        let result = ScoringEngine.computeWithTeamScoring(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            teamScoring: teamScoring,
            matchupResolutionStyle: .roundAggregate,
            resolvedCompetitionScope: .matchup
        )
        let matchupResult = try XCTUnwrap(result.matchupResults.first)

        let presentation = MatchupResultPresentationBuilder.build(
            snapshot: snapshot,
            result: result,
            matchupResult: matchupResult
        )

        XCTAssertFalse(presentation.isTie)
        XCTAssertEqual(presentation.winningSideID, "purple")
        XCTAssertEqual(presentation.title, "Team 9 wins")
        XCTAssertEqual(presentation.side(id: "purple")?.total ?? 0, -2, accuracy: 0.01)
        XCTAssertEqual(presentation.side(id: "red")?.total ?? 0, 12, accuracy: 0.01)
        XCTAssertEqual(presentation.side(id: "purple")?.scoreLabel, "-2")
        XCTAssertEqual(presentation.side(id: "red")?.scoreLabel, "+12")
        XCTAssertTrue(presentation.side(id: "purple")?.isParticipantActive(participants[0]) == true)
        XCTAssertTrue(presentation.side(id: "purple")?.isParticipantActive(participants[1]) == true)
        XCTAssertTrue(presentation.side(id: "purple")?.isParticipantActive(participants[2]) == false)
        XCTAssertTrue(SeriesViewModel.shouldShowMatchupResultChip(for: presentation))
        XCTAssertEqual(presentation.side(id: "purple")?.participants.count, 4)
    }

    func testMatchupPresentationDoesNotFabricateCompleteBestNPerRoundSidesWhenAggregateRowsAreMissing() throws {
        let participants = [
            makeParticipant(id: "purple1", name: "Gavin", teamID: "purple"),
            makeParticipant(id: "purple2", name: "Aristotle", teamID: "purple"),
            makeParticipant(id: "purple3", name: "Andrew", teamID: "purple"),
            makeParticipant(id: "purple4", name: "Evan", teamID: "purple"),
            makeParticipant(id: "red1", name: "Colton", teamID: "red"),
            makeParticipant(id: "red2", name: "Aaron", teamID: "red"),
            makeParticipant(id: "red3", name: "Karis", teamID: "red"),
            makeParticipant(id: "red4", name: "Abby", teamID: "red"),
        ]
        let teams = [
            RoundTeam(id: "purple", name: "Team 9", color: "purple", index: 0, createdAt: .init()),
            RoundTeam(id: "red", name: "Team 1", color: "red", index: 1, createdAt: .init()),
        ]
        let matchup = TeamMatchup(id: "m1", teamIDs: ["red", "purple"])
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let configuration = RoundConfiguration(
            primaryFormat: GameFormat(
                type: .strokePlay,
                configuration: GameConfiguration(
                    method: .individual,
                    aggregation: nil,
                    basis: .gross,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound),
            matchupResolutionStyle: .roundAggregate
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            segments: [segment],
            scoring: []
        )
        let result = ScoringResult(
            rows: [],
            holeStates: [:],
            template: FormatTemplateRegistry.strokePlayGross,
            matchupResults: [MatchupScoringResult(matchup: matchup, rows: [])]
        )

        let presentation = MatchupResultPresentationBuilder.build(
            snapshot: snapshot,
            result: result,
            matchupResult: try XCTUnwrap(result.matchupResults.first)
        )

        XCTAssertFalse(presentation.hasCompleteSides)
        XCTAssertFalse(presentation.isTie)
        XCTAssertNil(presentation.winningSideID)
        XCTAssertFalse(SeriesViewModel.shouldShowMatchupResultChip(for: presentation))
        XCTAssertEqual(presentation.title, "Matchup pending")
        XCTAssertEqual(presentation.side(id: "purple")?.scoreLabel, "—")
        XCTAssertEqual(presentation.side(id: "red")?.scoreLabel, "—")
        XCTAssertTrue(presentation.side(id: "purple")?.isParticipantActive(participants[0]) == false)
    }

    func testScoreOwnerPartnershipMatchupAggregatesResolvedSideRosterForBestNPerRound() throws {
        let holes = makeHoles(count: 1)
        let participants = [
            makeParticipant(id: "gavin", name: "Gavin", teamID: "purple"),
            makeParticipant(id: "aristotle", name: "Aristotle", teamID: "purple"),
            makeParticipant(id: "andrew", name: "Andrew", teamID: "purple"),
            makeParticipant(id: "evan", name: "Evan", teamID: "purple"),
            makeParticipant(id: "colton", name: "Colton", teamID: "red"),
            makeParticipant(id: "aaron", name: "Aaron", teamID: "red"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "purple", name: "Team 9", color: "purple", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            RoundScoringGroup(
                id: "red_pair",
                teamID: "red",
                kind: .partnership,
                memberIDs: ["colton", "aaron"],
                label: "Red Pair"
            ),
            RoundScoringGroup(
                id: "purple_pair",
                teamID: "purple",
                kind: .partnership,
                memberIDs: ["gavin", "aristotle", "andrew", "evan"],
                label: "Purple Pair"
            ),
        ]
        let matchup = TeamMatchup(
            id: "match1",
            teamIDs: [],
            scoreOwnerIDs: ["red_pair", "purple_pair"],
            scoreOwnerScope: .partnership,
            mode: .scoreOwner
        )
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 1),
            matchups: [matchup],
            competitionScope: .matchup
        )
        let teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: teamScoring,
            scoreOwnerScope: .partnership
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: [
                makeScore(pid: "gavin", hole: 1, strokes: holes[0].par - 3),
                makeScore(pid: "aristotle", hole: 1, strokes: holes[0].par),
                makeScore(pid: "andrew", hole: 1, strokes: holes[0].par + 5),
                makeScore(pid: "evan", hole: 1, strokes: holes[0].par + 7),
                makeScore(pid: "colton", hole: 1, strokes: holes[0].par + 2),
                makeScore(pid: "aaron", hole: 1, strokes: holes[0].par + 10),
            ]
        )
        let result = ScoringEngine.computeWithPipeline(
            scores: snapshot.scoring,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups
        )
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Match 1", rows: [])

        let presentation = MatchupResultPresentationBuilder.build(
            snapshot: snapshot,
            result: result,
            section: section,
            basis: .gross
        )

        XCTAssertFalse(presentation.isTie)
        XCTAssertEqual(presentation.winningSideID, "purple_pair")
        XCTAssertEqual(presentation.title, "Team 9 wins")
        XCTAssertEqual(presentation.side(id: "purple_pair")?.scoreLabel, "-3")
        XCTAssertEqual(presentation.side(id: "red_pair")?.scoreLabel, "+12")
        XCTAssertEqual(presentation.side(id: "purple_pair")?.title, "Team 9")
        XCTAssertEqual(presentation.side(id: "red_pair")?.title, "Team 1")
        XCTAssertEqual(Set(presentation.side(id: "purple_pair")?.countingParticipantIDs ?? []), Set(["gavin", "aristotle"]))
        XCTAssertTrue(presentation.side(id: "purple_pair")?.isParticipantActive(participants[2]) == false)
    }

    func testScoreOwnerPartnershipMatchupProjectsFromPartialCurrentScores() throws {
        let holes = makeHoles(count: 18)
        let participants = [
            makeParticipant(id: "gavin", name: "Gavin", teamID: "purple"),
            makeParticipant(id: "aristotle", name: "Aristotle", teamID: "purple"),
            makeParticipant(id: "andrew", name: "Andrew", teamID: "purple"),
            makeParticipant(id: "evan", name: "Evan", teamID: "purple"),
            makeParticipant(id: "colton", name: "Colton", teamID: "red"),
            makeParticipant(id: "aaron", name: "Aaron", teamID: "red"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "purple", name: "Team 9", color: "purple", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            RoundScoringGroup(id: "red_pair", teamID: "red", kind: .partnership, memberIDs: ["colton", "aaron"], label: "Red Pair"),
            RoundScoringGroup(id: "purple_pair", teamID: "purple", kind: .partnership, memberIDs: ["gavin", "aristotle", "andrew", "evan"], label: "Purple Pair"),
        ]
        let matchup = TeamMatchup(
            id: "match1",
            teamIDs: [],
            scoreOwnerIDs: ["red_pair", "purple_pair"],
            scoreOwnerScope: .partnership,
            mode: .scoreOwner
        )
        let segment = makeSegment(matchups: [matchup], competitionScope: .matchup)
        let teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: teamScoring,
            scoreOwnerScope: .partnership
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: [
                makeScore(pid: "gavin", hole: 1, strokes: holes[0].par - 3),
                makeScore(pid: "andrew", hole: 1, strokes: holes[0].par + 5),
                makeScore(pid: "evan", hole: 1, strokes: holes[0].par + 7),
                makeScore(pid: "colton", hole: 1, strokes: holes[0].par + 2),
                makeScore(pid: "aaron", hole: 1, strokes: holes[0].par + 10),
            ]
        )
        let result = ScoringEngine.computeWithPipeline(
            scores: snapshot.scoring,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups
        )
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Match 1", rows: [])

        let presentation = MatchupResultPresentationBuilder.build(snapshot: snapshot, result: result, section: section, basis: .gross)

        XCTAssertTrue(presentation.hasCompleteSides)
        XCTAssertEqual(presentation.title, "Team 9 wins")
        XCTAssertEqual(presentation.side(id: "purple_pair")?.scoreLabel, "+2")
        XCTAssertEqual(presentation.side(id: "red_pair")?.scoreLabel, "+12")
        XCTAssertEqual(Set(presentation.side(id: "purple_pair")?.countingParticipantIDs ?? []), Set(["gavin", "andrew"]))
        XCTAssertTrue(presentation.side(id: "purple_pair")?.isParticipantActive(participants[1]) == false)
    }

    func testScoreOwnerPartnershipDirectSideScoreCountsSharedScoreOnce() throws {
        let holes = makeHoles(count: 18)
        let participants = [
            makeParticipant(id: "gavin", name: "Gavin", teamID: "purple"),
            makeParticipant(id: "aristotle", name: "Aristotle", teamID: "purple"),
            makeParticipant(id: "colton", name: "Colton", teamID: "red"),
            makeParticipant(id: "aaron", name: "Aaron", teamID: "red"),
        ]
        let teams = [
            RoundTeam(id: "red", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "purple", name: "Team 9", color: "purple", index: 1, createdAt: .init()),
        ]
        let scoringGroups = [
            RoundScoringGroup(id: "red_pair", teamID: "red", kind: .partnership, memberIDs: ["colton", "aaron"], label: "Red Pair"),
            RoundScoringGroup(id: "purple_pair", teamID: "purple", kind: .partnership, memberIDs: ["gavin", "aristotle"], label: "Purple Pair"),
        ]
        let matchup = TeamMatchup(
            id: "match1",
            teamIDs: [],
            scoreOwnerIDs: ["red_pair", "purple_pair"],
            scoreOwnerScope: .partnership,
            mode: .scoreOwner
        )
        let segment = RoundSegment(
            id: "seg1",
            roundID: "round1",
            holeRange: HoleRange(startHole: 1, endHole: 18),
            scoringUnits: [
                ScoringUnit(id: "red_unit", owner: .scoreOwner, ownerIDs: ["colton", "aaron"], scoringMethod: .aggregate),
                ScoringUnit(id: "purple_unit", owner: .scoreOwner, ownerIDs: ["gavin", "aristotle"], scoringMethod: .aggregate),
            ],
            matchups: [matchup],
            competitionScope: .matchup
        )
        let teamScoring = RoundTeamScoringConfiguration(mode: .bestN, count: 2, scope: .perRound)
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.strokePlayGross),
            competitionScope: .matchup,
            teamScoring: teamScoring,
            scoreOwnerScope: .partnership
        )
        let snapshot = RoundSnapshot(
            round: Round(id: "round1", shareCode: "MATCH", createdBy: "host", configuration: configuration),
            participants: participants,
            teams: teams,
            scoringGroups: scoringGroups,
            segments: [segment],
            scoring: [
                ScoreEntry(
                    id: ScoreEntry.makeID(hole: 1, segment: "seg1", scoringUnit: "purple_unit"),
                    holeNumber: 1,
                    segmentID: "seg1",
                    scoringUnitID: "purple_unit",
                    participantIDs: ["gavin", "aristotle"],
                    relativeToPar: -2,
                    entryID: "gavin",
                    parentID: "round1"
                ),
                ScoreEntry(
                    id: ScoreEntry.makeID(hole: 1, segment: "seg1", scoringUnit: "red_unit"),
                    holeNumber: 1,
                    segmentID: "seg1",
                    scoringUnitID: "red_unit",
                    participantIDs: ["colton", "aaron"],
                    relativeToPar: 12,
                    entryID: "colton",
                    parentID: "round1"
                ),
            ]
        )
        let result = ScoringEngine.computeWithPipeline(
            scores: snapshot.scoring,
            participants: participants,
            teams: teams,
            segment: segment,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.strokePlayGross,
            resolvedCompetitionScope: .matchup,
            scoreOwnerScope: .partnership,
            scoringGroups: scoringGroups
        )
        let section = MatchupLeaderboardSection(id: matchup.id, matchup: matchup, name: "Match 1", rows: [])

        let presentation = MatchupResultPresentationBuilder.build(snapshot: snapshot, result: result, section: section, basis: .gross)

        XCTAssertTrue(presentation.hasCompleteSides)
        XCTAssertEqual(presentation.title, "Team 9 wins")
        XCTAssertEqual(presentation.side(id: "purple_pair")?.scoreLabel, "-2")
        XCTAssertEqual(presentation.side(id: "red_pair")?.scoreLabel, "+12")
    }

    // MARK: - Matchup Scope: Best Ball with Net Handicaps

    func testMatchupScope_BestBallNet_WithHandicaps() {
        let holes = makeHoles(count: 4)
        // Two 2-man teams, matchup scope, net scoring
        // Team 1: scratch player + 18 hcp
        // Team 2: 9 hcp + 9 hcp
        let participants = [
            makeParticipant(id: "p1", name: "Alice", handicap: 0, teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", handicap: 18, teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", handicap: 9, teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", handicap: 9, teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 4), matchups: matchups, competitionScope: .matchup)
        let template = FormatTemplateRegistry.bestBallMatchup

        // Both teams shoot all pars (gross). Net scoring with handicaps.
        // Hole handicaps for holes 1-4: 7, 3, 15, 1
        //
        // Alice (0 hcp): gets 0 strokes everywhere → net = par, score to par = 0
        // Bob (18 hcp): gets 1 stroke per hole → net = par-1, score to par = -1
        // Charlie (9 hcp): receives 2 prorated strokes across this 4-hole match → holes 2(hcp3),4(hcp1) → -1; holes 1/3 → 0
        // Dave (9 hcp): same as Charlie
        //
        // Team 1 best ball (net): Bob always -1 → [-1,-1,-1,-1]
        // Team 2 best ball (net): Charlie/Dave = [0,-1,0,-1]
        //
        // Compare:
        //   Hole 1: t1=-1, t2=0 → t1 wins
        //   Hole 2: t1=-1, t2=-1 → tie → 0.5 each
        //   Hole 3: t1=-1, t2=0 → t1 wins → t1=1, t2=0
        //   Hole 4: t1=-1, t2=-1 → tie → 0.5 each
        //   Total: t1=3, t2=1
        var scores: [ScoreEntry] = []
        for h in 1...4 {
            let par = holes[h - 1].par
            scores.append(makeScore(pid: "p1", hole: h, strokes: par))
            scores.append(makeScore(pid: "p2", hole: h, strokes: par))
            scores.append(makeScore(pid: "p3", hole: h, strokes: par))
            scores.append(makeScore(pid: "p4", hole: h, strokes: par))
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .net, template: template
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        let m1 = result.matchupResults[0]
        let rowMap = Dictionary(uniqueKeysWithValues: m1.rows.map { ($0.scoringUnitID, $0) })

        XCTAssertEqual(rowMap["t1"]?.total ?? 0, 3, accuracy: 0.01,
                       "Team 1 (scratch+18hcp) should win 3 pts with prorated 4-hole handicap allocation")
        XCTAssertEqual(rowMap["t2"]?.total ?? 0, 1, accuracy: 0.01,
                       "Team 2 (two 9hcp) should have 1 pt")
    }

    // MARK: - Field Scope: No Matchup Results

    func testFieldScope_ProducesNoMatchupResults() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2))
        let template = FormatTemplateRegistry.bestBall

        var scores: [ScoreEntry] = []
        for h in 1...2 {
            let par = holes[h - 1].par
            scores.append(makeScore(pid: "p1", hole: h, strokes: par))
            scores.append(makeScore(pid: "p2", hole: h, strokes: par + 1))
            scores.append(makeScore(pid: "p3", hole: h, strokes: par - 1))
            scores.append(makeScore(pid: "p4", hole: h, strokes: par))
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: template
        )

        XCTAssertTrue(result.matchupResults.isEmpty, "Field scope should have empty matchupResults")
        XCTAssertEqual(result.rows.count, 2, "Field scope should have team rows on the flat leaderboard")
    }

    // MARK: - Matchup Scope: Leaderboard Builder

    func testMatchupLeaderboardSections() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])]
        let segment = makeSegment(
            holeRange: HoleRange(startHole: 1, endHole: 2),
            matchups: matchups,
            competitionScope: .matchup
        )
        let template = FormatTemplateRegistry.bestBallMatchup

        // Hole 1 (par 4): t1 best=3, t2 best=5 → t1 wins
        // Hole 2 (par 4): t1 best=4, t2 best=3 → t2 wins
        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: 3), makeScore(pid: "p1", hole: 2, strokes: 4),
            makeScore(pid: "p2", hole: 1, strokes: 5), makeScore(pid: "p2", hole: 2, strokes: 5),
            makeScore(pid: "p3", hole: 1, strokes: 5), makeScore(pid: "p3", hole: 2, strokes: 3),
            makeScore(pid: "p4", hole: 1, strokes: 6), makeScore(pid: "p4", hole: 2, strokes: 4),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: template
        )

        let sections = LeaderboardBuilder.buildMatchupSections(result: result, teams: teams)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].name, "Team 1 vs Team 2")
        XCTAssertEqual(sections[0].rows.count, 2)
    }

    func testMatchupLeaderboardSections_IndividualMode_ResolvesParticipantNames() {
        // Individual matchup: stroke play with compare, participant IDs
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice"),
            makeParticipant(id: "p2", name: "Bob"),
        ]
        let matchups = [
            TeamMatchup(id: "m1", teamIDs: [], participantIDs: ["p1", "p2"], mode: .individual),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2), matchups: matchups, competitionScope: .matchup)
        let template = FormatTemplateRegistry.strokePlayMatchupIndividual

        let scores = [
            makeScore(pid: "p1", hole: 1, strokes: 3), makeScore(pid: "p1", hole: 2, strokes: 4),
            makeScore(pid: "p2", hole: 1, strokes: 5), makeScore(pid: "p2", hole: 2, strokes: 5),
        ]

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: [],
            segment: segment, holes: holes, basis: .gross, template: template
        )

        let sections = LeaderboardBuilder.buildMatchupSections(
            result: result, teams: [], participants: participants
        )
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].name, "Alice Test vs Bob Test")
        XCTAssertEqual(sections[0].rows.count, 2)
    }

    // MARK: - Validation

    func testValidation_MatchupScopeRequiresTeamsAndMatchups() {
        let template = GameTemplate(
            id: "bad_matchup",
            subject: .team,
            competitionScope: .matchup,
            pipeline: [.compare(ComparisonRule(mode: .matchPlay))],
            requirements: TemplateRequirements(requiresTeams: false, requiresMatchups: false)
        )
        let errors = template.validate()
        XCTAssertTrue(errors.contains(.teamSubjectRequiresTeams))
        XCTAssertTrue(errors.contains(.matchupScopeRequiresTeams))
        XCTAssertTrue(errors.contains(.matchupScopeRequiresMatchups))
    }

    func testValidation_FieldScopeWithCompareStageWarning_TeamSubject() {
        let template = GameTemplate(
            id: "field_with_compare",
            subject: .team,
            competitionScope: .field,
            pipeline: [
                .select(RankSelection(includeRanks: [1])),
                .compare(ComparisonRule(mode: .matchPlay)),
            ],
            requirements: TemplateRequirements(requiresTeams: true)
        )
        let errors = template.validate()
        XCTAssertTrue(errors.contains(.fieldScopeWithCompareStage),
                       "Field scope team format with compare stage should warn")
    }

    func testValidation_FieldScopeWithCompareStage_IndividualIsOk() {
        let template = FormatTemplateRegistry.matchPlayIndividual
        let errors = template.validate()
        XCTAssertFalse(errors.contains(.fieldScopeWithCompareStage),
                        "Individual match play with compare stage should not warn")
    }

    func testValidation_ValidMatchupTemplate() {
        let errors = FormatTemplateRegistry.bestBallMatchup.validate()
        XCTAssertTrue(errors.isEmpty, "bestBallMatchup should pass validation: \(errors)")
    }

    func testValidation_IndividualMatchupScope_DoesNotRequireTeams() {
        // subject .participant + competitionScope .matchup + requiresTeams false is valid
        let template = FormatTemplateRegistry.strokePlayMatchupIndividual
        let errors = template.validate()
        XCTAssertFalse(errors.contains(.matchupScopeRequiresTeams),
                       "Individual matchup format should not require teams: \(errors)")
    }

    func testValidation_ValidFieldTemplate() {
        let errors = FormatTemplateRegistry.bestBall.validate()
        XCTAssertTrue(errors.isEmpty, "bestBall (field) should pass validation: \(errors)")
    }

    // MARK: - TeamMatchup Codable & Mode

    func testTeamMatchup_Codable() throws {
        let matchup = TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])
        let data = try JSONEncoder().encode(matchup)
        let decoded = try JSONDecoder().decode(TeamMatchup.self, from: data)
        XCTAssertEqual(decoded.id, "m1")
        XCTAssertEqual(decoded.teamIDs, ["t1", "t2"])
    }

    func testTeamMatchup_BackwardCompatibility_DecodesWithoutModeAsTeam() throws {
        // Legacy Firestore docs may lack "mode" and "participant_ids"
        let json = """
        {"id":"m1","team_ids":["t1","t2"]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TeamMatchup.self, from: json)
        XCTAssertEqual(decoded.id, "m1")
        XCTAssertEqual(decoded.teamIDs, ["t1", "t2"])
        XCTAssertNil(decoded.mode)
        XCTAssertNil(decoded.participantIDs)
        XCTAssertEqual(decoded.pairingIDs(), ["t1", "t2"])
        XCTAssertTrue(decoded.isValid)
    }

    func testTeamMatchup_PairingIDs_TeamMode() {
        let matchup = TeamMatchup(id: "m1", teamIDs: ["t1", "t2"], mode: .team)
        XCTAssertEqual(matchup.pairingIDs(), ["t1", "t2"])
        XCTAssertTrue(matchup.isValid)
    }

    func testTeamMatchup_PairingIDs_IndividualMode() {
        let matchup = TeamMatchup(id: "m1", teamIDs: [], participantIDs: ["p1", "p2"], mode: .individual)
        XCTAssertEqual(matchup.pairingIDs(), ["p1", "p2"])
        XCTAssertTrue(matchup.isValid)
    }

    func testTeamMatchup_IsValid_RequiresTwoPairings() {
        XCTAssertFalse(TeamMatchup(id: "m1", teamIDs: [], mode: .team).isValid)
        XCTAssertFalse(TeamMatchup(id: "m1", teamIDs: ["t1"], mode: .team).isValid)
        XCTAssertTrue(TeamMatchup(id: "m1", teamIDs: ["t1", "t2"], mode: .team).isValid)
        XCTAssertFalse(TeamMatchup(id: "m1", participantIDs: ["p1"], mode: .individual).isValid)
        XCTAssertTrue(TeamMatchup(id: "m1", participantIDs: ["p1", "p2"], mode: .individual).isValid)
    }

    // MARK: - CompetitionScope Codable

    func testCompetitionScope_Codable() throws {
        let template = FormatTemplateRegistry.strokePlayMatchupIndividual
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(GameTemplate.self, from: data)
        XCTAssertEqual(decoded.competitionScope, .matchup)
        XCTAssertEqual(decoded.resolvedScope, .matchup)
    }

    func testCompetitionScope_NilDefaultsToField() {
        let template = GameTemplate(id: "test", competitionScope: nil)
        XCTAssertNil(template.competitionScope)
        XCTAssertEqual(template.resolvedScope, .field)
    }

    // MARK: - Matchup Scope with no matchups falls back to field behavior

    func testMatchupScope_NoMatchupsOnSegment_FallsBack() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2))
        let template = FormatTemplateRegistry.bestBallMatchup

        var scores: [ScoreEntry] = []
        for h in 1...2 {
            let par = holes[h - 1].par
            scores.append(makeScore(pid: "p1", hole: h, strokes: par))
            scores.append(makeScore(pid: "p2", hole: h, strokes: par))
            scores.append(makeScore(pid: "p3", hole: h, strokes: par))
            scores.append(makeScore(pid: "p4", hole: h, strokes: par))
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: template
        )

        XCTAssertTrue(result.matchupResults.isEmpty,
                       "Matchup scope with no matchups on segment should fall back to field-like behavior")
        XCTAssertEqual(result.rows.count, 2, "Should still produce team rows")
    }

    // MARK: - Score lookup across segment ids

    func testScoreLookup_ResolvesScoresKeyedUnderAlternateSegmentId() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2), matchups: matchups, competitionScope: .matchup)
        var primary = segment
        primary.id = "seg_primary"

        var scores: [ScoreEntry] = []
        for h in 1...2 {
            let par = holes[h - 1].par
            scores.append(makeScore(pid: "p1", hole: h, strokes: par, seg: "seg_scores"))
            scores.append(makeScore(pid: "p2", hole: h, strokes: par, seg: "seg_scores"))
            scores.append(makeScore(pid: "p3", hole: h, strokes: par, seg: "seg_scores"))
            scores.append(makeScore(pid: "p4", hole: h, strokes: par, seg: "seg_scores"))
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores,
            participants: participants,
            teams: teams,
            segment: primary,
            holes: holes,
            basis: .gross,
            template: FormatTemplateRegistry.bestBallMatchup,
            scoreLookupSegmentIDs: ["seg_primary", "seg_scores"],
            resolvedCompetitionScope: .matchup
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        let m1Map = Dictionary(uniqueKeysWithValues: result.matchupResults[0].rows.map { ($0.scoringUnitID, $0) })
        XCTAssertEqual(m1Map["t1"]?.holesPlayed, 2)
        XCTAssertEqual(m1Map["t2"]?.holesPlayed, 2)
    }

    // MARK: - Resolved competition scope vs segment

    func testResolvedCompetitionScope_OverridesSegmentFieldForMatchupBranch() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2), matchups: matchups, competitionScope: .field)

        var scores: [ScoreEntry] = []
        for h in 1...2 {
            let par = holes[h - 1].par
            scores.append(makeScore(pid: "p1", hole: h, strokes: par))
            scores.append(makeScore(pid: "p2", hole: h, strokes: par))
            scores.append(makeScore(pid: "p3", hole: h, strokes: par))
            scores.append(makeScore(pid: "p4", hole: h, strokes: par))
        }

        let withoutOverride = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: FormatTemplateRegistry.bestBallMatchup
        )
        XCTAssertTrue(withoutOverride.matchupResults.isEmpty, "Segment field scope should skip matchup branch")

        let withOverride = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: FormatTemplateRegistry.bestBallMatchup,
            resolvedCompetitionScope: .matchup
        )
        XCTAssertEqual(withOverride.matchupResults.count, 1, "Round configuration scope should enable matchup branch")
    }

    // MARK: - Stale matchup team references

    func testMatchupScope_StaleTeamIdYieldsIncompleteComparisonRows() {
        let holes = makeHoles(count: 2)
        let participants = [
            makeParticipant(id: "p1", name: "Alice", teamID: "t1"),
            makeParticipant(id: "p2", name: "Bob", teamID: "t1"),
            makeParticipant(id: "p3", name: "Charlie", teamID: "t2"),
            makeParticipant(id: "p4", name: "Dave", teamID: "t2"),
        ]
        let teams = [
            RoundTeam(id: "t1", name: "Team 1", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "Team 2", color: "blue", index: 1, createdAt: .init()),
        ]
        let matchups = [TeamMatchup(id: "m1", teamIDs: ["t1", "team_ghost"])]
        let segment = makeSegment(holeRange: HoleRange(startHole: 1, endHole: 2), matchups: matchups, competitionScope: .matchup)

        var scores: [ScoreEntry] = []
        for h in 1...2 {
            let par = holes[h - 1].par
            scores.append(makeScore(pid: "p1", hole: h, strokes: par))
            scores.append(makeScore(pid: "p2", hole: h, strokes: par))
            scores.append(makeScore(pid: "p3", hole: h, strokes: par))
            scores.append(makeScore(pid: "p4", hole: h, strokes: par))
        }

        let result = ScoringEngine.computeWithPipeline(
            scores: scores, participants: participants, teams: teams,
            segment: segment, holes: holes, basis: .gross, template: FormatTemplateRegistry.bestBallMatchup
        )

        XCTAssertEqual(result.matchupResults.count, 1)
        XCTAssertEqual(result.matchupResults[0].rows.count, 1, "Ghost team id should not produce a comparable second unit")
    }

    // MARK: - RoundSnapshot segment score lookup ids

    func testRoundSnapshot_SegmentScoreLookupSegmentIDs_PrimaryThenOthers() {
        let segA = RoundSegment(id: "a", roundID: "r1", holeRange: HoleRange(startHole: 1, endHole: 9))
        let segB = RoundSegment(id: "b", roundID: "r1", holeRange: HoleRange(startHole: 10, endHole: 18))
        var snapshot = RoundSnapshot(segments: [segA, segB], scoring: [])
        XCTAssertEqual(snapshot.segmentScoreLookupSegmentIDs, ["a", "b"])

        let entry = makeScore(pid: "p1", hole: 1, strokes: 4, seg: "from_scores")
        snapshot = RoundSnapshot(segments: [], scoring: [entry])
        XCTAssertEqual(snapshot.segmentScoreLookupSegmentIDs, ["from_scores"])
    }

    // MARK: - LeaderboardBuilder matchup row order

    func testLeaderboardBuilder_MatchupSections_UsePairingOrderNotSortedTotals() {
        let rowT1 = ScoringRow(
            scoringUnitID: "t1",
            participantIDs: ["p1"],
            countingParticipantIDs: ["p1"],
            owner: .team,
            holeValues: [:],
            total: 1,
            holesPlayed: 2
        )
        let rowT2 = ScoringRow(
            scoringUnitID: "t2",
            participantIDs: ["p2"],
            countingParticipantIDs: ["p2"],
            owner: .team,
            holeValues: [:],
            total: 3,
            holesPlayed: 2
        )
        let matchup = TeamMatchup(id: "m1", teamIDs: ["t1", "t2"])
        let template = FormatTemplateRegistry.bestBallMatchup
        let result = ScoringResult(
            rows: [],
            holeStates: [:],
            template: template,
            matchupResults: [MatchupScoringResult(matchup: matchup, rows: [rowT2, rowT1])]
        )
        let teams = [
            RoundTeam(id: "t1", name: "A", color: "red", index: 0, createdAt: .init()),
            RoundTeam(id: "t2", name: "B", color: "blue", index: 1, createdAt: .init()),
        ]
        let sections = LeaderboardBuilder.buildMatchupSections(result: result, teams: teams, participants: [])
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].rows.map(\.scoringUnitID), ["t1", "t2"])
        XCTAssertEqual(sections[0].rows[0].placeLabel, "2.")
        XCTAssertEqual(sections[0].rows[1].placeLabel, "1.")
    }
}
