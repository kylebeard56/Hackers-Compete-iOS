//
//  Tee.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import SwiftUI

struct Tee: Hashable, Codable {
    let id: String
    let name: String
    let gender: String
    let totalHoles: Int
    let holes: [Hole]
    let ratingFull: Double
    let slopeFull: Int
    let ratingFront: Double?
    let slopeFront: Int?
    let ratingBack: Double?
    let slopeBack: Int?
    
    init(
        id: String = HackersID.string(),
        name: String,
        gender: String,
        totalHoles: Int,
        holes: [Hole],
        ratingFull: Double,
        slopeFull: Int,
        ratingFront: Double?,
        slopeFront: Int?,
        ratingBack: Double?,
        slopeBack: Int?
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.totalHoles = totalHoles
        self.holes = holes
        self.ratingFull = ratingFull
        self.slopeFull = slopeFull
        self.ratingFront = ratingFront
        self.slopeFront = slopeFront
        self.ratingBack = ratingBack
        self.slopeBack = slopeBack
    }
    
    init(from tee: GolfCourseAPITee, for gender: Gender, with id: String = HackersID.string()) {
        self.id = id
        self.name = tee.teeName
        self.gender = gender.rawValue
        self.ratingFull = tee.courseRating
        self.slopeFull = tee.slopeRating
        self.ratingFront = tee.frontCourseRating
        self.slopeFront = tee.frontSlopeRating
        self.ratingBack = tee.backCourseRating
        self.slopeBack = tee.backSlopeRating
        self.holes = tee.holes.enumerated().map { index, value in
            Hole(from: value, number: index + 1)
        }
        self.totalHoles = holes.count
    }
}

extension Array where Element == Tee {
    var male: [Tee] {
        filter { $0.gender == Gender.male.rawValue }
    }
    
    var female: [Tee] {
        filter { $0.gender == Gender.female.rawValue }
    }
    
    func sortedByDifficulty(for segment: HoleSegment) -> [Tee] {
        sorted { $0.difficultyScore(for: segment) < $1.difficultyScore(for: segment) }
    }
}

extension Tee {
    func par(for segment: HoleSegment) -> Int {
        holes.slice(for: segment).reduce(0) { $0 + $1.par }
    }
    
    func yardage(for segment: HoleSegment) -> Int {
        holes.slice(for: segment).reduce(0) { $0 + $1.yardage }
    }

    func rating(for segment: HoleSegment) -> Double? {
        switch segment {
        case .full18: return ratingFull
        case .front9: return ratingFront
        case .back9:  return ratingBack
        case .custom: return nil
        }
    }
    
    func prettyRating(for segment: HoleSegment) -> String? {
        guard let rating = rating(for: segment) else { return nil }
        return String(format: "%.1f", rating)
    }
    
    func slope(for segment: HoleSegment) -> Int? {
        switch segment {
        case .full18: return slopeFull
        case .front9: return slopeFront
        case .back9:  return slopeBack
        case .custom: return nil
        }
    }
    
    func difficultyScore(for segment: HoleSegment) -> Int {
        let tee = self
        let SLOPE_MIN: Double = 55
        let SLOPE_MAX: Double = 155
        let CRDIFF_MIN: Double = -2
        let CRDIFF_MAX: Double = 6
        let wSlope: Double = 0.7
        let wCR: Double = 0.3

        var parts: [(Double, Double)] = []

        if let slope = tee.slope(for: segment).map(Double.init) {
            let slope01 = ((slope - SLOPE_MIN) / (SLOPE_MAX - SLOPE_MIN)).clamped01()
            parts.append((slope01, wSlope))
        }
        if let cr = tee.rating(for: segment) {
            let crDiff = cr - Double(tee.par(for: segment))
            let cr01 = ((crDiff - CRDIFF_MIN) / (CRDIFF_MAX - CRDIFF_MIN)).clamped01()
            parts.append((cr01, wCR))
        }

        if parts.isEmpty {
            // fallback: use full18 against full18 par
            let slope = Double(tee.slopeFull)
            let slope01 = ((slope - SLOPE_MIN) / (SLOPE_MAX - SLOPE_MIN)).clamped01()
            let crDiff = tee.ratingFull - Double(tee.par(for: .full18))
            let cr01 = ((crDiff - CRDIFF_MIN) / (CRDIFF_MAX - CRDIFF_MIN)).clamped01()
            parts = [(slope01, wSlope), (cr01, wCR)]
        }

        let wSum = parts.reduce(0) { $0 + $1.1 }
        let score01 = parts.reduce(0) { $0 + ($1.0 * ($1.1 / wSum)) }.clamped01()
        return Int((score01 * 100).rounded())
    }
    
    func difficultyColor(
        for segment: HoleSegment,
        palette: DifficultyPalette = .tightened
    ) -> Color {
        let s01 = Double(self.difficultyScore(for: segment)) / 100.0
        return palette.color(for: s01)
    }
}

struct DifficultyPalette {
    let stops: [(Double, Color)]
    
    static let tightened = DifficultyPalette(
        stops: [
            (0.55, .green),
            (0.70, .yellow),
            (0.85, .orange),
            (1.00, .pink)
        ]
    )

    func color(for score01: Double) -> Color {
        for (t, c) in stops { if score01 <= t { return c } }
        return stops.last?.1 ?? .pink
    }
}
