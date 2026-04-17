//
//  CourseInfo.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

struct CourseSegment: Hashable, Codable {
    var courseInfo: CourseInfo
    var holeRange: HoleRange
    var defaultTee: String?
    
    init(
        courseInfo: CourseInfo = .init(),
        holeRange: HoleRange = .init(),
        defaultTee: String? = nil
    ) {
        self.courseInfo = courseInfo
        self.holeRange = holeRange
        self.defaultTee = defaultTee
    }
    
    enum CodingKeys: String, CodingKey {
        case courseInfo = "course_info"
        case holeRange = "hole_range"
        case defaultTee = "default_tee"
    }
    
    var holeSegment: HoleSegment { holeRange.segment }
    
    func tee(from id: String) -> Tee? { courseInfo.tees.first(where: { $0.id == id }) }
    
    func par(for tee: Tee) -> Int { tee.par(for: holeSegment) }
    func yardage(for tee: Tee) -> Int { tee.par(for: holeSegment) }
    func rating(for tee: Tee) -> Double? { tee.rating(for: holeSegment) }
    func slope(for tee: Tee) -> Int? { tee.slope(for: holeSegment) }
    func difficulty(for tee: Tee) -> Int { tee.difficultyScore(for: holeSegment) }
}

struct CourseInfo_WithCourseToReduceDuplication: Hashable, Codable {
    var id: String
    var course: Course
    var totalHoles: Int
    
    var name: String { course.prettyCourseName }
    var location: CourseLocation? { course.location }
    var tees: [Tee] { course.tees }
    
    var teeMap: [String: Tee] {
        tees.reduce(into: [:]) { result, tee in result[tee.id] = tee }
    }
    
    init(
        id: String = "",
        course: Course = .init(),
        totalHoles: Int = 0
    ) {
        self.id = id
        self.course = course
        self.totalHoles = totalHoles
    }
    
    init(course: Course, for segment: HoleSegment) {
        self.id = course.id
        self.course = course
        self.totalHoles = segment.holeCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id, course
        case totalHoles = "total_holes"
    }
}

/// Friendly, usable snapshot of canonical `Course` which may or may not live in the DB.
struct CourseInfo: Hashable, Codable {
    var id: String                  // Matches the stable, external ID in the `courses` collection
    let golfCourseApiID: Int?       // ID of the course from the Golf Course API (if not manual)
    var name: String
    var totalHoles: Int
    var location: CourseLocation?
    var venueDetails: CourseVenueDetails?
    var tees: [Tee]
    
    var teeMap: [String: Tee] {
        tees.reduce(into: [:]) { result, tee in result[tee.id] = tee }
    }
    
    init(
        id: String = "",
        golfCourseApiID: Int? = nil,
        name: String = "",
        totalHoles: Int = 0,
        location: CourseLocation? = nil,
        venueDetails: CourseVenueDetails? = nil,
        tees: [Tee] = []
    ) {
        self.id = id
        self.golfCourseApiID = golfCourseApiID
        self.name = name
        self.totalHoles = totalHoles
        self.location = location
        self.venueDetails = venueDetails
        self.tees = tees
    }
    
    init(course: Course, for segment: HoleSegment) {
        self.id = course.id
        self.name = course.prettyCourseName
        self.totalHoles = segment.holeCount
        self.golfCourseApiID = course.golfCourseApiID
        self.location = course.location
        self.venueDetails = course.venueDetails
        self.tees = course.tees
    }

    enum CodingKeys: String, CodingKey {
        case id, name, tees, location
        case totalHoles = "total_holes"
        case golfCourseApiID = "golf_course_api_id"
        case venueDetails = "venue_details"
    }
}
