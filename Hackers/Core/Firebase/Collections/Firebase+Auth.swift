//
//  Firebase+Auth.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseAuth
import FirebaseFirestoreCombineSwift
import Foundation

extension FirebaseService {
    @discardableResult
    func loginAnonymously() async throws -> User {
        do {
            return try await Auth.auth().signInAnonymously().user
        } catch let error {
            self.addBreadcrumb(level: .error, message: "Failed to login anonymous user", error: error)
            throw error
        }
    }
}
