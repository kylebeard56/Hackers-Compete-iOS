//
//  CourseScorecardOCRServiceTests.swift
//  HackersUnitTests
//
//  Created by Codex on 3/23/26.
//

import Testing
import UIKit
@testable import Hackers

@MainActor
@Suite("Course Scorecard OCR Service")
struct CourseScorecardOCRServiceTests {
    @Test("Prompt includes multi-tee guidance and user notes")
    func promptIncludesGuidanceAndUserNotes() async throws {
        let provider = MockLLMProvider(response: minimalScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        _ = try await service.extractCourse(
            from: makeImage(),
            userNotes: "Blended tees are listed at the bottom."
        )

        let systemText = provider.lastMessages
            .first(where: { $0.role == "system" })
            .map(Self.joinedText(from:))
        let userText = provider.lastMessages
            .first(where: { $0.role == "user" })
            .map(Self.joinedText(from:))

        #expect(systemText?.contains("Extract every distinct tee row shown on the card.") == true)
        #expect(userText?.contains("User notes: Blended tees are listed at the bottom.") == true)
    }

    @Test("Extract uses vision model id when calling provider")
    func passesVisionModelToProvider() async throws {
        let provider = MockLLMProvider(response: minimalScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        _ = try await service.extractCourse(from: makeImage(), vision: .magnolia)

        #expect(provider.lastModel == "claude-sonnet-4-6")
    }

    @Test("Service preserves multiple tees and front back ratings from OCR JSON")
    func preservesMultiTeeData() async throws {
        let provider = MockLLMProvider(response: multiTeeScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        let course = try await service.extractCourse(from: makeImage())

        #expect(course.tees.count == 2)

        let gold = try #require(course.tees.first(where: { $0.name == "Gold" }))
        #expect(gold.gender == Gender.unknown.rawValue)
        #expect(abs(gold.ratingFull - 72.4) < 0.000_001)
        #expect(gold.slopeFull == 129)
        #expect(abs((gold.ratingFront ?? 0) - 36.1) < 0.000_001)
        #expect(gold.slopeFront == 126)
        #expect(abs((gold.ratingBack ?? 0) - 36.3) < 0.000_001)
        #expect(gold.slopeBack == 132)
        #expect(gold.holes.count == 2)
        #expect(gold.holes[0].yardage == 385)

        let blended = try #require(course.tees.first(where: { $0.name == "White/Red" }))
        #expect(blended.gender == Gender.female.rawValue)
    }

    private static func joinedText(from message: LLMMessage) -> String {
        message.content.compactMap { item -> String? in
            if case .text(let text) = item {
                return text
            }
            return nil
        }
        .joined(separator: "\n")
    }

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private let minimalScorecardJSON = """
    {
      "clubName": "Test Club",
      "courseName": "Test Course",
      "tees": [
        {
          "name": "White",
          "gender": "male",
          "courseRating": 71.1,
          "slopeRating": 122,
          "holes": [
            { "number": 1, "par": 4, "yardage": 360, "handicap": 7 }
          ]
        }
      ]
    }
    """

    private let multiTeeScorecardJSON = """
    {
      "clubName": "River Club",
      "courseName": "North Course",
      "tees": [
        {
          "name": "Gold",
          "gender": "unknown",
          "courseRating": 72.4,
          "slopeRating": 129,
          "frontCourseRating": 36.1,
          "frontSlopeRating": 126,
          "backCourseRating": 36.3,
          "backSlopeRating": 132,
          "holes": [
            { "number": 1, "par": 4, "yardage": 385, "handicap": 5 },
            { "number": 2, "par": 5, "yardage": 515, "handicap": 11 }
          ]
        },
        {
          "name": "White/Red",
          "gender": "female",
          "courseRating": 70.2,
          "slopeRating": 118,
          "holes": [
            { "number": 1, "par": 4, "yardage": 330, "handicap": 5 },
            { "number": 2, "par": 5, "yardage": 455, "handicap": 11 }
          ]
        }
      ]
    }
    """
}

@MainActor
private final class MockLLMProvider: LLMProviderProtocol {
    let response: String
    var lastMessages: [LLMMessage] = []
    var lastModel: String?

    init(response: String) {
        self.response = response
    }

    func complete(messages: [LLMMessage], model: String?, maxTokens: Int) async throws -> String {
        lastMessages = messages
        lastModel = model
        return response
    }
}
