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

    func getLibraryCourse(id: String) async throws -> Course? {
        guard !id.isEmpty else { return nil }
        let snapshot = try await Firestore.firestore().collection(Collections.courses.name).document(id).getDocument(source: .server)
        return snapshot.exists ? try snapshot.data(as: Course.self) : nil
    }

    func recentCourseSnapshots(roundIDs: [String]) async throws -> [Course] {
        var rounds: [Round] = []
        let ids = Array(roundIDs.prefix(60))
        for start in stride(from: 0, to: ids.count, by: 10) {
            let page = Array(ids[start..<min(start + 10, ids.count)])
            let snapshot = try await Firestore.firestore().collection(Collections.rounds.name)
                .whereField("id", in: page).getDocuments(source: .server)
            rounds += snapshot.documents.compactMap { try? $0.data(as: Round.self) }
        }
        return rounds.sorted { $0.createdAt.unix > $1.createdAt.unix }.flatMap { round in
            round.configuration.courses.map { Course(info: $0.courseInfo) }
        }
    }

    /// Backfill a played snapshot only when the shared document has no usable scorecard.
    func rememberPlayedCourse(_ course: Course) async {
        guard !course.id.isEmpty, course.hasPlayableScorecard, !course.isSimpleRoundCourse else { return }
        let ref = Firestore.firestore().collection(Collections.courses.name).document(course.id)
        do {
            _ = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    if snapshot.exists, let old = try? snapshot.data(as: Course.self), old.hasPlayableScorecard { return nil }
                    transaction.setData(try Firestore.Encoder().encode(course), forDocument: ref)
                } catch { errorPointer?.pointee = error as NSError }
                return nil
            }
        } catch { addBreadcrumb(level: .warning, message: "Couldn’t retain played course", error: error) }
    }

    /// A failed server read is different from a missing course. Do not mask it as a cache miss.
    func getCachedGolfCourseAPIByID(_ id: GolfCourseID) async throws -> Course? {
        guard id.isValid else { return nil }
        let courses = Firestore.firestore().collection(Collections.courses.name)
        let direct = try await courses.document(Course.golfCourseAPIDocumentID(for: id)).getDocument(source: .server)
        var matches: [Course] = []
        if direct.exists, let course = try? direct.data(as: Course.self), course.golfCourseApiID == id {
            matches.append(course)
            if course.hasPlayableScorecard { return course }
        }
        // Also find user-created and old UUID records carrying the same provider reference.
        let snapshot = try await courses.whereField("golf_course_api_id", isEqualTo: id.storageValue)
            .limit(to: 20).getDocuments(source: .server)
        matches += snapshot.documents.compactMap { try? $0.data(as: Course.self) }
        return matches.first(where: \.hasPlayableScorecard) ?? matches.first
    }

    /// Best-effort ingestion. Transactions preserve reviewed data and concurrent detail loads.
    func cacheGolfCourseAPICourses(_ courses: [Course]) async {
        let db = Firestore.firestore()
        for incoming in courses where incoming.golfCourseApiID != nil {
            guard let apiID = incoming.golfCourseApiID else { continue }
            let ref = db.collection(Collections.courses.name).document(Course.golfCourseAPIDocumentID(for: apiID))
            do {
                let outcome = try await db.runTransaction { transaction, errorPointer -> Any? in
                    do {
                        let snapshot = try transaction.getDocument(ref)
                        let existing = snapshot.exists ? try snapshot.data(as: Course.self) : nil
                        let merged = existing?.mergingProviderCourse(incoming) ?? incoming
                        // Write additive indexes even if an older document's course facts are unchanged.
                        if let existing, existing.hasSameDirectoryContent(as: merged), snapshot.data()?["search_tokens"] != nil {
                            return "unchanged"
                        }
                        let data = try Firestore.Encoder().encode(merged)
                        transaction.setData(data, forDocument: ref)
                        return existing == nil ? "inserted" : "updated"
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                }
                addEvent("course_library.save", eventProps: ["outcome": outcome as? String ?? "unknown"])
            } catch {
                addBreadcrumb(level: .warning, message: "Course library background save failed", error: error)
                addEvent("course_library.save", eventProps: ["outcome": "failed"])
            }
        }
    }

    /// Indexed word search with legacy prefix compatibility. Always establish a cloud result.
    func searchCachedGolfCourseAPICourses(matching query: String, limit: Int = 50) async throws -> [Course] {
        let normalized = query.normalizedForSearch
        let words = normalized.split(separator: " ").map(String.init)
        guard let token = words.max(by: { $0.count < $1.count }), token.count >= 2 else { return [] }
        let courses = Firestore.firestore().collection(Collections.courses.name)
        let indexed = courses.whereField("search_tokens", arrayContains: token).limit(to: limit)
        var candidates: [Course] = []
        var cursor: DocumentSnapshot?
        var readCount = 0
        // Continue filtering multiword queries beyond the first page, with a bounded read budget.
        for _ in 0..<5 {
            try Task.checkCancellation()
            let page = try await (cursor.map { indexed.start(afterDocument: $0) } ?? indexed).getDocuments(source: .server)
            readCount += page.documents.count
            candidates += page.documents.compactMap { try? $0.data(as: Course.self) }
                .filter { $0.matchesCachedSearch(query: normalized) }
            if candidates.count >= limit || page.documents.count < limit { break }
            cursor = page.documents.last
        }
        if let first = words.first, first.count >= 3 {
            async let forward = courses.whereField("search_key", isGreaterThanOrEqualTo: first)
                .whereField("search_key", isLessThanOrEqualTo: first + "\u{f8ff}").limit(to: limit).getDocuments(source: .server)
            async let reverse = courses.whereField("search_key_reverse", isGreaterThanOrEqualTo: first)
                .whereField("search_key_reverse", isLessThanOrEqualTo: first + "\u{f8ff}").limit(to: limit).getDocuments(source: .server)
            let (a, b) = try await (forward, reverse)
            readCount += a.documents.count + b.documents.count
            candidates += (a.documents + b.documents).compactMap { try? $0.data(as: Course.self) }
                .filter { $0.matchesCachedSearch(query: normalized) }
        }
        let result = Course.deduplicated(candidates.filter { !$0.isEmpty && !$0.isSimpleRoundCourse })
            .sorted { lhs, rhs in
                let leftExact = lhs.searchKey == normalized || lhs.searchKeyReverse == normalized
                let rightExact = rhs.searchKey == normalized || rhs.searchKeyReverse == normalized
                if leftExact != rightExact { return leftExact }
                if lhs.hasPlayableScorecard != rhs.hasPlayableScorecard { return lhs.hasPlayableScorecard }
                return (lhs.courseName, lhs.id) < (rhs.courseName, rhs.id)
            }
        addEvent("course_library.query", eventProps: ["documents_returned": readCount, "result_count": result.count])
        return Array(result.prefix(limit))
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
        
        var saved = course
        if saved.id.isEmpty { saved.id = HackersID.string() }
        saved.isUserEdited = true
        return await saved.put()

    }
}
