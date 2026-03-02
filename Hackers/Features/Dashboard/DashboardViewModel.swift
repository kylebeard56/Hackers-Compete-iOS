//
//  DashboardViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject, Loggable {
    @Published var scrollOffset: CGFloat = 0
    @Published var roundsSearchText: String = ""
    
    @Published private(set) var homeCourseName: String?
    @Published private(set) var homeCourseApiID: Int?
    @Published private(set) var homeCourseTeeID: String?
    
    init() {
        loadHomeCourse()
    }
    
    deinit { }
    
    func refreshHomeCourse() {
        loadHomeCourse()
    }
    
    func filteredRounds(from rounds: [Round]) -> [Round] {
        let query = roundsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isPopulated else { return rounds }
        
        return rounds.filter { round in
            if let course = round.configuration.courses.first {
                if course.courseInfo.name.lowercased().contains(query) { return true }
            }
            if round.shareCode.lowercased().contains(query) { return true }
            return false
        }
    }
    
    func playAtHomeCourse(routeToLobby: @escaping (String) -> Void) {
        guard let apiID = homeCourseApiID else { return }
        
        Task {
            do {
                let apiCourse = try await GolfCourseAPI.shared.getCourse(by: apiID)
                let course = Course(from: apiCourse)
                let tee = homeCourseTeeID.flatMap { id in course.tees.first(where: { $0.id == id }) }
                
                let selectionVM = CourseSelectionViewModel(course: course, tee: tee)
                selectionVM.selectedCourse = course
                selectionVM.selectedTee = tee ?? course.tees.first
                selectionVM.holeSegment = course.defaultSegment
                
                await selectionVM.createRoundLobby()
                
                if selectionVM.roundCreationID.isPopulated {
                    await MainActor.run {
                        routeToLobby(selectionVM.roundCreationID)
                    }
                }
            } catch {
                addBreadcrumb(level: .error, message: "Failed to create round at home course", error: error)
            }
        }
    }
    
    private func loadHomeCourse() {
        Task {
            homeCourseApiID = await Defaults.shared.getHomeCourseApiID()
            homeCourseName = await Defaults.shared.getHomeCourseName()
            homeCourseTeeID = await Defaults.shared.getHomeCourseTeeID()
        }
    }
}
