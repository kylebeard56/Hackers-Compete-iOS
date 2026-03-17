//
//  CourseEditViewModel.swift
//  Hackers
//
//  Created for Course OCR and Custom Course plan.
//

import CoreLocation
import SwiftUI

/// Hole-centric: each hole has par/handicap shared, and tees with yardage per tee.
struct EditableHoleWithTees: Identifiable {
    var id: String { "\(number)" }
    var number: Int
    var par: Int
    var handicap: Int?
    var tees: [EditableTeeData]
}

/// Per-hole tee data: yardage (required), optional overrides for par/handicap.
struct EditableTeeData: Identifiable {
    var id: String { teeId }
    var teeId: String
    var name: String
    var yardage: Int
    var parOverride: Int?
    var hcpOverride: Int?
}

/// Legacy tee-centric struct for backward compatibility during migration.
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

struct TeeMetadata {
    var gender: String
    var ratingFull: Double
    var slopeFull: Int
    var ratingFront: Double?
    var slopeFront: Int?
    var ratingBack: Double?
    var slopeBack: Int?
}

@MainActor
final class CourseEditViewModel: ObservableObject {
    private let originalCourse: Course
    private var teeMetadata: [String: TeeMetadata] = [:]
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
    /// Hole-centric: each hole has par, handicap, and tees with yardage.
    @Published var holes: [EditableHoleWithTees]

    init(course: Course) {
        self.originalCourse = course
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
        self.holes = Self.teeCentricToHoleCentric(course.tees)
        for tee in course.tees {
            teeMetadata[tee.id] = TeeMetadata(
                gender: tee.gender,
                ratingFull: tee.ratingFull,
                slopeFull: tee.slopeFull,
                ratingFront: tee.ratingFront,
                slopeFront: tee.slopeFront,
                ratingBack: tee.ratingBack,
                slopeBack: tee.slopeBack
            )
        }
    }

    /// Convert tee-centric Course.tees to hole-centric holes.
    private static func teeCentricToHoleCentric(_ tees: [Tee]) -> [EditableHoleWithTees] {
        guard let firstTee = tees.first, !firstTee.holes.isEmpty else {
            let defaultTeeId = HackersID.string()
            return (1...18).map { num in
                EditableHoleWithTees(
                    number: num,
                    par: 4,
                    handicap: nil,
                    tees: [EditableTeeData(teeId: defaultTeeId, name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]
                )
            }
        }
        let holeNumbers = firstTee.holes.map(\.number).sorted()
        return holeNumbers.map { holeNum in
            let firstHole = firstTee.holes.first(where: { $0.number == holeNum })
            let par = firstHole?.par ?? 4
            let handicap = firstHole?.handicap
            let teesData = tees.map { tee in
                let h = tee.holes.first(where: { $0.number == holeNum })
                return EditableTeeData(
                    teeId: tee.id,
                    name: tee.name,
                    yardage: h?.yardage ?? 0,
                    parOverride: nil,
                    hcpOverride: nil
                )
            }
            return EditableHoleWithTees(number: holeNum, par: par, handicap: handicap, tees: teesData)
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

        let builtTees = holeCentricToTeeCentric()
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

    /// Convert hole-centric to tee-centric Tee array.
    private func holeCentricToTeeCentric() -> [Tee] {
        guard !holes.isEmpty, let firstHole = holes.first, !firstHole.tees.isEmpty else {
            return [Tee(
                id: HackersID.string(),
                name: "Default",
                gender: Gender.male.rawValue,
                totalHoles: 18,
                holes: (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: nil) },
                ratingFull: 72.0,
                slopeFull: 113,
                ratingFront: nil,
                slopeFront: nil,
                ratingBack: nil,
                slopeBack: nil
            )]
        }
        return firstHole.tees.map { teeData in
            let teeHoles = holes.map { hole in
                let teeDataForHole = hole.tees.first(where: { $0.teeId == teeData.teeId }) ?? teeData
                let par = teeDataForHole.parOverride ?? hole.par
                let hcp = teeDataForHole.hcpOverride ?? hole.handicap
                return Hole(
                    number: hole.number,
                    par: par,
                    yardage: teeDataForHole.yardage,
                    handicap: hcp
                )
            }
            let meta = teeMetadata[teeData.teeId]
            return Tee(
                id: teeData.teeId,
                name: teeData.name,
                gender: meta?.gender ?? Gender.male.rawValue,
                totalHoles: teeHoles.count,
                holes: teeHoles,
                ratingFull: meta?.ratingFull ?? 72.0,
                slopeFull: meta?.slopeFull ?? 113,
                ratingFront: meta?.ratingFront,
                slopeFront: meta?.slopeFront,
                ratingBack: meta?.ratingBack,
                slopeBack: meta?.slopeBack
            )
        }
    }

    /// Returns true if the built course differs from the original (excluding createdAt/lastUpdatedAt).
    func wasEdited() -> Bool {
        let built = buildCourse()
        return !coursesEqualIgnoringTimestamps(built, originalCourse)
    }

    private func coursesEqualIgnoringTimestamps(_ a: Course, _ b: Course) -> Bool {
        a.id == b.id
            && a.golfCourseApiID == b.golfCourseApiID
            && a.origin == b.origin
            && a.clubName == b.clubName
            && a.courseName == b.courseName
            && teesEqual(a.tees, b.tees)
            && locationsEqual(a.location, b.location)
    }

    private func teesEqual(_ a: [Tee], _ b: [Tee]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { teeA, teeB in
            teeA.id == teeB.id
                && teeA.name == teeB.name
                && teeA.gender == teeB.gender
                && teeA.holes.count == teeB.holes.count
                && zip(teeA.holes, teeB.holes).allSatisfy { hA, hB in
                    hA.number == hB.number && hA.par == hB.par && hA.yardage == hB.yardage && hA.handicap == hB.handicap
                }
        }
    }

    private func locationsEqual(_ a: CourseLocation?, _ b: CourseLocation?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?):
            return a.address == b.address && a.city == b.city && a.state == b.state && a.country == b.country
                && abs(a.latitude - b.latitude) < 0.0001 && abs(a.longitude - b.longitude) < 0.0001
        default: return false
        }
    }

    var holeCount: Int { holes.count }

    func setHoleCount(_ count: Int) {
        let clamped = min(18, max(9, count))
        if clamped < holes.count {
            holes = Array(holes.prefix(clamped))
            for i in holes.indices { holes[i].number = i + 1 }
        } else if clamped > holes.count {
            let template = holes.first?.tees.map { EditableTeeData(teeId: $0.teeId, name: $0.name, yardage: 350, parOverride: nil, hcpOverride: nil) } ?? [EditableTeeData(teeId: HackersID.string(), name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]
            for num in (holes.count + 1)...clamped {
                holes.append(EditableHoleWithTees(number: num, par: 4, handicap: nil, tees: template))
            }
        }
    }

    func addHole() {
        let nextNum = (holes.map(\.number).max() ?? 0) + 1
        let defaultTees: [EditableTeeData] = holes.first.map { h in
            h.tees.isEmpty ? [EditableTeeData(teeId: HackersID.string(), name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)] : h.tees.map { EditableTeeData(teeId: $0.teeId, name: $0.name, yardage: 350, parOverride: nil, hcpOverride: nil) }
        } ?? [EditableTeeData(teeId: HackersID.string(), name: "Default", yardage: 350, parOverride: nil, hcpOverride: nil)]
        holes.append(EditableHoleWithTees(number: nextNum, par: 4, handicap: nil, tees: defaultTees))
    }

    func removeHole(at index: Int) {
        guard index >= 0, index < holes.count, holes.count > 9 else { return }
        holes.remove(at: index)
        for i in holes.indices {
            holes[i].number = i + 1
        }
    }

    func addTee(to holeIndex: Int) {
        guard holeIndex >= 0, holeIndex < holes.count else { return }
        let newId = HackersID.string()
        teeMetadata[newId] = TeeMetadata(gender: Gender.male.rawValue, ratingFull: 72.0, slopeFull: 113, ratingFront: nil, slopeFront: nil, ratingBack: nil, slopeBack: nil)
        holes[holeIndex].tees.append(EditableTeeData(teeId: newId, name: "New Tee", yardage: 350, parOverride: nil, hcpOverride: nil))
        for i in holes.indices where i != holeIndex {
            holes[i].tees.append(EditableTeeData(teeId: newId, name: "New Tee", yardage: 350, parOverride: nil, hcpOverride: nil))
        }
    }

    func removeTee(holeIndex: Int, teeIndex: Int) {
        guard holeIndex >= 0, holeIndex < holes.count, holes[holeIndex].tees.count > 1 else { return }
        let teeId = holes[holeIndex].tees[teeIndex].teeId
        holes[holeIndex].tees.remove(at: teeIndex)
        for i in holes.indices where i != holeIndex {
            if let idx = holes[i].tees.firstIndex(where: { $0.teeId == teeId }) {
                holes[i].tees.remove(at: idx)
            }
        }
    }

    func setTeeName(teeId: String, name: String) {
        for i in holes.indices {
            if let idx = holes[i].tees.firstIndex(where: { $0.teeId == teeId }) {
                holes[i].tees[idx].name = name
            }
        }
    }

    /// Default tee for display (first tee's yardage per hole).
    var defaultTeeYardage: (Int) -> Int {
        { holeNum in
            self.holes.first(where: { $0.number == holeNum })?.tees.first?.yardage ?? 0
        }
    }
}
