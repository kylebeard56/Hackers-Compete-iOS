//
//  CourseSelectionViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import Combine
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
    @Published var nearbyCourseNames: [String] = []
    @Published var nearbyCourses: [GolfCourseAPIModel] = []
    @Published var isLoadingNearby = false
    
    // TODO: Favorites
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        print("init CourseSelectionViewModel")
        
        $selectedChip
            .subscribe(on: DispatchQueue.main)
            //.debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                if value == .nearby {
                    
                }
            })
            .store(in: &subscriptions)
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
    func loadNearby() async {
        addBreadcrumb(#function)
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
