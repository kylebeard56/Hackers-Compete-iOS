//
//  CourseSelectionViewModelTests.swift
//  HackersUnitTests
//

import Testing
import Foundation
import SwiftUI
import UIKit
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
            ),
            searchProvider: MockCourseSelectionSearchProvider(results: [])
        )
        let viewModel = CourseSelectionViewModel(askAIService: askAIService)

        await viewModel.sendAskAIMessage("Oxmoor Valley Ridge from rtjgolf.com/scorecards")

        #expect(viewModel.askAIMessages.count == 2)
        #expect(viewModel.askAIMessages.last?.candidates.isEmpty == true)
        #expect(viewModel.askAIMessages.last?.text.contains("Which city and state") == true)
        #expect(viewModel.showCourseEdit == false)
        #expect(viewModel.showConfirmation == false)
        #expect(viewModel.lastSelectionSource == nil)
    }
    @Test("Reset cancels a turn and ignores a late search response")
    func resetIgnoresLateResponse() async {
        let search = SuspendedChatSearchProvider()
        let model = CourseSelectionViewModel(askAIService: CourseTextLookupService(searchProvider: search))
        model.isSetHomeCourseMode = true
        let send = Task { await model.sendAskAIMessage("Verdae") }
        await search.waitUntilStarted()
        #expect(model.isSendingAskAIMessage)
        await model.sendAskAIMessage("Duplicate")
        #expect(search.calls == 1)
        model.resetAskAIConversation()
        search.finish()
        await send.value
        #expect(model.askAIMessages.isEmpty)
        #expect(!model.isSendingAskAIMessage)
        #expect(model.askAIError == nil)
    }

    @Test("Stopping preserves the conversation without a late assistant response")
    func stopPreservesConversation() async {
        let search = SuspendedChatSearchProvider()
        let model = CourseSelectionViewModel(askAIService: CourseTextLookupService(searchProvider: search))
        model.isSetHomeCourseMode = true
        let send = Task { await model.sendAskAIMessage("Verdae") }
        await search.waitUntilStarted()
        model.cancelAskAIRequest()
        search.finish()
        await send.value
        #expect(model.askAIMessages.count == 1)
        #expect(model.askAIMessages.first?.text == "Verdae")
        #expect(!model.isSendingAskAIMessage)
        #expect(model.askAIError == nil)
    }

    @Test("Retry clears an inline error without duplicating the user message")
    func retryDoesNotDuplicateUserMessage() async {
        let search = RetryingChatSearchProvider()
        let model = CourseSelectionViewModel(askAIService: CourseTextLookupService(searchProvider: search))
        model.isSetHomeCourseMode = true
        await model.sendAskAIMessage("Verdae", context: .init(isLocationAssistEnabled: true,
            approximateLocation: .init(latitude: 34.85, longitude: -82.39)))
        #expect(model.askAIError != nil)
        #expect(model.askAIMessages.count == 1)
        await model.retryAskAIMessage(context: .init(isLocationAssistEnabled: false))
        #expect(search.calls == 2)
        #expect(model.askAIMessages.filter(\.isUser).count == 1)
        #expect(model.askAIMessages.count == 2)
        #expect(model.askAIError == nil)
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

@MainActor
private final class SuspendedChatSearchProvider: CourseScorecardSearchProviding {
    var calls = 0
    private var request: CheckedContinuation<[GolfCourseAPIModel], Error>?
    private var started: CheckedContinuation<Void, Never>?

    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation in
            request = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if request != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish() {
        request?.resume(returning: [])
        request = nil
    }
}

@MainActor
private final class RetryingChatSearchProvider: CourseScorecardSearchProviding {
    var calls = 0
    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        calls += 1
        if calls == 1 { throw URLError(.timedOut) }
        return []
    }
}

/// Opt-in visual diagnostic: render the actual chat view without requiring a signed-in account.
@MainActor
@Suite("Course chat previews", .serialized, .enabled(if: ProcessInfo.processInfo.environment["RENDER_COURSE_CHAT"] == "1"))
struct CourseChatPreviewTests {
    @Test
    func renderStates() async throws {
        let course = Course(clubName: "Preserve At Verdae, The", courseName: "Preserve At Verdae, The")
        let candidate = AskAICourseCandidate(course: course, requiresReview: false, isCanonicalMatch: true,
            sources: [.golfCourseAPI], locationText: "Greenville, SC", needsScorecard: true)
        let conversation: [AskAICourseChatMessage] = [
            .init(role: .user, text: "Verdae"),
            .init(role: .assistant, text: "Does this look like your course? Choose it to continue to the scorecard.", candidates: [candidate])
        ]
        for state in ["empty-light", "candidate-light", "candidate-dark", "error-large", "loading"] {
            let view = AskAICourseSheet(
                messages: state == "empty-light" ? [] : conversation,
                isSending: state == "loading", isLocationAssistEnabled: .constant(true),
                approximateLocation: nil, examplePrompts: ["Verdae", "Oxmoor Valley", "Twin Lakes"],
                errorMessage: state == "error-large" ? "Couldn’t connect. Check your connection and try again." : nil
            )
            .environment(\.colorScheme, state == "candidate-dark" ? .dark : .light)
            .environment(\.dynamicTypeSize, state == "error-large" ? .accessibility2 : .large)
            let host = UIHostingController(rootView: view)
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            window.overrideUserInterfaceStyle = state == "candidate-dark" ? .dark : .light
            window.windowLevel = .alert + 1
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(500))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("course-chat-\(state).png")
            try image.pngData()?.write(to: path)
            print("CHAT_PREVIEW \(path.path)")
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }
    }
}
