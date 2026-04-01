//
//  LiveRoundHoleOrdering.swift
//  Hackers
//
//  Pure helpers for tee-group play order (testable without LiveRoundViewModel).
//

import Foundation

enum LiveRoundHoleOrdering {

    /// Holes in course numeric order from the round’s hole range.
    static func courseHoleNumbers(holeRange: HoleRange?) -> [Int] {
        let range = holeRange ?? HoleRange(startHole: 1, endHole: 18)
        let lo = max(1, range.startHole)
        let hi = max(lo, min(18, range.endHole == 0 ? 18 : range.endHole))
        return Array(lo...hi)
    }

    /// Rotate so `startingHole` is first when it exists in `course`.
    static func playOrderedHoleNumbers(course: [Int], startingHole: Int) -> [Int] {
        guard startingHole > 0, let i = course.firstIndex(of: startingHole) else { return course }
        if i == 0 { return course }
        return Array(course[i...] + course[..<i])
    }

    /// Play order for the viewer’s tee group (`teeGroupID` nil → course order).
    static func playOrderHoleNumbers(
        holeRange: HoleRange?,
        teeGroupID: String?,
        teeGroups: [TeeTimeGroup]
    ) -> [Int] {
        let course = courseHoleNumbers(holeRange: holeRange)
        guard let gid = teeGroupID,
              let group = teeGroups.first(where: { $0.id == gid }) else {
            return course
        }
        return playOrderedHoleNumbers(course: course, startingHole: group.startingHole)
    }

    /// True when `holeNumber` is strictly before `currentHole` in `playOrder` (incomplete “skipped” styling).
    static func isIncompletePastInPlayOrder(
        playOrder: [Int],
        holeNumber: Int,
        currentHole: Int
    ) -> Bool {
        guard let curIdx = playOrder.firstIndex(of: currentHole),
              let holeIdx = playOrder.firstIndex(of: holeNumber) else {
            return false
        }
        return holeIdx < curIdx
    }
}
