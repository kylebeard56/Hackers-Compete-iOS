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

struct CourseInfo: Hashable, Codable {
    var id: String                  // Matches the stable, external ID in the `courses` collection
    let golfCourseApiID: Int?       // ID of the course from the Golf Course API (if not manual)
    var name: String
    var totalHoles: Int
    var location: CourseLocation?
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
        tees: [Tee] = []
    ) {
        self.id = id
        self.golfCourseApiID = golfCourseApiID
        self.name = name
        self.totalHoles = totalHoles
        self.location = location
        self.tees = tees
    }
    
    init(course: Course, for segment: HoleSegment) {
        self.id = course.id
        self.name = course.prettyCourseName
        self.totalHoles = segment.holeCount
        self.golfCourseApiID = course.golfCourseApiID
        self.location = course.location
        self.tees = course.tees//.reduce(into: [:]) { result, tee in result[tee.id] = tee }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, tees, location
        case totalHoles = "total_holes"
        case golfCourseApiID = "golf_course_api_id"
    }
}

//struct TeeBox: Hashable, Codable, Teeable {
//    var id: String
//    var name: String
//    var gender: String
//    
//    var par: Int
//    var yardage: Int
//    
//    var rating: Double?
//    var slope: Int?
//    
//    var holes: [Hole]
//    var totalHoles: Int
//    
//    init(
//        id: String = "",
//        name: String = "",
//        gender: String = "",
//        par: Int = 0,
//        yardage: Int = 0,
//        rating: Double? = nil,
//        slope: Int? = nil,
//        holes: [Hole] = []
//    ) {
//        self.id = id
//        self.name = name
//        self.rating = rating
//        self.slope = slope
//        self.par = par
//        self.yardage = yardage
//        self.gender = gender
//        self.holes = holes
//        self.totalHoles = holes.count
//    }
//    
//    init(tee: Tee, for segment: HoleSegment) {
//        self.id = tee.id
//        self.name = tee.name
//        self.par = tee.par(for: segment)
//        self.yardage = tee.holes.reduce(0) { $0 + $1.yardage }
//        self.gender = tee.gender
//        
//        switch segment {
//        case .front9:
//            self.rating = tee.ratingFront
//            self.slope = tee.slopeFront
//        case .back9:
//            self.rating = tee.ratingBack
//            self.slope = tee.slopeBack
//        default:
//            self.rating = tee.ratingFull
//            self.slope = tee.slopeFull
//        }
//        
//        self.holes = tee.holes
//        self.totalHoles = tee.holes.count
//    }
//    
//    init(tee: GolfCourseAPITee, for gender: String, with segment: HoleSegment) {
//        self.id = tee.id
//        self.name = tee.teeName
//        self.gender = gender
//        
//        self.par = tee.par
//        self.yardage = tee.holes.reduce(0) { $0 + $1.yardage }
//        
//        switch segment {
//        case .front9:
//            self.rating = tee.frontCourseRating
//            self.slope = tee.frontSlopeRating
//        case .back9:
//            self.rating = tee.backCourseRating
//            self.slope = tee.backSlopeRating
//        default:
//            self.rating = tee.courseRating
//            self.slope = tee.slopeRating
//        }
//        
//        self.holes = tee.holes.enumerated().map { number, hole in Hole(from: hole, number: number + 1) }
//        self.totalHoles = tee.holes.count
//    }
//    
//    enum CodingKeys: String, CodingKey {
//        case id, name, rating, slope, par, yardage, gender, holes
//    }
//    
//    func par(for hole: Int) -> Int? {
//        guard let teeHole = holes[hole] else { return nil }
//        return teeHole.par
//    }
//}

//struct TeeHole: Hashable, Codable {
//    var par: Int
//    var handicap: Int?      // Hole ranking: 1 = hardest, 18 = easiest
//    var yardage: Int?
//    
//    init(
//        par: Int = 0,
//        handicap: Int? = nil,
//        yardage: Int? = nil
//    ) {
//        self.par = par
//        self.handicap = handicap
//        self.yardage = yardage
//    }
//    enum CodingKeys: String, CodingKey {
//        case par, handicap, yardage
//    }
//}
