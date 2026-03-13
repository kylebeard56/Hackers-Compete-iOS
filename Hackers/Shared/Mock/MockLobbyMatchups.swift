//
//  MockLobbyMatchups.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import SwiftUI

/// Lobby with 4 teams, 8 players, 2 tee groups, and preset matchups (Red vs Blue, Green vs Purple).
/// Used for GameLobby previews to show the Matchups tab and matchup cards.
enum MockLobbyMatchups {
    static let roundID = "mock_lobby_matchups"
    private static let defaultTeeID = defaultCourseSegment.courseInfo.tees.first?.id ?? "default_tee_1"

    static let teams: [RoundTeam] = [
        .init(id: "team_red", name: "Red Team", color: "red", index: 0, createdAt: .init(), parentID: roundID),
        .init(id: "team_blue", name: "Blue Team", color: "blue", index: 1, createdAt: .init(), parentID: roundID),
        .init(id: "team_green", name: "Green Team", color: "green", index: 2, createdAt: .init(), parentID: roundID),
        .init(id: "team_purple", name: "Purple Team", color: "purple", index: 3, createdAt: .init(), parentID: roundID),
    ]

    static let teeGroups: [TeeTimeGroup] = [
        .init(id: "group_1", index: 0, teeTime: "7:30 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_2", index: 1, teeTime: "7:38 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
    ]

    static let participants: [RoundParticipant] = [
        makeParticipant(id: "p01", first: "Kyle", last: "Beard", teamID: "team_red", groupID: "group_1", teeOrder: 1, handicap: 12, isHost: true),
        makeParticipant(id: "p02", first: "Jake", last: "Palmer", teamID: "team_red", groupID: "group_1", teeOrder: 2, handicap: 8),
        makeParticipant(id: "p03", first: "Drew", last: "Collins", teamID: "team_blue", groupID: "group_1", teeOrder: 3, handicap: 22),
        makeParticipant(id: "p04", first: "Nick", last: "Rivera", teamID: "team_blue", groupID: "group_1", teeOrder: 4, handicap: 15),
        makeParticipant(id: "p05", first: "Liam", last: "Carter", teamID: "team_green", groupID: "group_2", teeOrder: 1, handicap: 6),
        makeParticipant(id: "p06", first: "Ethan", last: "Brooks", teamID: "team_green", groupID: "group_2", teeOrder: 2, handicap: 18),
        makeParticipant(id: "p07", first: "Noah", last: "Reeves", teamID: "team_purple", groupID: "group_2", teeOrder: 3, handicap: 10),
        makeParticipant(id: "p08", first: "Mason", last: "Harper", teamID: "team_purple", groupID: "group_2", teeOrder: 4, handicap: 25),
    ]

    static let matchups: [TeamMatchup] = [
        .init(id: "m1", teamIDs: ["team_red", "team_blue"]),
        .init(id: "m2", teamIDs: ["team_green", "team_purple"]),
    ]

    static let segment: RoundSegment = .init(
        id: "segment_1",
        roundID: roundID,
        holeRange: .init(startHole: 1, endHole: 18),
        gameFormat: .strokePlay,
        templateID: FormatTemplateRegistry.bestBall.id,
        scoringUnits: teams.map { .init(id: "unit_\($0.id)", owner: .team, ownerIDs: [$0.id], scoringMethod: .individual) },
        matchups: matchups,
        competitionScope: .matchup,
        createdAt: .init(),
        lastUpdatedAt: .init(),
        parentID: roundID
    )

    static let snapshot: RoundSnapshot = .init(
        round: round,
        participants: participants,
        teams: teams,
        teeGroups: teeGroups,
        segments: [segment],
        scoring: []
    )

    /// Same as snapshot but status .live for LiveRound previews (Matchups tab).
    static var liveSnapshot: RoundSnapshot {
        var r = round
        r.status = .live
        return .init(round: r, participants: participants, teams: teams, teeGroups: teeGroups, segments: [segment], scoring: [])
    }

    static let round: Round = .init(
        id: roundID,
        shareCode: "MATCH",
        createdBy: "player_p01",
        status: .lobby,
        players: participants.compactMap(\.playerID),
        configuration: .init(
            primaryFormat: .init(
                type: .strokePlay,
                configuration: .init(
                    method: .individual,
                    aggregation: nil,
                    basis: .net,
                    handicap: .individualStrokePlay,
                    requiresTeams: true,
                    teeGroupOnly: false
                )
            ),
            formatSummary: RoundFormatSummary(from: FormatTemplateRegistry.bestBall),
            courses: [defaultCourseSegment],
            competitionScope: .matchup
        ),
        createdAt: .init(),
        lastUpdatedAt: .init()
    )

    private static func makeParticipant(
        id: String,
        first: String,
        last: String,
        teamID: String,
        groupID: String,
        teeOrder: Int,
        handicap: Int,
        isHost: Bool = false
    ) -> RoundParticipant {
        .init(
            id: id,
            userID: "user_\(id)",
            playerID: "player_\(id)",
            name: Name(first, last),
            teeBoxID: defaultTeeID,
            originalHandicap: handicap,
            adjustedHandicap: handicap,
            teamID: teamID,
            groupID: groupID,
            teeOrder: teeOrder,
            isHost: isHost,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: roundID
        )
    }

    private static var defaultCourseSegment: CourseSegment {
        let courseInfo = CourseInfo(
            course: Course(from: MockCourses.mountainPark, with: "course_id"),
            for: .full18
        )
        return .init(
            courseInfo: courseInfo,
            holeRange: HoleSegment.full18.holeRange,
            defaultTee: courseInfo.tees.first?.id ?? "default_tee_1"
        )
    }
}
