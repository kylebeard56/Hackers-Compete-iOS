//
//  GolfCourseAPIResponse.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import CoreLocation
import Foundation
import SwiftUI

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

extension GolfCourseAPILocation {
    func formattedDistance(to location: CLLocation?) -> String? {
        guard let location else { return nil }
        let courseLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distance = location.distance(from: courseLocation) // meters
        let distanceInMiles = distance / 1609.34
        return String(format: "%.1f miles", distanceInMiles)
    }
    
    /// Removes trailing US ZIP and country from a comma-separated address.
    /// Examples:
    /// "201 Gold Bridge Rd, Marietta, SC, 29661, USA" -> "201 Gold Bridge Rd, Marietta, SC"
    /// "123 Main St, Portland, ME 04101, United States" -> "123 Main St, Portland, ME"
    var trimmedAddress: String {
        guard let address else { return "" }
        
        // 1) Split into comma-separated parts and trim whitespace
            var parts = address
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Helpers
            func normalize(_ s: String) -> String {
                s.lowercased().filter { $0.isLetter } // drop spaces, dots, punctuation
            }
            func isUSZip(_ s: String) -> Bool {
                s.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
            }
            // Accept common US country tokens
            let usTokens: Set<String> = [
                "us", "usa", "unitedstates", "unitedstatesofamerica",
                "usminoroutlyingislands" // occasionally appears
            ]
            
            // 2) Pop trailing country/zip components regardless of order
            var changed = true
            while changed, let last = parts.last {
                changed = false
                let norm = normalize(last)
                if usTokens.contains(norm) {
                    parts.removeLast(); changed = true; continue
                }
                if isUSZip(last) {
                    parts.removeLast(); changed = true; continue
                }
            }
            
            // 3) If the remaining last part ends with a ZIP glued to state (e.g., "SC 29661"), strip it
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
            let key = "\(tee.teeName)-\(tee.totalYards)-\(tee.courseRating)-\(tee.slopeRating)"
            if !seenCombinations.contains(key) {
                seenCombinations.insert(key)
                uniqueTees.append(tee)
            }
        }
        
        return uniqueTees.sorted(by: { $0.difficultyScore() < $1.difficultyScore() })
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
    
    func courseRating(for segment: HoleSegment = .full18) -> Double {
        if let cr = frontCourseRating, segment == .front9 {
            return cr
        } else if let cr = backCourseRating, segment == .back9 {
            return cr
        } else {
            return courseRating
        }
    }
    
    func prettyCourseRating(for segment: HoleSegment = .full18) -> String {
        String(format: "%.1f", courseRating(for: segment))
    }
    
    func slopeRating(for segment: HoleSegment = .full18) -> Int {
        if let sr = frontSlopeRating, segment == .front9 {
            return sr
        } else if let sr = backSlopeRating, segment == .back9 {
            return sr
        } else {
            return slopeRating
        }
    }
    
    func yardage(for segment: HoleSegment = .full18) -> Int {
        switch segment {
        case .full18:
            return holes[0..<min(18, holes.count)].reduce(0) { $0 + $1.yardage }
            
        case .front9:
            return holes[0..<min(9, holes.count)].reduce(0) { $0 + $1.yardage }
            
        case .back9:
            guard holes.count >= 10 else { return 0 }
            return holes[9..<min(18, holes.count)].reduce(0) { $0 + $1.yardage }
            
        case .custom(let count):
            return holes[0..<count].reduce(0) { $0 + $1.yardage }
        }
    }
    
    func par(for segment: HoleSegment = .full18) -> Int {
        switch segment {
        case .full18:
            return holes[0..<min(18, holes.count)].reduce(0) { $0 + $1.par }
            
        case .front9:
            return holes[0..<min(9, holes.count)].reduce(0) { $0 + $1.par }
            
        case .back9:
            guard holes.count >= 10 else { return 0 }
            return holes[9..<min(18, holes.count)].reduce(0) { $0 + $1.par }
            
        case .custom(let count):
            return holes[0..<count].reduce(0) { $0 + $1.par }
        }
    }
}

extension Collection where Element == GolfCourseAPITee {
    func sortedByDifficulty(for segment: HoleSegment) -> [GolfCourseAPITee] {
        sorted { lhs, rhs in
            lhs.difficultyScore(for: segment) < rhs.difficultyScore(for: segment)
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

extension GolfCourseAPITee {
    /// 0–100 normalized difficulty for this tee.
    /// Uses: slope (55–155) and (courseRating − par) mapped from −2…+6 strokes.
    /// Weights: 70% slope, 30% CR−Par. Rounded to Int.
    func difficultyScore(for segment: HoleSegment = .full18) -> Int {
        // Tunables
        let SLOPE_MIN: Double = 55
        let SLOPE_MAX: Double = 155
        let CRDIFF_MIN: Double = -2
        let CRDIFF_MAX: Double =  6
        let wSlope: Double = 0.7
        let wCR: Double    = 0.3

        // Normalize slope → 0…1
        let slope = Double(slopeRating(for: segment))
        let slope01 = ((slope - SLOPE_MIN) / (SLOPE_MAX - SLOPE_MIN)).clamped01()

        // Normalize (CR − Par) → 0…1
        let crDiff = courseRating(for: segment) - Double(par(for: segment))      // works for 9 or 18 if CR/Par match the hole count
        let crDiff01 = ((crDiff - CRDIFF_MIN) / (CRDIFF_MAX - CRDIFF_MIN)).clamped01()

        // Combine and scale
        let combined01 = (wSlope * slope01 + wCR * crDiff01).clamped01()
        return Int((combined01 * 100).rounded())
    }
    
    /// Difficulty color from 0 (green) → yellow → orange → pink (100)
    func difficultyColor(for segment: HoleSegment = .full18) -> Color {
        let score = Double(difficultyScore(for: segment)) / 100.0 // normalize 0–1

        // Define stops (fraction, Color)
        let stops: [(Double, Color)] = [
            (0.4, .green),        // Easy
            (0.6, .yellow),       // Moderate
            (0.8, .orange),       // Challenging
            (1.0, .pink)          // Very Hard
        ]

        // Find the two stops we’re between
        guard let upper = stops.first(where: { score <= $0.0 }) else {
            return stops.last!.1
        }
        guard let lower = stops.last(where: { score >= $0.0 && $0.0 < upper.0 }) else {
            return stops.first!.1
        }

        // Interpolation factor between the two stops
        let range = upper.0 - lower.0
        let t = range > 0 ? (score - lower.0) / range : 0

        // Blend the colors in HSB space for smoothness
        return lower.1.interpolate(to: upper.1, fraction: t)
    }
}

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
    
    /// Distinct total par values across tees.
    private var parTotalsSet: Set<Int> {
        Set(tees.combined.map { $0.par() })
    }
    
    /// Returns a label like "Par 72" or "Par varies by tee (70–72)".
    var parLabel: String {
        let conflicts = parConflictsByHole
        let totals = Array(parTotalsSet).sorted()
        
        if conflicts.isEmpty, let tee = tees.canonicalTee {
            return "Par \(tee.par())"
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
    /// - If any tee is 18 ⇒ ["Front 9", "Back 9", "Full 18"]
    /// - Else show the unique count(s) (usually one), e.g. ["12 holes"]
    var holeSegments: [HoleSegment] {
        if hasEighteen {
            return [.full18, .front9, .back9]
        }
        // No 18-hole tees — show the actual distinct counts
        let counts = rawHoleCounts.sorted()
        if counts.isEmpty { return [.custom(count: 0)] } // fallback
        return counts.map { .custom(count: $0) }
    }

    /// Reasonable default selection for the picker / label.
    var defaultHoleSegment: HoleSegment {
        if hasEighteen { return .full18 }
        if let c = rawHoleCounts.sorted().last { return .custom(count: c) }
        return .custom(count: 0)
    }
}
