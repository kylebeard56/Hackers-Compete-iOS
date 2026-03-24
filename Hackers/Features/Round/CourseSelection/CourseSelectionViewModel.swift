//
//  CourseSelectionViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import CoreLocation
import SwiftUI
import UIKit

enum CourseSelectionChip: String, CaseIterable {
    case recent = "Recent"
    case nearby = "Nearby"
    //case favorite = "Favorites"
}

enum CourseSelectionError: Error {
    case couldntLoadNearby
    case couldntFetchCourse
    
    var label: String {
        switch self {
        case .couldntLoadNearby:    return "Couldn't load nearby"
        case .couldntFetchCourse:   return "Couldn't load course"
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
    @Published var recentCourseEntries: [CourseHistoryEntry] = []
    @Published var isLoadingRecents = false
    @Published var showCourseFetchError = false
    
    /// Nearby
    @Published var nearbyPlacemarks: [GolfCoursePlacemark] = []
    @Published var nearbyCourses: [Course] = []
    @Published var isLoadingNearby = false
    @Published var isSearchingNearby = false
    
    // TODO: Favorites
    
    /// Confirmation
    @Published var selectedCourse: Course = .init() { didSet { clearDefaultTee() } }
    @Published var showCourseEdit = false
    @Published var showConfirmation = false
    @Published var holeSegment: HoleSegment = .full18
    @Published var selectedTee: Tee?
    
    /// Game Lobby
    @Published var isCreatingRound = false
    @Published var showRoundCreationError = false
    @Published var roundCreationID = ""
    
    /// Scorecard OCR
    @Published var isScanningScorecard = false
    @Published var scorecardScanError: String?

    /// Modify/Change
    @Published var modifyingCourse: Course?
    @Published var modifyingTee: Tee?
    @Published var modifiedSegment: CourseSegment?
    @Published var modificationRequested: Bool = false
    @Published var commitModification: Bool = false
    var isModifying: Bool { modifyingCourse.exists || modifyingTee.exists || modifiedSegment.exists }
    
    @Published var globalDismiss: Bool = false
    
    /// When true, confirmation saves as home course instead of creating a round.
    var isSetHomeCourseMode: Bool = false
    var onSetHomeCourse: ((Int, String, String?, String?) -> Void)?

    /// When true, confirmation saves as series default course instead of creating a round.
    var isSetSeriesDefaultCourseMode: Bool = false
    var onSetSeriesDefaultCourse: ((String, String, String?) -> Void)?

    /// When true, confirmation passes course segment to callback for series round creation.
    var isSetSeriesRoundCourseMode: Bool = false
    var onSetSeriesRoundCourse: ((CourseSegment) -> Void)?
    
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
        addBreadcrumb()
        
        recentCourseEntries = []
        isLoadingRecents = true
        defer { isLoadingRecents = false }
        
        guard let user = await AppData.shared.user, user.players.isPopulated else { return }
        
        switch await FirebaseService.shared.getPlayersByIDs(user.players) {
        case .success(let players):
            var merged: [String: CourseHistoryEntry] = [:]
            for player in players {
                for (key, entry) in player.courseHistory {
                    let existing = merged[key]
                    if existing == nil || (entry.lastPlayedAt.unix > (existing?.lastPlayedAt.unix ?? 0)) {
                        merged[key] = entry
                    }
                }
            }
            recentCourseEntries = merged.values.sorted { $0.lastPlayedAt.unix > $1.lastPlayedAt.unix }
        case .failure:
            recentCourseEntries = []
        }
    }
    
    func selectFromRecent(entry: CourseHistoryEntry) async {
        addBreadcrumb(message: "\(#function) [\(entry.compositeKey)]")
        Haptics.fire(.light)
        
        let course: Course?
        switch entry.courseIDType {
        case .courseAPI:
            guard let id = Int(entry.courseID) else {
                showCourseFetchError = true
                Haptics.fire(.error)
                return
            }
            do {
                let apiCourse = try await GolfCourseAPI.shared.getCourse(by: id)
                course = Course(from: apiCourse)
            } catch {
                addBreadcrumb(level: .error, message: "Failed to fetch course by API id \(id)", error: error)
                showCourseFetchError = true
                Haptics.fire(.error)
                return
            }
        case .manual:
            switch await FirebaseService.shared.getCourseByID(entry.courseID) {
            case .success(let c): course = c
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to fetch manual course \(entry.courseID)", error: error)
                showCourseFetchError = true
                Haptics.fire(.error)
                return
            }
        }
        
        if let course {
            select(course: course)
        }
    }
}

// MARK: - Nearby
extension CourseSelectionViewModel {
    func loadNearby(using location: CLLocation, silently: Bool = false) async {
        addBreadcrumb()
        
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
            addBreadcrumb(level: .warning, message: "nearby placemark not found", error: error)
        }
    }
}

// MARK: - Search
extension CourseSelectionViewModel {
    func searchCourses(for query: String, using location: CLLocation? = nil) async {
        addBreadcrumb(message: "\(#function) [\(query)]")
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
            addBreadcrumb(level: .error, message: "error searching API from course selection", error: error)
        }
    }
    
    func getClosestCourse(from query: String, using location: CLLocation?) async throws -> Course? {
        addBreadcrumb(message: "\(#function) [\(query)]")
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

// MARK: - Scorecard OCR
extension CourseSelectionViewModel {
    func scanScorecard(image: UIImage, userNotes: String? = nil, vision: ScorecardScanVisionModel = .defaultSelection) async {
        addBreadcrumb()
        isScanningScorecard = true
        scorecardScanError = nil
        defer { isScanningScorecard = false }

        do {
            let course = try await CourseScorecardOCRService.shared.extractCourse(from: image, userNotes: userNotes, vision: vision)
            printPretty(course)
            select(course: course)
        } catch CourseScorecardOCRError.apiKeyMissing {
            let provider = vision.config.provider
            let keyName = provider == .anthropic ? "ANTHROPIC_API_KEY" : "OPENAI_API_KEY"
            addBreadcrumb(level: .error, message: "Failed to read scorecard: \(keyName) missing")
            scorecardScanError = "API key missing. Add \(keyName) to your config."
        } catch CourseScorecardOCRError.decodingFailed {
            addBreadcrumb(level: .error, message: "Failed to read scorecard")
            scorecardScanError = "Couldn't read the scorecard. Try a clearer photo."
        } catch CourseScorecardOCRError.requestTooLarge {
            addBreadcrumb(level: .error, message: "Scorecard image too large")
            scorecardScanError = "Image too large. Try a smaller photo."
        } catch CourseScorecardOCRError.rateLimitExceeded {
            addBreadcrumb(level: .error, message: "AI rate limit exceeded")
            scorecardScanError = "Rate limit exceeded. Try again later."
        } catch CourseScorecardOCRError.overloaded {
            addBreadcrumb(level: .error, message: "AI service overloaded")
            scorecardScanError = "AI is busy. Try again in a moment."
        } catch {
            addBreadcrumb(level: .error, message: "Failed to scan scorecard", error: error)
            scorecardScanError = "Scan failed. Please try again."
        }
    }
}

// MARK: - Selection
extension CourseSelectionViewModel {
    func fetchFromNearby(using query: String, and location: CLLocation?) {
        addBreadcrumb(message: "\(#function) [\(query)]")
        
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
        addBreadcrumb(message: "\(#function) [\(course.id)]")
        UIApplication.shared.endEditing()
        selectedCourse = course
        let isManualAndNeedsEntry = course.origin == CourseOrigin.manual.rawValue
            && course.courseName.isEmpty
            && course.tees.isEmpty
        let isOCRNeedsReview = course.origin == CourseOrigin.ocr.rawValue
        if isManualAndNeedsEntry || isOCRNeedsReview {
            showCourseEdit = true
            showConfirmation = false
        } else {
            showCourseEdit = false
            showConfirmation = true
        }
    }

    /// Called when user saves from CourseEditView (edit-from-confirmation flow). Only persists to Firebase when the course was actually edited.
    func saveCourseIfEdited(course: Course, wasEdited: Bool) async {
        addBreadcrumb(message: "\(#function), course \(course.id), wasEdited \(wasEdited)")
        var finalCourse = course
        if wasEdited && !course.isEmpty {
            switch await FirebaseService.shared.saveCourse(course) {
            case .success(let saved):
                finalCourse = saved
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to save course", error: error)
            }
        }
        selectedCourse = finalCourse
    }
}

// MARK: - Game Lobby

extension CourseSelectionViewModel {
    func createRoundLobby() async {
        addBreadcrumb(message: "\(#function), course \(selectedCourse.id)")
        
        isCreatingRound = true
        defer { isCreatingRound = false }
        
        guard let user = await AppData.shared.user else {
            throwRoundCreationError(msg: "user not found")
            return
        }
        
        guard let player = await AppData.shared.getPrimaryPlayer() else {
            throwRoundCreationError(msg: "primary player not found")
            return
        }
        
        let template = FormatTemplateRegistry.strokePlayGross
        let configuration = RoundConfiguration(
            primaryFormat: .strokePlay,
            formatSummary: RoundFormatSummary(from: template),
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
        
        var segment = RoundSegment(
            id: HackersID.string(),
            roundID: round.id,
            holeRange: holeSegment.holeRange,
            gameFormat: .strokePlay,
            templateID: template.id,
            scoringUnits: [],
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: round.id
        )
        
        var teeGroup = TeeTimeGroup(
            id: HackersID.string(),
            index: 0,
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
        
        var participant = RoundParticipant(
            id: HackersID.string(),
            userID: user.id,
            playerID: player.id,
            name: player.name,
            teeBoxID: selectedTee?.id ?? "",
            originalHandicap: 0,
            adjustedHandicap: 0,
            teamID: nil,
            groupID: teeGroup.id,
            teeOrder: nil,
            isHost: true,
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
        addBreadcrumb(level: .error, message: "Failed to create game lobby: \(msg, default: "")", error: error)
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
        addBreadcrumb(message: "\(#function), course \(selectedCourse.id)")
        self.modifiedSegment = buildCourseSegment()
        self.modificationRequested = true
    }
}
