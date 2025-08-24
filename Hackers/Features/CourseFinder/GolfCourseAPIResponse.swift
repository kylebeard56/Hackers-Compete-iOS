//
//  GolfCourseAPIResponse.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//
//
//  GolfCourseAPIResponse.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - API Response (Decodable only)

struct GolfCourseAPIResponse: Decodable {
    let courses: [GolfCourseAPIModel]
    let course: GolfCourseAPIModel?

    enum CodingKeys: String, CodingKey { case courses, course }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.courses = try c.decodeLossyArray(GolfCourseAPIModel.self, forKey: .courses)
        self.course = try? c.decode(GolfCourseAPIModel.self, forKey: .course)
    }
}

// MARK: - Raw DTOs (mirror JSON only)

struct GolfCourseAPIModel: Codable, Identifiable {
    let id: Int
    let clubName: String
    let courseName: String
    let location: GolfCourseAPILocation
    var tees: GolfCourseAPITees

    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
        case location
        case tees
    }
}

struct GolfCourseAPILocation: Codable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
}

struct GolfCourseAPITees: Codable {
    let female: [GolfCourseAPITee]?
    let male: [GolfCourseAPITee]?

    /// Removes hybrid tees (i.e. red/yellow)
    var filteredFemale: [GolfCourseAPITee] {
        (female ?? []).filter({ !$0.teeName.contains("/") })
    }
    
    /// Removes hybrid tees (i.e. white/blue)
    var filteredMale: [GolfCourseAPITee] {
        (male ?? []).filter({ !$0.teeName.contains("/") })
    }
}

struct GolfCourseAPITee: Codable, Identifiable {
    let id: String = HackersID.string()
    let teeName: String
    let courseRating: Double
    let slopeRating: Int
    let bogeyRating: Double
    let totalYards: Int
    let totalMeters: Int
    let numberOfHoles: Int
    let parTotal: Int?
    let frontCourseRating: Double?
    let frontSlopeRating: Int?
    let frontBogeyRating: Double?
    let backCourseRating: Double?
    let backSlopeRating: Int?
    let backBogeyRating: Double?
    let holes: [GolfCourseAPIHole]

    enum CodingKeys: String, CodingKey {
        case teeName = "tee_name"
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case bogeyRating = "bogey_rating"
        case totalYards = "total_yards"
        case totalMeters = "total_meters"
        case numberOfHoles = "number_of_holes"
        case parTotal = "par_total"
        case frontCourseRating = "front_course_rating"
        case frontSlopeRating = "front_slope_rating"
        case frontBogeyRating = "front_bogey_rating"
        case backCourseRating = "back_course_rating"
        case backSlopeRating = "back_slope_rating"
        case backBogeyRating = "back_bogey_rating"
        case holes
    }
    
    var par: Int {
        parTotal ?? holes.reduce(0, { count, hole in count + hole.par })
    }
}

struct GolfCourseAPIHole: Codable, Identifiable {
    var id: String = HackersID.string()
    let par: Int
    let yardage: Int
    let handicap: Int?
}

// MARK: - Lossy array decode helper (Data-layer utility)

extension KeyedDecodingContainer {
    func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: K) throws -> [T] {
        var result: [T] = []
        if var unkeyed = try? nestedUnkeyedContainer(forKey: key) {
            while !unkeyed.isAtEnd {
                if let item = try? unkeyed.decode(T.self) {
                    result.append(item)
                } else {
                    _ = try? unkeyed.decode(DummyDecodable.self)
                }
            }
        }
        return result
    }
    private struct DummyDecodable: Decodable {}
}
