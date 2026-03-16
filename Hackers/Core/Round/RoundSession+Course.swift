//
//  RoundSession+Course.swift
//  Hackers
//
//  Created by Kyle Beard on 9/28/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundSession {
    func setDefaultTee(to teeID: String) async {
        addBreadcrumb(message: "Set default tee to teeBoxID: \(teeID)")
        
        do {
            snapshot.round.configuration.courses[0].defaultTee = teeID
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set default tee", error: error)
        }
    }
    
    /// Updates the round's course segment. Option C: also persists to courses collection
    /// when the course is in our DB (PUT) or was edited from API (POST).
    func setCourseSegment(to segment: CourseSegment) async {
        addBreadcrumb()

        var segmentToSave = segment
        let course = Course(info: segment.courseInfo)

        if !course.isEmpty {
            switch await FirebaseService.shared.saveCourse(course) {
            case .success(let saved):
                if !segment.courseInfo.id.isPopulated, saved.id.isPopulated {
                    segmentToSave.courseInfo = CourseInfo(course: saved, for: segment.holeSegment)
                }
            case .failure(let error):
                addBreadcrumb(level: .error, message: "Failed to save course to collection", error: error)
            }
        }

        do {
            snapshot.round.configuration.courses[0] = segmentToSave
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set course segment", error: error)
        }
    }
}
