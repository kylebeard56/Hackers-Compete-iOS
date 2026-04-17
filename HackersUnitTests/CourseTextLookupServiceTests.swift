//
//  CourseTextLookupServiceTests.swift
//  HackersUnitTests
//

import Testing
@testable import Hackers

@MainActor
@Suite("Course Text Lookup Service")
struct CourseTextLookupServiceTests {
    @Test("Prompt includes location tie-break guidance only when enabled")
    func promptIncludesLocationGuidanceWhenEnabled() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "clubName": "Twin Lakes",
              "courseName": "North",
              "searchText": "Twin Lakes North Austin",
              "needsMoreDetail": false
            }
            """
        )
        let searchProvider = MockTextLookupSearchProvider(results: [])
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: searchProvider,
                venueLookupProvider: MockTextLookupVenueLookupProvider()
            )
        )

        _ = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "I'm playing Twin Lakes North in Austin.")
            ],
            context: .init(
                isLocationAssistEnabled: true,
                approximateLocation: .init(latitude: 30.2672, longitude: -97.7431)
            )
        )

        let systemText = provider.lastMessages
            .first(where: { $0.role == "system" })
            .map(Self.joinedText(from:))
        let finalUserText = provider.lastMessages.last.map(Self.joinedText(from:))

        #expect(systemText?.contains("Approximate user location may be provided only to help a later course-matching step break ties") == true)
        #expect(finalUserText?.contains("Approximate location for later tie-break only: 30.2672, -97.7431") == true)
    }

    @Test("Confirmed canonical match returns API-backed course candidate")
    func confirmedCanonicalMatchReturnsAPICandidate() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "clubName": "Twin Lakes Golf Club",
              "courseName": "North Course",
              "searchText": "Twin Lakes North Austin",
              "city": "Austin",
              "state": "TX",
              "confidence": "high",
              "needsMoreDetail": false
            }
            """
        )
        let candidate = Self.makeCandidate(
            id: 101,
            clubName: "Twin Lakes Golf Club",
            courseName: "North Course",
            city: "Austin",
            state: "TX",
            latitude: 30.2672,
            longitude: -97.7431
        )
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: MockTextLookupSearchProvider(results: [candidate]),
                venueLookupProvider: MockTextLookupVenueLookupProvider(
                    detailsByCourseID: [
                        101: .init(websiteURL: "https://twinlakes.example", phoneNumber: "5125551111")
                    ]
                )
            )
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "I'm playing Twin Lakes North in Austin.")
            ],
            context: .init(
                isLocationAssistEnabled: true,
                approximateLocation: .init(latitude: 30.2672, longitude: -97.7431)
            )
        )

        let candidateResult = try #require(result.candidate)
        #expect(candidateResult.isCanonicalMatch == true)
        #expect(candidateResult.requiresReview == false)
        #expect(candidateResult.course.origin == CourseOrigin.golfCourseAPI.rawValue)
        #expect(candidateResult.course.golfCourseApiID == 101)
        #expect(candidateResult.course.tees.count == 1)
        #expect(candidateResult.course.venueDetails?.websiteURL == "https://twinlakes.example")
        #expect(result.assistantMessage.contains("Twin Lakes"))
    }

    @Test("No canonical match returns a reviewable draft")
    func unresolvedLookupReturnsDraftCandidate() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "clubName": "Oxmoor Valley",
              "courseName": "Ridge Course",
              "searchText": "Oxmoor Valley RTJ Trail Alabama",
              "confidence": "medium",
              "needsMoreDetail": true
            }
            """
        )
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: MockTextLookupSearchProvider(results: []),
                venueLookupProvider: MockTextLookupVenueLookupProvider()
            )
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "I'm playing Oxmoor Valley on the RTJ Trail in Alabama.")
            ]
        )

        let candidate = try #require(result.candidate)
        #expect(candidate.isCanonicalMatch == false)
        #expect(candidate.requiresReview == true)
        #expect(candidate.course.origin == CourseOrigin.manual.rawValue)
        #expect(candidate.course.prettyCourseName == "Ridge Course")
        #expect(result.assistantMessage.contains("Review"))
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

    private static func makeCandidate(
        id: Int,
        clubName: String,
        courseName: String,
        city: String,
        state: String,
        latitude: Double,
        longitude: Double
    ) -> GolfCourseAPIModel {
        GolfCourseAPIModel(
            id: id,
            clubName: clubName,
            courseName: courseName,
            location: .init(
                address: "100 Fairway Dr",
                city: city,
                state: state,
                country: "US",
                latitude: latitude,
                longitude: longitude
            ),
            tees: GolfCourseAPITees(
                female: nil,
                male: [
                    GolfCourseAPITee(
                        teeName: "Blue",
                        courseRating: 72.0,
                        slopeRating: 120,
                        bogeyRating: 96.0,
                        totalYards: 380,
                        totalMeters: 347,
                        numberOfHoles: 1,
                        parTotal: 4,
                        frontCourseRating: nil,
                        frontSlopeRating: nil,
                        frontBogeyRating: nil,
                        backCourseRating: nil,
                        backSlopeRating: nil,
                        backBogeyRating: nil,
                        holes: [
                            GolfCourseAPIHole(par: 4, yardage: 380, handicap: nil)
                        ]
                    )
                ]
            )
        )
    }
}

@MainActor
private final class MockTextLookupLLMProvider: LLMProviderProtocol {
    let response: String
    var lastMessages: [LLMMessage] = []

    init(response: String) {
        self.response = response
    }

    func complete(messages: [LLMMessage], model: String?, maxTokens: Int) async throws -> String {
        lastMessages = messages
        return response
    }
}

@MainActor
private final class MockTextLookupSearchProvider: CourseScorecardSearchProviding {
    private let results: [GolfCourseAPIModel]

    init(results: [GolfCourseAPIModel]) {
        self.results = results
    }

    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        results
    }
}

@MainActor
private final class MockTextLookupVenueLookupProvider: CourseScorecardVenueLookupProviding {
    let detailsByCourseID: [Int: CourseVenueDetails]

    init(detailsByCourseID: [Int: CourseVenueDetails] = [:]) {
        self.detailsByCourseID = detailsByCourseID
    }

    func venueDetails(
        for course: GolfCourseAPIModel,
        approximateLocation: ScorecardScanApproximateLocation?
    ) async -> CourseVenueDetails? {
        detailsByCourseID[course.id]
    }
}
