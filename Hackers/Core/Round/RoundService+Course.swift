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
            let r = try await snapshot.round.put().get()
        } catch {
            addBreadcrumb(.error, .gameLobby, "Failed to set default tee", error)
        }
    }
}
