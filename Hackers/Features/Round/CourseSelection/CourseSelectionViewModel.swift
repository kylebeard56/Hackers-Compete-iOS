//
//  CourseSelectionViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import CoreLocation
import SwiftUI
import UIKit

enum ScorecardScanSource: String {
    case camera
    case photoLibrary = "photo_library"
}

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

struct SimpleRoundSetup: Equatable {
    var courseName: String
    var holeCount: Int
    var startingHole: Int

    init(
        courseName: String = "",
        holeCount: Int = 9,
        startingHole: Int = 1
    ) {
        self.courseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.holeCount = min(max(holeCount, 1), 18)
        self.startingHole = min(max(startingHole, 1), min(max(holeCount, 1), 18))
    }

    var resolvedCourseName: String {
        courseName.isPopulated ? courseName : "Simple Round"
    }

    /// Synthetic simple-round course (friendly net scoring); used by course selection and history fallbacks.
    func makeCourse() -> Course {
        let holes = (1...holeCount).map { holeNumber in
            Hole(number: holeNumber, par: 4, yardage: 0, handicap: nil)
        }

        let tee = Tee(
            id: "simple_round_default_tee",
            name: "Simple",
            gender: Gender.unknown.rawValue,
            totalHoles: holeCount,
            holes: holes,
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )

        return Course(
            golfCourseApiID: nil,
            origin: .simple,
            clubName: resolvedCourseName,
            courseName: resolvedCourseName,
            location: nil,
            venueDetails: nil,
            locationGeohash: nil,
            tees: [tee]
        )
    }
}

@MainActor
final class CourseSelectionViewModel: ObservableObject, Loggable {
    private let courseRepository: GolfCourseRepository
    private var searchRequestID = UUID()
    private var searchRequest: Task<[Course], Error>?
    private var resolvedRecents: [String: Course] = [:]
    @Published var recentCoursesError: String?
    @Published var recoveryCourseName: String?
    @Published var searchError: String?
    @Published var courseFetchErrorMessage = "Please try again or search for the course."
    @Published var isLoadingSelectedCourse = false

    private let ocrService: CourseScorecardOCRService
    private let enrichmentService: CourseScorecardEnrichmentService
    private let askAIService: CourseTextLookupService

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
    @Published private(set) var simpleRoundSetup: SimpleRoundSetup?
    @Published private(set) var lastSelectionSource: CourseSelectionSource?
    
    /// Game Lobby
    @Published var isCreatingRound = false
    @Published var showRoundCreationError = false
    @Published var roundCreationID = ""
    
    /// Scorecard OCR
    @Published var isScanningScorecard = false
    @Published var scorecardScanError: String?

    /// Ask AI
    @Published var askAIMessages: [AskAICourseChatMessage] = []
    @Published var isSendingAskAIMessage = false
    @Published var askAIError: String?
    private var askAIRequest: Task<AskAICourseLookupResult, Error>?
    private var askAISelection: Task<Course, Error>?
    private var askAITurnID: UUID?
    private var lastAskAIContext = AskAICourseLookupContext()


    /// Modify/Change
    @Published var modifyingCourse: Course?
    @Published var modifyingTee: Tee?
    @Published var modifiedSegment: CourseSegment?
    @Published var modificationRequested: Bool = false
    @Published var commitModification: Bool = false
    var isModifying: Bool { modifyingCourse.exists || modifyingTee.exists || modifiedSegment.exists }
    var shouldCommitSelectionAsModification: Bool = false
    
    @Published var globalDismiss: Bool = false
    
    /// When true, confirmation saves as home course instead of creating a round.
    var isSetHomeCourseMode: Bool = false
    var onSetHomeCourse: ((GolfCourseID, String, String?, String?) -> Void)?

    /// When true, confirmation saves as series default course instead of creating a round.
    var isSetSeriesDefaultCourseMode: Bool = false
    var onSetSeriesDefaultCourse: ((String, String, String?, HoleSegment) -> Void)?

    /// When true, confirmation passes course segment to callback for series round creation.
    var isSetSeriesRoundCourseMode: Bool = false
    var onSetSeriesRoundCourse: ((CourseSegment) -> Void)?

    var shouldTrackRoundSetup: Bool {
        !isSetHomeCourseMode && !isSetSeriesDefaultCourseMode
    }
    
    init(
        course: Course? = nil,
        tee: Tee? = nil,
        holeSegment: HoleSegment = .full18,
        ocrService: CourseScorecardOCRService? = nil,
        enrichmentService: CourseScorecardEnrichmentService? = nil,
        askAIService: CourseTextLookupService? = nil,
        courseRepository: GolfCourseRepository? = nil
    ) {
        print("init CourseSelectionViewModel")
        self.courseRepository = courseRepository ?? .shared
        self.ocrService = ocrService ?? .shared
        self.enrichmentService = enrichmentService ?? .shared
        self.askAIService = askAIService ?? .shared
        modifyingCourse = course
        modifyingTee = tee
        selectedTee = tee
        self.holeSegment = holeSegment
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
        
        recentCoursesError = nil
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
            let entries = merged.values.sorted { $0.lastPlayedAt.unix > $1.lastPlayedAt.unix }
            var saved: [String: Course] = [:]
            var missing: [CourseHistoryEntry] = []
            for entry in entries.prefix(30) {
                do {
                    if let course = try await courseRepository.cachedCourse(for: entry), course.hasPlayableScorecard {
                        saved[entry.compositeKey] = course
                    } else { missing.append(entry) }
                } catch {
                    recentCoursesError = "Some saved courses couldn’t be checked. Try again when you’re connected."
                    missing.append(entry)
                }
            }
            if !missing.isEmpty {
                let ids = players.flatMap { Array($0.processedRoundIds.suffix(30)) }
                do {
                    let snapshots = try await FirebaseService.shared.recentCourseSnapshots(roundIDs: Array(Set(ids)).sorted())
                    for entry in missing {
                        if let course = snapshots.first(where: { course in
                            course.hasPlayableScorecard && (entry.courseIDType == .courseAPI
                                ? course.golfCourseApiID?.description == entry.courseID
                                : course.id == entry.courseID)
                        }) {
                            saved[entry.compositeKey] = course
                            Task { await FirebaseService.shared.rememberPlayedCourse(course) }
                        }
                    }
                } catch {
                    recentCoursesError = "Some saved courses couldn’t be recovered. Try again when you’re connected."
                }
            }
            applyResolvedRecents(entries: entries, courses: saved)
        case .failure:
            recentCoursesError = "Couldn’t load recent courses. Please try again."
        }
    }
    
    func applyResolvedRecents(entries: [CourseHistoryEntry], courses: [String: Course]) {
        var displayed: [Course] = []
        var visible: [CourseHistoryEntry] = []
        for entry in entries {
            guard let course = courses[entry.compositeKey], course.hasPlayableScorecard,
                  !displayed.contains(where: { $0.refersToSameCourse(as: course) }) else { continue }
            displayed.append(course)
            visible.append(entry)
        }
        resolvedRecents = courses
        recentCourseEntries = visible
    }

    func selectFromRecent(entry: CourseHistoryEntry) async {
        addBreadcrumb(message: "\(#function) [\(entry.compositeKey)]")
        if let course = resolvedRecents[entry.compositeKey] {
            select(course: course, source: .recent)
            return
        }
        guard !isLoadingSelectedCourse else { return }
        isLoadingSelectedCourse = true
        showCourseFetchError = false
        defer { isLoadingSelectedCourse = false }
        Haptics.fire(.light)
        
        let course: Course?
        switch entry.courseIDType {
        case .courseAPI:
            guard let id = GolfCourseID(entry.courseID) else {
                showCourseFetchError = true
                Haptics.fire(.error)
                return
            }
            do {
                course = try await courseRepository.course(by: id)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError),
                      (error as? URLError)?.code != .cancelled else { return }
                addBreadcrumb(level: .error, message: "Failed to fetch course by API id \(id)", error: error)
                if id.isLegacy, !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    recoveryCourseName = entry.name
                    await searchCourses(for: entry.name)
                    return
                }
                courseFetchErrorMessage = Self.courseErrorMessage(error)
                showCourseFetchError = true
                Haptics.fire(.error)
                return
            }
        case .manual:
            switch await FirebaseService.shared.getCourseByID(entry.courseID) {
            case .success(let c): course = c
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to fetch manual course \(entry.courseID)", error: error)
                // Simple rounds are stored as manual + course id; if the course doc is missing, rebuild locally.
                let fallback = SimpleRoundSetup(courseName: entry.name, holeCount: 9, startingHole: 1)
                simpleRoundSetup = fallback
                holeSegment = fallback.holeCount == 18
                    ? .full18
                    : .custom(count: fallback.holeCount)
                let rebuilt = fallback.makeCourse()
                selectedTee = rebuilt.tees.first
                select(course: rebuilt, source: .recent, retainSimpleRoundSetup: true)
                return
            }
        }
        
        if let course {
            select(course: course, source: .recent)
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
    func searchCourses(for query: String, using location: CLLocation? = nil, searchMore: Bool = false) async {
        addBreadcrumb(message: "\(#function) [\(query)]")
        let requestID = UUID()
        searchRequestID = requestID
        searchRequest?.cancel()
        if !searchMore { searchedCourses = [] }
        searchError = nil
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            return
        }

        if shouldTrackRoundSetup {
            addEvent(
                "round_setup.course_search_started",
                eventProps: [
                    "query_length": query.count,
                    "has_location": location != nil,
                    "is_existing_round_change": isModifying
                ]
            )
        }
        
        isSearching = true
        defer { if searchRequestID == requestID { isSearching = false } }

        do {
            let request = Task { try await courseRepository.searchCourses(with: query, searchMore: searchMore) }
            searchRequest = request
            let courses = try await withTaskCancellationHandler {
                try await request.value
            } onCancel: { request.cancel() }
            guard searchRequestID == requestID, !Task.isCancelled else { return }
            searchedCourses = courses
            
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
                    
                    return (course1.location == nil ? Double.greatestFiniteMagnitude : loc1.distance(from: location)) < (course2.location == nil ? Double.greatestFiniteMagnitude : loc2.distance(from: location))
                }
            }
            
            print("\(searchedCourses.count) courses found:")
            printPretty(searchedCourses)

            if shouldTrackRoundSetup {
                addEvent(
                    "round_setup.course_search_results_loaded",
                    eventProps: [
                        "query_length": query.count,
                        "result_count": searchedCourses.count,
                        "has_location": location != nil,
                        "is_existing_round_change": isModifying
                    ]
                )
            }
        } catch let error {
            guard searchRequestID == requestID, !Task.isCancelled,
                  !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            addBreadcrumb(level: .error, message: "error searching API from course selection", error: error)
            searchError = Self.courseErrorMessage(error)
        }
    }

    func selectSearchCourse(_ course: Course) async {
        guard !isLoadingSelectedCourse else { return }
        guard let id = course.golfCourseApiID, !course.hasPlayableScorecard else {
            guard course.hasPlayableScorecard else {
                courseFetchErrorMessage = GolfCourseAPIError.scorecardUnavailable.localizedDescription
                showCourseFetchError = true
                return
            }
            select(course: course, source: .search)
            return
        }
        isLoadingSelectedCourse = true
        defer { isLoadingSelectedCourse = false }
        do {
            let detailed = try await courseRepository.course(by: id)
            guard !Task.isCancelled else { return }
            select(course: detailed, source: .search)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError),
                  (error as? URLError)?.code != .cancelled else { return }
            courseFetchErrorMessage = Self.courseErrorMessage(error)
            showCourseFetchError = true
        }
    }

    private static func courseErrorMessage(_ error: Error) -> String {
        if let error = error as? GolfCourseAPIError { return error.localizedDescription }
        if error is DecodingError { return GolfCourseAPIError.invalidResponse.localizedDescription }
        if error is URLError { return "Unable to connect to the course provider. Check your connection and try again." }
        return "Couldn't load courses. Please try again."
    }

    func getClosestCourse(from query: String, using location: CLLocation?) async throws -> Course? {
        addBreadcrumb(message: "\(#function) [\(query)]")
        guard query.isPopulated else { return nil }
        guard let location else { return nil }
        
        let courses = try await courseRepository.searchCourseModels(with: query)
            .map(Course.init(canonicalGolfCourseAPI:))
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
    func scanScorecard(
        image: UIImage,
        scanContext: ScorecardScanContext = .init(),
        vision: ScorecardScanVisionModel = .defaultSelection,
        scanSource: ScorecardScanSource
    ) async {
        addBreadcrumb()
        isScanningScorecard = true
        scorecardScanError = nil
        defer { isScanningScorecard = false }

        if shouldTrackRoundSetup {
            addEvent(
                "round_setup.course_scorecard_scan_started",
                eventProps: scorecardScanTelemetryProps(
                    scanSource: scanSource,
                    vision: vision,
                    scanContext: scanContext
                )
            )
        }

        do {
            let ocrCourse = try await ocrService.extractCourse(
                from: image,
                scanContext: scanContext,
                vision: vision
            )
            let course = await enrichmentService.enrich(course: ocrCourse, scanContext: scanContext)
            printPretty(course)
            if shouldTrackRoundSetup {
                addEvent(
                    "round_setup.course_scorecard_scan_succeeded",
                    eventProps: telemetryCourseProperties(
                        course: course,
                        holeSegment: course.defaultSegment,
                        selectionSource: .scorecardScan,
                        isModifying: isModifying,
                        extra: scorecardScanTelemetryProps(
                            scanSource: scanSource,
                            vision: vision,
                            scanContext: scanContext
                        )
                    )
                )
            }
            select(course: course, source: .scorecardScan)
        } catch CourseAIGatewayError.signInRequired {
            scorecardScanError = CourseAIGatewayError.signInRequired.localizedDescription
        } catch CourseScorecardOCRError.apiKeyMissing {
            addBreadcrumb(level: .error, message: "Scorecard AI service unavailable")
            scorecardScanError = "Scorecard scanning is temporarily unavailable. Please try again later."
            trackScorecardScanFailure(
                reason: "ai_service_unavailable",
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            )
        } catch CourseScorecardOCRError.decodingFailed {
            addBreadcrumb(level: .error, message: "Failed to read scorecard")
            scorecardScanError = "Couldn't read the scorecard. Try a clearer photo."
            trackScorecardScanFailure(
                reason: "decoding_failed",
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            )
        } catch CourseScorecardOCRError.requestTooLarge {
            addBreadcrumb(level: .error, message: "Scorecard image too large")
            scorecardScanError = "Image too large. Try a smaller photo."
            trackScorecardScanFailure(
                reason: "request_too_large",
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            )
        } catch CourseScorecardOCRError.rateLimitExceeded {
            addBreadcrumb(level: .error, message: "AI rate limit exceeded")
            scorecardScanError = "Rate limit exceeded. Try again later."
            trackScorecardScanFailure(
                reason: "rate_limit_exceeded",
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            )
        } catch CourseScorecardOCRError.overloaded {
            addBreadcrumb(level: .error, message: "AI service overloaded")
            scorecardScanError = "AI is busy. Try again in a moment."
            trackScorecardScanFailure(
                reason: "service_overloaded",
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to scan scorecard", error: error)
            scorecardScanError = "Scan failed. Please try again."
            trackScorecardScanFailure(
                reason: "unknown",
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            )
        }
    }
}

// MARK: - Selection
extension CourseSelectionViewModel {
    func configureSimpleRound(_ setup: SimpleRoundSetup) {
        addBreadcrumb(message: "\(#function) [\(setup.holeCount) holes, start \(setup.startingHole)]")

        let normalizedSetup = SimpleRoundSetup(
            courseName: setup.courseName,
            holeCount: setup.holeCount,
            startingHole: setup.startingHole
        )

        simpleRoundSetup = normalizedSetup
        holeSegment = normalizedSetup.holeCount == 18
            ? .full18
            : .custom(count: normalizedSetup.holeCount)
        let course = normalizedSetup.makeCourse()
        selectedTee = course.tees.first
        select(course: course, source: .simpleRound)
    }

    func fetchFromNearby(using query: String, and location: CLLocation?) {
        addBreadcrumb(message: "\(#function) [\(query)]")
        
        isSearchingNearby = true
        defer { isSearchingNearby = false }
        
        Task {
            if let course = try? await getClosestCourse(from: query, using: location) {
                select(course: course, source: .nearby)
            } else {
                // TODO: Handle error somehow
            }
        }
    }

    func cancelAskAIRequest() {
        askAITurnID = nil
        askAIRequest?.cancel()
        askAISelection?.cancel()
        askAIRequest = nil
        askAISelection = nil
        isSendingAskAIMessage = false
    }

    func resetAskAIConversation() {
        cancelAskAIRequest()
        askAIMessages = []
        askAIError = nil
    }

    func retryAskAIMessage(context: AskAICourseLookupContext? = nil) async {
        guard let text = askAIMessages.last(where: \.isUser)?.text else { return }
        await sendAskAIMessage(text, context: context ?? lastAskAIContext, appendUserMessage: false)
    }

    func sendAskAIMessage(
        _ text: String,
        context: AskAICourseLookupContext = .init(),
        appendUserMessage: Bool = true
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated, !isSendingAskAIMessage else { return }
        askAIError = nil
        isSendingAskAIMessage = true
        lastAskAIContext = context
        if appendUserMessage {
            askAIMessages.append(AskAICourseChatMessage(role: .user, text: trimmed))
        }
        let turnID = UUID()
        askAITurnID = turnID
        let transcript = askAIMessages
        let request = Task { try await askAIService.resolveCourse(from: transcript, context: context) }
        askAIRequest = request
        if shouldTrackRoundSetup {
            addEvent("round_setup.course_ask_ai_prompt_sent", eventProps: askAITelemetryProps(
                context: context, extra: ["prompt_length": trimmed.count, "message_count": transcript.count]
            ))
        }
        defer {
            if askAITurnID == turnID {
                askAITurnID = nil
                askAIRequest = nil
                isSendingAskAIMessage = false
            }
        }
        do {
            let result = try await request.value
            guard askAITurnID == turnID, !Task.isCancelled else { return }
            askAIMessages.append(AskAICourseChatMessage(
                role: .assistant, text: result.assistantMessage,
                candidates: result.candidates, lookupQuery: result.lookupQuery
            ))
            if shouldTrackRoundSetup {
                addEvent("round_setup.course_ask_ai_result_received", eventProps: askAITelemetryProps(
                    context: context, extra: ["candidate_count": result.candidates.count, "lookup_source": result.source.rawValue]
                ))
            }
        } catch {
            guard askAITurnID == turnID, !Task.isCancelled,
                  !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            switch error {
            case CourseTextLookupError.apiKeyMissing:
                askAIError = "Course research is temporarily unavailable. You can still search courses from the course picker."
            case CourseTextLookupError.requestTooLarge:
                askAIError = "That message was too long. Try a shorter course name and location."
            case CourseTextLookupError.rateLimitExceeded, CourseTextLookupError.overloaded:
                askAIError = "Course research is busy. Try again in a moment."
            case is GolfCourseAPIError, is URLError:
                askAIError = Self.courseErrorMessage(error)
            default:
                askAIError = "I couldn’t finish that search. Please try again."
            }
            trackAskAIFailure(reason: "lookup_failed", context: context)
        }
    }

    /// Keep the conversation visible until the selected summary has a real scorecard.
    func loadAskAICandidate(_ candidate: AskAICourseCandidate) async -> Bool {
        guard !isSendingAskAIMessage else { return false }
        guard candidate.needsScorecard || !candidate.course.tees.contains(where: { !$0.holes.isEmpty }), let id = candidate.course.golfCourseApiID else {
            selectAskAICandidate(candidate)
            return true
        }
        askAIError = nil
        isSendingAskAIMessage = true
        let turnID = UUID()
        askAITurnID = turnID
        let request = Task { try await courseRepository.course(by: id) }
        askAISelection = request
        defer {
            if askAITurnID == turnID {
                askAITurnID = nil
                askAISelection = nil
                isSendingAskAIMessage = false
            }
        }
        do {
            let course = try await request.value
            guard askAITurnID == turnID, !Task.isCancelled else { return false }
            guard course.tees.contains(where: { !$0.holes.isEmpty }) else { throw GolfCourseAPIError.invalidResponse }
            selectAskAICandidate(AskAICourseCandidate(
                course: course, requiresReview: false, isCanonicalMatch: true, sources: candidate.sources
            ))
            return true
        } catch {
            guard askAITurnID == turnID, !Task.isCancelled,
                  !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return false }
            askAIError = Self.courseErrorMessage(error) + " Choose the course again to retry its scorecard."
            return false
        }
    }

    func selectAskAICandidate(_ candidate: AskAICourseCandidate) {
        selectedTee = candidate.course.tees.count == 1 ? candidate.course.tees.first : nil
        select(
            course: candidate.course,
            source: .askAI,
            forceCourseEdit: candidate.requiresReview
        )
    }

    func prepareAskAIDraftReview(_ course: Course, trackEvent: Bool = true) {
        addBreadcrumb(message: "\(#function) [\(course.id)]")
        UIApplication.shared.endEditing()
        simpleRoundSetup = nil
        selectedCourse = course
        lastSelectionSource = .askAI
        selectedTee = course.tees.count == 1 ? course.tees.first : nil
        showCourseEdit = false
        showConfirmation = false

        guard trackEvent, shouldTrackRoundSetup else { return }
        addEvent(
            "round_setup.course_selected",
            eventProps: telemetryCourseProperties(
                course: course,
                holeSegment: course.defaultSegment,
                selectedTee: selectedTee,
                selectionSource: .askAI,
                isModifying: isModifying,
                extra: [
                    "requires_review": true,
                    "is_canonical_match": false
                ]
            )
        )
    }
    
    func select(
        course: Course,
        source: CourseSelectionSource,
        trackEvent: Bool = true,
        retainSimpleRoundSetup: Bool = false,
        forceCourseEdit: Bool = false
    ) {
        addBreadcrumb(message: "\(#function) [\(course.id)]")
        UIApplication.shared.endEditing()
        if source != .simpleRound && !retainSimpleRoundSetup {
            simpleRoundSetup = nil
        }
        selectedCourse = course
        lastSelectionSource = source
        if selectedTee == nil, course.tees.count == 1 {
            selectedTee = course.tees.first
        }

        if trackEvent, shouldTrackRoundSetup {
            if source == .manual {
                addEvent(
                    "round_setup.course_manual_started",
                    eventProps: telemetryCourseProperties(
                        course: course,
                        holeSegment: course.defaultSegment,
                        selectionSource: source,
                        isModifying: isModifying
                    )
                )
            }

            addEvent(
                "round_setup.course_selected",
                eventProps: telemetryCourseProperties(
                    course: course,
                    holeSegment: course.defaultSegment,
                    selectedTee: selectedTee,
                    selectionSource: source,
                    isModifying: isModifying
                )
            )
        }

        let isManualAndNeedsEntry = course.origin == CourseOrigin.manual.rawValue
            && course.courseName.isEmpty
            && course.tees.isEmpty
        let isOCRNeedsReview = course.origin == CourseOrigin.ocr.rawValue
        if forceCourseEdit || isManualAndNeedsEntry || isOCRNeedsReview {
            showCourseEdit = true
            showConfirmation = false
        } else {
            showCourseEdit = false
            showConfirmation = true
        }

        if isSetSeriesDefaultCourseMode || isSetSeriesRoundCourseMode {
            holeSegment = course.defaultSegment
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
            courses: [ buildCourseSegment() ],
            scoreInputMode: selectedCourse.isSimpleRoundCourse ? .friendlyRelativeToPar : .strokes
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
            startingHole: selectedStartingHole,
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
            let playedCourse = selectedCourse
            Task { await FirebaseService.shared.rememberPlayedCourse(playedCourse) }

            if shouldTrackRoundSetup {
                addEvent(
                    "round_setup.lobby_created",
                    eventProps: telemetryCourseProperties(
                        course: selectedCourse,
                        holeSegment: holeSegment,
                        selectedTee: selectedTee,
                        selectionSource: lastSelectionSource,
                        isModifying: isModifying,
                        extra: [
                            "round_id": round.id,
                            "format_template_id": template.id,
                            "format_name": template.name,
                            "format_category": template.category.rawValue,
                            "competition_scope": CompetitionScope.field.rawValue,
                            "uses_handicaps": false,
                            "requires_teams": false,
                            "max_score_over_par": template.requirements.defaultMaxScoreOverPar.rawValue,
                            "participant_count": 1,
                            "team_count": 2,
                            "tee_group_count": 1,
                            "matchup_count": 0
                        ]
                    )
                )
            }
        } catch let error {
            throwRoundCreationError(error: error)
        }
    }
    
    private func throwRoundCreationError(msg: String? = nil, error: Error? = nil) {
        Haptics.fire(.error)
        let failureReason = msg?.isPopulated == true ? msg! : "unknown"
        addBreadcrumb(level: .error, message: "Failed to create game lobby: \(failureReason)", error: error)
        if shouldTrackRoundSetup {
            let template = FormatTemplateRegistry.strokePlayGross
            addEvent(
                "round_setup.lobby_creation_failed",
                eventProps: telemetryCourseProperties(
                    course: selectedCourse,
                    holeSegment: holeSegment,
                    selectedTee: selectedTee,
                    selectionSource: lastSelectionSource,
                    isModifying: isModifying,
                    extra: [
                        "format_template_id": template.id,
                        "format_name": template.name,
                        "format_category": template.category.rawValue,
                        "competition_scope": CompetitionScope.field.rawValue,
                        "uses_handicaps": false,
                        "requires_teams": false,
                        "max_score_over_par": template.requirements.defaultMaxScoreOverPar.rawValue,
                        "participant_count": 1,
                        "team_count": 2,
                        "tee_group_count": 1,
                        "matchup_count": 0,
                        "failure_reason": failureReason
                    ]
                )
            )
        }
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

    private var selectedStartingHole: Int {
        guard selectedCourse.isSimpleRoundCourse else {
            return holeSegment.holeRange.startHole
        }
        return simpleRoundSetup?.startingHole ?? 1
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

private extension CourseSelectionViewModel {
    func scorecardScanTelemetryProps(
        scanSource: ScorecardScanSource,
        vision: ScorecardScanVisionModel,
        scanContext: ScorecardScanContext
    ) -> [String: Any] {
        [
            "scan_source": scanSource.rawValue,
            "vision_tier": vision.rawValue,
            "ai_provider": vision.config.provider.rawValue,
            "ai_model_id": vision.config.model,
            "has_notes": scanContext.notes?.isPopulated == true,
            "notes_length": scanContext.notes?.count ?? 0,
            "location_assist_enabled": scanContext.isLocationAssistEnabled,
            "has_approximate_location": scanContext.approximateLocation != nil,
            "is_existing_round_change": isModifying
        ]
    }

    func trackScorecardScanFailure(
        reason: String,
        scanSource: ScorecardScanSource,
        vision: ScorecardScanVisionModel,
        scanContext: ScorecardScanContext
    ) {
        guard shouldTrackRoundSetup else { return }
        addEvent(
            "round_setup.course_scorecard_scan_failed",
            eventProps: scorecardScanTelemetryProps(
                scanSource: scanSource,
                vision: vision,
                scanContext: scanContext
            ).merging(["failure_reason": reason]) { _, new in new }
        )
    }

    func askAITelemetryProps(
        context: AskAICourseLookupContext,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        [
            "location_assist_enabled": context.isLocationAssistEnabled,
            "has_approximate_location": context.approximateLocation != nil,
            "ai_provider": context.model.config.provider.rawValue,
            "ai_model_id": context.model.config.model
        ]
        .merging(extra) { _, new in new }
    }

    func trackAskAIFailure(
        reason: String,
        context: AskAICourseLookupContext
    ) {
        guard shouldTrackRoundSetup else { return }
        addEvent(
            "round_setup.course_ask_ai_failed",
            eventProps: askAITelemetryProps(
                context: context,
                extra: [
                    "failure_reason": reason,
                    "message_count": askAIMessages.count,
                    "is_existing_round_change": isModifying
                ]
            )
        )
    }
}
