//
//  Course.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import CoreLocation
import SwiftUI

enum CourseOrigin: String {
    case golfCourseAPI
    case hackers
    case manual
    case simple
    case ocr
    case unknown
}

struct CourseVenueDetails: Hashable, Codable {
    let websiteURL: String?
    let phoneNumber: String?

    init(
        websiteURL: String? = nil,
        phoneNumber: String? = nil
    ) {
        self.websiteURL = websiteURL
        self.phoneNumber = phoneNumber
    }
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
    let venueDetails: CourseVenueDetails?
    /// Top-level geohash for Firestore queries (e.g. fetchCourses near location)
    let locationGeohash: String?
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
        venueDetails: CourseVenueDetails? = nil,
        locationGeohash: String? = nil,
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
        self.venueDetails = venueDetails
        self.locationGeohash = locationGeohash ?? location?.geohash
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
        
        let loc = CourseLocation(from: model.location)
        self.init(
            id: id,
            golfCourseApiID: model.id,
            origin: .golfCourseAPI,
            clubName: model.clubName,
            courseName: model.courseName,
            location: loc,
            venueDetails: CourseVenueDetails(
                websiteURL: model.websiteURL,
                phoneNumber: model.phoneNumber
            ),
            locationGeohash: loc?.geohash,
            tees: female + male,
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
    }
    
    init(info: CourseInfo) {
        let origin: CourseOrigin = info.id.isPopulated
            ? .hackers
            : (info.golfCourseApiID != nil ? .golfCourseAPI : .hackers)
        self.init(
            id: info.id,
            golfCourseApiID: info.golfCourseApiID,
            origin: origin,
            clubName: info.name,
            courseName: info.name,
            location: info.location,
            venueDetails: info.venueDetails,
            locationGeohash: info.location?.geohash,
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
        case venueDetails = "venue_details"
        case locationGeohash = "location_geohash"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
        case searchKey = "search_key"
        case searchKeyReverse = "search_key_reverse"
    }
}

// MARK: - Search Index (Codable)

extension Course {
    var searchKey: String { courseName.normalizedForSearch }
    var searchKeyReverse: String {
        clubName != courseName ? clubName.normalizedForSearch : searchKey
    }

    /// Matches the normalized prefix/token search used by the Firebase course cache.
    /// The first token must start either the course or club name; remaining tokens can appear in
    /// either name. This keeps cached search focused while accepting common queries such as
    /// "Pinehurst 2" for "Pinehurst No. 2".
    func matchesCachedSearch(query: String) -> Bool {
        let tokens = query.normalizedForSearch
            .split(separator: " ")
            .map(String.init)
        guard let first = tokens.first else { return false }

        let keys = [searchKey, searchKeyReverse]
        guard keys.contains(where: { $0.hasPrefix(first) }) else { return false }

        return tokens.dropFirst().allSatisfy { token in
            keys.contains(where: { $0.contains(token) })
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        golfCourseApiID = try c.decodeIfPresent(Int.self, forKey: .golfCourseApiID)
        origin = try c.decode(String.self, forKey: .origin)
        clubName = try c.decode(String.self, forKey: .clubName)
        courseName = try c.decode(String.self, forKey: .courseName)
        location = try c.decodeIfPresent(CourseLocation.self, forKey: .location)
        venueDetails = try c.decodeIfPresent(CourseVenueDetails.self, forKey: .venueDetails)
        locationGeohash = try c.decodeIfPresent(String.self, forKey: .locationGeohash)
        tees = try c.decode([Tee].self, forKey: .tees)
        createdAt = try c.decode(Time.self, forKey: .createdAt)
        lastUpdatedAt = try c.decode(Time.self, forKey: .lastUpdatedAt)
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        _ = try c.decodeIfPresent(String.self, forKey: .searchKey)
        _ = try c.decodeIfPresent(String.self, forKey: .searchKeyReverse)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(golfCourseApiID, forKey: .golfCourseApiID)
        try c.encode(origin, forKey: .origin)
        try c.encode(clubName, forKey: .clubName)
        try c.encode(courseName, forKey: .courseName)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(venueDetails, forKey: .venueDetails)
        try c.encodeIfPresent(locationGeohash ?? location?.geohash, forKey: .locationGeohash)
        try c.encode(tees, forKey: .tees)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try c.encode(schema, forKey: .schema)
        try c.encode(searchKey, forKey: .searchKey)
        try c.encode(searchKeyReverse, forKey: .searchKeyReverse)
    }
}

extension Course {
    /// Canonical Firestore document ID for a GolfCourseAPI-backed course.
    ///
    /// Keeping the provider ID deterministic gives cache lookups a direct document read and
    /// prevents concurrent clients from creating duplicate UUID-backed copies of the same course.
    static func golfCourseAPIDocumentID(for apiID: Int) -> String {
        String(apiID)
    }

    /// Builds the one canonical `Course` representation used for GolfCourseAPI cache documents.
    init(canonicalGolfCourseAPI model: GolfCourseAPIModel) {
        self.init(
            from: model,
            with: Self.golfCourseAPIDocumentID(for: model.id),
            useStableTeeIDs: true
        )
    }

    var hasCanonicalGolfCourseAPIIdentity: Bool {
        guard origin == CourseOrigin.golfCourseAPI.rawValue,
              let apiID = golfCourseApiID,
              apiID > 0 else { return false }
        return id == Self.golfCourseAPIDocumentID(for: apiID)
    }

    /// Accepts a legacy UUID-backed cache record for the requested provider ID and returns it
    /// with the deterministic identity used by the current cache. Records for another provider
    /// ID (or a non-provider origin) are rejected instead of leaking stale course data.
    func canonicalizedGolfCourseAPICacheEntry(expectedAPIID: Int) -> Course? {
        guard expectedAPIID > 0,
              origin == CourseOrigin.golfCourseAPI.rawValue,
              golfCourseApiID == expectedAPIID else { return nil }

        var course = self
        course.id = Self.golfCourseAPIDocumentID(for: expectedAPIID)
        return course
    }

    var isSimpleRoundCourse: Bool {
        origin == CourseOrigin.simple.rawValue
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
    
    init?(from location: GolfCourseAPILocation) {
        guard let coordinate = location.coordinate else { return nil }
        self.address = location.address
        self.city = location.city
        self.state = location.state
        self.country = location.country
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.geohash = Geohash.encode(latitude: coordinate.latitude, longitude: coordinate.longitude)
        self.pinpoint = Geohash.encode(latitude: coordinate.latitude, longitude: coordinate.longitude, precision: 8)
    }
    
    enum CodingKeys: String, CodingKey {
        case address, city, state, country, latitude, longitude, geohash, pinpoint
    }
    
    var trimmedAddress: String {
        AddressFormatter.trimmedUSAddress(address ?? "")
    }
    
    var streetName: String? {
        trimmedAddress
            .split(separator: ",", maxSplits: 1)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) }
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
        if maxCount <= 0 { return .full18 }
        return .custom(lower: 1, upper: maxCount)
    }
}
