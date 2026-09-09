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

    @Test("Legacy UUID cache identity is canonicalized for recent-course loading")
    func legacyCacheIdentityIsCanonicalized() async throws {
        let legacy = Course(
            id: "legacy-generated-uuid",
            golfCourseApiID: 42,
            origin: .golfCourseAPI,
            clubName: "Cached Club",
            courseName: "Cached Course"
        )
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: 42))
        let cache = MockGolfCourseCache(coursesByID: [42: legacy])
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let recovered = try await repository.course(by: 42)

        #expect(recovered.id == "42")
        #expect(recovered.golfCourseApiID == 42)
        #expect(recovered.hasCanonicalGolfCourseAPIIdentity)
        #expect(remote.detailRequestIDs.isEmpty)
    }

    @Test("Legacy cache lookup rejects a different provider course")
    func legacyCacheIdentityRejectsMismatchedCourse() {
        let legacy = Course(
            id: "legacy-generated-uuid",
            golfCourseApiID: 7,
            origin: .golfCourseAPI,
            clubName: "Wrong Club",
            courseName: "Wrong Course"
        )

        #expect(legacy.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: 42) == nil)
    }


    @Test("Legacy cache rejects non-provider origins even when the provider ID matches")
    func legacyCacheRejectsOtherOrigins() {
        for origin in [CourseOrigin.hackers, .manual, .ocr, .unknown] {
            let course = Course(golfCourseApiID: 42, origin: origin)
            #expect(course.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: 42) == nil)
        }
    }

    @Test("Legacy detail and search preserve the same selected tee identity and scoring data")
    func legacyTeeIdentityMatchesSearch() async throws {
        let holes = (1...18).map { number in
            Hole(from: GolfCourseAPIHole(par: 4, yardage: 400, handicap: number), number: number)
        }
        let tee = Tee(
            id: "legacy-tee-uuid",
            name: "Blue",
            gender: Gender.male.rawValue,
            totalHoles: 18,
            holes: holes,
            ratingFull: 72.4,
            slopeFull: 131,
            ratingFront: 36.1,
            slopeFront: 129,
            ratingBack: 36.3,
            slopeBack: 133
        )
        let femaleTee = Tee(
            id: "legacy-female-tee",
            name: "Blue",
            gender: Gender.female.rawValue,
            totalHoles: 18,
            holes: holes,
            ratingFull: 76.4,
            slopeFull: 139,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
        let legacy = Course(
            id: "legacy-course-uuid",
            golfCourseApiID: 42,
            origin: .golfCourseAPI,
            clubName: "Test Club",
            courseName: "Test Course",
            location: CourseLocation(from: makeAPIModel(id: 42).location),
            tees: [femaleTee, tee]
        )
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: 42))
        let cache = MockGolfCourseCache(coursesByID: [42: legacy], searchResults: [legacy])
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let searchModels = try await repository.searchCourseModels(with: "Test Club")
        let searchCourse = Course(canonicalGolfCourseAPI: try #require(searchModels.first))
        let selectedTee = try #require(searchCourse.tees.first { $0.id == "blue_male" })
        let detail = try await repository.course(by: 42)
        let restoredTee = try #require(detail.tees.first { $0.id == selectedTee.id })

        #expect(Set(detail.tees.map(\.id)) == Set(searchCourse.tees.map(\.id)))
        #expect(restoredTee.name == tee.name)
        #expect(restoredTee.gender == tee.gender)
        #expect(restoredTee.totalHoles == tee.totalHoles)
        #expect(restoredTee.holes == tee.holes)
        #expect(restoredTee.ratingFull == tee.ratingFull)
        #expect(restoredTee.slopeFull == tee.slopeFull)
        #expect(restoredTee.ratingFront == tee.ratingFront)
        #expect(restoredTee.slopeFront == tee.slopeFront)
        #expect(restoredTee.ratingBack == tee.ratingBack)
        #expect(restoredTee.slopeBack == tee.slopeBack)
        #expect(detail.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: 42) == detail)
        #expect(remote.detailRequestIDs.isEmpty)
        #expect(remote.searchQueries.isEmpty)
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

    @Test("Legacy UUID cached search result avoids GolfCourseAPI")
    func legacyCachedSearchAvoidsRemoteRequest() async throws {
        var legacy = Course(canonicalGolfCourseAPI: makeAPIModel(id: 37140))
        legacy.id = "legacy-generated-uuid"
        let remote = MockGolfCourseRemote(courseModel: makeAPIModel(id: 1))
        let cache = MockGolfCourseCache(searchResults: [legacy])
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let models = try await repository.searchCourseModels(with: "Test Club")

        #expect(models.map(\.id) == [37140])
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

    private func makeAPIModel(id: Int) -> GolfCourseAPIModel {
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

    private func apiJSON(id: Int) -> String {
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
    private(set) var detailRequestIDs: [Int] = []
    private(set) var searchQueries: [String] = []

    init(
        courseModel: GolfCourseAPIModel,
        searchModels: [GolfCourseAPIModel] = []
    ) {
        self.courseModel = courseModel
        self.searchModels = searchModels
    }

    func getCourseModel(by id: Int) async throws -> GolfCourseAPIModel {
        detailRequestIDs.append(id)
        return courseModel
    }

    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel] {
        searchQueries.append(query)
        return searchModels
    }
}

@MainActor
private final class MockGolfCourseCache: GolfCourseCacheProviding {
    let coursesByID: [Int: Course]
    let searchResults: [Course]
    private(set) var cachedBatches: [[Course]] = []
    private(set) var searchQueries: [String] = []

    init(coursesByID: [Int: Course] = [:], searchResults: [Course] = []) {
        self.coursesByID = coursesByID
        self.searchResults = searchResults
    }

    func course(byGolfCourseAPIID id: Int) async -> Course? {
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
