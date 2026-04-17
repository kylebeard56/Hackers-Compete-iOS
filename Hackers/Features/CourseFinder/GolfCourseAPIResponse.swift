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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.courses = try c.decodeLossyArray(GolfCourseAPIModel.self, forKey: .courses)
        do {
            self.course = try c.decode(GolfCourseAPIModel.self, forKey: .course)
        } catch let error {
            printPretty(error)
            self.course = nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case courses, course
    }
}

// MARK: - Raw DTOs (mirror JSON only)

struct GolfCourseAPIModel: Codable, Identifiable {
    let id: Int
    let clubName: String
    let courseName: String
    let location: GolfCourseAPILocation
    let websiteURL: String?
    let phoneNumber: String?
    var tees: GolfCourseAPITees

    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
        case location
        case tees
        case website
        case websiteURL = "website_url"
        case url
        case phone
        case phoneNumber = "phone_number"
        case telephone
    }

    init(
        id: Int,
        clubName: String,
        courseName: String,
        location: GolfCourseAPILocation,
        websiteURL: String? = nil,
        phoneNumber: String? = nil,
        tees: GolfCourseAPITees
    ) {
        self.id = id
        self.clubName = clubName
        self.courseName = courseName
        self.location = location
        self.websiteURL = websiteURL
        self.phoneNumber = phoneNumber
        self.tees = tees
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        clubName = try c.decode(String.self, forKey: .clubName)
        courseName = try c.decode(String.self, forKey: .courseName)
        location = try c.decode(GolfCourseAPILocation.self, forKey: .location)
        tees = try c.decode(GolfCourseAPITees.self, forKey: .tees)
        websiteURL =
            try c.decodeIfPresent(String.self, forKey: .websiteURL)
            ?? c.decodeIfPresent(String.self, forKey: .website)
            ?? c.decodeIfPresent(String.self, forKey: .url)
        phoneNumber =
            try c.decodeIfPresent(String.self, forKey: .phoneNumber)
            ?? c.decodeIfPresent(String.self, forKey: .phone)
            ?? c.decodeIfPresent(String.self, forKey: .telephone)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(clubName, forKey: .clubName)
        try c.encode(courseName, forKey: .courseName)
        try c.encode(location, forKey: .location)
        try c.encode(tees, forKey: .tees)
        try c.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try c.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
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
    
    enum CodingKeys: String, CodingKey {
        case par, yardage, handicap
    }
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
