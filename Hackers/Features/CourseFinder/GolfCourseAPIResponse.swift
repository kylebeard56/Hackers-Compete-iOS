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

// MARK: - HoleSegment



// MARK: - Lossy array decoding helper

private extension KeyedDecodingContainer {
    /// Decodes an array by skipping elements that fail to decode.
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

// MARK: - API Response

struct GolfCourseAPIResponse: Decodable {
    let courses: [GolfCourseAPIModel]
    let course: GolfCourseAPIModel?

    enum CodingKeys: String, CodingKey {
        case courses
        case course
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.courses = try container.decodeLossyArray(GolfCourseAPIModel.self, forKey: .courses)
        self.course = try? container.decode(GolfCourseAPIModel.self, forKey: .course)
    }
}

// MARK: - Models

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
    let latitude: Double
    let longitude: Double

    init(
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
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
}

// MARK: - Location helpers

extension GolfCourseAPILocation {
    func formattedDistance(to location: CLLocation?) -> String? {
        guard let location else { return nil }
        let courseLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distance = location.distance(from: courseLocation) // meters
        let miles = distance / 1609.34
        return String(format: "%.1f miles", miles)
    }

    /// Removes trailing US ZIP and country from a comma-separated address.
    /// "201 Gold Bridge Rd, Marietta, SC, 29661, USA" → "201 Gold Bridge Rd, Marietta, SC"
    /// "123 Main St, Portland, ME 04101, United States" → "123 Main St, Portland, ME"
    var trimmedAddress: String {
        guard let address else { return "" }
        var parts = address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        func normalize(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter }
        }
        func isUSZip(_ s: String) -> Bool {
            s.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
        }
        let usTokens: Set<String> = [
            "us", "usa", "unitedstates", "unitedstatesofamerica", "usminoroutlyingislands"
        ]

        var changed = true
        while changed, let last = parts.last {
            changed = false
            let norm = normalize(last)
            if usTokens.contains(norm) { parts.removeLast(); changed = true; continue }
            if isUSZip(last) { parts.removeLast(); changed = true; continue }
        }

        if var tail = parts.last {
            if let range = tail.range(of: #"\s*\d{5}(-\d{4})?$"#, options: .regularExpression) {
                tail.removeSubrange(range)
                tail = tail.trimmingCharacters(in: .whitespacesAndNewlines)
                if tail.isEmpty {
                    parts.removeLast()
                } else {
                    parts[parts.count - 1] = tail
                }
            }
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Tees collection

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

    /// De-duped tees (by name+yards+CR+slope), **not pre-sorted**.
    var combined: [GolfCourseAPITee] {
        let allTees = (female ?? []) + (male ?? [])

        var uniqueTees: [GolfCourseAPITee] = []
        var seen: Set<String> = []

        for tee in allTees {
            let key = "\(tee.teeName)-\(tee.totalYards)-\(tee.courseRating)-\(tee.slopeRating)"
            if seen.insert(key).inserted {
                uniqueTees.append(tee)
            }
        }
        return uniqueTees
    }
}

extension GolfCourseAPITees {
    /// Prefer an 18-hole tee; otherwise the one with the most holes; then longest totalYards.
    var canonicalTee: GolfCourseAPITee? {
        let all = combined
        return all.sorted {
            if $0.numberOfHoles != $1.numberOfHoles { return $0.numberOfHoles > $1.numberOfHoles }
            if $0.holes.count != $1.holes.count { return $0.holes.count > $1.holes.count }
            return $0.totalYards > $1.totalYards
        }.first
    }
}

// MARK: - Tee & Hole

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
}

struct GolfCourseAPIHole: Codable, Identifiable {
    let id: UUID = UUID()
    let par: Int
    let yardage: Int
    let handicap: Int?

    enum CodingKeys: String, CodingKey {
        case par, yardage, handicap
    }

    var handicapValue: Int { handicap ?? 0 }
}

// MARK: - Slicing and aggregates

private extension Array where Element == GolfCourseAPIHole {
    func slice(for segment: HoleSegment) -> ArraySlice<GolfCourseAPIHole> {
        guard let r = segment.indexBounds(totalHoles: count) else { return [] }
        return self[r]
    }
}

extension GolfCourseAPITee {
    func yardage(for segment: HoleSegment = .full18) -> Int {
        holes.slice(for: segment).reduce(0) { $0 + $1.yardage }
    }

    func par(for segment: HoleSegment = .full18) -> Int {
        holes.slice(for: segment).reduce(0) { $0 + $1.par }
    }

    /// Segment-aware course rating if available (front/back only).
    func courseRating(for segment: HoleSegment = .full18) -> Double? {
        switch segment {
        case .full18: return courseRating
        case .front9: return frontCourseRating
        case .back9:  return backCourseRating
        case .custom: return nil
        }
    }

    /// Segment-aware slope rating if available (front/back only).
    func slopeRating(for segment: HoleSegment = .full18) -> Int? {
        switch segment {
        case .full18: return slopeRating
        case .front9: return frontSlopeRating
        case .back9:  return backSlopeRating
        case .custom: return nil
        }
    }

    func prettyCourseRating(for segment: HoleSegment = .full18) -> String {
        if let cr = courseRating(for: segment) {
            return String(format: "%.1f", cr)
        } else {
            return String(format: "%.1f", courseRating)
        }
    }
}

// MARK: - Difficulty

private extension Double {
    func clamped01() -> Double { max(0, min(1, self)) }
}

extension GolfCourseAPITee {
    /// 0–100 normalized difficulty for this tee.
    /// Uses per-segment slope and CR−Par when available; otherwise ignores the missing parts and reweights.
    /// Tunables:
    ///  - Slope range: 55–155 → 0…1 (70%)
    ///  - (CR − Par) range: −2…+6 strokes → 0…1 (30%)
    func difficultyScore(for segment: HoleSegment = .full18) -> Int {
        let SLOPE_MIN: Double = 55
        let SLOPE_MAX: Double = 155
        let CRDIFF_MIN: Double = -2
        let CRDIFF_MAX: Double =  6
        let wSlopeDefault: Double = 0.7
        let wCRDefault: Double    = 0.3

        var parts: [(value01: Double, weight: Double)] = []

        // Slope component
        if let slope = slopeRating(for: segment).map(Double.init) {
            let slope01 = ((slope - SLOPE_MIN) / (SLOPE_MAX - SLOPE_MIN)).clamped01()
            parts.append((slope01, wSlopeDefault))
        }

        // CR − Par component (only when we have a segment-specific CR)
        if let cr = courseRating(for: segment) {
            let crDiff = cr - Double(par(for: segment))
            let cr01 = ((crDiff - CRDIFF_MIN) / (CRDIFF_MAX - CRDIFF_MIN)).clamped01()
            parts.append((cr01, wCRDefault))
        }

        // Fallback: if both missing (e.g., custom range), use full18 values as last resort.
        if parts.isEmpty {
            let slope = Double(self.slopeRating)
            let slope01 = ((slope - SLOPE_MIN) / (SLOPE_MAX - SLOPE_MIN)).clamped01()
            let crDiff = self.courseRating - Double(par(for: .full18))
            let cr01 = ((crDiff - CRDIFF_MIN) / (CRDIFF_MAX - CRDIFF_MIN)).clamped01()
            parts = [(slope01, wSlopeDefault), (cr01, wCRDefault)]
        }

        // Renormalize weights for whatever parts we have.
        let wSum = parts.reduce(0) { $0 + $1.weight }
        let score01 = parts.reduce(0) { $0 + ($1.value01 * ($1.weight / wSum)) }.clamped01()
        return Int((score01 * 100).rounded())
    }

    /// Difficulty color (static tightened stops): green ≤ 55, yellow ≤ 70, orange ≤ 85, pink otherwise.
    func difficultyColor(for segment: HoleSegment = .full18) -> Color {
        let s = Double(difficultyScore(for: segment)) / 100.0
        let stops: [(Double, Color)] = [
            (0.55, .green),
            (0.70, .yellow),
            (0.85, .orange),
            (1.00, .pink)
        ]
        for (t, c) in stops {
            if s <= t { return c }
        }
        return .pink
    }
}

// MARK: - Sorting helpers

extension Collection where Element == GolfCourseAPITee {
    /// Returns tees sorted by difficulty for the given segment.
    func sortedByDifficulty(for segment: HoleSegment) -> [GolfCourseAPITee] {
        sorted { lhs, rhs in
            lhs.difficultyScore(for: segment) < rhs.difficultyScore(for: segment)
        }
    }
}

extension Array where Element == GolfCourseAPITee {
    /// Sorts the array in-place by difficulty for the given segment.
    mutating func sortByDifficulty(for segment: HoleSegment) {
        sort { lhs, rhs in
            lhs.difficultyScore(for: segment) < rhs.difficultyScore(for: segment)
        }
    }
}

// MARK: - Course-level labels & options

extension GolfCourseAPIModel {
    /// Distinct hole counts across tees (treat 18 as also supporting 9).
    private var holeCountSetWithFrontBack: Set<Int> {
        tees.combined.reduce(into: Set<Int>()) { acc, tee in
            let count = tee.numberOfHoles > 0 ? tee.numberOfHoles : tee.holes.count
            guard count > 0 else { return }
            if count == 18 {
                acc.insert(9)
                acc.insert(18)
            } else {
                acc.insert(count)
            }
        }
    }

    /// Returns a label like "18 holes", "9 or 18 holes", "12 holes", etc.
    var numberOfHolesLabel: String {
        let counts = holeCountSetWithFrontBack.sorted()
        switch counts.count {
        case 0:
            return "Holes data unavailable"
        case 1:
            return "\(counts[0]) holes"
        case 2 where counts == [9, 18]:
            return "9 or 18 holes"
        case 2:
            return "\(counts[0]) or \(counts[1]) holes"
        default:
            let leading = counts.dropLast().map(String.init).joined(separator: ", ")
            return "\(leading), or \(counts.last!) holes"
        }
    }

    /// Detect whether per-hole par is consistent across tees; returns conflicting hole numbers (1-based).
    private var parConflictsByHole: Set<Int> {
        let all = tees.combined
        guard !all.isEmpty else { return [] }
        let maxHoles = all.map { max($0.numberOfHoles, $0.holes.count) }.max() ?? 0

        var conflicts = Set<Int>()
        for idx in 0..<maxHoles {
            var pars = Set<Int>()
            for tee in all {
                guard tee.holes.indices.contains(idx) else { continue }
                pars.insert(tee.holes[idx].par)
            }
            if pars.count > 1 { conflicts.insert(idx + 1) }
        }
        return conflicts
    }

    /// Distinct total par values across tees (defaults to full18).
    private func parTotalsSet(for segment: HoleSegment = .full18) -> Set<Int> {
        Set(tees.combined.map { $0.par(for: segment) })
    }

    /// Returns a label like "Par 72" or "Par varies by tee (70–72)" for the given segment (default full18).
    func parLabel(for segment: HoleSegment = .full18) -> String {
        let conflicts = parConflictsByHole
        let totals = Array(parTotalsSet(for: segment)).sorted()

        if conflicts.isEmpty, let tee = tees.canonicalTee {
            return "Par \(tee.par(for: segment))"
        } else if !totals.isEmpty {
            let minPar = totals.first!, maxPar = totals.last!
            return minPar == maxPar ? "Par \(minPar)" : "Par varies by tee (\(minPar)–\(maxPar))"
        } else {
            return "Par unavailable"
        }
    }

    /// True if *any* tee is 18 holes.
    private var hasEighteen: Bool {
        tees.combined.contains { tee in
            let n = tee.numberOfHoles > 0 ? tee.numberOfHoles : tee.holes.count
            return n == 18
        }
    }

    /// Collect actual counts (ignores 0/invalid).
    private var rawHoleCounts: Set<Int> {
        var s = Set<Int>()
        for t in tees.combined {
            let n = t.numberOfHoles > 0 ? t.numberOfHoles : t.holes.count
            if n > 0 { s.insert(n) }
        }
        return s
    }

    /// Options to show in the UI.
    /// - If any tee is 18 ⇒ [.full18, .front9, .back9]
    /// - Else show the unique count(s) as custom ranges like [.custom(1...12)]
    var holeSegments: [HoleSegment] {
        if hasEighteen {
            return [.full18, .front9, .back9]
        }
        let counts = rawHoleCounts.sorted()
        if counts.isEmpty { return [.custom(lower: 1, upper: 0)] } // fallback (empty)
        return counts.map { .custom(lower: 1, upper: $0) }
    }

    /// Reasonable default selection for the picker / label.
    var defaultHoleSegment: HoleSegment {
        if hasEighteen { return .full18 }
        if let c = rawHoleCounts.sorted().last { return .custom(lower: 1, upper: c) }
        return .custom(lower: 1, upper: 0)
    }
}
