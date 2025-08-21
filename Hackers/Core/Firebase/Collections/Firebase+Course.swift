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
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "id", isEqualTo: value, in: collection)
    }

    // TODO: Add function to query by name and return batch
    // func getCoursesByName(_ query: String) async -> Result<[Course], Error> { }
    
    // TODO: Add function to find by nearby location (geohashing V3.1)
    // func fetchCourses(near geohash: String) async -> Result<Course, Error> { }
}
