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

@MainActor
final class CourseSelectionViewModel: ObservableObject, Loggable {
    @Published var selectedChip: CourseSelectionChip = .recent
    
    /// Search
    @Published var searchedCourses: [GolfCourseAPIModel] = []
    @Published var isSearching = false
    
    /// Recent
    @Published var recentCourseCache: [Int] = [15724, 24833, 24749]
    @Published var recentCourses: [GolfCourseAPIModel] = []
    @Published var isLoadingRecents = false
    
    /// Nearby
    @Published var nearbyPlacemarks: [GolfCoursePlacemark] = []
    @Published var nearbyCourses: [GolfCourseAPIModel] = []
    @Published var isLoadingNearby = false
    
    // TODO: Favorites
    
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
            if let course = try? await GolfCourseAPI.shared.getCourse(by: id) {
                recentCourses.append(course)
            }
        }
    }
}

// MARK: - Nearby
extension CourseSelectionViewModel {
    func loadNearby(using location: CLLocation) async {
        addBreadcrumb(#function)
        
        isLoadingNearby = true
        defer { isLoadingNearby = false }
        
        let finder = GolfCourseFinder(for: location)
        nearbyCourses = []
        
        do {
            nearbyPlacemarks = try await finder.findGolfCourses()
            print("\(nearbyPlacemarks.count) courses found within 12 mile diameter")
            for p in nearbyPlacemarks {
                print("\(p.name) | \(p.formattedDistance)")
            }
        } catch let error {
            // TODO: How do we want to handle this?
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
            searchedCourses = try await GolfCourseAPI.shared.searchCourses(with: query)
            
            if let location {
                searchedCourses.sort { course1, course2 in
                    let loc1 = CLLocation(
                        latitude: course1.location.latitude ?? 0,
                        longitude: course1.location.longitude ?? 0
                    )
                    let loc2 = CLLocation(
                        latitude: course2.location.latitude ?? 0,
                        longitude: course2.location.longitude ?? 0
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
    
    
}
