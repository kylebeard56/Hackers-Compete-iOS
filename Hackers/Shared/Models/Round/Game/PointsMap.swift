//
//  PointsMap.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Points Map

/// Transforms strokes into points. Supports par-relative (stableford), par-dependent,
/// fixed (match play), and custom mappings.
struct PointsMap: Codable, Hashable {
    var mode: PointsMapMode
    /// For parRelative: maps score-to-par offset to points. e.g. [(-2, 4), (-1, 3), (0, 2), (1, 1), (2, 0)]
    var entries: [PointsMapEntry]?
    /// For parDependent: points = par * multiplier. e.g. 1.0 means par 3 = 3 pts, par 4 = 4 pts.
    var parMultiplier: Double?

    init(
        mode: PointsMapMode = .parRelative,
        entries: [PointsMapEntry]? = nil,
        parMultiplier: Double? = nil
    ) {
        self.mode = mode
        self.entries = entries
        self.parMultiplier = parMultiplier
    }

    enum CodingKeys: String, CodingKey {
        case mode, entries
        case parMultiplier = "par_multiplier"
    }
}

enum PointsMapMode: String, Codable {
    /// Stableford-style: points based on score relative to par.
    case parRelative = "par_relative"
    /// Points equal a function of the hole's par value.
    case parDependent = "par_dependent"
    /// Every hole awards the same fixed points (e.g. match play: 1 point per hole).
    case fixed
    /// Fully custom per-hole point values.
    case custom
}

struct PointsMapEntry: Codable, Hashable {
    /// Score relative to par. e.g. -2 = eagle, -1 = birdie, 0 = par, 1 = bogey.
    var scoreToPar: Int
    var points: Double

    init(scoreToPar: Int, points: Double) {
        self.scoreToPar = scoreToPar
        self.points = points
    }

    enum CodingKeys: String, CodingKey {
        case scoreToPar = "score_to_par"
        case points
    }
}

// MARK: - Round Stableford Points

struct RoundStablefordPoints: Codable, Hashable {
    static let minimumPointValue = -21
    static let maximumPointValue = 21
    static let classic = RoundStablefordPoints()

    var albatrossOrBetter: Int
    var eagle: Int
    var birdie: Int
    var par: Int
    var bogey: Int
    var doubleBogey: Int
    var tripleBogeyOrWorse: Int
    var quadrupleBogeyOrWorse: Int

    init(
        albatrossOrBetter: Int = 5,
        eagle: Int = 4,
        birdie: Int = 3,
        par: Int = 2,
        bogey: Int = 1,
        doubleBogey: Int = 0,
        tripleBogeyOrWorse: Int = 0,
        quadrupleBogeyOrWorse: Int = 0
    ) {
        self.albatrossOrBetter = albatrossOrBetter
        self.eagle = eagle
        self.birdie = birdie
        self.par = par
        self.bogey = bogey
        self.doubleBogey = doubleBogey
        self.tripleBogeyOrWorse = tripleBogeyOrWorse
        self.quadrupleBogeyOrWorse = quadrupleBogeyOrWorse
    }

    enum CodingKeys: String, CodingKey {
        case albatrossOrBetter = "albatross_or_better"
        case eagle
        case birdie
        case par
        case bogey
        case doubleBogey = "double_bogey"
        case tripleBogeyOrWorse = "triple_bogey_or_worse"
        case quadrupleBogeyOrWorse = "quadruple_bogey_or_worse"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let classic = Self.classic
        albatrossOrBetter = try c.decodeIfPresent(Int.self, forKey: .albatrossOrBetter) ?? classic.albatrossOrBetter
        eagle = try c.decodeIfPresent(Int.self, forKey: .eagle) ?? classic.eagle
        birdie = try c.decodeIfPresent(Int.self, forKey: .birdie) ?? classic.birdie
        par = try c.decodeIfPresent(Int.self, forKey: .par) ?? classic.par
        bogey = try c.decodeIfPresent(Int.self, forKey: .bogey) ?? classic.bogey
        doubleBogey = try c.decodeIfPresent(Int.self, forKey: .doubleBogey) ?? classic.doubleBogey
        tripleBogeyOrWorse = try c.decodeIfPresent(Int.self, forKey: .tripleBogeyOrWorse) ?? classic.tripleBogeyOrWorse
        quadrupleBogeyOrWorse = try c.decodeIfPresent(Int.self, forKey: .quadrupleBogeyOrWorse) ?? classic.quadrupleBogeyOrWorse
    }

    var isClassic: Bool { self == Self.classic }

    var clamped: RoundStablefordPoints {
        RoundStablefordPoints(
            albatrossOrBetter: Self.clamped(albatrossOrBetter),
            eagle: Self.clamped(eagle),
            birdie: Self.clamped(birdie),
            par: Self.clamped(par),
            bogey: Self.clamped(bogey),
            doubleBogey: Self.clamped(doubleBogey),
            tripleBogeyOrWorse: Self.clamped(tripleBogeyOrWorse),
            quadrupleBogeyOrWorse: Self.clamped(quadrupleBogeyOrWorse)
        )
    }

    var pointsMap: PointsMap {
        PointsMap(
            mode: .parRelative,
            entries: [
                .init(scoreToPar: -3, points: Double(albatrossOrBetter)),
                .init(scoreToPar: -2, points: Double(eagle)),
                .init(scoreToPar: -1, points: Double(birdie)),
                .init(scoreToPar:  0, points: Double(par)),
                .init(scoreToPar:  1, points: Double(bogey)),
                .init(scoreToPar:  2, points: Double(doubleBogey)),
                .init(scoreToPar:  3, points: Double(tripleBogeyOrWorse)),
                .init(scoreToPar:  4, points: Double(quadrupleBogeyOrWorse)),
            ]
        )
    }

    private static func clamped(_ value: Int) -> Int {
        min(maximumPointValue, max(minimumPointValue, value))
    }
}

enum RoundStablefordPointsPreset: String, CaseIterable, Hashable, Identifiable {
    case classic
    case modified
    case fibonacci

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: return "Classic"
        case .modified: return "Modified"
        case .fibonacci: return "Fibonacci"
        }
    }

    var points: RoundStablefordPoints {
        switch self {
        case .classic:
            return .classic
        case .modified:
            return RoundStablefordPoints(
                albatrossOrBetter: 8,
                eagle: 5,
                birdie: 2,
                par: 0,
                bogey: -1,
                doubleBogey: -3,
                tripleBogeyOrWorse: -3,
                quadrupleBogeyOrWorse: -3
            )
        case .fibonacci:
            return RoundStablefordPoints(
                albatrossOrBetter: 21,
                eagle: 13,
                birdie: 8,
                par: 5,
                bogey: 3,
                doubleBogey: 2,
                tripleBogeyOrWorse: 1,
                quadrupleBogeyOrWorse: 0
            )
        }
    }

    static func matching(_ points: RoundStablefordPoints) -> RoundStablefordPointsPreset? {
        let clamped = points.clamped
        return allCases.first { $0.points == clamped }
    }
}

// MARK: - Standard Points Maps

extension PointsMap {
    /// Modified Stableford (standard): double bogey+ = 0, bogey = 1, par = 2, birdie = 3, eagle = 4, albatross+ = 5
    static var stableford: PointsMap {
        PointsMap(
            mode: .parRelative,
            entries: [
                .init(scoreToPar: -3, points: 5),
                .init(scoreToPar: -2, points: 4),
                .init(scoreToPar: -1, points: 3),
                .init(scoreToPar:  0, points: 2),
                .init(scoreToPar:  1, points: 1),
                .init(scoreToPar:  2, points: 0),
                .init(scoreToPar:  3, points: 0),
                .init(scoreToPar:  4, points: 0),
            ]
        )
    }

    /// Fixed 1 point per hole (match play style).
    static var matchPlayFixed: PointsMap {
        PointsMap(mode: .fixed)
    }
}
