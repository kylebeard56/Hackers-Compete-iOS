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
        #expect(course.defaultSegment == .full18)

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

    @Test("Configuring simple round builds a synthetic course and preserves setup state")
    func configureSimpleRoundBuildsSyntheticCourse() {
        let viewModel = CourseSelectionViewModel()

        viewModel.configureSimpleRound(
            .init(courseName: "Evening Nine", holeCount: 9, startingHole: 3)
        )

        #expect(viewModel.selectedCourse.isSimpleRoundCourse == true)
        #expect(viewModel.selectedCourse.clubName == "Evening Nine")
        #expect(viewModel.selectedCourse.courseName == "Evening Nine")
        #expect(viewModel.showCourseEdit == false)
        #expect(viewModel.showConfirmation == true)
        #expect(viewModel.simpleRoundSetup == .init(courseName: "Evening Nine", holeCount: 9, startingHole: 3))
        #expect(viewModel.holeSegment == .custom(count: 9))
        #expect(viewModel.selectedTee?.name == "Simple")
        #expect(viewModel.selectedCourse.tees.first?.holes.count == 9)
        #expect(viewModel.selectedCourse.tees.first?.holes.first?.par == 4)
        #expect(viewModel.selectedCourse.tees.first?.holes.last?.number == 9)
    }

    @Test("Configuring simple round clamps custom hole count and starting hole into range")
    func configureSimpleRoundClampsInvalidValues() {
        let viewModel = CourseSelectionViewModel()

        viewModel.configureSimpleRound(
            .init(courseName: "Test Round", holeCount: 12, startingHole: 17)
        )

        #expect(viewModel.simpleRoundSetup == .init(courseName: "Test Round", holeCount: 12, startingHole: 12))
        #expect(viewModel.selectedCourse.clubName == "Test Round")
        #expect(viewModel.selectedCourse.courseName == "Test Round")
        #expect(viewModel.holeSegment == .custom(count: 12))
        #expect(viewModel.selectedCourse.tees.first?.holes.count == 12)
    }

    @Test("Selecting Ask AI canonical match goes to confirmation")
    func selectAskAICanonicalMatchGoesToConfirmation() {
        let viewModel = CourseSelectionViewModel()
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
            golfCourseApiID: 101,
            origin: .golfCourseAPI,
            clubName: "Twin Lakes Golf Club",
            courseName: "North Course",
            tees: [tee]
        )

        viewModel.selectAskAICandidate(
            .init(
                course: course,
                requiresReview: false,
                isCanonicalMatch: true,
                sources: [.golfCourseAPI]
            )
        )

        #expect(viewModel.showCourseEdit == false)
        #expect(viewModel.showConfirmation == true)
        #expect(viewModel.lastSelectionSource == .askAI)
    }

    @Test("Ask AI no-candidate result stays in conversation without opening selection flow")
    func askAINoCandidateResultDoesNotOpenEditorOrConfirmation() async {
        let provider = MockCourseSelectionTextLookupProvider(
            response: """
            {
              "courseLookup": {
                "clubName": "Oxmoor Valley",
                "courseName": "Ridge Course",
                "confidence": "low",
                "apiSearchStrings": ["Oxmoor Valley Ridge", "Oxmoor Valley"]
              }
            }
            """
        )
        let askAIService = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: MockCourseSelectionSearchProvider(results: []),
                venueLookupProvider: MockCourseSelectionVenueLookupProvider()
            )
        )
        let viewModel = CourseSelectionViewModel(askAIService: askAIService)

        await viewModel.sendAskAIMessage("Oxmoor Valley Ridge from rtjgolf.com/scorecards")

        #expect(viewModel.askAIMessages.count == 2)
        #expect(viewModel.askAIMessages.last?.candidates.isEmpty == true)
        #expect(viewModel.askAIMessages.last?.text.contains("Can you send the city/state") == true)
        #expect(viewModel.showCourseEdit == false)
        #expect(viewModel.showConfirmation == false)
        #expect(viewModel.lastSelectionSource == nil)
    }
}

@MainActor
private final class MockCourseSelectionTextLookupProvider: LLMProviderProtocol {
    let response: String

    init(response: String) {
        self.response = response
    }

    func complete(messages: [LLMMessage], model: String?, maxTokens: Int) async throws -> String {
        response
    }
}

@MainActor
private final class MockCourseSelectionSearchProvider: CourseScorecardSearchProviding {
    let results: [GolfCourseAPIModel]

    init(results: [GolfCourseAPIModel]) {
        self.results = results
    }

    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        results
    }
}

@MainActor
private final class MockCourseSelectionVenueLookupProvider: CourseScorecardVenueLookupProviding {
    func venueDetails(
        for course: GolfCourseAPIModel,
        approximateLocation: ScorecardScanApproximateLocation?
    ) async -> CourseVenueDetails? {
        nil
    }
}
