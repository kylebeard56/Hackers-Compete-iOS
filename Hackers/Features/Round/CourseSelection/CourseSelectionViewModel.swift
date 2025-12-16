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
        @unknown default:           return "Unexpected error"
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
    @Published var selectedCourse: Course = .init() { didSet { clearDefaultTee() } }
    @Published var showConfirmation = false
    @Published var holeSegment: HoleSegment = .full18
    @Published var selectedTee: Tee?
    
    /// Game Lobby
    @Published var isCreatingRound = false
    @Published var showRoundCreationError = false
    @Published var roundCreationID = ""
    
    /// Modify/Change
    @Published var modifyingCourse: Course?
    @Published var modifyingTee: Tee?
    @Published var modifiedSegment: CourseSegment?
    @Published var modificationRequested: Bool = false
    @Published var commitModification: Bool = false
    var isModifying: Bool { modifyingCourse.exists || modifyingTee.exists || modifiedSegment.exists }
    
    init(course: Course? = nil, tee: Tee? = nil) {
        print("init CourseSelectionViewModel")
        modifyingCourse = course
        modifyingTee = tee
        selectedTee = tee
    }
    
    deinit {
        print("deinit CourseSelectionViewModel")
    }
    
    func clearDefaultTee() {
        if selectedCourse.id != modifyingCourse?.id {
            selectedTee = nil
        }
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

// MARK: - Game Lobby

extension CourseSelectionViewModel {
    func createRoundLobby() async {
        addBreadcrumb("\(#function), course \(selectedCourse.id)")
        
        isCreatingRound = true
        defer { isCreatingRound = false }
        
        guard let user = await AppData.shared.user else {
            throwRoundCreationError(msg: "user not found")
            return
        }
        
        guard let players = try? await FirebaseService.shared.getPlayersByIDs(user.players).get(),
              let player = players.first(where: \.isPrimary) else {
            throwRoundCreationError(msg: "players not found")
            return
        }
        
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            courses: [ buildCourseSegment() ]
        )
        
        let shareCode = await FirebaseService.shared.getUniqueShareCode()
        
        var round = Round(
            id: HackersID.string(),
            shareCode: shareCode,
            createdBy: user.id,
            status: .lobby,
            players: [player.id],
            configuration: configuration,
            createdAt: .init(),
            lastUpdatedAt: .init()
        )
        
        var participant = RoundParticipant(
            id: HackersID.string(),
            userID: user.id,
            playerID: player.id,
            name: player.name,
            teeBoxID: "",
            originalHandicap: 0,
            adjustedHandicap: 0,
            teamID: nil,
            groupID: nil,
            teeOrder: nil,
            isHost: true,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )
        
        var segment = RoundSegment(
            id: HackersID.string(),
            roundID: round.id,
            holeRange: holeSegment.holeRange,
            gameFormat: .strokePlay,
            scoringUnits: [],
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )
        
        var teeGroup = TeeTimeGroup(
            id: HackersID.string(),
            index: 1,
            teeTime: nil,
            startingHole: holeSegment.holeRange.startHole,
            lastCompletedHole: nil,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )
        
        var redTeam = RoundTeam(
            id: HackersID.string(),
            name: TeamColor.teamValue(for: 0).1,
            color: TeamColor.teamValue(for: 0).0.rawValue,
            index: 0,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )
        
        var blueTeam = RoundTeam(
            id: HackersID.string(),
            name: TeamColor.teamValue(for: 1).1,
            color: TeamColor.teamValue(for: 1).0.rawValue,
            index: 1,
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )
        
        do {
            participant = try await participant.post().get()
            segment = try await segment.post().get()
            teeGroup = try await teeGroup.post().get()
            redTeam = try await redTeam.post().get()
            blueTeam = try await blueTeam.post().get()
            round = try await round.post().get()
            roundCreationID = round.id
        } catch let error {
            throwRoundCreationError(error: error)
        }
    }
    
    private func throwRoundCreationError(msg: String? = nil, error: Error? = nil) {
        Haptics.fire(.error)
        addBreadcrumb(.error, .gameLobby, "Failed to create game lobby: \(msg, default: "")", error)
        withAnimation(.easeIn(duration: 0.2)) {
            self.showRoundCreationError = true
        }
    }
    
    func buildCourseSegment() -> CourseSegment {
        .init(
            courseInfo: CourseInfo(course: selectedCourse, for: holeSegment),
            holeRange: holeSegment.holeRange,
            defaultTee: selectedTee?.id ?? nil
        )
    }
}

// MARK: - Update lobby course

extension CourseSelectionViewModel {
    func confirmCourseModification() {
        addBreadcrumb("\(#function), course \(selectedCourse.id)")
        self.modifiedSegment = buildCourseSegment()
        self.modificationRequested = true
    }
}
