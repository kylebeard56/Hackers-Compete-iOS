//
//  Course.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import CoreLocation
import SwiftUI

enum CourseOrigin: String {
    case golfCourseAPI, manual, unknown
}

enum Gender: String, CaseIterable, Identifiable {
    case male = "male"
    case female = "female"
    case unknown = ""
    
    var name: String {
        switch self {
        case .male:     return "Men"
        case .female:   return "Women"
        default:        return ""
        }
    }
    
    var id: String { rawValue }
}

struct Course: FirebaseIdentifiable {
    let golfCourseApiID: Int?
    let origin: String
    let clubName: String
    let courseName: String
    let location: CourseLocation?
    let tees: [Tee]
    
    /// Conformance for FirebaseIdentifiable
    var id: String
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection: String { Collections.courses.name }
    var schema: Int = 1
    
    init(
        id: String = HackersID.string(),
        golfCourseApiID: Int? = nil,
        origin: CourseOrigin = .unknown,
        clubName: String = "",
        courseName: String = "",
        location: CourseLocation? = nil,
        tees: [Tee] = [],
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.golfCourseApiID = golfCourseApiID
        self.origin = origin.rawValue
        self.clubName = clubName
        self.courseName = courseName
        self.location = location
        self.tees = tees
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    init(
        from model: GolfCourseAPIModel,
        with id: String = HackersID.string(),
        useStableTeeIDs: Bool = false
    ) {
        let female = model.tees.filteredFemale.map { t in
            Tee(from: t, for: .female, with: useStableTeeIDs ? Self.stableTeeID(teeName: t.teeName, gender: .female) : HackersID.string())
        }
        let male = model.tees.filteredMale.map { t in
            Tee(from: t, for: .male, with: useStableTeeIDs ? Self.stableTeeID(teeName: t.teeName, gender: .male) : HackersID.string())
        }
        
        self.init(
            id: id,
            golfCourseApiID: model.id,
            origin: .golfCourseAPI,
            clubName: model.clubName,
            courseName: model.courseName,
            location: CourseLocation(from: model.location),
            tees: female + male,
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
    }
    
    init(info: CourseInfo) {
        self.init(
            id: info.id,
            golfCourseApiID: info.golfCourseApiID,
            origin: info.golfCourseApiID != nil ? .golfCourseAPI : .manual,
            clubName: info.name,
            courseName: info.name,
            location: info.location,
            tees: info.tees,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
    }
  
    enum CodingKeys: String, CodingKey {
        case id, origin, location, tees, schema
        case golfCourseApiID = "golf_course_api_id"
        case clubName = "club_name"
        case courseName = "course_name"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
    
    private static func stableTeeID(teeName: String, gender: Gender) -> String {
        let base = teeName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "")
        return "\(base)_\(gender.rawValue)"
    }
    
    var isEmpty: Bool {
        id.isEmpty && clubName.isEmpty && courseName.isEmpty && tees.isEmpty
    }
    var prettyClubName: String {
        clubName.prettifiedCourseTitle()
    }

    var prettyCourseName: String {
        courseName.prettifiedCourseTitle()
    }
}

struct CourseLocation: Hashable, Codable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let geohash: String
    let pinpoint: String
    
    init(
        address: String?,
        city: String?,
        state: String?,
        country: String?,
        latitude: Double,
        longitude: Double
    ) {
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.geohash = Geohash.encode(latitude: latitude, longitude: longitude, precision: 5)
        self.pinpoint = Geohash.encode(latitude: latitude, longitude: longitude, precision: 8)
    }
    
    init(from location: GolfCourseAPILocation) {
        self.address = location.address
        self.city = location.city
        self.state = location.state
        self.country = location.country
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.geohash = Geohash.encode(latitude: location.latitude, longitude: location.longitude)
        self.pinpoint = Geohash.encode(latitude: location.latitude, longitude: location.longitude, precision: 8)
    }
    
    enum CodingKeys: String, CodingKey {
        case address, city, state, country, latitude, longitude, geohash, pinpoint
    }
    
    var trimmedAddress: String {
        AddressFormatter.trimmedUSAddress(address ?? "")
    }
    
    func formattedDistance(to location: CLLocation?) -> String? {
        DistanceFormatter.formattedDistanceMiles(from: location, to: latitude, longitude: longitude)
    }
    
    func toCLLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

extension Course {
    var hasEighteen: Bool { tees.contains { $0.totalHoles >= 18 } }

    var availableSegments: [HoleSegment] {
        if hasEighteen { return [.full18, .front9, .back9] }
        let counts = Set(tees.map(\.totalHoles)).sorted()
        return counts.map { .custom(lower: 1, upper: $0) }
    }

    var defaultSegment: HoleSegment {
        if hasEighteen { return .full18 }
        let maxCount = tees.map(\.totalHoles).max() ?? 0
        return .custom(lower: 1, upper: maxCount)
    }
}
