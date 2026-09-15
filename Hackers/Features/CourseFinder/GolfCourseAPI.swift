//
//  GolfCourseAPI.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import Foundation
import SwiftUI

enum GolfCourseAPIError: Error, LocalizedError, Equatable {
    case invalidURL, invalidResponse, apiKeyMissing, tooManyRequests, invalidStatusCode(code: Int)
    case legacyCourseUnavailable

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: "The course provider could not authorize the request. Please try again later."
        case .tooManyRequests: "The course provider is busy. Please wait a moment and try again."
        case .legacyCourseUnavailable: "This saved course needs to be selected again. Search by its name to find the current scorecard."
        case .invalidStatusCode(let code): "The course provider could not load this course (HTTP \(code)). Please try again."
        case .invalidURL, .invalidResponse: "The course provider returned an unexpected response. Please try again later."
        }
    }
}

@MainActor
final class GolfCourseAPI: NSObject, Loggable {
    static let shared = GolfCourseAPI()
    
    private let baseURL = "https://api.golfcourseapi.com/v1"
    private let apiKey = "LDG3VZLYBMTO3VAGKT5SODV36Q"
    
    private let session: URLSession

    override init() {
        session = .shared
        print("init GolfCourseAPI")
        super.init()
    }

    init(session: URLSession) {
        self.session = session
        super.init()
    }

    deinit {
        print("deinit GolfCourseAPI")
    }
    
    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }
}

// MARK: - Provider requests

extension GolfCourseAPI {
    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel] {
        var components = URLComponents(string: "\(baseURL)/search")
        components?.queryItems = [URLQueryItem(name: "search_query", value: query)]
        guard let url = components?.url else { throw GolfCourseAPIError.invalidURL }
        let response = try await load(url)
        // IDs are opaque, and distinct courses can share an address. Preserve provider ranking.
        var seen: Set<GolfCourseID> = []
        return response.courses.filter { seen.insert($0.id).inserted }
    }

    func getCourseModel(by id: GolfCourseID) async throws -> GolfCourseAPIModel {
        guard id.isValid else { throw GolfCourseAPIError.invalidURL }
        // The provider explicitly no longer accepts numeric IDs. The repository checks cache first.
        guard !id.isLegacy else { throw GolfCourseAPIError.legacyCourseUnavailable }
        guard let url = URL(string: "\(baseURL)/courses/\(id)") else {
            throw GolfCourseAPIError.invalidURL
        }
        let response = try await load(url)
        guard let course = response.course, course.id == id, !course.isSummary else {
            throw GolfCourseAPIError.invalidResponse
        }
        return course
    }

    private func load(_ url: URL) async throws -> GolfCourseAPIResponse {
        do {
            let (data, response) = try await session.data(for: request(for: url))
            guard let response = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.invalidResponse
            }
            addBreadcrumb(message: "GolfCourseAPI \(url.path): HTTP \(response.statusCode)")
            switch response.statusCode {
            case 200: break
            case 401, 403: throw GolfCourseAPIError.apiKeyMissing
            case 429: throw GolfCourseAPIError.tooManyRequests
            default: throw GolfCourseAPIError.invalidStatusCode(code: response.statusCode)
            }
            return try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)
        } catch {
            addBreadcrumb(level: .error, message: "GolfCourseAPI request failed: \(url.path)", error: error)
            throw error
        }
    }
}

// MARK: - Cache-first Repository

@MainActor
protocol GolfCourseAPIRemoteProviding {
    func getCourseModel(by id: GolfCourseID) async throws -> GolfCourseAPIModel
    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel]
}

extension GolfCourseAPI: GolfCourseAPIRemoteProviding {}

@MainActor
protocol GolfCourseCacheProviding {
    func course(byGolfCourseAPIID id: GolfCourseID) async -> Course?
    func courses(matching query: String) async -> [Course]
    func cacheGolfCourseAPICourses(_ courses: [Course]) async
}

@MainActor
struct FirebaseGolfCourseCache: GolfCourseCacheProviding {
    func course(byGolfCourseAPIID id: GolfCourseID) async -> Course? {
        await FirebaseService.shared.getCachedGolfCourseAPIByID(id)
    }

    func courses(matching query: String) async -> [Course] {
        await FirebaseService.shared.searchCachedGolfCourseAPICourses(matching: query)
    }

    func cacheGolfCourseAPICourses(_ courses: [Course]) async {
        await FirebaseService.shared.cacheGolfCourseAPICoursesIfMissing(courses)
    }
}

/// The single entry point for GolfCourseAPI data used by the app.
///
/// Provider course IDs are resolved from Firebase first. Remote successes are converted to the
/// app's stable `Course` representation and written back to Firebase before being returned.
@MainActor
final class GolfCourseRepository: Loggable {
    static let shared = GolfCourseRepository()

    private let remote: GolfCourseAPIRemoteProviding
    private let cache: GolfCourseCacheProviding

    init() {
        self.remote = GolfCourseAPI.shared
        self.cache = FirebaseGolfCourseCache()
    }

    init(
        remote: GolfCourseAPIRemoteProviding,
        cache: GolfCourseCacheProviding
    ) {
        self.remote = remote
        self.cache = cache
    }

    func course(by id: GolfCourseID) async throws -> Course {
        if let cached = await cache.course(byGolfCourseAPIID: id),
           let cached = cached.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: id) {
            addBreadcrumb(message: "GolfCourseAPI cache hit for id: \(id)")
            return cached
        }

        addBreadcrumb(message: "GolfCourseAPI cache miss for id: \(id)")
        let model = try await remote.getCourseModel(by: id)
        let course = Course(canonicalGolfCourseAPI: model)
        await cache.cacheGolfCourseAPICourses([course])
        return course
    }

    /// Searches cache first, then the provider. Only full scorecards are written to cache.
    /// Interactive search defers detail loads; scoring/enrichment consumers request full models.
    func searchCourseModels(with query: String, includeScorecards: Bool = true) async throws -> [GolfCourseAPIModel] {
        let cached = await cache.courses(matching: query)
        let cachedModels = cached.compactMap { course -> GolfCourseAPIModel? in
            guard let id = course.golfCourseApiID,
                  let canonical = course.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: id) else { return nil }
            return GolfCourseAPIModel(cachedCourse: canonical)
        }
        if cachedModels.isPopulated {
            addBreadcrumb(message: "GolfCourseAPI cached search hit for query: \(query)")
            return cachedModels
        }

        addBreadcrumb(message: "GolfCourseAPI cached search miss for query: \(query)")
        var models = try await remote.searchCourses(with: query)
        if includeScorecards {
            for index in models.indices where models[index].isSummary {
                try Task.checkCancellation()
                models[index] = try await remote.getCourseModel(by: models[index].id)
            }
        }
        let courses = models.filter { !$0.isSummary }.map {
            Course(canonicalGolfCourseAPI: $0)
        }
        if !courses.isEmpty { await cache.cacheGolfCourseAPICourses(courses) }
        return models
    }
}
