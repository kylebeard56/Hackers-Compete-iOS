//
//  GolfCourseFailureRegressionTests.swift
//  HackersUnitTests
//

import Foundation
import Testing
@testable import Hackers

@MainActor
@Suite("Golf Course Failure Regressions")
struct GolfCourseFailureRegressionTests {
    @Test("Failed course requests preserve the error and can be retried")
    func detailFailureDoesNotPoisonRetry() async throws {
        let remote = RegressionGolfCourseRemote(detailResult: .failure(CourseRepositoryFailure.offline))
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        do {
            _ = try await repository.course(by: 42)
            Issue.record("An unavailable provider must not produce a course")
        } catch {
            #expect(error as? CourseRepositoryFailure == .offline)
        }
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.isEmpty)

        remote.detailResult = .success(makeAPIModel(id: 42))
        let recovered = try await repository.course(by: 42)

        #expect(recovered.golfCourseApiID == 42)
        #expect(recovered.hasCanonicalGolfCourseAPIIdentity)
        #expect(remote.detailRequestIDs == [42, 42])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.map { $0.map(\.id) } == [["42"]])
    }

    @Test("Failed searches preserve the error instead of becoming empty successes")
    func searchFailureDoesNotPoisonRetry() async throws {
        let remote = RegressionGolfCourseRemote(searchResult: .failure(CourseRepositoryFailure.offline))
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        do {
            _ = try await repository.searchCourseModels(with: "Recovery Club")
            Issue.record("An unavailable provider must not look like an empty search")
        } catch {
            #expect(error as? CourseRepositoryFailure == .offline)
        }
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.isEmpty)

        remote.searchResult = .success([makeAPIModel(id: 42)])
        let recovered = try await repository.searchCourseModels(with: "Recovery Club")

        #expect(recovered.map(\.id) == [42])
        #expect(remote.searchQueries == ["Recovery Club", "Recovery Club"])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.map { $0.map(\.id) } == [["42"]])
    }

    @Test("Canceled course requests preserve cancellation and do not write the cache")
    func detailCancellationPropagates() async {
        let remote = RegressionGolfCourseRemote(detailResult: .failure(CancellationError()))
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        do {
            _ = try await repository.course(by: 42)
            Issue.record("A canceled request must remain canceled")
        } catch {
            #expect(error is CancellationError)
        }

        #expect(remote.detailRequestIDs == [42])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.isEmpty)
    }

    @Test("Canceled searches preserve cancellation and do not write the cache")
    func searchCancellationPropagates() async {
        let remote = RegressionGolfCourseRemote(searchResult: .failure(CancellationError()))
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        do {
            _ = try await repository.searchCourseModels(with: "Recovery Club")
            Issue.record("A canceled search must remain canceled")
        } catch {
            #expect(error is CancellationError)
        }

        #expect(remote.searchQueries == ["Recovery Club"])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.isEmpty)
    }

    @Test("Explicit provider search supplements cached rows without usable provider scorecards")
    func unusableCachedRowsDoNotSuppressRemoteSearch() async throws {
        let remote = RegressionGolfCourseRemote(searchResult: .success([makeAPIModel(id: 42)]))
        let cache = RegressionGolfCourseCache(searchResultsOverride: unusableCachedCourses())
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let courses = try await repository.searchCourses(with: "Recovery Club", searchMore: true)

        #expect(courses.contains { $0.golfCourseApiID == 42 && $0.hasPlayableScorecard })
        #expect(remote.searchQueries == ["Recovery Club"])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.map { $0.map(\.id) } == [["42"]])
    }

    @Test("Valid cached search rows remain available among unusable rows during an outage")
    func usableCachedRowsSurviveMixedSearchResults() async throws {
        let first = Course(canonicalGolfCourseAPI: makeAPIModel(id: 42))
        let second = Course(canonicalGolfCourseAPI: makeAPIModel(id: 43))
        let remote = RegressionGolfCourseRemote(searchResult: .failure(CourseRepositoryFailure.offline))
        let cache = RegressionGolfCourseCache(
            searchResultsOverride: [first] + unusableCachedCourses() + [second]
        )
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let models = try await repository.searchCourseModels(with: "Recovery Club")

        #expect(models.map(\.id) == [42, 43])
        #expect(models.map(\.courseName) == ["Recovery Course 42", "Recovery Course 43"])
        #expect(remote.searchQueries.isEmpty)
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.isEmpty)
    }

    @Test("An unsuccessful cache write does not discard a fetched course or prevent retry")
    func detailRemainsAvailableWhenCacheDoesNotPersist() async throws {
        let remote = RegressionGolfCourseRemote(detailResult: .success(makeAPIModel(id: 42)))
        let cache = RegressionGolfCourseCache(persistsWrites: false)
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let first = try await repository.course(by: 42)
        let second = try await repository.course(by: 42)
        #expect(remote.detailRequestIDs == [42]) // The current session retains fetched detail.
        await repository.finishPendingSaves()
        let restarted = GolfCourseRepository(remote: remote, cache: cache)
        let retried = try await restarted.course(by: 42)
        await restarted.finishPendingSaves()
        #expect(retried.id == first.id)

        #expect(first.id == "42")
        #expect(first.courseName == "Recovery Course 42")
        #expect(second.id == first.id)
        #expect(second.hasCanonicalGolfCourseAPIIdentity)
        #expect(remote.detailRequestIDs == [42, 42])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.map { $0.map(\.id) } == [["42"], ["42"]])
    }

    @Test("An unsuccessful cache write preserves search results and provider ordering")
    func searchRemainsAvailableWhenCacheDoesNotPersist() async throws {
        let remote = RegressionGolfCourseRemote(
            searchResult: .success([makeAPIModel(id: 43), makeAPIModel(id: 42)])
        )
        let cache = RegressionGolfCourseCache(persistsWrites: false)
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let first = try await repository.searchCourseModels(with: "Recovery Club")
        let second = try await repository.searchCourseModels(with: "Recovery Club")
        #expect(remote.searchQueries == ["Recovery Club"]) // Repeated session searches reuse results.
        await repository.finishPendingSaves()
        let restarted = GolfCourseRepository(remote: remote, cache: cache)
        let retried = try await restarted.searchCourseModels(with: "Recovery Club")
        await restarted.finishPendingSaves()
        #expect(retried.map(\.id) == first.map(\.id))

        #expect(first.map(\.id) == [43, 42])
        #expect(second.map(\.id) == [43, 42])
        #expect(remote.searchQueries == ["Recovery Club", "Recovery Club"])
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.map { $0.map(\.id) } == [["43", "42"], ["43", "42"]])
    }

    @Test("Search write-through keeps course selection available during a provider outage")
    func searchPrimesSubsequentDetailLookup() async throws {
        let remote = RegressionGolfCourseRemote(
            detailResult: .failure(CourseRepositoryFailure.offline),
            searchResult: .success([makeAPIModel(id: 42), makeAPIModel(id: 43)])
        )
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        _ = try await repository.searchCourseModels(with: "Recovery Club")
        await repository.finishPendingSaves()
        let selected = try await repository.course(by: 43)

        #expect(selected.hasCanonicalGolfCourseAPIIdentity)
        #expect(selected.golfCourseApiID == 43)
        #expect(selected.courseName == "Recovery Course 43")
        #expect(remote.detailRequestIDs.isEmpty)
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.count == 1)
    }

    @Test("Detail write-through keeps later searches available during a provider outage")
    func detailPrimesSubsequentSearch() async throws {
        let remote = RegressionGolfCourseRemote(
            detailResult: .success(makeAPIModel(id: 42)),
            searchResult: .failure(CourseRepositoryFailure.offline)
        )
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        _ = try await repository.course(by: 42)
        await repository.finishPendingSaves()
        let models = try await repository.searchCourseModels(with: "Recovery Club")

        #expect(models.map(\.id) == [42])
        #expect(models.first?.clubName == "Recovery Club")
        #expect(remote.searchQueries.isEmpty)
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.count == 1)
    }

    @Test("An empty provider search is cached briefly and can recover in a new session")
    func emptySearchDoesNotPoisonSubsequentSearch() async throws {
        let remote = RegressionGolfCourseRemote(searchResult: .success([]))
        let cache = RegressionGolfCourseCache()
        let repository = GolfCourseRepository(remote: remote, cache: cache)

        let empty = try await repository.searchCourseModels(with: "Recovery Club")
        #expect(empty.isEmpty)
        await repository.finishPendingSaves()
        #expect(cache.cachedBatches.flatMap { $0 }.isEmpty)

        remote.searchResult = .success([makeAPIModel(id: 42)])
        let rememberedEmpty = try await repository.searchCourseModels(with: "Recovery Club")
        #expect(rememberedEmpty.isEmpty)
        #expect(remote.searchQueries == ["Recovery Club"])
        let restarted = GolfCourseRepository(remote: remote, cache: cache)
        let recovered = try await restarted.searchCourseModels(with: "Recovery Club")

        #expect(recovered.map(\.id) == [42])
        #expect(remote.searchQueries == ["Recovery Club", "Recovery Club"])
        await restarted.finishPendingSaves()
        #expect(cache.cachedBatches.flatMap { $0 }.map(\.id) == ["42"])
    }

    private func makeAPIModel(id: GolfCourseID) -> GolfCourseAPIModel {
        GolfCourseAPIModel(
            id: id,
            clubName: "Recovery Club",
            courseName: "Recovery Course \(id)",
            location: GolfCourseAPILocation(
                address: "1 Fairway Drive",
                city: "Greenville",
                state: "SC",
                country: "US",
                latitude: 34.85,
                longitude: -82.40
            ),
            tees: GolfCourseAPITees(female: nil, male: [GolfCourseAPITee(cachedTee: Tee(
                id: "white_male", name: "White", gender: "male", totalHoles: 18,
                holes: (1...18).map { Hole(number: $0, par: 4, yardage: 350, handicap: $0) },
                ratingFull: 72, slopeFull: 113, ratingFront: 36, slopeFront: 113,
                ratingBack: 36, slopeBack: 113
            ))])
        )
    }

    private func unusableCachedCourses() -> [Course] {
        let location = Course(canonicalGolfCourseAPI: makeAPIModel(id: 42)).location
        return [
            Course(
                id: "legacy-random-document-id",
                golfCourseApiID: 50,
                origin: .hackers,
                clubName: "Recovery Club",
                courseName: "Non-provider Course",
                location: location
            ),
            Course(
                id: "51",
                golfCourseApiID: 51,
                origin: .manual,
                clubName: "Recovery Club",
                courseName: "Manual Course",
                location: location
            ),
            Course(
                id: "52",
                origin: .golfCourseAPI,
                clubName: "Recovery Club",
                courseName: "Missing Provider Identity",
                location: location
            )
        ]
    }
}

private enum CourseRepositoryFailure: Error, Equatable {
    case offline
    case unexpectedRemoteCall
}

@MainActor
private final class RegressionGolfCourseRemote: GolfCourseAPIRemoteProviding {
    var detailResult: Result<GolfCourseAPIModel, Error>
    var searchResult: Result<[GolfCourseAPIModel], Error>
    private(set) var detailRequestIDs: [GolfCourseID] = []
    private(set) var searchQueries: [String] = []

    init(
        detailResult: Result<GolfCourseAPIModel, Error> = .failure(CourseRepositoryFailure.unexpectedRemoteCall),
        searchResult: Result<[GolfCourseAPIModel], Error> = .failure(CourseRepositoryFailure.unexpectedRemoteCall)
    ) {
        self.detailResult = detailResult
        self.searchResult = searchResult
    }

    func getCourseModel(by id: GolfCourseID) async throws -> GolfCourseAPIModel {
        detailRequestIDs.append(id)
        return try detailResult.get()
    }

    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel] {
        searchQueries.append(query)
        return try searchResult.get()
    }
}

@MainActor
private final class RegressionGolfCourseCache: GolfCourseCacheProviding {
    private let persistsWrites: Bool
    private let searchResultsOverride: [Course]?
    private var coursesByID: [GolfCourseID: Course] = [:]
    private(set) var cachedBatches: [[Course]] = []

    init(persistsWrites: Bool = true, searchResultsOverride: [Course]? = nil) {
        self.persistsWrites = persistsWrites
        self.searchResultsOverride = searchResultsOverride
    }

    func course(byGolfCourseAPIID id: GolfCourseID) async -> Course? {
        coursesByID[id]
    }

    func courses(matching query: String) async -> [Course] {
        searchResultsOverride ?? coursesByID.values.filter { $0.matchesCachedSearch(query: query) }
    }

    func cacheGolfCourseAPICourses(_ courses: [Course]) async {
        cachedBatches.append(courses)
        guard persistsWrites else { return }
        for course in courses {
            if let id = course.golfCourseApiID {
                coursesByID[id] = course
            }
        }
    }
}
