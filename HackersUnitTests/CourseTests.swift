//
//  CourseTests.swift
//  HackersUnitTests
//

import Testing
@testable import Hackers

@Suite("Course model")
struct CourseTests {
    @Test("Manual course with no tees uses a valid default segment")
    func emptyTeesDefaultSegmentIsValid() {
        let course = Course(origin: .manual)
        #expect(course.defaultSegment == .full18)
        #expect(course.defaultSegment.holeCount == 18)
    }
}
