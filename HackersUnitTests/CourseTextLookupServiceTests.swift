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
            )
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
        #expect(result.assistantMessage.contains("Internet + Golf Course API"))
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
            )
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
        #expect(result.assistantMessage.contains("2 possible confirmed course matches"))
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
            )
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
        #expect(result.assistantMessage.contains("Golf Course API"))
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
            )
        )

        let result = try await service.resolveCourse(
            from: [
                .init(role: .user, text: "I'm playing Oxmoor Valley on the RTJ Trail in Alabama.")
            ]
        )

        #expect(result.candidates.isEmpty)
        #expect(result.source == .noMatch)
        #expect(searchProvider.queries == ["Oxmoor Valley Ridge", "Oxmoor Valley", "Ridge Course", "Oxmoor Valley Ridge Course"])
        #expect(result.assistantMessage.contains("neither the public web result nor Golf Course API confirmed"))
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
