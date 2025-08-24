//
//  CourseInfo.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/25.
//

import Foundation

// MARK: - CourseInfo
struct CourseInfo: Hashable, Codable {
    var id: String
    var name: String
    var totalHoles: Int
    var tees: [String: TeeBox]  // Tee box ID as key with data as value
    
    init(
        id: String = "",
        name: String = "",
        totalHoles: Int = 0,
        tees: [String : TeeBox] = [:]
    ) {
        self.id = id
        self.name = name
        self.totalHoles = totalHoles
        self.tees = tees
    }
    
    init(course: Course, for segment: HoleSegment) {
        self.id = course.id
        self.name = course.prettyCourseName
        self.totalHoles = segment.holeCount
        self.tees = course.tees.reduce(into: [:]) { result, tee in
            result[tee.id] = TeeBox(tee: tee, for: segment)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, tees
        case totalHoles = "total_holes"
    }
}

struct TeeBox: Hashable, Codable {
    var id: String
    var name: String
    var totalPar: Int
    var par: [Int: Int]         // [hole #: par]
    
    init(
        id: String = "",
        name: String = "",
        totalPar: Int = 0,
        par: [Int : Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.totalPar = totalPar
        self.par = par
    }
    
    init(tee: Tee, for segment: HoleSegment) {
        self.id = tee.id
        self.name = tee.name
        self.totalPar = tee.par(for: segment)
        self.par = Dictionary(uniqueKeysWithValues: zip(1..., tee.holes.map(\.par)))
    }
    
    init(tee: GolfCourseAPITee) {
        self.id = tee.id
        self.name = tee.teeName
        self.totalPar = tee.par
        self.par = Dictionary(uniqueKeysWithValues: zip(1..., tee.holes.map(\.par)))
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, par
        case totalPar = "total_par"
    }
}
