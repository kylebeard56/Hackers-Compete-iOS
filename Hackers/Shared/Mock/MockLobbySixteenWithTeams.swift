//
//  MockLobbySixteenWithTeams.swift
//  Hackers
//
//  Created by Kyle Beard on 2/16/26.
//

import SwiftUI

/// Sixteensome lobby: 16 players, 4 teams, 4 tee groups, stroke play with handicaps.
enum MockLobbySixteenWithTeams {
    static let roundID = "mock_lobby_sixteen"
    
    static let snapshot: RoundSnapshot = .init(
        round: round,
        participants: participants,
        teams: teams,
        teeGroups: teeGroups,
        segments: [],
        scoring: []
    )
    
    static let round: Round = .init(
        id: roundID,
        shareCode: "BIG16X",
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
            courses: [defaultCourseSegment]
        ),
        createdAt: .init(),
        lastUpdatedAt: .init()
    )
    
    static let teams: [RoundTeam] = [
        .init(id: "team_red", name: "Red Team", color: "red", index: 0, createdAt: .init(), parentID: roundID),
        .init(id: "team_blue", name: "Blue Team", color: "blue", index: 1, createdAt: .init(), parentID: roundID),
        .init(id: "team_green", name: "Green Team", color: "green", index: 2, createdAt: .init(), parentID: roundID),
        .init(id: "team_purple", name: "Purple Team", color: "purple", index: 3, createdAt: .init(), parentID: roundID),
    ]
    
    static let teeGroups: [TeeTimeGroup] = [
        .init(id: "group_1", index: 0, teeTime: "7:30 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_2", index: 1, teeTime: "7:38 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_3", index: 2, teeTime: "7:46 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
        .init(id: "group_4", index: 3, teeTime: "7:54 AM", startingHole: 1, lastCompletedHole: 0, createdAt: .init(), parentID: roundID),
    ]
    
    static let participants: [RoundParticipant] = [
        // Group 1 (mixed teams)
        makeParticipant(id: "p01", first: "Kyle",    last: "Beard",    teamID: "team_red",    groupID: "group_1", teeOrder: 1, handicap: 12, isHost: true),
        makeParticipant(id: "p02", first: "Jake",    last: "Palmer",   teamID: "team_blue",   groupID: "group_1", teeOrder: 2, handicap: 8),
        makeParticipant(id: "p03", first: "Drew",    last: "Collins",  teamID: "team_green",  groupID: "group_1", teeOrder: 3, handicap: 22),
        makeParticipant(id: "p04", first: "Nick",    last: "Rivera",   teamID: "team_purple", groupID: "group_1", teeOrder: 4, handicap: 15),
        // Group 2
        makeParticipant(id: "p05", first: "Liam",    last: "Carter",   teamID: "team_red",    groupID: "group_2", teeOrder: 1, handicap: 6),
        makeParticipant(id: "p06", first: "Ethan",   last: "Brooks",   teamID: "team_blue",   groupID: "group_2", teeOrder: 2, handicap: 18),
        makeParticipant(id: "p07", first: "Noah",    last: "Reeves",   teamID: "team_green",  groupID: "group_2", teeOrder: 3, handicap: 10),
        makeParticipant(id: "p08", first: "Mason",   last: "Harper",   teamID: "team_purple", groupID: "group_2", teeOrder: 4, handicap: 25),
        // Group 3
        makeParticipant(id: "p09", first: "James",   last: "Tucker",   teamID: "team_red",    groupID: "group_3", teeOrder: 1, handicap: 14),
        makeParticipant(id: "p10", first: "Owen",    last: "Grant",    teamID: "team_blue",   groupID: "group_3", teeOrder: 2, handicap: 3),
        makeParticipant(id: "p11", first: "Lucas",   last: "Walsh",    teamID: "team_green",  groupID: "group_3", teeOrder: 3, handicap: 20),
        makeParticipant(id: "p12", first: "Henry",   last: "Stone",    teamID: "team_purple", groupID: "group_3", teeOrder: 4, handicap: 28),
        // Group 4
        makeParticipant(id: "p13", first: "Logan",   last: "Perry",    teamID: "team_red",    groupID: "group_4", teeOrder: 1, handicap: 9),
        makeParticipant(id: "p14", first: "Caleb",   last: "Fox",      teamID: "team_blue",   groupID: "group_4", teeOrder: 2, handicap: 16),
        makeParticipant(id: "p15", first: "Ryan",    last: "Hayes",    teamID: "team_green",  groupID: "group_4", teeOrder: 3, handicap: 5),
        makeParticipant(id: "p16", first: "Cole",    last: "Bennett",  teamID: "team_purple", groupID: "group_4", teeOrder: 4, handicap: 30),
    ]
    
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
            teeBoxID: "default_tee_1",
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
        .init(
            courseInfo: CourseInfo(
                course: Course(from: MockCourses.mountainPark, with: "course_id"),
                for: .full18
            ),
            holeRange: HoleSegment.full18.holeRange,
            defaultTee: "default_tee_1"
        )
    }
}
