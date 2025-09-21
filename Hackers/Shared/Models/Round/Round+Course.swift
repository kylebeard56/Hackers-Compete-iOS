//
//  CourseInfo.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

struct CourseSegment: Hashable, Codable {
    var course: Course
    var courseInfo: CourseInfo
    var holeRange: HoleRange
    
    init(
        courseInfo: CourseInfo = .init(),
        holeRange: HoleRange = .init()
    ) {
        self.courseInfo = courseInfo
        self.holeRange = holeRange
    }
    
    enum CodingKeys: String, CodingKey {
        case course
        case courseInfo = "course_info"
        case holeRange = "hole_range"
    }
    
    var holeSegment: HoleSegment { holeRange.segment }
}

struct CourseInfo: Hashable, Codable {
    var id: String                  // Matches the stable, external ID in the `courses` collection
    let golfCourseApiID: Int?       // ID of the course from the Golf Course API (if not manual)
    var name: String
    var totalHoles: Int
    var tees: [String: TeeBox]      // Tee box ID as key with data as value
    
    init(
        id: String = "",
        golfCourseApiID: Int? = nil,
        name: String = "",
        totalHoles: Int = 0,
        tees: [String : TeeBox] = [:]
    ) {
        self.id = id
        self.golfCourseApiID = golfCourseApiID
        self.name = name
        self.totalHoles = totalHoles
        self.tees = tees
    }
    
    init(course: Course, for segment: HoleSegment) {
        self.id = course.id
        self.name = course.prettyCourseName
        self.totalHoles = segment.holeCount
        self.golfCourseApiID = course.golfCourseApiID
        self.tees = course.tees.reduce(into: [:]) { result, tee in
            result[tee.id] = TeeBox(tee: tee, for: segment)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, tees
        case totalHoles = "total_holes"
        case golfCourseApiID = "golf_course_api_id"
    }
}

struct TeeBox: Hashable, Codable {
    var id: String
    var name: String
    
    var rating: Double?
    var slope: Int?
    
    var par: Int                    // Total par for this tee box
    var holes: [Int: TeeHole]
    
    init(
        id: String = "",
        name: String = "",
        rating: Double? = nil,
        slope: Int? = nil,
        par: Int = 0,
        holes: [Int : TeeHole] = [:]
    ) {
        self.id = id
        self.name = name
        self.rating = rating
        self.slope = slope
        self.par = par
        self.holes = holes
    }
    
    init(tee: Tee, for segment: HoleSegment) {
        self.id = tee.id
        self.name = tee.name
        self.par = tee.par(for: segment)
        
        let sequence = zip(
            1...,
            tee.holes.map{ TeeHole(par: $0.par, handicap: $0.handicap, yardage: $0.yardage) }
        )
        self.holes = Dictionary(uniqueKeysWithValues: sequence)
    }
    
    init(tee: GolfCourseAPITee) {
        self.id = tee.id
        self.name = tee.teeName
        self.par = tee.par
        let sequence = zip(
            1...,
            tee.holes.map{ TeeHole(par: $0.par, handicap: $0.handicap, yardage: $0.yardage) }
        )
        self.holes = Dictionary(uniqueKeysWithValues: sequence)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, rating, slope, par, holes
    }
    
    func par(for hole: Int) -> Int? {
        guard let teeHole = holes[hole] else { return nil }
        return teeHole.par
    }
}

struct TeeHole: Hashable, Codable {
    var par: Int
    var handicap: Int?      // Hole ranking: 1 = hardest, 18 = easiest
    var yardage: Int?
    
    init(
        par: Int = 0,
        handicap: Int? = nil,
        yardage: Int? = nil
    ) {
        self.par = par
        self.handicap = handicap
        self.yardage = yardage
    }
    enum CodingKeys: String, CodingKey {
        case par, handicap, yardage
    }
}
