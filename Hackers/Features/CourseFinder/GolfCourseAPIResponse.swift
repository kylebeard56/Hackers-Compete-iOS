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
        // The provider has returned both a top-level course and `{ "course": ... }` over time.
        // Support both shapes so cache misses can still be populated across response variants.
        if let topLevelCourse = try? GolfCourseAPIModel(from: decoder) {
            self.courses = []
            self.course = topLevelCourse
            return
        }

        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.courses = try c.decodeLossyArray(GolfCourseAPIModel.self, forKey: .courses)
        // The /search endpoint only returns `courses`; `course` (singular) is only present
        // on the by-id endpoint. Do not suppress a malformed `course` value: surfacing its
        // decoding error makes provider schema changes diagnosable instead of looking empty.
        self.course = try c.decodeIfPresent(GolfCourseAPIModel.self, forKey: .course)
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

    enum CodingKeys: String, CodingKey {
        case address, city, state, country, latitude, longitude
    }

    init(
        address: String?,
        city: String?,
        state: String?,
        country: String?,
        latitude: Double = 0,
        longitude: Double = 0
    ) {
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
    }

    var coordinate: CLLocationCoordinate2D? {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard (latitude != 0 || longitude != 0),
              CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }
        return coordinate
    }
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
    let bogeyRating: Double?
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

// MARK: - Cached Course Reconstruction

extension GolfCourseAPIModel {
    /// Reconstructs the API-shaped model required by existing search consumers from our canonical
    /// cached `Course`. Some provider-only aggregate tee fields are not retained by `Course`, so
    /// they are derived from the saved holes and are not used for scoring.
    init?(cachedCourse course: Course) {
        guard course.hasCanonicalGolfCourseAPIIdentity,
              let apiID = course.golfCourseApiID,
              let location = course.location else {
            return nil
        }

        self.init(
            id: apiID,
            clubName: course.clubName,
            courseName: course.courseName,
            location: GolfCourseAPILocation(
                address: location.address,
                city: location.city,
                state: location.state,
                country: location.country,
                latitude: location.latitude,
                longitude: location.longitude
            ),
            websiteURL: course.venueDetails?.websiteURL,
            phoneNumber: course.venueDetails?.phoneNumber,
            tees: GolfCourseAPITees(
                female: course.tees.female.map(GolfCourseAPITee.init(cachedTee:)),
                male: course.tees.male.map(GolfCourseAPITee.init(cachedTee:))
            )
        )
    }
}

extension GolfCourseAPITee {
    init(cachedTee tee: Tee) {
        let holes = tee.holes
            .sorted { $0.number < $1.number }
            .map { GolfCourseAPIHole(par: $0.par, yardage: $0.yardage, handicap: $0.handicap) }
        let totalYards = holes.reduce(0) { $0 + $1.yardage }

        self.init(
            teeName: tee.name,
            courseRating: tee.ratingFull,
            slopeRating: tee.slopeFull,
            bogeyRating: nil,
            totalYards: totalYards,
            totalMeters: Int((Double(totalYards) * 0.9144).rounded()),
            numberOfHoles: holes.count,
            parTotal: holes.reduce(0) { $0 + $1.par },
            frontCourseRating: tee.ratingFront,
            frontSlopeRating: tee.slopeFront,
            frontBogeyRating: nil,
            backCourseRating: tee.ratingBack,
            backSlopeRating: tee.slopeBack,
            backBogeyRating: nil,
            holes: holes
        )
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
