//
//  MockDashboardData.swift
//  Hackers
//
//  Created for Dashboard preview and development.
//

import Foundation
import SwiftUI

/// Mock rounds scattered over the past year for dashboard development.
enum MockDashboardData {
    
    // MARK: - Mock Rounds
    
    static let rounds: Set<Round> = {
        let courses: [(GolfCourseAPIModel, String)] = [
            (MockCourses.mountainPark, "mountain_park"),
            (MockCourses.threesGreenville, "threes_greenville")
        ]
        
        var result: Set<Round> = []
        let calendar = Calendar.current
        let now = Date()
        
        // 1 active lobby round (recent)
        let lobbyRound = makeRound(
            id: "mock_lobby_1",
            shareCode: "LOBBY1",
            status: .lobby,
            course: courses[0],
            date: now,
            playerCount: 4
        )
        result.insert(lobbyRound)
        
        // 1 active live round (recent)
        let liveRound = makeRound(
            id: "mock_live_1",
            shareCode: "LIVE01",
            status: .live,
            course: courses[1],
            date: now,
            playerCount: 2
        )
        result.insert(liveRound)
        
        // Completed rounds scattered over the past year
        let roundCount = 18
        for i in 0..<roundCount {
            let monthsAgo = Int.random(in: 0...11)
            let daysOffset = Int.random(in: 0...28)
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now),
                  let roundDate = calendar.date(byAdding: .day, value: -daysOffset, to: date) else { continue }
            
            let courseIndex = i % courses.count
            let round = makeRound(
                id: "mock_complete_\(i)",
                shareCode: String(format: "M%04d", 1000 + i),
                status: .complete,
                course: courses[courseIndex],
                date: roundDate,
                playerCount: Int.random(in: 2...4)
            )
            result.insert(round)
        }
        
        return result
    }()
    
    private static func makeRound(
        id: String,
        shareCode: String,
        status: RoundStatus,
        course: (GolfCourseAPIModel, String),
        date: Date,
        playerCount: Int
    ) -> Round {
        let courseInfo = CourseInfo(
            course: Course(from: course.0, with: course.1, useStableTeeIDs: true),
            for: .full18
        )
        let segment = CourseSegment(
            courseInfo: courseInfo,
            holeRange: HoleSegment.full18.holeRange,
            defaultTee: courseInfo.tees.first?.id
        )
        let time = Time(for: date)
        return Round(
            id: id,
            shareCode: shareCode,
            createdBy: "mock_user_1",
            status: status,
            players: (0..<playerCount).map { "player_\($0)" },
            configuration: .init(primaryFormat: .strokePlay, courses: [segment]),
            createdAt: time,
            lastUpdatedAt: time
        )
    }
    
    // MARK: - Mock Profile
    
    struct MockProfile {
        let displayName: String
        let initials: String
        let joinedDate: Date
        let roundsPlayed: Int
        
        var joinedDateFormatted: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: joinedDate)
        }
    }
    
    static let mockProfile: MockProfile = {
        let joinDate = Calendar.current.date(byAdding: .month, value: -8, to: Date()) ?? Date()
        return MockProfile(
            displayName: "Kyle Beard",
            initials: "KB",
            joinedDate: joinDate,
            roundsPlayed: 24
        )
    }()

    // MARK: - Dashboard series tile preview

    private static let previewSeriesLiveID = "mock_series_live_chip"
    private static let previewSeriesScheduledID = "mock_series_scheduled_chip"

    static let previewSeriesList: [Series] = [
        Series(
            id: previewSeriesLiveID,
            name: "Thursday League",
            commissionerUserID: "mock_user_1",
            commissionerPlayerID: "player_0",
            memberPlayerIDs: ["player_0"],
            status: .active,
            roundCount: 2,
            completedRoundCount: 0
        ),
        Series(
            id: previewSeriesScheduledID,
            name: "Weekend Trip",
            commissionerUserID: "mock_user_1",
            commissionerPlayerID: "player_0",
            memberPlayerIDs: ["player_0"],
            status: .active,
            roundCount: 1,
            completedRoundCount: 0
        )
    ]

    static let previewSeriesRoundsByID: [String: [SeriesRound]] = {
        let now = Date()
        let calendar = Calendar.current
        let tomorrowBase = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowTee = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: tomorrowBase) ?? tomorrowBase
        let tNow = Time(for: now)
        let tTomorrow = Time(for: tomorrowTee)

        let liveLinked = SeriesRound(
            id: "mock_sr_live",
            title: "",
            index: 0,
            status: .live,
            scheduledAt: tNow,
            roundID: "mock_live_1",
            createdAt: tNow,
            lastUpdatedAt: tNow,
            parentID: previewSeriesLiveID
        )

        let plannedTomorrow = SeriesRound(
            id: "mock_sr_planned",
            title: "",
            index: 0,
            status: .planned,
            scheduledAt: tTomorrow,
            roundID: nil,
            createdAt: tNow,
            lastUpdatedAt: tNow,
            parentID: previewSeriesScheduledID
        )

        return [
            previewSeriesLiveID: [liveLinked],
            previewSeriesScheduledID: [plannedTomorrow]
        ]
    }()
}
