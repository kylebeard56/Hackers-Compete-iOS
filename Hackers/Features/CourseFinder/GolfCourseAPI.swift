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
    case rateLimited(until: Date)
    case scorecardUnavailable
    case libraryUnavailable

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: "The course provider could not authorize the request. Please try again later."
        case .tooManyRequests: "Additional course searches are temporarily limited. You can still use saved courses or scan a scorecard."
        case .rateLimited(let until): "Additional course searches are limited until \(until.formatted(date: .omitted, time: .shortened)). You can still use saved courses or scan a scorecard."
        case .scorecardUnavailable: "This course was found, but a usable scorecard isn’t available yet. Try scanning its scorecard."
        case .libraryUnavailable: "Couldn’t check saved courses. Check your connection and try again, or choose Search more courses."
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
    private var retryAfter: Date?

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
            if let retryAfter, retryAfter > Date() { throw GolfCourseAPIError.rateLimited(until: retryAfter) }
            let (data, response) = try await session.data(for: request(for: url))
            guard let response = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.invalidResponse
            }
            addBreadcrumb(message: "GolfCourseAPI \(url.path): HTTP \(response.statusCode)")
            switch response.statusCode {
            case 200: break
            case 401, 403: throw GolfCourseAPIError.apiKeyMissing
            case 429:
                if let value = response.value(forHTTPHeaderField: "Retry-After") {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                    retryAfter = TimeInterval(value).map { Date().addingTimeInterval(max(0, $0)) } ?? formatter.date(from: value)
                }
                if let retryAfter, retryAfter > Date() { throw GolfCourseAPIError.rateLimited(until: retryAfter) }
                throw GolfCourseAPIError.tooManyRequests
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
    func course(byGolfCourseAPIID id: GolfCourseID) async throws -> Course?
    func course(byDocumentID id: String) async throws -> Course?
    func courses(matching query: String) async throws -> [Course]
    func cacheGolfCourseAPICourses(_ courses: [Course]) async
}

extension GolfCourseCacheProviding {
    func course(byDocumentID id: String) async throws -> Course? { nil }
}

@MainActor
struct FirebaseGolfCourseCache: GolfCourseCacheProviding {
    func course(byGolfCourseAPIID id: GolfCourseID) async throws -> Course? {
        try await FirebaseService.shared.getCachedGolfCourseAPIByID(id)
    }
    func course(byDocumentID id: String) async throws -> Course? {
        try await FirebaseService.shared.getLibraryCourse(id: id)
    }
    func courses(matching query: String) async throws -> [Course] {
        try await FirebaseService.shared.searchCachedGolfCourseAPICourses(matching: query)
    }
    func cacheGolfCourseAPICourses(_ courses: [Course]) async {
        await FirebaseService.shared.cacheGolfCourseAPICourses(courses)
    }
}

/// Shared Firestore library first; external discovery is an explicit fallback.
@MainActor
final class GolfCourseRepository: Loggable {
    static let shared = GolfCourseRepository()
    private let remote: GolfCourseAPIRemoteProviding
    private let cache: GolfCourseCacheProviding
    private var recentSearches: [String: (expires: Date, courses: [Course])] = [:]
    private var loadedCourses: [GolfCourseID: Course] = [:]
    private var pendingSaves: [UUID: Task<Void, Never>] = [:]

    init(remote: GolfCourseAPIRemoteProviding? = nil, cache: GolfCourseCacheProviding? = nil) {
        self.remote = remote ?? GolfCourseAPI.shared
        self.cache = cache ?? FirebaseGolfCourseCache()
    }

    func cachedCourse(for entry: CourseHistoryEntry) async throws -> Course? {
        switch entry.courseIDType {
        case .courseAPI:
            guard let id = GolfCourseID(entry.courseID) else { return nil }
            return try await cache.course(byGolfCourseAPIID: id)
        case .manual:
            return try await cache.course(byDocumentID: entry.courseID)
        }
    }

    func course(by id: GolfCourseID) async throws -> Course {
        let start = Date()
        if let loaded = loadedCourses[id], loaded.hasPlayableScorecard { return loaded }
        let cached = try await cache.course(byGolfCourseAPIID: id)
        if let cached, cached.golfCourseApiID == id, cached.hasPlayableScorecard {
            loadedCourses[id] = cached
            addEvent("course_library.detail", eventProps: ["source": "firestore", "duration_ms": Date().timeIntervalSince(start) * 1000])
            return cached
        }
        let model = try await remote.getCourseModel(by: id)
        try Task.checkCancellation()
        let incoming = Course(canonicalGolfCourseAPI: model)
        guard incoming.hasPlayableScorecard else { throw GolfCourseAPIError.scorecardUnavailable }
        let resolved = cached?.mergingProviderCourse(incoming) ?? incoming
        guard resolved.hasPlayableScorecard else { throw GolfCourseAPIError.scorecardUnavailable }
        loadedCourses[id] = resolved
        persist([incoming])
        addEvent("course_library.detail", eventProps: ["source": "provider", "duration_ms": Date().timeIntervalSince(start) * 1000])
        return resolved
    }

    func searchCourses(with query: String, searchMore: Bool = false) async throws -> [Course] {
        let normalized = query.normalizedForSearch
        guard normalized.count >= 2 else { return [] }
        let start = Date()
        var saved: [Course] = []
        do { saved = try await cache.courses(matching: query) }
        catch {
            try Task.checkCancellation()
            addEvent("course_library.search", eventProps: ["source": "firestore", "outcome": "failed"])
            if !searchMore { throw GolfCourseAPIError.libraryUnavailable }
        }
        try Task.checkCancellation()
        if !searchMore, !saved.isEmpty {
            addEvent("course_library.search", eventProps: ["source": "firestore", "result_count": saved.count, "duration_ms": Date().timeIntervalSince(start) * 1000])
            return Course.deduplicated(saved)
        }
        if let remembered = recentSearches[normalized], remembered.expires > Date() {
            addEvent("course_library.search", eventProps: ["source": "session", "result_count": remembered.courses.count, "provider_calls": 0])
            return Course.deduplicated(saved + remembered.courses)
        }
        do {
            let models = try await remote.searchCourses(with: query)
            try Task.checkCancellation()
            let courses = models.map(Course.init(canonicalGolfCourseAPI:))
            recentSearches = recentSearches.filter { $0.value.expires > Date() }
            recentSearches[normalized] = (Date().addingTimeInterval(courses.isEmpty ? 60 : 300), courses)
            persist(courses)
            addEvent("course_library.search", eventProps: ["source": "provider", "provider_calls": 1, "result_count": courses.count, "duration_ms": Date().timeIntervalSince(start) * 1000])
            return Course.deduplicated(saved + courses)
        } catch {
            addEvent("course_library.search", eventProps: ["source": "provider", "outcome": "failed", "duration_ms": Date().timeIntervalSince(start) * 1000])
            throw error
        }
    }

    /// Compatibility for OCR/enrichment consumers. Interactive UI uses the provider-independent Course.
    func searchCourseModels(with query: String, includeScorecards: Bool = true) async throws -> [GolfCourseAPIModel] {
        let courses = try await searchCourses(with: query)
        var result: [GolfCourseAPIModel] = []
        for var candidate in courses {
            guard let id = candidate.golfCourseApiID else { continue }
            if includeScorecards, !candidate.hasPlayableScorecard { candidate = try await course(by: id) }
            if let model = GolfCourseAPIModel(cachedCourse: candidate) { result.append(model) }
        }
        return result
    }

    /// Repository owns best-effort writes so leaving the picker does not cancel ingestion.
    private func persist(_ courses: [Course]) {
        guard !courses.isEmpty else { return }
        let id = UUID()
        pendingSaves[id] = Task { [cache] in
            await cache.cacheGolfCourseAPICourses(courses)
            pendingSaves[id] = nil
        }
    }

    func finishPendingSaves() async {
        for task in Array(pendingSaves.values) { await task.value }
    }
}
