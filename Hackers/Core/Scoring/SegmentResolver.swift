//
//  SegmentResolver.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

/// Resolves which RoundSegment applies to a given hole number.
/// Pure and stateless -- operates on the segment list from a RoundSnapshot.
struct SegmentResolver {

    /// Returns the segment whose hole range contains the given hole number.
    /// Falls back to the first segment if no match is found.
    static func segment(forHole holeNumber: Int, in segments: [RoundSegment]) -> RoundSegment? {
        segments.first(where: { $0.holeRange.contains(holeNumber) })
            ?? segments.first
    }

    /// Returns all hole numbers covered by a given segment.
    static func holeNumbers(for segment: RoundSegment) -> [Int] {
        segment.holeRange.holeNumbers
    }

    /// Returns scoring units for the segment that covers the given hole.
    static func scoringUnits(forHole holeNumber: Int, in segments: [RoundSegment]) -> [ScoringUnit] {
        segment(forHole: holeNumber, in: segments)?.scoringUnits ?? []
    }
}
