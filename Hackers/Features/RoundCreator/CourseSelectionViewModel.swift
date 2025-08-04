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
    
    @Published var searchedCourses: [GolfCourseAPIModel] = []
    @Published var isSearching = false
    
    init() { print("init CourseSelectionViewModel") }
    deinit { print("deinit CourseSelectionViewModel") }
}

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
