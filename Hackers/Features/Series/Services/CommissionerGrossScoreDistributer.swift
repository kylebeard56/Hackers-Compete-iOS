//
//  CommissionerGrossScoreDistributer.swift
//  Hackers
//

import Foundation

/// Builds per-hole commissioner corrections so total gross matches a target, using par for unscored holes then adjusting from the last hole backward.
enum CommissionerGrossScoreDistributer {
    private static let minStrokes = 1
    private static let maxStrokes = 15
    private static let maxIterations = 800

    /// - Parameters:
    ///   - currentStrokes: `nil` means the hole is unscored (treated as par for the initial sum).
    static func correctionChanges(
        holes: [Hole],
        participantID: String,
        currentStrokes: (Int) -> Int?,
        targetGross: Int
    ) -> [SeriesScoreCorrectionChange]? {
        guard targetGross >= 0 else { return nil }
        let sortedHoles = holes.sorted { $0.number < $1.number }
        guard !sortedHoles.isEmpty else { return nil }

        var values: [Int: Int] = [:]
        for hole in sortedHoles {
            let n = hole.number
            values[n] = currentStrokes(n) ?? hole.par
        }

        var sum = values.values.reduce(0, +)
        var delta = targetGross - sum
        if delta == 0 {
            return buildChanges(holes: sortedHoles, participantID: participantID, values: values, currentStrokes: currentStrokes)
        }

        var iterations = 0
        while delta != 0, iterations < maxIterations {
            iterations += 1
            if delta > 0 {
                guard bumpUp(sortedHoles: sortedHoles, values: &values) else { return nil }
                delta -= 1
            } else {
                guard bumpDown(sortedHoles: sortedHoles, values: &values) else { return nil }
                delta += 1
            }
        }

        guard delta == 0 else { return nil }
        return buildChanges(holes: sortedHoles, participantID: participantID, values: values, currentStrokes: currentStrokes)
    }

    private static func bumpUp(sortedHoles: [Hole], values: inout [Int: Int]) -> Bool {
        for hole in sortedHoles.reversed() {
            let n = hole.number
            let v = values[n] ?? hole.par
            if v < maxStrokes {
                values[n] = v + 1
                return true
            }
        }
        return false
    }

    private static func bumpDown(sortedHoles: [Hole], values: inout [Int: Int]) -> Bool {
        for hole in sortedHoles.reversed() {
            let n = hole.number
            let v = values[n] ?? hole.par
            if v > minStrokes {
                values[n] = v - 1
                return true
            }
        }
        return false
    }

    private static func buildChanges(
        holes: [Hole],
        participantID: String,
        values: [Int: Int],
        currentStrokes: (Int) -> Int?
    ) -> [SeriesScoreCorrectionChange] {
        var out: [SeriesScoreCorrectionChange] = []
        for hole in holes {
            let n = hole.number
            let newVal = values[n] ?? hole.par
            let oldVal = currentStrokes(n)
            if newVal != oldVal {
                out.append(
                    SeriesScoreCorrectionChange(
                        participantID: participantID,
                        holeNumber: n,
                        strokes: newVal
                    )
                )
            }
        }
        return out
    }
}
