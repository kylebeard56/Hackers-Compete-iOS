//
//  CourseEditViewModel.swift
//  Hackers
//
//  Created for Course OCR and Custom Course plan.
//

import CoreLocation
import SwiftUI

/// Mutable representation for editing course data. Maps to/from Course.
struct EditableHole: Identifiable {
    var id: String { "\(number)" }
    var number: Int
    var par: Int
    var yardage: Int
    var handicap: Int?
}

struct EditableTee: Identifiable {
    var id: String
    var name: String
    var gender: String
    var holes: [EditableHole]
    var ratingFull: Double
    var slopeFull: Int
    var ratingFront: Double?
    var slopeFront: Int?
    var ratingBack: Double?
    var slopeBack: Int?

    var totalHoles: Int { holes.count }
    var par: Int { holes.reduce(0) { $0 + $1.par } }
    var yardage: Int { holes.reduce(0) { $0 + $1.yardage } }
}

@MainActor
final class CourseEditViewModel: ObservableObject {
    let originalOrigin: String
    @Published var courseId: String
    @Published var golfCourseApiID: Int?
    @Published var clubName: String
    @Published var courseName: String
    @Published var address: String
    @Published var city: String
    @Published var state: String
    @Published var country: String
    @Published var latitude: Double
    @Published var longitude: Double
    @Published var tees: [EditableTee]

    init(course: Course) {
        self.originalOrigin = course.origin
        self.courseId = course.id
        self.golfCourseApiID = course.golfCourseApiID
        self.clubName = course.clubName
        self.courseName = course.courseName
        self.address = course.location?.address ?? ""
        self.city = course.location?.city ?? ""
        self.state = course.location?.state ?? ""
        self.country = course.location?.country ?? ""
        self.latitude = course.location?.latitude ?? 0
        self.longitude = course.location?.longitude ?? 0
        self.tees = course.tees.map { tee in
            EditableTee(
                id: tee.id,
                name: tee.name,
                gender: tee.gender,
                holes: tee.holes.map { EditableHole(number: $0.number, par: $0.par, yardage: $0.yardage, handicap: $0.handicap) },
                ratingFull: tee.ratingFull,
                slopeFull: tee.slopeFull,
                ratingFront: tee.ratingFront,
                slopeFront: tee.slopeFront,
                ratingBack: tee.ratingBack,
                slopeBack: tee.slopeBack
            )
        }
    }

    func buildCourse() -> Course {
        let hasLocation = latitude != 0 || longitude != 0 || !address.isEmpty || !city.isEmpty || !state.isEmpty
        let loc: CourseLocation? = hasLocation
            ? CourseLocation(
                address: address.isEmpty ? nil : address,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                country: country.isEmpty ? nil : country,
                latitude: latitude,
                longitude: longitude
            )
            : nil

        let builtTees = tees.map { tee in
            Tee(
                id: tee.id,
                name: tee.name,
                gender: tee.gender,
                totalHoles: tee.totalHoles,
                holes: tee.holes.map { Hole(number: $0.number, par: $0.par, yardage: $0.yardage, handicap: $0.handicap) },
                ratingFull: tee.ratingFull,
                slopeFull: tee.slopeFull,
                ratingFront: tee.ratingFront,
                slopeFront: tee.slopeFront,
                ratingBack: tee.ratingBack,
                slopeBack: tee.slopeBack
            )
        }

        return Course(
            id: courseId,
            golfCourseApiID: golfCourseApiID,
            origin: .hackers,
            clubName: clubName.isEmpty ? courseName : clubName,
            courseName: courseName.isEmpty ? clubName : courseName,
            location: loc,
            locationGeohash: loc?.geohash,
            tees: builtTees,
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
    }

    func addTee() {
        let defaultHoles = (1...18).map { EditableHole(number: $0, par: 4, yardage: 350, handicap: nil) }
        tees.append(EditableTee(
            id: HackersID.string(),
            name: "New Tee",
            gender: Gender.male.rawValue,
            holes: defaultHoles,
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        ))
    }

    func addHole(to teeIndex: Int) {
        guard teeIndex >= 0, teeIndex < tees.count else { return }
        let nextNum = (tees[teeIndex].holes.map(\.number).max() ?? 0) + 1
        tees[teeIndex].holes.append(EditableHole(number: nextNum, par: 4, yardage: 350, handicap: nil))
    }

    func addHoleToAllTees() {
        let maxHole = tees.flatMap(\.holes).map(\.number).max() ?? 0
        let nextNum = maxHole + 1
        for i in tees.indices {
            tees[i].holes.append(EditableHole(number: nextNum, par: 4, yardage: 350, handicap: nil))
        }
    }
}
