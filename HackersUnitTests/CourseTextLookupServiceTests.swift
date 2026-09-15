//
//  CourseTextLookupServiceTests.swift
//  HackersUnitTests
//

import Testing
import Foundation
@testable import Hackers

@MainActor
@Suite("Course Text Lookup Service")
struct CourseTextLookupServiceTests {
    @Test("Prompt includes location tie-break guidance only when enabled")
    func promptIncludesLocationGuidanceWhenEnabled() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "courseLookup": {
                "clubName": "Twin Lakes",
                "courseName": "North",
                "confidence": "low",
                "apiSearchStrings": ["Twin Lakes North", "Twin Lakes Austin"]
              }
            }
            """
        )
        let searchProvider = MockTextLookupSearchProvider(results: [])
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: searchProvider,
                venueLookupProvider: MockTextLookupVenueLookupProvider()
            ),
            searchProvider: MockTextLookupSearchProvider(results: [])
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

        #expect(systemText?.contains("Approximate user location may be appended below only to break ties") == true)
        #expect(finalUserText?.contains("Approximate user location for tie-break only: 30.2672, -97.7431") == true)
        #expect(provider.lastModel == AskAITextModel.defaultSelection.config.model)
    }

    @Test("High-confidence web scorecard plus matching API returns merged candidate")
    func highConfidenceWebScorecardPlusMatchingAPIReturnsMergedCandidate() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "courseLookup": {
                "clubName": "Wade Hampton Golf Club",
                "courseName": "Wade Hampton Golf Club",
                "confidence": "high",
                "officialWebsiteURL": "www.wadehampton.example",
                "apiSearchStrings": ["Wade Hampton Golf Club"],
                "scorecard": {
                  "clubName": "Wade Hampton Golf Club",
                  "courseName": "Wade Hampton Golf Club",
                  "tees": [
                    {
                      "name": "Blue",
                      "gender": "male",
                      "courseRating": 72.4,
                      "slopeRating": 138,
                      "holes": [
                        { "number": 1, "par": 4, "yardage": 410, "handicap": 7 }
                      ]
                    }
                  ]
                }
              }
            }
            """
        )
        let apiCandidate = Self.makeCandidate(
            id: 101,
            clubName: "Wade Hampton Golf Club",
            courseName: "Wade Hampton Golf Club",
            city: "Cashiers",
            state: "NC",
            latitude: 35.0834,
            longitude: -83.0879
        )
        let searchProvider = MockTextLookupSearchProvider(resultsByQuery: [
            "Wade Hampton Golf Club": [apiCandidate]
        ])
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: searchProvider,
                venueLookupProvider: MockTextLookupVenueLookupProvider()
            ),
            searchProvider: MockTextLookupSearchProvider(results: [])
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "Wade Hampton golf course in Cashiers, NC")
            ]
        )

        let candidateResult = try #require(result.candidates.first)
        #expect(result.candidates.count == 1)
        #expect(result.source == .webAndAPI)
        #expect(candidateResult.isCanonicalMatch == true)
        #expect(candidateResult.requiresReview == false)
        #expect(candidateResult.sources == [.internet, .golfCourseAPI])
        #expect(candidateResult.course.origin == CourseOrigin.golfCourseAPI.rawValue)
        #expect(candidateResult.course.golfCourseApiID == 101)
        #expect(searchProvider.queries == ["Wade Hampton Golf Club"])
        #expect(result.assistantMessage.contains("I found "))
    }

    @Test("High-confidence web scorecard plus distinct API returns two candidates")
    func highConfidenceWebScorecardPlusDistinctAPIReturnsTwoCandidates() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "courseLookup": {
                "clubName": "Twin Lakes Golf Club",
                "courseName": "North Course",
                "location": {
                  "city": "Austin",
                  "state": "TX"
                },
                "confidence": "high",
                "apiSearchStrings": ["Twin Lakes South", "Twin Lakes"],
                "scorecard": {
                  "clubName": "Twin Lakes Golf Club",
                  "courseName": "North Course",
                  "location": {
                    "city": "Austin",
                    "state": "TX"
                  },
                  "tees": [
                    {
                      "name": "Blue",
                      "gender": "male",
                      "courseRating": 72.4,
                      "slopeRating": 138,
                      "holes": [
                        { "number": 1, "par": 4, "yardage": 410, "handicap": 7 }
                      ]
                    }
                  ]
                }
              }
            }
            """
        )
        let apiCandidate = Self.makeCandidate(
            id: 202,
            clubName: "Twin Lakes Golf Club",
            courseName: "South Course",
            city: "Austin",
            state: "TX",
            latitude: 30.2672,
            longitude: -97.7431
        )
        let searchProvider = MockTextLookupSearchProvider(
            resultsByQuery: [
                "Twin Lakes South": [apiCandidate],
                "Twin Lakes": [apiCandidate]
            ]
        )
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: searchProvider,
                venueLookupProvider: MockTextLookupVenueLookupProvider()
            ),
            searchProvider: MockTextLookupSearchProvider(results: [])
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "Twin Lakes in Austin, I think North")
            ]
        )

        #expect(result.source == .multiple)
        #expect(result.candidates.count == 2)
        #expect(result.candidates[0].sources == [.internet])
        #expect(result.candidates[0].course.origin == CourseOrigin.manual.rawValue)
        #expect(result.candidates[1].sources == [.golfCourseAPI])
        #expect(result.candidates[1].course.golfCourseApiID == 202)
        #expect(searchProvider.queries == ["Twin Lakes South", "Twin Lakes", "North Course", "Twin Lakes Golf Club", "Twin Lakes Golf Club North Course"])
        #expect(result.assistantMessage.contains("2 possible course matches"))
    }

    @Test("Resolved identity returns API-only candidate using ordered search strings")
    func resolvedIdentityReturnsAPIOnlyCandidateInOrder() async throws {
        let provider = MockTextLookupLLMProvider(
            response: """
            {
              "courseLookup": {
                "clubName": "Wade Hampton Golf Club",
                "courseName": "Wade Hampton Golf Club",
                "location": {
                  "city": "Cashiers",
                  "state": "NC"
                },
                "confidence": "medium",
                "apiSearchStrings": ["Wade Hampton", "Wade Hampton Golf Club"]
              }
            }
            """
        )
        let apiCandidate = Self.makeCandidate(
            id: 101,
            clubName: "Wade Hampton Golf Club",
            courseName: "Wade Hampton Golf Club",
            city: "Cashiers",
            state: "NC",
            latitude: 35.0834,
            longitude: -83.0879
        )
        let searchProvider = MockTextLookupSearchProvider(
            resultsByQuery: [
                "Wade Hampton": [],
                "Wade Hampton Golf Club": [apiCandidate]
            ]
        )
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: searchProvider,
                venueLookupProvider: MockTextLookupVenueLookupProvider(
                    detailsByCourseID: [
                        101: .init(websiteURL: "https://wadehampton.example", phoneNumber: "8285551111")
                    ]
                )
            ),
            searchProvider: MockTextLookupSearchProvider()
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "Wade Hampton golf course in Cashiers, NC")
            ],
            context: .init(model: .claudeSonnet46)
        )

        let candidate = try #require(result.candidates.first)
        #expect(result.candidates.count == 1)
        #expect(result.source == .apiFallback)
        #expect(candidate.isCanonicalMatch == true)
        #expect(candidate.requiresReview == false)
        #expect(candidate.sources == [.golfCourseAPI])
        #expect(candidate.course.origin == CourseOrigin.golfCourseAPI.rawValue)
        #expect(candidate.course.golfCourseApiID == 101)
        #expect(searchProvider.queries == ["Wade Hampton", "Wade Hampton Golf Club"])
        #expect(provider.lastModel == AskAITextModel.claudeSonnet46.config.model)
        #expect(result.assistantMessage.contains("I found "))
    }

    @Test("Resolved identity with failed API fallback asks for more info")
    func resolvedIdentityWithFailedAPIFallbackAsksForMoreInfo() async throws {
        let provider = MockTextLookupLLMProvider(
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
        let searchProvider = MockTextLookupSearchProvider(resultsByQuery: [
            "Oxmoor Valley Ridge": [],
            "Oxmoor Valley": []
        ])
        let service = CourseTextLookupService(
            provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(
                searchProvider: searchProvider,
                venueLookupProvider: MockTextLookupVenueLookupProvider()
            ),
            searchProvider: MockTextLookupSearchProvider(results: [])
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "I'm playing Oxmoor Valley on the RTJ Trail in Alabama.")
            ]
        )

        #expect(result.candidates.isEmpty)
        #expect(result.source == .noMatch)
        #expect(searchProvider.queries == ["Oxmoor Valley Ridge", "Oxmoor Valley", "Ridge Course", "Oxmoor Valley Ridge Course"])
        #expect(result.assistantMessage.contains("couldn’t confirm a usable scorecard"))
    }

    @Test("Course names return summaries without calling AI or loading scorecards")
    func courseNameFastPath() async throws {
        let provider = MockTextLookupLLMProvider(response: "invalid if called")
        let summary = try Self.summary(id: "xnmmcgzp", city: "Greenville", state: "SC")
        let search = MockTextLookupSearchProvider(results: [summary])
        let service = CourseTextLookupService(provider: provider, searchProvider: search)
        let result = try await service.resolveCourse(from: [.init(role: .user, text: "Verdae")])
        #expect(provider.lastMessages.isEmpty)
        #expect(search.queries == ["Verdae"])
        #expect(result.candidates.count == 1)
        #expect(result.candidates.first?.needsScorecard == true)
        #expect(result.candidates.first?.course.tees.isEmpty == true)
        #expect(result.candidates.first?.locationText == "Greenville, SC, US")
    }

    @Test("Location clarification retains the original course and avoids another request")
    func locationClarification() async throws {
        let provider = MockTextLookupLLMProvider(response: "invalid if called")
        let search = MockTextLookupSearchProvider(results: [
            try Self.summary(id: "xnmmcgzp", city: "Greenville", state: "SC"),
            try Self.summary(id: "ach6dj3v", city: "Austin", state: "TX")
        ])
        let service = CourseTextLookupService(provider: provider, searchProvider: search)
        let user = AskAICourseChatMessage(role: .user, text: "Verdae")
        let first = try await service.resolveCourse(from: [user])
        #expect(first.candidates.count == 2)
        #expect(first.assistantMessage.contains("Which city or state"))
        let result = try await service.resolveCourse(from: [user,
            .init(role: .assistant, text: first.assistantMessage, candidates: first.candidates, lookupQuery: first.lookupQuery),
            .init(role: .user, text: "It’s in Austin, Texas")
        ], context: .init(isLocationAssistEnabled: true, approximateLocation: .init(latitude: 34.85, longitude: -82.39)))
        #expect(result.candidates.count == 1)
        #expect(result.candidates.first?.course.golfCourseApiID == "ach6dj3v")
        #expect(search.queries == ["Verdae"])
        #expect(provider.lastMessages.isEmpty)
    }

    @Test("Device locality narrows summaries even when the provider omits coordinates")
    func localityWithoutCourseCoordinates() async throws {
        let search = MockTextLookupSearchProvider(results: [
            try Self.summary(id: "xnmmcgzp", city: "Greenville", state: "SC"),
            try Self.summary(id: "ach6dj3v", city: "Austin", state: "TX")
        ])
        var localityCalls = 0
        let service = CourseTextLookupService(searchProvider: search, localityLookup: { _ in
            localityCalls += 1
            return "Greenville"
        })
        let result = try await service.resolveCourse(from: [.init(role: .user, text: "Verdae")],
            context: .init(isLocationAssistEnabled: true, approximateLocation: .init(latitude: 34.85, longitude: -82.39)))
        #expect(localityCalls == 1)
        #expect(result.candidates.count == 1)
        #expect(result.candidates.first?.course.golfCourseApiID == "xnmmcgzp")
    }

    @Test("Missing or disabled location asks a short location question without AI")
    func noLocationOrResults() async throws {
        let provider = MockTextLookupLLMProvider(response: "invalid if called")
        let service = CourseTextLookupService(provider: provider,
            searchProvider: MockTextLookupSearchProvider(), localityLookup: { _ in
                Issue.record("Disabled location must not be used")
                return nil
            })
        let result = try await service.resolveCourse(from: [.init(role: .user, text: "Verdae")],
            context: .init(isLocationAssistEnabled: false, approximateLocation: .init(latitude: 34.85, longitude: -82.39)))
        #expect(result.lookupQuery == "Verdae")
        #expect(result.assistantMessage.contains("Which city and state"))
        #expect(provider.lastMessages.isEmpty)
    }

    @Test("Web-only scorecards require review even with high model confidence")
    func webScorecardRequiresReview() async throws {
        let provider = MockTextLookupLLMProvider(response: """
        {"courseLookup":{"clubName":"Test","courseName":"Test","confidence":"high",
        "scorecard":{"tees":[{"name":"Blue","holes":[{"number":1,"par":4,"yardage":400}]}]}}}
        """)
        let service = CourseTextLookupService(provider: provider,
            enrichmentService: CourseScorecardEnrichmentService(searchProvider: MockTextLookupSearchProvider(),
                venueLookupProvider: MockTextLookupVenueLookupProvider()),
            searchProvider: MockTextLookupSearchProvider())
        let result = try await service.resolveCourse(from: [.init(role: .user, text: "Test in Greenville")])
        #expect(result.candidates.first?.requiresReview == true)
        #expect(result.candidates.first?.isCanonicalMatch == false)
    }

    @Test("Live chat search returns Verdae without AI", .enabled(if: ProcessInfo.processInfo.environment["RUN_LIVE_GOLFCOURSE_API_TEST"] == "1"))
    func liveChatSearch() async throws {
        let provider = MockTextLookupLLMProvider(response: "AI should not be called")
        let service = CourseTextLookupService(provider: provider)
        let start = ContinuousClock.now
        let result = try await service.resolveCourse(from: [.init(role: .user, text: "Verdae")])
        print("LIVE_CHAT_SEARCH elapsed=\(start.duration(to: .now)) candidates=\(result.candidates.count) aiCalls=\(provider.lastMessages.isEmpty ? 0 : 1)")
        #expect(!result.candidates.isEmpty)
        #expect(provider.lastMessages.isEmpty)
        let candidate = try #require(result.candidates.first)
        let id = try #require(candidate.course.golfCourseApiID)
        let course = try await GolfCourseRepository.shared.course(by: id)
        #expect(!course.tees.isEmpty)
        #expect(course.tees.contains { $0.totalHoles == 18 })
    }

    private static func summary(id: String, city: String, state: String) throws -> GolfCourseAPIModel {
        try JSONDecoder().decode(GolfCourseAPIModel.self, from: Data("""
        {"id":"\(id)","club_name":"Verdae","course_name":"Verdae", "location":{"city":"\(city)","state":"\(state)","country":"US"},"tees":{"male":3,"female":2}}
        """.utf8))
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
        id: GolfCourseID,
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

@MainActor
private final class MockTextLookupSearchProvider: CourseScorecardSearchProviding {
    private let fallbackResults: [GolfCourseAPIModel]
    private let resultsByQuery: [String: [GolfCourseAPIModel]]
    private(set) var queries: [String] = []

    init(
        results: [GolfCourseAPIModel] = [],
        resultsByQuery: [String: [GolfCourseAPIModel]] = [:]
    ) {
        self.fallbackResults = results
        self.resultsByQuery = resultsByQuery
    }

    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        queries.append(query)
        return resultsByQuery[query] ?? fallbackResults
    }
}

@MainActor
private final class MockTextLookupVenueLookupProvider: CourseScorecardVenueLookupProviding {
    let detailsByCourseID: [GolfCourseID: CourseVenueDetails]

    init(detailsByCourseID: [GolfCourseID: CourseVenueDetails] = [:]) {
        self.detailsByCourseID = detailsByCourseID
    }

    func venueDetails(
        for course: GolfCourseAPIModel,
        approximateLocation: ScorecardScanApproximateLocation?
    ) async -> CourseVenueDetails? {
        detailsByCourseID[course.id]
    }
}
