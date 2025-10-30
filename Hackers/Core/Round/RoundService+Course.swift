//
//  RoundService+Course.swift
//  Hackers
//
//  Created by Kyle Beard on 9/28/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

extension RoundService {
    func setDefaultTee(to teeID: String) async {
        addBreadcrumb("\(#function), \(teeID)")
        
        do {
            snapshot.round.configuration.courses[0].defaultTee = teeID
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to set default tee", error)
        }
    }
    
    func setCourseSegment(to segment: CourseSegment) async {
        addBreadcrumb(#function)
        
        do {
            snapshot.round.configuration.courses[0] = segment
            _ = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to set modified course", error)
        }
    }
}
