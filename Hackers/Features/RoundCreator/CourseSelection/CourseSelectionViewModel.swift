//
//  CourseSelectionViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import CoreLocation
import SwiftUI

enum CourseSelectionChip: String, CaseIterable {
    case recent = "Recent"
    case nearby = "Nearby"
    case favorite = "Favorites"
}

enum CourseSelectionError: Error {
    case couldntLoadNearby
    
    var label: String {
        switch self {
        case .couldntLoadNearby:    return "Couldn't load nearby"
        default:                    return "Unexpected error"
        }
    }
}

@MainActor
final class CourseSelectionViewModel: ObservableObject, Loggable {
    @Published var selectedChip: CourseSelectionChip = .recent
    @Published var currentError: CourseSelectionError?
    
    /// Search
    @Published var searchedCourses: [Course] = []
    @Published var isSearching = false
    
    /// Recent
    @Published var recentCourseCache: [Int] = [15724, 24833, 24749]
    @Published var recentCourses: [Course] = []
    @Published var isLoadingRecents = false
    
    /// Nearby
    @Published var nearbyPlacemarks: [GolfCoursePlacemark] = []
    @Published var nearbyCourses: [Course] = []
    @Published var isLoadingNearby = false
    @Published var isSearchingNearby = false
    
    // TODO: Favorites
    
    /// Confirmation
    @Published var selectedCourse: Course = .init()
    @Published var showConfirmation = false
    @Published var holeSegment: HoleSegment = .full18
    
    init() {
        print("init CourseSelectionViewModel")
    }
    
    deinit {
        print("deinit CourseSelectionViewModel")
    }
}

// MARK: - Recents
extension CourseSelectionViewModel {
    func loadRecents() async {
        addBreadcrumb(#function)
        guard recentCourseCache.isPopulated else { return }
        
        recentCourses = []
        isLoadingRecents = true
        defer { isLoadingRecents = false }
        
        for id in recentCourseCache {
            print("find by \(id)")
            if let apiCourse = try? await GolfCourseAPI.shared.getCourse(by: id) {
                let course = Course(from: apiCourse)
                recentCourses.append(course)
            }
        }
    }
}

// MARK: - Nearby
extension CourseSelectionViewModel {
    func loadNearby(using location: CLLocation, silently: Bool = false) async {
        addBreadcrumb(#function)
        
        isLoadingNearby = silently ? false : true
        defer { isLoadingNearby = false }
        
        let finder = GolfCourseFinder(for: location)
        nearbyCourses = []
        
        do {
            nearbyPlacemarks = try await finder.findGolfCourses()
            nearbyPlacemarks = nearbyPlacemarks.filter( { !$0.name.lowercased().contains("range") })
            print("\(nearbyPlacemarks.count) courses found within 12 mile diameter")
            for p in nearbyPlacemarks {
                print("\(p.name) | \(p.normalizedName) | \(p.formattedDistance)")
            }
        } catch let error {
            // TODO: How do we want to handle this?
            addBreadcrumb(.warning, .golfCourseAPI, "nearby placemark not found", error)
        }
    }
}

// MARK: - Search
extension CourseSelectionViewModel {
    func searchCourses(for query: String, using location: CLLocation? = nil) async {
        addBreadcrumb("\(#function) [\(query)]")
        guard query.isPopulated else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            let courses = try await GolfCourseAPI.shared.searchCourses(with: query)
            searchedCourses = courses.map { Course(from: $0) }
            
            if let location {
                searchedCourses.sort { course1, course2 in
                    let loc1 = CLLocation(
                        latitude: course1.location?.latitude ?? 0,
                        longitude: course1.location?.longitude ?? 0
                    )
                    let loc2 = CLLocation(
                        latitude: course2.location?.latitude ?? 0,
                        longitude: course2.location?.longitude ?? 0
                    )
                    
                    return loc1.distance(from: location) < loc2.distance(from: location)
                }
            }
            
            print("\(searchedCourses.count) courses found:")
            printPretty(searchedCourses)
        } catch let error {
            addBreadcrumb(.error, .golfCourseAPI, "error searching API from course selection", error)
        }
    }
    
    func getClosestCourse(from query: String, using location: CLLocation?) async throws -> Course? {
        addBreadcrumb("\(#function) [\(query)]")
        guard query.isPopulated else { return nil }
        guard let location else { return nil }
        
        let courses = try await GolfCourseAPI.shared.searchCourses(with: query).map { Course(from: $0) }
        printPretty(courses)
        
        // Only consider courses with valid coordinates
        let candidates = courses.compactMap { course -> (course: Course, dist: CLLocationDistance)? in
            let courseLoc = CLLocation(
                latitude: course.location?.latitude ?? 0,
                longitude: course.location?.longitude ?? 0
            )
            return (course, courseLoc.distance(from: location))
        }
        
        // Return the closest one, or nil if none had coords
        return candidates.min(by: { $0.dist < $1.dist })?.course
    }

}

// MARK: - Selection
extension CourseSelectionViewModel {
    func fetchFromNearby(using query: String, and location: CLLocation?) {
        addBreadcrumb("\(#function) [\(query)]")
        
        isSearchingNearby = true
        defer { isSearchingNearby = false }
        
        Task {
            if let course = try? await getClosestCourse(from: query, using: location) {
                select(course: course)
            } else {
                // TODO: Handle error somehow
            }
        }
    }
    
    func select(course: Course) {
        addBreadcrumb("\(#function) [\(course.id)]")
        UIApplication.shared.endEditing()
        selectedCourse = course
        showConfirmation = true
    }
}
