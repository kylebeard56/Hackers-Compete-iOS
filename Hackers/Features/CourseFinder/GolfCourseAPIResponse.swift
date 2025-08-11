//
//  GolfCourseAPIResponse.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import CoreLocation
import Foundation

struct GolfCourseAPIResponse: Decodable {
    let courses: [GolfCourseAPIModel]
    let course: GolfCourseAPIModel?

    enum CodingKeys: String, CodingKey {
        case courses
        case course
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // This will decode only valid items, skipping bad ones
        self.courses = try container.decodeLossyArray(GolfCourseAPIModel.self, forKey: .courses)
        self.course = try? container.decode(GolfCourseAPIModel.self, forKey: .course)
    }
}

struct GolfCourseAPIModel: Codable, Identifiable {
    let id: Int
    let clubName: String
    let courseName: String
    let location: GolfCourseAPILocation
    var tees: GolfCourseAPITees
    
    init(
        id: Int = 0,
        clubName: String = "",
        courseName: String = "",
        location: GolfCourseAPILocation = .init(),
        tees: GolfCourseAPITees = .init()
    ) {
        self.id = id
        self.clubName = clubName
        self.courseName = courseName
        self.location = location
        self.tees = tees
    }

    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
        case location
        case tees
    }
    
    var isEmpty: Bool {
        id == 0 && clubName.isEmpty && courseName.isEmpty
    }
    
    var prettyClubName: String {
        clubName.prettifiedCourseTitle()
    }
    
    var prettyCourseName: String {
        courseName.prettifiedCourseTitle()
    }
}

struct GolfCourseAPILocation: Codable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    
    init(
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func formattedDistance(to loc: CLLocation?) -> String? {
        guard
            let loc = loc,
            let lat = latitude,
            let lon = longitude
        else {
            return nil
        }

        let courseLocation = CLLocation(latitude: lat, longitude: lon)
        let distance = loc.distance(from: courseLocation) // meters
        let distanceInMiles = distance / 1609.34
        return String(format: "%.1f miles", distanceInMiles)
    }
}

struct GolfCourseAPITees: Codable {
    let female: [GolfCourseAPITee]?
    let male: [GolfCourseAPITee]?
    
    init(
        female: [GolfCourseAPITee]? = nil,
        male: [GolfCourseAPITee]? = nil
    ) {
        self.female = female
        self.male = male
    }
    
    var combined: [GolfCourseAPITee] {
        let allTees = (female ?? []) + (male ?? [])
        
        // Remove duplicates based on teeName and totalYards
        var uniqueTees: [GolfCourseAPITee] = []
        var seenCombinations: Set<String> = []
        
        for tee in allTees {
            let key = "\(tee.teeName)-\(tee.totalYards)"
            if !seenCombinations.contains(key) {
                seenCombinations.insert(key)
                uniqueTees.append(tee)
            }
        }
        
        return uniqueTees
    }
}

struct GolfCourseAPITee: Codable, Identifiable {
    let id: UUID = UUID()
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
        parTotal ?? holes.reduce(0) { sum, hole in
            sum + hole.par
        }
    }
}

struct GolfCourseAPIHole: Codable, Identifiable {
    let id: UUID = UUID()
    let par: Int
    let yardage: Int
    let handicap: Int?
    
    enum CodingKeys: String, CodingKey {
        case par, yardage, handicap
    }
    
    var handicapValue: Int {
        handicap ?? 0
    }
}
