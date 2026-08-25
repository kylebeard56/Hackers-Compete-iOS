//
//  SegmentResolverTests.swift
//  HackersTests
//
//  Created by Kyle Beard on 3/7/26.
//

@testable import Hackers
import XCTest

final class SegmentResolverTests: XCTestCase {

    // MARK: - Helpers

    private func makeSegment(id: String, startHole: Int, endHole: Int, templateID: String? = nil) -> RoundSegment {
        RoundSegment(
            id: id,
            roundID: "round1",
            holeRange: HoleRange(startHole: startHole, endHole: endHole),
            templateID: templateID
        )
    }

    // MARK: - Single Segment

    func testSingleSegmentCoversAllHoles() {
        let segments = [makeSegment(id: "seg1", startHole: 1, endHole: 18)]

        for hole in 1...18 {
            let resolved = SegmentResolver.segment(forHole: hole, in: segments)
            XCTAssertEqual(resolved?.id, "seg1", "Hole \(hole) should resolve to seg1")
        }
    }

    // MARK: - Multi-Segment (Front 9 / Back 9)

    func testMultiSegment_Front9Back9() {
        let segments = [
            makeSegment(id: "front", startHole: 1, endHole: 9),
            makeSegment(id: "back", startHole: 10, endHole: 18),
        ]

        for hole in 1...9 {
            let resolved = SegmentResolver.segment(forHole: hole, in: segments)
            XCTAssertEqual(resolved?.id, "front", "Hole \(hole) should resolve to front")
        }

        for hole in 10...18 {
            let resolved = SegmentResolver.segment(forHole: hole, in: segments)
            XCTAssertEqual(resolved?.id, "back", "Hole \(hole) should resolve to back")
        }
    }

    // MARK: - Boundary Holes

    func testHoleOnSegmentBoundary() {
        let segments = [
            makeSegment(id: "first6", startHole: 1, endHole: 6),
            makeSegment(id: "second6", startHole: 7, endHole: 12),
            makeSegment(id: "third6", startHole: 13, endHole: 18),
        ]

        XCTAssertEqual(SegmentResolver.segment(forHole: 6, in: segments)?.id, "first6")
        XCTAssertEqual(SegmentResolver.segment(forHole: 7, in: segments)?.id, "second6")
        XCTAssertEqual(SegmentResolver.segment(forHole: 12, in: segments)?.id, "second6")
        XCTAssertEqual(SegmentResolver.segment(forHole: 13, in: segments)?.id, "third6")
    }

    // MARK: - Fallback

    func testFallbackToFirstSegment() {
        let segments = [makeSegment(id: "seg1", startHole: 1, endHole: 9)]
        let resolved = SegmentResolver.segment(forHole: 15, in: segments)
        XCTAssertEqual(resolved?.id, "seg1", "Out-of-range hole should fall back to first segment")
    }

    func testEmptySegmentsReturnsNil() {
        let resolved = SegmentResolver.segment(forHole: 1, in: [])
        XCTAssertNil(resolved)
    }

    // MARK: - Hole Numbers

    func testHoleNumbers_FullRange() {
        let segment = makeSegment(id: "seg1", startHole: 1, endHole: 18)
        let holes = SegmentResolver.holeNumbers(for: segment)
        XCTAssertEqual(holes, Array(1...18))
    }

    func testHoleNumbers_PartialRange() {
        let segment = makeSegment(id: "back9", startHole: 10, endHole: 18)
        let holes = SegmentResolver.holeNumbers(for: segment)
        XCTAssertEqual(holes, Array(10...18))
    }

    // MARK: - Scoring Units

    func testScoringUnitsForHole() {
        let unit = ScoringUnit(id: "su1", owner: .participant, ownerIDs: ["p1"])
        var segment = makeSegment(id: "seg1", startHole: 1, endHole: 18)
        segment.scoringUnits = [unit]

        let units = SegmentResolver.scoringUnits(forHole: 5, in: [segment])
        XCTAssertEqual(units.count, 1)
        XCTAssertEqual(units[0].id, "su1")
    }

    // MARK: - Template ID Resolution

    func testSegmentWithTemplateID() {
        let segment = makeSegment(id: "seg1", startHole: 1, endHole: 18, templateID: "stableford")
        let resolved = SegmentResolver.segment(forHole: 1, in: [segment])
        XCTAssertEqual(resolved?.templateID, "stableford")
    }
}
