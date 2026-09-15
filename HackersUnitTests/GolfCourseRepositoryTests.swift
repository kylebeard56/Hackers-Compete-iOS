//
//  GolfCourseRepositoryTests.swift
//  HackersUnitTests
//

import Foundation
import Testing
@testable import Hackers

@MainActor
@Suite("Golf Course Repository")
struct GolfCourseRepositoryTests {
    @Test("Cache hit avoids GolfCourseAPI")
    func cacheHitAvoidsRemoteRequest() async throws {
        let cached = Course(
            id: "42",
            golfCourseApiID: 42,
            origin: .golfCourseAPI,
            clubName: "Cached Club",
            courseName: "Cached Course"
        )
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: 42))
        let cache = MockGolfCourseCache(coursesByID: [42: cached])
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let resolved = try await repository.course(by: 42)

        #expect(resolved == cached)
        #expect(remote.detailRequestIDs.isEmpty)
        #expect(cache.cachedBatches.isEmpty)
    }

    @Test("GolfCourseAPI identity is deterministic and canonical")
    func deterministicGolfCourseAPIIdentity() {
        let canonical = Course(canonicalGolfCourseAPI: makeAPIModel(id: 37140))
        let unrelated = Course(
            id: "37140",
            golfCourseApiID: 37140,
            origin: .hackers
        )

        #expect(Course.golfCourseAPIDocumentID(for: 37140) == "37140")
        #expect(canonical.id == "37140")
        #expect(canonical.golfCourseApiID == 37140)
        #expect(canonical.hasCanonicalGolfCourseAPIIdentity)
        #expect(!unrelated.hasCanonicalGolfCourseAPIIdentity)
        #expect(canonical.matchesCachedSearch(query: "Test Club"))
        #expect(!canonical.matchesCachedSearch(query: "Club"))
    }

    @Test("Cache miss fetches API course and writes it through")
    func cacheMissFetchesAndCachesRemoteCourse() async throws {
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: 42))
        let cache = MockGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let resolved = try await repository.course(by: 42)

        #expect(remote.detailRequestIDs == [42])
        #expect(resolved.id == "42")
        #expect(resolved.golfCourseApiID == 42)
        #expect(resolved.origin == CourseOrigin.golfCourseAPI.rawValue)
        #expect(cache.cachedBatches.count == 1)
        #expect(cache.cachedBatches.first?.map(\.id) == ["42"])
    }

    @Test("Cached search avoids GolfCourseAPI")
    func cachedSearchAvoidsRemoteRequest() async throws {
        let cached = Course(canonicalGolfCourseAPI: makeAPIModel(id: 37140))
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: 1))
        let cache = MockGolfCourseCache(searchResults: [cached])
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let models = try await repository.searchCourseModels(with: "Test Club")

        #expect(models.map(\.id) == [37140])
        #expect(cache.searchQueries == ["Test Club"])
        #expect(remote.searchQueries.isEmpty)
    }

    @Test("Successful search writes every result through")
    func successfulSearchCachesAllResults() async throws {
        let remote = MockGolfCourseRemote(
            courseModel: makeAPIModel(id: 1),
            searchModels: [makeAPIModel(id: 10), makeAPIModel(id: 11)]
        )
        let cache = MockGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let models = try await repository.searchCourseModels(with: "Greenville")

        #expect(models.map(\.id) == [10, 11])
        #expect(remote.searchQueries == ["Greenville"])
        #expect(cache.cachedBatches.count == 1)
        #expect(cache.cachedBatches.first?.map(\.id) == ["10", "11"])
    }

    @Test("Top-level by-ID response decodes")
    func topLevelResponseDecodes() throws {
        let data = Data(apiJSON(id: 37140).utf8)

        let response = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)

        #expect(response.course?.id == 37140)
        #expect(response.courses.isEmpty)
    }

    @Test("Legacy wrapped by-ID response still decodes")
    func wrappedResponseDecodes() throws {
        let data = Data("""
        {"course": \(apiJSON(id: 27670))}
        """.utf8)

        let response = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)

        #expect(response.course?.id == 27670)
        #expect(response.courses.isEmpty)
    }

    @Test("Current by-ID response tolerates omitted optional provider fields")
    func currentResponseWithOmittedFieldsDecodes() throws {
        let data = Data("""
        {
          "course": {
            "id": 24833,
            "club_name": "The Preserve at Verdae",
            "course_name": "The Preserve at Verdae",
            "location": {
              "address": "650 Verdae Blvd",
              "city": "Greenville",
              "state": "South Carolina",
              "country": "United States"
            },
            "tees": {
              "female": [{
                "tee_name": "Forward",
                "course_rating": 71.2,
                "slope_rating": 125,
                "total_yards": 5200,
                "total_meters": 4755,
                "number_of_holes": 18,
                "par_total": 72,
                "holes": [{"par": 4, "yardage": 320, "handicap": 9}]
              }],
              "male": []
            }
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)
        let course = try #require(response.course)

        #expect(course.id == 24833)
        #expect(course.location.coordinate == nil)
        #expect(course.tees.female?.first?.bogeyRating == nil)

        let cached = Course(canonicalGolfCourseAPI: course)
        #expect(cached.location == nil)
        #expect(cached.locationGeohash == nil)
        #expect(cached.tees.female.count == 1)
    }

    @Test("Search decodes the current summary contract without inventing scorecards")
    func currentSearchSummaryDecodes() throws {
        let response = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8))
        let model = try #require(response.courses.first)
        #expect(model.id == "xnmmcgzp")
        #expect(model.isSummary)
        #expect(model.tees.male == nil)
        #expect(model.tees.female == nil)
    }

    @Test("Malformed search data throws instead of silently reporting zero courses")
    func malformedSearchThrows() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(#"{"courses":[{"id":"xnmmcgzp"}]}"#.utf8))
        }
    }

    @Test("Stored numeric IDs and new opaque IDs retain their wire types", arguments: ["24833", #""xnmmcgzp""#, #""00001234""#])
    func providerIDsRoundTrip(json: String) throws {
        let id = try JSONDecoder().decode(GolfCourseID.self, from: Data(json.utf8))
        let course = Course(golfCourseApiID: id, origin: .golfCourseAPI)
        let stored = try JSONEncoder().encode(course)
        let decoded = try JSONDecoder().decode(Course.self, from: stored)
        #expect(decoded.golfCourseApiID == id)
        let snapshot = CourseInfo(course: course, for: .full18)
        let snapshotData = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(CourseInfo.self, from: snapshotData).golfCourseApiID == id)
        #expect(String(data: try JSONEncoder().encode(id), encoding: .utf8) == json)
    }

    @Test("Summary searches do not fetch every detail or cache incomplete scorecards")
    func summarySearchIsLazy() async throws {
        let summary = try #require(JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8)).courses.first)
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"), searchModels: [summary])
        let cache = MockGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)
        let models = try await repository.searchCourseModels(with: "Verdae", includeScorecards: false)
        #expect(models.count == 1)
        #expect(remote.detailRequestIDs.isEmpty)
        #expect(cache.cachedBatches.isEmpty)
    }

    @Test("Consumers needing scorecards resolve summary details before caching")
    func scorecardSearchLoadsDetail() async throws {
        let summary = try #require(JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8)).courses.first)
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"), searchModels: [summary])
        let cache = MockGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)
        let models = try await repository.searchCourseModels(with: "Verdae")
        #expect(models.first?.isSummary == false)
        #expect(remote.detailRequestIDs == ["xnmmcgzp"])
        #expect(cache.cachedBatches.first?.first?.id == "xnmmcgzp")
    }

    @Test("Legacy UUID cache records load without calling the retired numeric endpoint")
    func legacyCacheRecovery() async throws {
        let legacy = Course(id: "legacy-uuid", golfCourseApiID: 24833, origin: .golfCourseAPI, courseName: "Verdae")
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"), detailError: .legacyCourseUnavailable)
        let repository = GolfCourseRepository(remote: remote, cache: MockGolfCourseCache(coursesByID: [24833: legacy]))
        let resolved = try await repository.course(by: 24833)
        #expect(resolved.id == "24833")
        #expect(remote.detailRequestIDs.isEmpty)
        #expect(legacy.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: 99) == nil)
        #expect(Course(golfCourseApiID: 24833, origin: .manual).canonicalizedGolfCourseAPICacheEntry(expectedAPIID: 24833) == nil)
    }

    @Test("Legacy cached search preserves selected tee identity and scoring data across detail loads")
    func legacySearchAndDetailAgree() async throws {
        let tee = Tee(
            id: "legacy-tee-uuid", name: "Blue", gender: Gender.male.rawValue,
            totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: 72.4, slopeFull: 131,
            ratingFront: 36.1, slopeFront: 129,
            ratingBack: 36.3, slopeBack: 133
        )
        let legacy = Course(
            id: "legacy-course-uuid", golfCourseApiID: 24833, origin: .golfCourseAPI,
            clubName: "Verdae", courseName: "Verdae", tees: [tee]
        )
        let remote = MockGolfCourseRemote(
            courseModel: makeAPIModel(id: "xnmmcgzp"),
            detailError: .legacyCourseUnavailable, searchError: .apiKeyMissing
        )
        let repository = GolfCourseRepository(
            remote: remote,
            cache: MockGolfCourseCache(coursesByID: [24833: legacy], searchResults: [legacy])
        )

        let searchModel = try #require(try await repository.searchCourseModels(with: "Verdae").first)
        let searchCourse = Course(canonicalGolfCourseAPI: searchModel)
        let detail = try await repository.course(by: 24833)
        let selectedTee = try #require(searchCourse.tees.first)
        let restoredTee = try #require(detail.tees.first { $0.id == selectedTee.id })

        #expect(searchCourse.id == detail.id)
        #expect(selectedTee.id == "blue_male")
        #expect(restoredTee.holes == tee.holes)
        #expect(restoredTee.totalHoles == tee.totalHoles)
        #expect(restoredTee.ratingFull == tee.ratingFull)
        #expect(restoredTee.slopeFull == tee.slopeFull)
        #expect(restoredTee.ratingFront == tee.ratingFront)
        #expect(restoredTee.slopeFront == tee.slopeFront)
        #expect(restoredTee.ratingBack == tee.ratingBack)
        #expect(restoredTee.slopeBack == tee.slopeBack)
        #expect(detail.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: 24833) == detail)
        #expect(remote.searchQueries.isEmpty)
        #expect(remote.detailRequestIDs.isEmpty)
    }

    @Test("Cached search rejects unrelated origins even when a provider ID is present")
    func searchRejectsNonProviderCacheRecords() async throws {
        let unrelated = Course(golfCourseApiID: 24833, origin: .manual, courseName: "Verdae")
        let remote = MockGolfCourseRemote(
            courseModel: makeAPIModel(id: "xnmmcgzp"),
            searchModels: [makeAPIModel(id: "xnmmcgzp")]
        )
        let repository = GolfCourseRepository(remote: remote, cache: MockGolfCourseCache(searchResults: [unrelated]))

        let models = try await repository.searchCourseModels(with: "Verdae")

        #expect(models.map(\.id) == ["xnmmcgzp"])
        #expect(remote.searchQueries == ["Verdae"])
    }

    @Test("Missing legacy recents show matches and wait for an explicit selection")
    func recentRecoveryRequiresConfirmation() async throws {
        let summary = try #require(JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8)).courses.first)
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"), searchModels: [summary], detailError: .legacyCourseUnavailable)
        let repository = GolfCourseRepository(remote: remote, cache: MockGolfCourseCache())
        let vm = CourseSelectionViewModel(courseRepository: repository)
        vm.isSetHomeCourseMode = true
        await vm.selectFromRecent(entry: CourseHistoryEntry(courseID: "24833", name: "Verdae"))
        #expect(vm.recoveryCourseName == "Verdae")
        #expect(remote.searchQueries == ["Verdae"])
        #expect(vm.searchedCourses.first?.golfCourseApiID == "xnmmcgzp")
        #expect(!vm.showConfirmation)
        #expect(!vm.showCourseFetchError)
    }

    @Test("Selecting a summary fetches its current detail before confirmation")
    func selectSearchSummaryLoadsDetail() async throws {
        let summary = try #require(JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8)).courses.first)
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"))
        let vm = CourseSelectionViewModel(courseRepository: GolfCourseRepository(remote: remote, cache: MockGolfCourseCache()))
        vm.isSetHomeCourseMode = true
        await vm.selectSearchCourse(Course(canonicalGolfCourseAPI: summary))
        #expect(remote.detailRequestIDs == ["xnmmcgzp"])
        #expect(vm.selectedCourse.golfCourseApiID == "xnmmcgzp")
        #expect(vm.showConfirmation)
        #expect(!vm.isLoadingSelectedCourse)
    }

    @Test("Provider search errors replace stale results with a visible error")
    func searchErrorsAreVisible() async {
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"), searchError: .apiKeyMissing)
        let vm = CourseSelectionViewModel(courseRepository: GolfCourseRepository(remote: remote, cache: MockGolfCourseCache()))
        vm.isSetHomeCourseMode = true
        vm.searchedCourses = [Course(courseName: "Stale")]
        await vm.searchCourses(for: "Verdae")
        #expect(vm.searchError == GolfCourseAPIError.apiKeyMissing.localizedDescription)
        #expect(vm.searchedCourses.isEmpty)
        #expect(!vm.isSearching)
    }

    @Test("Chat summary selection loads a scorecard before round confirmation")
    func selectChatSummaryLoadsDetail() async throws {
        let summary = try #require(JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8)).courses.first)
        var detailed = makeAPIModel(id: "xnmmcgzp")
        let tee = Tee(name: "Blue", gender: Gender.male.rawValue, totalHoles: 18,
            holes: (1...18).map { Hole(number: $0, par: 4, yardage: 400, handicap: $0) },
            ratingFull: 72, slopeFull: 113, ratingFront: nil, slopeFront: nil, ratingBack: nil, slopeBack: nil)
        detailed.tees = GolfCourseAPITees(female: nil, male: [GolfCourseAPITee(cachedTee: tee)])
        let remote = MockGolfCourseRemote(courseModel: detailed)
        let vm = CourseSelectionViewModel(courseRepository: GolfCourseRepository(remote: remote, cache: MockGolfCourseCache()))
        vm.isSetHomeCourseMode = true
        let success = await vm.loadAskAICandidate(.init(course: Course(canonicalGolfCourseAPI: summary),
            requiresReview: false, isCanonicalMatch: true, sources: [.golfCourseAPI], needsScorecard: true))
        #expect(success)
        #expect(remote.detailRequestIDs == ["xnmmcgzp"])
        #expect(vm.selectedCourse.tees.isPopulated)
        #expect(vm.showConfirmation)
        #expect(vm.lastSelectionSource == .askAI)
        #expect(!vm.isSendingAskAIMessage)
    }

    @Test("Chat scorecard failure remains inline and does not open confirmation")
    func selectChatSummaryFailureStaysInChat() async throws {
        let summary = try #require(JSONDecoder().decode(GolfCourseAPIResponse.self, from: Data(Self.summaryJSON.utf8)).courses.first)
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"), detailError: .apiKeyMissing)
        let vm = CourseSelectionViewModel(courseRepository: GolfCourseRepository(remote: remote, cache: MockGolfCourseCache()))
        vm.isSetHomeCourseMode = true
        let success = await vm.loadAskAICandidate(.init(course: Course(canonicalGolfCourseAPI: summary),
            requiresReview: false, isCanonicalMatch: true, sources: [.golfCourseAPI], needsScorecard: true))
        #expect(!success)
        #expect(vm.askAIError?.contains("authorize") == true)
        #expect(!vm.showConfirmation)
        #expect(!vm.isSendingAskAIMessage)
    }

    @Test("An empty provider scorecard cannot advance the chat into a round")
    func emptyChatScorecardDoesNotConfirm() async {
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: "xnmmcgzp"))
        let vm = CourseSelectionViewModel(courseRepository: GolfCourseRepository(remote: remote, cache: MockGolfCourseCache()))
        vm.isSetHomeCourseMode = true
        let success = await vm.loadAskAICandidate(.init(course: Course(canonicalGolfCourseAPI: makeAPIModel(id: "xnmmcgzp")),
            requiresReview: false, isCanonicalMatch: true, sources: [.golfCourseAPI], needsScorecard: true))
        #expect(!success)
        #expect(vm.askAIError != nil)
        #expect(!vm.showConfirmation)
    }

    private static let summaryJSON = #"{"courses":[{"id":"xnmmcgzp","club_name":"Preserve At Verdae, The","course_name":"Preserve At Verdae, The","location":{"address":"650 Verdae Blvd, Greenville, SC 29607, USA","city":"Greenville","state":"SC","country":"United States"},"tees":{"female":3,"male":9}}]}"#

    private func makeAPIModel(id: GolfCourseID) -> GolfCourseAPIModel {
        GolfCourseAPIModel(
            id: id,
            clubName: "Test Club \(id)",
            courseName: "Test Course \(id)",
            location: GolfCourseAPILocation(
                address: "1 Fairway Drive",
                city: "Greenville",
                state: "SC",
                country: "US",
                latitude: 34.85,
                longitude: -82.40
            ),
            tees: GolfCourseAPITees(female: nil, male: nil)
        )
    }

    private func apiJSON(id: GolfCourseID) -> String {
        """
        {
          "id": \(id),
          "club_name": "Test Club",
          "course_name": "Test Course",
          "location": {
            "address": "1 Fairway Drive",
            "city": "Greenville",
            "state": "SC",
            "country": "US",
            "latitude": 34.85,
            "longitude": -82.40
          },
          "tees": {"female": [], "male": []}
        }
        """
    }
}

@MainActor
private final class MockGolfCourseRemote: GolfCourseAPIRemoteProviding {
    let courseModel: GolfCourseAPIModel
    let searchModels: [GolfCourseAPIModel]
    let detailError: GolfCourseAPIError?
    let searchError: GolfCourseAPIError?
    private(set) var detailRequestIDs: [GolfCourseID] = []
    private(set) var searchQueries: [String] = []

    init(
        courseModel: GolfCourseAPIModel,
        searchModels: [GolfCourseAPIModel] = [],
        detailError: GolfCourseAPIError? = nil,
        searchError: GolfCourseAPIError? = nil
    ) {
        self.courseModel = courseModel
        self.searchModels = searchModels
        self.detailError = detailError
        self.searchError = searchError
    }

    func getCourseModel(by id: GolfCourseID) async throws -> GolfCourseAPIModel {
        detailRequestIDs.append(id)
        if let detailError { throw detailError }
        return courseModel
    }

    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel] {
        searchQueries.append(query)
        if let searchError { throw searchError }
        return searchModels
    }
}

@MainActor
private final class MockGolfCourseCache: GolfCourseCacheProviding {
    let coursesByID: [GolfCourseID: Course]
    let searchResults: [Course]
    private(set) var cachedBatches: [[Course]] = []
    private(set) var searchQueries: [String] = []

    init(coursesByID: [GolfCourseID: Course] = [:], searchResults: [Course] = []) {
        self.coursesByID = coursesByID
        self.searchResults = searchResults
    }

    func course(byGolfCourseAPIID id: GolfCourseID) async -> Course? {
        coursesByID[id]
    }

    func courses(matching query: String) async -> [Course] {
        searchQueries.append(query)
        return searchResults
    }

    func cacheGolfCourseAPICourses(_ courses: [Course]) async {
        cachedBatches.append(courses)
    }
}

@MainActor
@Suite("GolfCourseAPI HTTP contract")
struct GolfCourseAPIHTTPTests {
    private func makeAPI() -> GolfCourseAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GolfCourseHTTPStub.self]
        return GolfCourseAPI(session: URLSession(configuration: configuration))
    }

    @Test("Search encodes reserved characters as one query parameter")
    func searchQueryEncoding() async throws {
        let models = try await makeAPI().searchCourses(with: "A & B #?")
        #expect(models.isEmpty)
    }

    @Test("Authentication and quota failures retain actionable error types", arguments: [401, 403, 429, 503])
    func httpErrors(status: Int) async {
        let expected: GolfCourseAPIError = switch status {
        case 401, 403: .apiKeyMissing
        case 429: .tooManyRequests
        default: .invalidStatusCode(code: status)
        }
        await #expect(throws: expected) {
            try await makeAPI().searchCourses(with: String(status))
        }
    }

    @Test("Numeric remote lookups fail explicitly rather than making a doomed request")
    func legacyLookup() async {
        await #expect(throws: GolfCourseAPIError.legacyCourseUnavailable) {
            try await makeAPI().getCourseModel(by: 24833)
        }
    }

    @Test("Current string-ID detail response loads")
    func stringDetailLookup() async throws {
        let model = try await makeAPI().getCourseModel(by: "xnmmcgzp")
        #expect(model.id == "xnmmcgzp")
        #expect(!model.isSummary)
    }
}

/// Immutable URLProtocol stub: concurrent tests choose their response through the request itself.
private final class GolfCourseHTTPStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first { $0.name == "search_query" }?.value
        let status: Int
        let body: String
        if request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Key ") != true {
            status = 401
            body = "{}"
        } else if url.path == "/v1/courses/xnmmcgzp" {
            status = 200
            body = #"{"course":{"id":"xnmmcgzp","club_name":"Verdae","course_name":"Verdae","location":{},"tees":{"female":[],"male":[]}}}"#
        } else if let query, let code = Int(query) {
            status = code
            body = "{}"
        } else if query == "A & B #?", components?.queryItems?.count == 1, components?.fragment == nil {
            status = 200
            body = #"{"courses":[]}"#
        } else {
            status = 422
            body = "{}"
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite("GolfCourseAPI live diagnostic", .enabled(if: ProcessInfo.processInfo.environment["RUN_LIVE_GOLFCOURSE_API_TEST"] == "1"))
struct GolfCourseAPILiveDiagnosticTests {
    @Test("Live search and detail agree on opaque IDs and load a playable scorecard")
    func liveSearchAndDetail() async throws {
        let results = try await GolfCourseAPI.shared.searchCourses(with: "Verdae")
        let summary = try #require(results.first)
        #expect(summary.isSummary)
        #expect(!summary.id.isLegacy)
        let detail = try await GolfCourseAPI.shared.getCourseModel(by: summary.id)
        #expect(detail.id == summary.id)
        #expect(!detail.isSummary)
        let course = Course(canonicalGolfCourseAPI: detail)
        #expect(course.tees.contains { $0.holes.count == 18 })
        print("Live GolfCourseAPI verified: search returned \(results.count) matches; \(detail.id) loaded \(course.tees.count) tees.")
    }
}
