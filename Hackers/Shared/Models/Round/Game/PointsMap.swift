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
            ]
        )
    }

    /// Fixed 1 point per hole (match play style).
    static var matchPlayFixed: PointsMap {
        PointsMap(mode: .fixed)
    }
}
