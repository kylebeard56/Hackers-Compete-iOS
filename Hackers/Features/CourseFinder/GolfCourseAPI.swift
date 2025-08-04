//
//  GolfCourseAPI.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import Foundation
import SwiftUI

enum GolfCourseAPIError: Error {
    case invalidURL, invalidResponse, apiKeyMissing, invalidStatusCode(code: Int)
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
        addBreadcrumb("\(#function) for \(query)")
        guard let url = URL(string: "\(baseURL)/search?search_query=\(query)") else {
            throw GolfCourseAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request(for: url))
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw httpResponse.statusCode == 401
                ? GolfCourseAPIError.apiKeyMissing
                : GolfCourseAPIError.invalidStatusCode(code: httpResponse.statusCode)
            }
            
            let result = try JSONDecoder().decode(GolfCourseAPIResponse.self, from: data)
            
            // Some courses are duplicated in the API database -> group by address and return highest course id (newest)
            var courses = Dictionary(
                grouping: result.courses,
                by: { $0.location.address }
            )
            .compactMap { (address, duplicateCourses) in
                duplicateCourses.max(by: { $0.id < $1.id })
            }
            
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
            addBreadcrumb(.error, .golfCourseAPI, "failed to query golf courses by search", error)
            throw error
        }
    }
}

// MARK: - Fetch by ID

extension GolfCourseAPI {
    func getCourse(by id: Int) async throws -> GolfCourseAPIModel {
        addBreadcrumb("\(#function) by \(id)")

        guard let url = URL(string: "\(baseURL)/courses/\(id)") else {
            throw GolfCourseAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request(for: url))
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw httpResponse.statusCode == 401
                ? GolfCourseAPIError.apiKeyMissing
                : GolfCourseAPIError.invalidStatusCode(code: httpResponse.statusCode)
            }
            
            let result = try JSONDecoder().decode(GolfCourseAPIModel.self, from: data)
            return result
        } catch let error {
            addBreadcrumb(.error, .golfCourseAPI, "failed to get golf course by id", error)
            throw error
        }
    }
}
