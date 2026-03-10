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
        teamID: String? = nil, groupID: String? = nil
    ) -> RoundParticipant {
        RoundParticipant(
            id: id,
            name: Name(name, "Test"),
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID
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
        let template = FormatTemplateRegistry.bestTwoOfFourMatchup

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
        // Charlie (9 hcp): gets stroke on holes with hcp <=9 → holes 1(hcp7),2(hcp3),4(hcp1) → -1; hole 3(hcp15) → 0
        // Dave (9 hcp): same as Charlie
        //
        // Team 1 best ball (net): Bob always -1 → [-1,-1,-1,-1]
        // Team 2 best ball (net): Charlie/Dave = [-1,-1,0,-1]
        //
        // Compare:
        //   Hole 1: t1=-1, t2=-1 → tie → 0.5 each
        //   Hole 2: t1=-1, t2=-1 → tie → 0.5 each
        //   Hole 3: t1=-1, t2=0 → t1 wins → t1=1, t2=0
        //   Hole 4: t1=-1, t2=-1 → tie → 0.5 each
        //   Total: t1=2.5, t2=1.5
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

        XCTAssertEqual(rowMap["t1"]?.total ?? 0, 2.5, accuracy: 0.01,
                       "Team 1 (scratch+18hcp) should win 2.5 pts with net advantage on hole 3")
        XCTAssertEqual(rowMap["t2"]?.total ?? 0, 1.5, accuracy: 0.01,
                       "Team 2 (two 9hcp) should have 1.5 pts")
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
}
