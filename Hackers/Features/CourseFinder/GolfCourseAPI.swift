//
//  GolfCourseAPI.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import Foundation
import SwiftUI

enum GolfCourseAPIError: Error {
    case invalidURL, invalidResponse, apiKeyMissing, tooManyRequests, invalidStatusCode(code: Int)
}

@MainActor
final class GolfCourseAPI: NSObject, Loggable {
    static let shared = GolfCourseAPI()
    
    private let baseURL = "https://api.golfcourseapi.com/v1"
    private let apiKey = "LDG3VZLYBMTO3VAGKT5SODV36Q"
    
    override init() {
        print("init GolfCourseAPI")
        super.init()
    }

    deinit {
        print("deinit GolfCourseAPI")
    }
    
    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }
}

// MARK: - Search

extension GolfCourseAPI {
    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel] {
        addBreadcrumb(message: "Search courses with query: \(query)")
        guard let url = URL(string: "\(baseURL)/search?search_query=\(query)") else {
            throw GolfCourseAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request(for: url))
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 401:
                    throw GolfCourseAPIError.apiKeyMissing
                case 429:
                    throw GolfCourseAPIError.tooManyRequests
                default:
                    throw GolfCourseAPIError.invalidStatusCode(code: httpResponse.statusCode)
                }
            }
            
            let result = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)
            var courses = result.courses
            
            // Some courses are duplicated in the API database -> group by address and return highest course id (newest)
            courses = Dictionary(
                grouping: courses,
                by: { $0.location.address }
            )
            .compactMap { (address, duplicateCourses) in
                duplicateCourses.max(by: { $0.id < $1.id })
            }
            
            // TODO: Cross-reference to search any courses in our database
            
            // Remove hybrid tees for simplicity (i.e. some are Black / Blue)
            courses = courses.compactMap { originalCourse in
                var course = originalCourse
                course.tees = GolfCourseAPITees(
                    female: course.tees.female?.filter { !$0.teeName.contains("/") },
                    male: course.tees.male?.filter { !$0.teeName.contains("/") }
                )
                
                return course
            }

            return courses
        } catch let error {
            addBreadcrumb(level: .error, message: "failed to query golf courses by search", error: error)
            throw error
        }
    }
}

// MARK: - Fetch by ID

extension GolfCourseAPI {    
    /// Queries the Golf Course API
    func getCourseModel(by id: Int) async throws -> GolfCourseAPIModel {
        addBreadcrumb(message: "GET course by id: \(id)")

        guard let url = URL(string: "\(baseURL)/courses/\(id)") else {
            throw GolfCourseAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request(for: url))
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 401:
                    throw GolfCourseAPIError.apiKeyMissing
                case 429:
                    throw GolfCourseAPIError.tooManyRequests
                default:
                    throw GolfCourseAPIError.invalidStatusCode(code: httpResponse.statusCode)
                }
            }
            
            let result = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)
            guard let course = result.course else { throw GolfCourseAPIError.invalidResponse }
            return course
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "failed to get course from GolfCourseAPI by id",
                error: error
            )
            throw error
        }
    }
}

// MARK: - Cache-first Repository

@MainActor
protocol GolfCourseAPIRemoteProviding {
    func getCourseModel(by id: Int) async throws -> GolfCourseAPIModel
    func searchCourses(with query: String) async throws -> [GolfCourseAPIModel]
}

extension GolfCourseAPI: GolfCourseAPIRemoteProviding {}

@MainActor
protocol GolfCourseCacheProviding {
    func course(byGolfCourseAPIID id: Int) async -> Course?
    func courses(matching query: String) async -> [Course]
    func cacheGolfCourseAPICourses(_ courses: [Course]) async
}

@MainActor
struct FirebaseGolfCourseCache: GolfCourseCacheProviding {
    func course(byGolfCourseAPIID id: Int) async -> Course? {
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
/// Numeric course IDs are resolved from Firebase first. Remote successes are converted to the
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

    func course(by id: Int) async throws -> Course {
        if let cached = await cache.course(byGolfCourseAPIID: id),
           let canonical = cached.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: id) {
            addBreadcrumb(message: "GolfCourseAPI cache hit for id: \(id)")
            return canonical
        }

        addBreadcrumb(message: "GolfCourseAPI cache miss for id: \(id)")
        let model = try await remote.getCourseModel(by: id)
        let course = Course(canonicalGolfCourseAPI: model)
        await cache.cacheGolfCourseAPICourses([course])
        return course
    }

    /// Searches the local cache first, then uses GolfCourseAPI for a fuzzy fallback. Every remote
    /// result is written through so later matching searches can avoid the external API entirely.
    func searchCourseModels(with query: String) async throws -> [GolfCourseAPIModel] {
        let cached = await cache.courses(matching: query)
        let cachedModels = cached.compactMap { course -> GolfCourseAPIModel? in
            guard let apiID = course.golfCourseApiID,
                  let canonical = course.canonicalizedGolfCourseAPICacheEntry(expectedAPIID: apiID) else {
                return nil
            }
            return GolfCourseAPIModel(cachedCourse: canonical)
        }
        if cachedModels.isPopulated {
            addBreadcrumb(message: "GolfCourseAPI cached search hit for query: \(query)")
            return cachedModels
        }

        addBreadcrumb(message: "GolfCourseAPI cached search miss for query: \(query)")
        let models = try await remote.searchCourses(with: query)
        let courses = models.map {
            Course(canonicalGolfCourseAPI: $0)
        }
        await cache.cacheGolfCourseAPICourses(courses)
        return models
    }
}
