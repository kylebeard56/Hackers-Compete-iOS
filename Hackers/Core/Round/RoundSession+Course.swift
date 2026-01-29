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
    
    func setCourseSegment(to segment: CourseSegment) async {
        addBreadcrumb()
        
        do {
            snapshot.round.configuration.courses[0] = segment
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(level: .error, message: "Failed to set course segment", error: error)
        }
    }
}
