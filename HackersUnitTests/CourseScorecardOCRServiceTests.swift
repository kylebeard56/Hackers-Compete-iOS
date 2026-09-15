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

    @Test("Prompt includes location-assist guidance only when enabled")
    func promptIncludesLocationAssistGuidanceWhenEnabled() async throws {
        let provider = MockLLMProvider(response: minimalScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        _ = try await service.extractCourse(
            from: makeImage(),
            scanContext: .init(
                notes: "Looks like a members card.",
                isLocationAssistEnabled: true,
                approximateLocation: .init(latitude: 33.7488, longitude: -84.3877)
            )
        )

        let systemText = provider.lastMessages
            .first(where: { $0.role == "system" })
            .map(Self.joinedText(from:))
        let userText = provider.lastMessages
            .first(where: { $0.role == "user" })
            .map(Self.joinedText(from:))

        #expect(systemText?.contains("Approximate user location may be provided only to help a later course-matching step break ties") == true)
        #expect(userText?.contains("Approximate location for later matching only: 33.7488, -84.3877") == true)
    }

    @Test("Prompt omits approximate location when location assist is disabled")
    func promptOmitsLocationAssistWhenDisabled() async throws {
        let provider = MockLLMProvider(response: minimalScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        _ = try await service.extractCourse(
            from: makeImage(),
            scanContext: .init(
                notes: "Use the middle columns.",
                isLocationAssistEnabled: false,
                approximateLocation: .init(latitude: 33.7488, longitude: -84.3877)
            )
        )

        let systemText = provider.lastMessages
            .first(where: { $0.role == "system" })
            .map(Self.joinedText(from:))
        let userText = provider.lastMessages
            .first(where: { $0.role == "user" })
            .map(Self.joinedText(from:))

        #expect(systemText?.contains("Approximate user location may be provided only") == false)
        #expect(userText?.contains("Approximate location for later matching only") == false)
    }

    @Test("Extract uses vision model id when calling provider")
    func passesVisionModelToProvider() async throws {
        let provider = MockLLMProvider(response: minimalScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        _ = try await service.extractCourse(
            from: makeImage(),
            scanContext: .init(),
            vision: .magnolia
        )

        #expect(provider.lastModel == "sonnet")
    }

    @Test("Service preserves multiple tees and front back ratings from OCR JSON")
    func preservesMultiTeeData() async throws {
        let provider = MockLLMProvider(response: multiTeeScorecardJSON)
        let service = CourseScorecardOCRService(provider: provider)

        let course = try await service.extractCourse(
            from: makeImage(),
            scanContext: .init()
        )

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

    @Test("A course cover without hole data cannot create an invented scorecard")
    func identityOnlyImageHasNoPlaceholderHoles() async throws {
        let provider = MockLLMProvider(response: #"{"clubName":"The Preserve at Verdae","tees":[]}"#)
        let course = try await CourseScorecardOCRService(provider: provider).extractCourse(from: makeImage(), scanContext: .init())
        #expect(course.clubName == "The Preserve at Verdae")
        #expect(course.tees.isEmpty)
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
@Suite("Course Scorecard Enrichment Service")
struct CourseScorecardEnrichmentServiceTests {
    @Test("Approximate location breaks ties between otherwise plausible course matches")
    func approximateLocationBreaksPlausibleTie() async {
        let nearCandidate = Self.makeCandidate(
            id: 101,
            clubName: "Twin Lakes Golf Club",
            courseName: "North Course",
            city: "Austin",
            state: "TX",
            latitude: 30.2672,
            longitude: -97.7431
        )
        let fartherCandidate = Self.makeCandidate(
            id: 202,
            clubName: "Twin Lakes Golf Club",
            courseName: "North Course",
            city: "Austin",
            state: "TX",
            latitude: 30.4630,
            longitude: -97.9100
        )
        let searchProvider = MockScorecardSearchProvider(results: [nearCandidate, fartherCandidate])
        let venueProvider = MockVenueLookupProvider(
            detailsByCourseID: [
                101: .init(websiteURL: "https://twinlakes.example", phoneNumber: "5125551111")
            ]
        )
        let service = CourseScorecardEnrichmentService(
            searchProvider: searchProvider,
            venueLookupProvider: venueProvider
        )

        let enriched = await service.enrich(
            course: Self.makeOCRCourse(
                clubName: "Twin Lakes",
                courseName: "North",
                city: "Austin",
                state: "TX"
            ),
            scanContext: .init(
                isLocationAssistEnabled: true,
                approximateLocation: .init(latitude: 30.2672, longitude: -97.7431)
            )
        )

        #expect(enriched.golfCourseApiID == 101)
        #expect(enriched.location?.city == "Austin")
        #expect(enriched.venueDetails?.websiteURL == "https://twinlakes.example")
        #expect(enriched.venueDetails?.phoneNumber == "5125551111")
        #expect(venueProvider.requestedCourseIDs == [101])
        #expect(searchProvider.queries.contains("North"))
    }

    @Test("A named cover image can use a confirmed provider scorecard")
    func identityOnlyImageUsesMatchedScorecard() async {
        let candidate = Self.makeCandidate(id: "xnmmcgzp", clubName: "The Preserve at Verdae",
            courseName: "The Preserve at Verdae", city: "Greenville", state: "SC", latitude: 34.85, longitude: -82.39)
        let service = CourseScorecardEnrichmentService(
            searchProvider: MockScorecardSearchProvider(results: [candidate]),
            venueLookupProvider: MockVenueLookupProvider())
        let result = await service.enrich(course: Course(origin: .ocr, clubName: "The Preserve at Verdae",
            courseName: "The Preserve at Verdae", tees: []))
        #expect(result.golfCourseApiID == "xnmmcgzp")
        #expect(!result.tees.isEmpty)
        #expect(result.tees.first?.holes == Course(canonicalGolfCourseAPI: candidate).tees.first?.holes)
    }

    @Test("Unresolved equally plausible matches fall back to OCR data without enrichment")
    func unresolvedTieFallsBackToOCRData() async {
        let firstCandidate = Self.makeCandidate(
            id: 101,
            clubName: "Twin Lakes Golf Club",
            courseName: "North Course",
            city: "Austin",
            state: "TX",
            latitude: 30.2672,
            longitude: -97.7431
        )
        let secondCandidate = Self.makeCandidate(
            id: 202,
            clubName: "Twin Lakes Golf Club",
            courseName: "North Course",
            city: "Austin",
            state: "TX",
            latitude: 30.3200,
            longitude: -97.8000
        )
        let venueProvider = MockVenueLookupProvider()
        let service = CourseScorecardEnrichmentService(
            searchProvider: MockScorecardSearchProvider(results: [firstCandidate, secondCandidate]),
            venueLookupProvider: venueProvider
        )
        let original = Self.makeOCRCourse(
            clubName: "Twin Lakes",
            courseName: "North",
            city: "Austin",
            state: "TX"
        )

        let enriched = await service.enrich(course: original, scanContext: .init())

        #expect(enriched.golfCourseApiID == nil)
        #expect(enriched.clubName == original.clubName)
        #expect(enriched.courseName == original.courseName)
        #expect(enriched.venueDetails == nil)
        #expect(venueProvider.requestedCourseIDs.isEmpty)
    }

    @Test("Approximate location alone does not force a course match")
    func locationAloneDoesNotForceCourseMatch() async {
        let unrelatedNearbyCandidate = Self.makeCandidate(
            id: 303,
            clubName: "Austin Municipal",
            courseName: "Lions Course",
            city: "Austin",
            state: "TX",
            latitude: 30.2672,
            longitude: -97.7431
        )
        let venueProvider = MockVenueLookupProvider()
        let service = CourseScorecardEnrichmentService(
            searchProvider: MockScorecardSearchProvider(results: [unrelatedNearbyCandidate]),
            venueLookupProvider: venueProvider
        )
        let original = Self.makeOCRCourse(
            clubName: "",
            courseName: "Hidden Valley",
            city: "Austin",
            state: "TX"
        )

        let enriched = await service.enrich(
            course: original,
            scanContext: .init(
                isLocationAssistEnabled: true,
                approximateLocation: .init(latitude: 30.2672, longitude: -97.7431)
            )
        )

        #expect(enriched.golfCourseApiID == nil)
        #expect(enriched.courseName == "Hidden Valley")
        #expect(enriched.location?.city == "Austin")
        #expect(venueProvider.requestedCourseIDs.isEmpty)
    }

    private static func makeOCRCourse(
        clubName: String,
        courseName: String,
        city: String?,
        state: String?
    ) -> Course {
        let tee = Tee(
            name: "Blue",
            gender: Gender.male.rawValue,
            totalHoles: 1,
            holes: [Hole(number: 1, par: 4, yardage: 380, handicap: nil)],
            ratingFull: 72.0,
            slopeFull: 120,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )

        return Course(
            origin: .ocr,
            clubName: clubName,
            courseName: courseName,
            location: CourseLocation(
                address: nil,
                city: city,
                state: state,
                country: "US",
                latitude: 30.2000,
                longitude: -97.7000
            ),
            tees: [tee]
        )
    }

    private static func makeCandidate(
        id: GolfCourseID,
        clubName: String,
        courseName: String,
        city: String?,
        state: String?,
        latitude: Double,
        longitude: Double
    ) -> GolfCourseAPIModel {
        GolfCourseAPIModel(
            id: id,
            clubName: clubName,
            courseName: courseName,
            location: GolfCourseAPILocation(
                address: "123 Clubhouse Way",
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

@MainActor
private final class MockScorecardSearchProvider: CourseScorecardSearchProviding {
    private let results: [GolfCourseAPIModel]
    private(set) var queries: [String] = []

    init(results: [GolfCourseAPIModel]) {
        self.results = results
    }

    func searchCourses(query: String) async throws -> [GolfCourseAPIModel] {
        queries.append(query)
        return results
    }
}

@MainActor
private final class MockVenueLookupProvider: CourseScorecardVenueLookupProviding {
    let detailsByCourseID: [GolfCourseID: CourseVenueDetails]
    private(set) var requestedCourseIDs: [GolfCourseID] = []

    init(detailsByCourseID: [GolfCourseID: CourseVenueDetails] = [:]) {
        self.detailsByCourseID = detailsByCourseID
    }

    func venueDetails(
        for course: GolfCourseAPIModel,
        approximateLocation: ScorecardScanApproximateLocation?
    ) async -> CourseVenueDetails? {
        requestedCourseIDs.append(course.id)
        return detailsByCourseID[course.id]
    }
}

/// Explicitly enabled diagnostics exercise the real image encoding, provider, and DTO mapping.
@MainActor
@Suite("Live scorecard OCR diagnostic", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["RUN_LIVE_SCORECARD_OCR"] == "1"))
struct LiveScorecardOCRDiagnosticTests {
    @Test("Official course cover resolves to a real scorecard")
    func officialCourseCoverLookup() async throws {
        let url = try #require(URL(string: "https://www.thepreserveatverdae.com/wp-content/uploads/sites/7866/2022/12/2022-Scorecard.jpg"))
        let (data, response) = try await URLSession.shared.data(from: url)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let image = try #require(UIImage(data: data))
        let start = ContinuousClock.now
        let extracted = try await CourseScorecardOCRService.shared.extractCourse(from: image, scanContext: .init(), vision: .juniper)
        #expect((extracted.clubName + extracted.courseName).localizedCaseInsensitiveContains("Verdae"))
        #expect(extracted.tees.isEmpty)
        let matched = await CourseScorecardEnrichmentService.shared.enrich(course: extracted)
        print("LIVE_IMAGE_LOOKUP elapsed=\(start.duration(to: .now)) matched=\(matched.golfCourseApiID?.description ?? "none") tees=\(matched.tees.count)")
        #expect(matched.golfCourseApiID != nil)
        #expect(matched.tees.contains { $0.holes.count == 18 })
    }

    @Test("Bundled scorecard preserves its Blue tee", arguments: [ScorecardScanVisionModel.juniper, .magnolia])
    func bundledScorecard(vision: ScorecardScanVisionModel) async throws {
        let image = try #require(UIImage(named: "MockScorecard", in: Bundle.main, compatibleWith: nil))
        let start = ContinuousClock.now
        let course = try await CourseScorecardOCRService.shared.extractCourse(
            from: image, scanContext: .init(), vision: vision
        )
        print("LIVE_OCR tier=\(vision.rawValue) elapsed=\(start.duration(to: .now)) tees=\(course.tees.count)")
        let blue = try #require(course.tees.first { $0.name.lowercased() == "blue" })
        #expect(blue.holes.count == 18)
        #expect(blue.holes.reduce(0) { $0 + $1.par } == 72)
        #expect(blue.holes.reduce(0) { $0 + $1.yardage } == 6197)
        #expect(blue.holes.first?.yardage == 327)
        #expect(blue.holes.last?.yardage == 385)
        #expect(abs(blue.ratingFull - 71.1) < 0.001)
        #expect(blue.slopeFull == 133)
        // This side of the sample card has no course name: location cannot manufacture one.
        #expect(course.clubName.isEmpty)
        #expect(course.courseName.isEmpty)
    }
}

@MainActor
@Suite("Course AI Gateway")
struct CourseAIGatewayTests {
    @Test("Gateway sends selected model, user transcript, and only consented location")
    func lookupPayloadAndDecoding() async throws {
        let gateway = CourseAIGateway { payload in
            #expect(payload["operation"] as? String == "courseLookup")
            #expect(payload["model"] as? String == "sonnet")
            let messages = try #require(payload["messages"] as? [[String: String]])
            #expect(messages == [["role": "user", "text": "Example Links in Greenville"]])
            let context = try #require(payload["context"] as? [String: Any])
            #expect(context["latitude"] == nil)
            #expect(context["longitude"] == nil)
            #expect(payload["tools"] == nil)
            #expect(payload["apiKey"] == nil)
            return ["courseLookup": ["courseName": "Example Links", "confidence": "medium", "apiSearchStrings": ["Example Links"]]]
        }
        let dto = try await gateway.lookupCourse(
            messages: [.init(role: "system", content: [.text("not sent")]), .init(role: "user", content: [.text("Example Links in Greenville")])],
            model: AskAITextModel.claudeSonnet46.config.model,
            context: .init(isLocationAssistEnabled: false, approximateLocation: .init(latitude: 34, longitude: -82))
        )
        #expect(dto.courseName == "Example Links")
        let context = CourseAIGateway.contextPayload(.init(isLocationAssistEnabled: true, approximateLocation: .init(latitude: 34, longitude: -82)))
        #expect(context["latitude"] as? Double == 34)
        #expect(context["longitude"] as? Double == -82)
    }

    @Test("OCR gateway preserves empty scorecards without inventing holes")
    func ocrPayloadAndDecoding() async throws {
        let gateway = CourseAIGateway { payload in
            #expect(payload["operation"] as? String == "scorecard")
            #expect(payload["model"] as? String == "luna")
            #expect(payload["imageBase64"] as? String == "fixture")
            return ["scorecard": ["courseName": "Example Links", "tees": []]]
        }
        let dto = try await gateway.extractScorecard(imageBase64: "fixture", model: AIModelConfig.defaultForVision.model, context: .init())
        #expect(dto.tees?.isEmpty == true)
    }

    @Test("Gateway rejects malformed response and oversized image")
    func invalidPayloads() async throws {
        let gateway = CourseAIGateway { _ in ["scorecard": ["tees": "invalid"]] }
        await #expect(throws: CourseAIGatewayError.self) {
            try await gateway.extractScorecard(imageBase64: "fixture", model: "luna", context: .init())
        }
        let neverCalled = CourseAIGateway { _ in
            Issue.record("Oversized input must not reach the network")
            return [:]
        }
        await #expect(throws: CourseAIGatewayError.self) {
            try await neverCalled.extractScorecard(imageBase64: String(repeating: "a", count: 7_000_001), model: "luna", context: .init())
        }
    }

    @Test("Gateway strips raw server messages and retains cancellation")
    func errorSanitization() {
        let error = CourseAIGateway.mappedError(NSError(domain: "network", code: 401, userInfo: [NSLocalizedDescriptionKey: "PRIVATE-KEY"]))
        #expect(!error.localizedDescription.contains("PRIVATE-KEY"))
        #expect(CourseAIGateway.mappedError(CancellationError()) is CancellationError)
    }

    @Test("Built app contains no AI provider keys; legacy chat choice migrates to Luna")
    func noBundledSecretsAndModelMigration() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") == nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") == nil)
        #expect(AskAITextModel.fromStoredRawValue("gpt-4.1-mini") == .luna)
        #expect(AskAITextModel.fromStoredRawValue("claude-sonnet-4-6") == .claudeSonnet46)
    }
}
