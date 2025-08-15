//
//  Course.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import CoreLocation
import SwiftUI

enum CourseSource {
    case golfCourseAPI, manual, unknown
}

enum Gender: String, CaseIterable, Identifiable {
    case male = "male"
    case female = "female"
    case unknown = ""
    
    var name: String {
        switch self {
        case .male:     return "Male"
        case .female:   return "Female"
        default:        return ""
        }
    }
    
    var id: String { rawValue }
}

struct Course {
    let id: String
    let source: CourseSource
    let clubName: String
    let courseName: String
    let location: CourseLocation?
    let tees: [Tee]
    
    init(
        id: String = "",
        source: CourseSource = .unknown,
        clubName: String = "",
        courseName: String = "",
        location: CourseLocation? = nil,
        tees: [Tee] = []
    ) {
        self.id = id
        self.source = source
        self.clubName = clubName
        self.courseName = courseName
        self.location = location
        self.tees = tees
    }
    
    init(from apiModel: GolfCourseAPIModel) {
        let female = (apiModel.tees.female ?? []).compactMap { Tee(from: $0, for: .female) }
        let male = (apiModel.tees.male ?? []).compactMap { Tee(from: $0, for: .male) }
        
        self.init(
            id: String(apiModel.id),
            clubName: apiModel.clubName,
            courseName: apiModel.courseName,
            location: CourseLocation(from: apiModel.location),
            tees: female + male
        )
    }
    
    var isEmpty: Bool {
        id.isEmpty && source == .unknown && clubName.isEmpty && courseName.isEmpty && tees.isEmpty
    }
    
    var prettyClubName: String {
        clubName.prettifiedCourseTitle()
    }

    var prettyCourseName: String {
        courseName.prettifiedCourseTitle()
    }
}

struct CourseLocation {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    
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
    }
    
    init(from apiLocation: GolfCourseAPILocation) {
        self.address = apiLocation.address
        self.city = apiLocation.city
        self.state = apiLocation.state
        self.country = apiLocation.country
        self.latitude = apiLocation.latitude
        self.longitude = apiLocation.longitude
    }
    
    var trimmedAddress: String {
        AddressFormatter.trimmedUSAddress(address ?? "")
    }
    
    func formattedDistance(to location: CLLocation?) -> String? {
        DistanceFormatter.formattedDistanceMiles(from: location, to: latitude, longitude: longitude)
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
