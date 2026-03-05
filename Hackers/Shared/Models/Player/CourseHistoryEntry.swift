//
//  CourseHistoryEntry.swift
//  Hackers
//
//  Denormalized history of courses this player has played.
//

import Foundation

// MARK: - CourseIDType

enum CourseIDType: String, Codable {
    case courseAPI = "course_api"
    case manual = "manual"
}

// MARK: - CourseHistoryEntry

struct CourseHistoryEntry: Hashable, Codable {
    var courseID: String
    var courseIDType: CourseIDType
    var name: String
    var roundsPlayed: Int
    var lastPlayedAt: Time

    enum CodingKeys: String, CodingKey {
        case courseID = "course_id"
        case courseIDType = "course_id_type"
        case name
        case roundsPlayed = "rounds_played"
        case lastPlayedAt = "played_at"
    }

    init(
        courseID: String = "",
        courseIDType: CourseIDType = .courseAPI,
        name: String = "",
        roundsPlayed: Int = 0,
        lastPlayedAt: Time = .init()
    ) {
        self.courseID = courseID
        self.courseIDType = courseIDType
        self.name = name
        self.roundsPlayed = roundsPlayed
        self.lastPlayedAt = lastPlayedAt
    }

    var compositeKey: String { "\(courseIDType.rawValue):\(courseID)" }
}
