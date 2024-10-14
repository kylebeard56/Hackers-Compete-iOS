//
//  Firebase+Auth.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//


import Firebase
import FirebaseAuth
import FirebaseFirestoreCombineSwift
import Foundation

extension FirebaseService {
    func loginAnonymously() async -> Result<User, Error> {
        do {
            let response = try await Auth.auth().signInAnonymously()
            return .success(response.user)
        } catch let error {
            print("error logging user into Firebase anonymously, \(error)")
            self.addBreadcrumb(.error, .auth, "Cannot login anonymous user", error)
            return .failure(error)
        }
    }
}
