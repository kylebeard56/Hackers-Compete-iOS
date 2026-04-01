//
//  CourseSelectionViewModelTests.swift
//  HackersUnitTests
//

import Testing
@testable import Hackers

@MainActor
@Suite("Course Selection ViewModel")
struct CourseSelectionViewModelTests {
    @Test("Selecting OCR course opens edit sheet before confirmation")
    func selectOCROpensCourseEdit() {
        let tee = Tee(
            name: "Blue",
            gender: Gender.male.rawValue,
            totalHoles: 1,
            holes: [Hole(number: 1, par: 4, yardage: 380, handicap: nil)],
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        let course = Course(origin: .ocr, clubName: "", courseName: "", tees: [tee])

        let viewModel = CourseSelectionViewModel()
        viewModel.select(course: course, source: .scorecardScan)

        #expect(viewModel.showCourseEdit == true)
        #expect(viewModel.showConfirmation == false)
        #expect(viewModel.selectedCourse.origin == CourseOrigin.ocr.rawValue)
    }

    @Test("Selecting empty manual course opens edit sheet")
    func selectManualEmptyOpensCourseEdit() {
        let course = Course(origin: .manual)

        let viewModel = CourseSelectionViewModel()
        // Empty manual courses have no tees, so `defaultSegment` is not valid for `holeCount` in telemetry.
        // Assert navigation only; skip analytics for this fixture.
        viewModel.select(course: course, source: .manual, trackEvent: false)

        #expect(viewModel.showCourseEdit == true)
        #expect(viewModel.showConfirmation == false)
    }

    @Test("Selecting API course goes to confirmation without edit sheet")
    func selectAPIOpensConfirmation() {
        let tee = Tee(
            name: "Blue",
            gender: Gender.male.rawValue,
            totalHoles: 1,
            holes: [Hole(number: 1, par: 4, yardage: 380, handicap: nil)],
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        let course = Course(
            origin: .golfCourseAPI,
            clubName: "Test Club",
            courseName: "North",
            tees: [tee]
        )

        let viewModel = CourseSelectionViewModel()
        viewModel.select(course: course, source: .search)

        #expect(viewModel.showCourseEdit == false)
        #expect(viewModel.showConfirmation == true)
    }
}
