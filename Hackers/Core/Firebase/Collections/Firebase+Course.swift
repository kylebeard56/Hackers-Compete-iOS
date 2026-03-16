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

    // TODO: Add function to query by name and return batch
//     func getCoursesByName(_ query: String) async -> Result<[Course], Error> { }
    
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
