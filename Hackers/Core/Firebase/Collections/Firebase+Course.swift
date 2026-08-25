//
//  Firebase+Course.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection: String = Collections.courses.rawValue

extension FirebaseService {
    func getCourseByID(_ value: String) async -> Result<Course, Error> {
        addBreadcrumb(message: "\(#function), \(value)")
        return await fetch(where: "id", isEqualTo: value, in: collection)
    }

    /// Reads an API-backed course directly by its deterministic Firebase document ID.
    /// Returns nil for a missing, malformed, or mismatched document so callers can fall back to
    /// GolfCourseAPI without making Firebase availability part of the course-selection failure path.
    func getCachedGolfCourseAPIByID(_ id: Int) async -> Course? {
        guard id > 0 else { return nil }
        let documentID = Course.golfCourseAPIDocumentID(for: id)
        let reference = Firestore.firestore()
            .collection(Collections.courses.name)
            .document(documentID)

        do {
            let snapshot = try await reference.getDocument()
            guard snapshot.exists else { return nil }

            let course = try snapshot.data(as: Course.self)
            guard course.hasCanonicalGolfCourseAPIIdentity,
                  course.golfCourseApiID == id else {
                addBreadcrumb(
                    level: .warning,
                    message: "Ignoring mismatched GolfCourseAPI cache document \(documentID)"
                )
                return nil
            }
            return course
        } catch {
            addBreadcrumb(
                level: .warning,
                message: "Failed to read GolfCourseAPI cache document \(documentID)",
                error: error
            )
            return nil
        }
    }

    /// Inserts API courses that are not already cached. Existing documents are never overwritten;
    /// this keeps repeat searches from generating Firestore writes and preserves deliberate edits.
    func cacheGolfCourseAPICoursesIfMissing(_ courses: [Course]) async {
        let candidates = Dictionary(
            courses
                .filter(\.hasCanonicalGolfCourseAPIIdentity)
                .map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        guard candidates.isPopulated else { return }

        let existingIDs: Set<String>
        switch await fetchByIDs(Array(candidates.keys), in: Collections.courses.name) as Result<[Course], Error> {
        case .success(let existing):
            existingIDs = Set(existing.map(\.id))
        case .failure(let error):
            addBreadcrumb(
                level: .warning,
                message: "Skipping GolfCourseAPI cache write because existing IDs could not be checked",
                error: error
            )
            return
        }

        let missing = candidates.values.filter { !existingIDs.contains($0.id) }
        guard missing.isPopulated else { return }

        switch await Array(missing).batchPostChunked() {
        case .success:
            addBreadcrumb(message: "Cached \(missing.count) GolfCourseAPI course(s) in Firebase")
        case .failure(let error):
            addBreadcrumb(
                level: .warning,
                message: "Failed to cache GolfCourseAPI course(s) in Firebase",
                error: error
            )
        }
    }

    /// Searches the locally cached GolfCourseAPI courses before the app calls the provider's
    /// fuzzy-search endpoint. Firestore supports the normalized prefix range queries below, not
    /// typo-tolerant matching, so callers fall back to the provider when this returns no results.
    func searchCachedGolfCourseAPICourses(
        matching query: String,
        limit: Int = 50
    ) async -> [Course] {
        let normalized = query.normalizedForSearch
        guard let firstToken = normalized.split(separator: " ").first,
              firstToken.count >= 3 else {
            return []
        }

        let start = String(firstToken)
        let end = start + "\u{f8ff}"
        let courses = Firestore.firestore().collection(Collections.courses.name)
        let forwardQuery = courses
            .whereField("search_key", isGreaterThanOrEqualTo: start)
            .whereField("search_key", isLessThanOrEqualTo: end)
            .limit(to: limit)
        let reverseQuery = courses
            .whereField("search_key_reverse", isGreaterThanOrEqualTo: start)
            .whereField("search_key_reverse", isLessThanOrEqualTo: end)
            .limit(to: limit)

        do {
            async let forwardSnapshot = forwardQuery.getDocuments()
            async let reverseSnapshot = reverseQuery.getDocuments()
            let (forward, reverse) = try await (forwardSnapshot, reverseSnapshot)

            let candidates = (forward.documents + reverse.documents)
                .compactMap { try? $0.data(as: Course.self) }
                .filter(\.hasCanonicalGolfCourseAPIIdentity)
                .filter { $0.matchesCachedSearch(query: normalized) }
            let deduplicated = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            return deduplicated.values.sorted { lhs, rhs in
                let lhsExactPrefix = lhs.searchKey.hasPrefix(normalized) || lhs.searchKeyReverse.hasPrefix(normalized)
                let rhsExactPrefix = rhs.searchKey.hasPrefix(normalized) || rhs.searchKeyReverse.hasPrefix(normalized)
                if lhsExactPrefix != rhsExactPrefix { return lhsExactPrefix }
                return lhs.courseName.localizedCaseInsensitiveCompare(rhs.courseName) == .orderedAscending
            }
        } catch {
            addBreadcrumb(
                level: .warning,
                message: "Failed to search cached GolfCourseAPI courses for \(normalized)",
                error: error
            )
            return []
        }
    }

     func fetchCourses(near geohash: String) async -> Result<[Course], Error> {
         addBreadcrumb(message: "\(#function), \(geohash)")
         
         // Get all 9 geohashes (center + 8 neighbors)
         let allGeohashes = Geohash.neighbors(for: geohash)
         
         var allCourses: Set<Course> = []
         
         // Fetch courses for each geohash
         for targetGeohash in allGeohashes {
             let result = await fetchCoursesForGeohash(targetGeohash)
             
             switch result {
             case .success(let courses):
                 allCourses.formUnion(courses)
             case .failure(let error):
                 // Log warning but continue with other geohashes
                 addBreadcrumb(
                    level: .warning,
                    message: "Failed to fetch courses for geohash \(targetGeohash)",
                    error: error
                 )
             }
         }
         
         let coursesArray = Array(allCourses)
         addBreadcrumb(message: "Found \(coursesArray.count) unique courses near geohash \(geohash)")
         
         // Return success even if some individual geohash queries failed
         // as long as we got some results
         return .success(coursesArray)
     }
    
    /// Fetches courses for a single specific geohash
    private func fetchCoursesForGeohash(_ geohash: String) async -> Result<[Course], Error> {
        let query = Firestore.firestore()
            .collection(Collections.courses.name)
            .whereField("location_geohash", isEqualTo: geohash)
            .limit(to: 50) // Reasonable limit per geohash
        
        return await fetchDocuments(query: query)
    }
    
    /// Returns true if a course document exists with the given ID
    func courseExists(id: String) async -> Bool {
        guard id.isPopulated else { return false }
        switch await getCourseByID(id) {
        case .success: return true
        case .failure: return false
        }
    }
    
    /// Saves a course (Option C: POST for new, PUT for existing). Sets origin to .hackers when creating.
    @discardableResult
    func saveCourse(_ course: Course) async -> Result<Course, Error> {
        addBreadcrumb(message: "\(#function), course \(course.id)")
        
        if course.id.isPopulated, await courseExists(id: course.id) {
            return await course.put()
        } else {
            let newCourse = Course(
                id: HackersID.string(),
                golfCourseApiID: course.golfCourseApiID,
                origin: .hackers,
                clubName: course.clubName,
                courseName: course.courseName,
                location: course.location,
                locationGeohash: course.locationGeohash ?? course.location?.geohash,
                tees: course.tees,
                createdAt: Time(),
                lastUpdatedAt: Time()
            )
            return await newCourse.post()
        }
    }
}
