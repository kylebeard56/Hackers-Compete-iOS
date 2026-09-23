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

struct CourseSourceReference: Hashable, Codable {
    let provider: String
    let identifier: String
}

/// Textual locality survives directory responses that omit coordinates.
struct CourseLocality: Hashable, Codable {
    let city: String?
    let state: String?
    let country: String?

    var text: String {
        [city, state, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Course: FirebaseIdentifiable {
    let golfCourseApiID: GolfCourseID?
    let origin: String
    let clubName: String
    let courseName: String
    let location: CourseLocation?
    let venueDetails: CourseVenueDetails?
    /// Top-level geohash for Firestore queries (e.g. fetchCourses near location)
    let locationGeohash: String?
    private(set) var tees: [Tee]
    var locality: CourseLocality?
    var sourceReferences: [CourseSourceReference]
    var isUserEdited: Bool
    
    /// Conformance for FirebaseIdentifiable
    var id: String
    var createdAt: Time
    var lastUpdatedAt: Time
    var collection: String { Collections.courses.name }
    var schema: Int = 1
    
    init(
        id: String = HackersID.string(),
        golfCourseApiID: GolfCourseID? = nil,
        origin: CourseOrigin = .unknown,
        clubName: String = "",
        courseName: String = "",
        location: CourseLocation? = nil,
        venueDetails: CourseVenueDetails? = nil,
        locationGeohash: String? = nil,
        tees: [Tee] = [],
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time(),
        locality: CourseLocality? = nil,
        sourceReferences: [CourseSourceReference] = [],
        isUserEdited: Bool = false
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
        self.locality = locality ?? location.map { CourseLocality(city: $0.city, state: $0.state, country: $0.country) }
        self.sourceReferences = sourceReferences.isEmpty
            ? golfCourseApiID.map { [CourseSourceReference(provider: "golfCourseAPI", identifier: $0.description)] } ?? []
            : sourceReferences
        self.isUserEdited = isUserEdited
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
            lastUpdatedAt: Time(),
            locality: CourseLocality(city: model.location.city, state: model.location.state, country: model.location.country)
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
        case searchTokens = "search_tokens"
        case sourceReferences = "source_references"
        case isUserEdited = "is_user_edited"
        case locality
    }
}

// MARK: - Search Index (Codable)

extension Course {
    var searchKey: String { courseName.normalizedForSearch }
    var searchKeyReverse: String {
        clubName != courseName ? clubName.normalizedForSearch : searchKey
    }

    var searchTokens: [String] {
        Array(Set((searchKey + " " + searchKeyReverse).split(separator: " ").map(String.init))).sorted()
    }

    func matchesCachedSearch(query: String) -> Bool {
        let words = query.normalizedForSearch.split(separator: " ").map(String.init)
        return !words.isEmpty && words.allSatisfy { word in searchTokens.contains { $0.hasPrefix(word) } }
    }

    var hasPlayableScorecard: Bool {
        tees.contains { tee in
            tee.totalHoles > 0 && tee.holes.count == tee.totalHoles
                && Set(tee.holes.map(\.number)).count == tee.totalHoles
                && tee.holes.allSatisfy { $0.number > 0 && (1...6).contains($0.par) && $0.yardage >= 0 }
        }
    }

    var displayLocality: String {
        locality?.text ?? location.map { [$0.city, $0.state, $0.country].compactMap { $0 }.joined(separator: ", ") } ?? ""
    }

    /// Merge provider data without changing the Hackers identity or losing reviewed data.
    func mergingProviderCourse(_ incoming: Course) -> Course {
        guard !isUserEdited, origin == CourseOrigin.golfCourseAPI.rawValue else { return self }
        var result = Course(
            id: id, golfCourseApiID: golfCourseApiID, origin: .golfCourseAPI,
            clubName: incoming.clubName.isEmpty ? clubName : incoming.clubName,
            courseName: incoming.courseName.isEmpty ? courseName : incoming.courseName,
            location: incoming.location ?? location,
            venueDetails: CourseVenueDetails(
                websiteURL: incoming.venueDetails?.websiteURL ?? venueDetails?.websiteURL,
                phoneNumber: incoming.venueDetails?.phoneNumber ?? venueDetails?.phoneNumber),
            tees: incoming.hasPlayableScorecard ? incoming.tees : tees,
            createdAt: createdAt, lastUpdatedAt: lastUpdatedAt,
            locality: incoming.locality ?? locality,
            sourceReferences: Array(Set(sourceReferences + incoming.sourceReferences))
                .sorted { ($0.provider, $0.identifier) < ($1.provider, $1.identifier) }
        )
        if !hasSameDirectoryContent(as: result) { result.lastUpdatedAt = incoming.lastUpdatedAt }
        return result
    }

    func hasSameDirectoryContent(as other: Course) -> Bool {
        var lhs = self
        var rhs = other
        lhs.lastUpdatedAt = rhs.lastUpdatedAt
        lhs.createdAt = rhs.createdAt
        lhs.sourceReferences.sort { ($0.provider, $0.identifier) < ($1.provider, $1.identifier) }
        rhs.sourceReferences.sort { ($0.provider, $0.identifier) < ($1.provider, $1.identifier) }
        return lhs == rhs
    }

    /// Collapse only shared source identities or exact routing names in a known locality.
    static func deduplicated(_ courses: [Course]) -> [Course] {
        var result: [Course] = []
        for course in courses {
            if let index = result.firstIndex(where: { $0.refersToSameCourse(as: course) }) {
                let old = result[index]
                if (course.hasPlayableScorecard && !old.hasPlayableScorecard)
                    || (course.hasPlayableScorecard == old.hasPlayableScorecard && course.isUserEdited && !old.isUserEdited)
                    || (course.hasPlayableScorecard == old.hasPlayableScorecard && course.isUserEdited == old.isUserEdited
                        && course.lastUpdatedAt.unix > old.lastUpdatedAt.unix) {
                    result[index] = course
                }
            } else { result.append(course) }
        }
        return result
    }

    func refersToSameCourse(as other: Course) -> Bool {
        if id == other.id || !Set(sourceReferences).isDisjoint(with: other.sourceReferences) { return true }
        let city = (locality?.city ?? location?.city ?? "").normalizedForSearch
        let state = (locality?.state ?? location?.state ?? "").normalizedForSearch
        let otherCity = (other.locality?.city ?? other.location?.city ?? "").normalizedForSearch
        let otherState = (other.locality?.state ?? other.location?.state ?? "").normalizedForSearch
        guard !city.isEmpty, !state.isEmpty, city == otherCity, state == otherState else { return false }
        let name = CourseNameNormalizer.normalize(courseName)
        return !name.isEmpty && name == CourseNameNormalizer.normalize(other.courseName)
            && CourseNameNormalizer.normalize(clubName) == CourseNameNormalizer.normalize(other.clubName)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        golfCourseApiID = try c.decodeIfPresent(GolfCourseID.self, forKey: .golfCourseApiID)
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
        locality = try c.decodeIfPresent(CourseLocality.self, forKey: .locality)
            ?? location.map { CourseLocality(city: $0.city, state: $0.state, country: $0.country) }
        sourceReferences = try c.decodeIfPresent([CourseSourceReference].self, forKey: .sourceReferences)
            ?? golfCourseApiID.map { [CourseSourceReference(provider: "golfCourseAPI", identifier: $0.description)] } ?? []
        isUserEdited = try c.decodeIfPresent(Bool.self, forKey: .isUserEdited) ?? (origin != CourseOrigin.golfCourseAPI.rawValue)
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
        try c.encode(searchTokens, forKey: .searchTokens)
        try c.encodeIfPresent(locality, forKey: .locality)
        try c.encode(sourceReferences, forKey: .sourceReferences)
        try c.encode(isUserEdited, forKey: .isUserEdited)
    }
}

extension Course {
    /// Canonical Firestore document ID for a GolfCourseAPI-backed course.
    ///
    /// Keeping the provider ID deterministic gives cache lookups a direct document read and
    /// prevents concurrent clients from creating duplicate UUID-backed copies of the same course.
    static func golfCourseAPIDocumentID(for apiID: GolfCourseID) -> String {
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
              apiID.isValid else { return false }
        return id == Self.golfCourseAPIDocumentID(for: apiID)
    }

    func canonicalizedGolfCourseAPICacheEntry(expectedAPIID: GolfCourseID) -> Course? {
        guard expectedAPIID.isValid,
              origin == CourseOrigin.golfCourseAPI.rawValue,
              golfCourseApiID == expectedAPIID else { return nil }
        var course = self
        course.id = Self.golfCourseAPIDocumentID(for: expectedAPIID)
        course.tees = tees.map { tee in
            guard let gender = Gender(rawValue: tee.gender), gender != .unknown else { return tee }
            return Tee(
                id: Self.stableTeeID(teeName: tee.name, gender: gender),
                name: tee.name, gender: tee.gender, totalHoles: tee.totalHoles, holes: tee.holes,
                ratingFull: tee.ratingFull, slopeFull: tee.slopeFull,
                ratingFront: tee.ratingFront, slopeFront: tee.slopeFront,
                ratingBack: tee.ratingBack, slopeBack: tee.slopeBack
            )
        }
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
