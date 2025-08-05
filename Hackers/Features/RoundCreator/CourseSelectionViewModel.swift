//
//  CourseSelectionViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

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
    
    // TODO: Favorites
    
    init() { print("init CourseSelectionViewModel") }
    deinit { print("deinit CourseSelectionViewModel") }
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

// MARK: - Search
extension CourseSelectionViewModel {
    func searchCourses(for query: String) async {
        addBreadcrumb("\(#function) [\(query)]")
        guard query.isPopulated else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            searchedCourses = try await GolfCourseAPI.shared.searchCourses(with: query)
            print("\(searchedCourses.count) courses found:")
            printPretty(searchedCourses)
        } catch let error {
            addBreadcrumb(.error, .golfCourseAPI, "error searching API from course selection", error)
        }
    }
}
