//
//  Firebase+User.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection: String = Collections.users.rawValue

extension FirebaseService {
    func getUserByID(_ value: String) async -> Result<HackersUser, Error> {
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "id", isEqualTo: value, in: collection)
    }
    
    func getUserByEmail(_ value: String) async -> Result<HackersUser, Error> {
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "email", isEqualTo: value, in: collection)
    }
    
    func getUserByPhone(_ value: String) async -> Result<HackersUser, Error> {
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "profile.phone", isEqualTo: value, in: collection)
    }

    func getUserByUsername(_ value: String) async -> Result<HackersUser, Error> {
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "profile.username", isEqualTo: value, in: collection)
    }

    // MARK: - POST
    
    func postUser(
        for id: String,
        email: String,
        givenName: String = "",
        familyName: String = ""
    ) async -> Result<HackersUser, Error> {
        addBreadcrumb("\(#function), id: \(id)")
        let ref = Firestore.firestore().collection(collection).document(id)
        
        var terms = "1.0.0"
        if let t = try? await FirebaseService.shared.fetchLatestTermsVersion() {
            terms = t
        }
        
        var policy = "1.0.0"
        if let t = try? await FirebaseService.shared.fetchLatestPolicyVersion() {
            terms = t
        }
        
        let data = HackersUser(
            id: id,
            email: email,
            players: [
                buildNewPlayerProfile(given: givenName, family: familyName)
            ],
            legal: UserLegal(terms: terms, privacyPolicy: policy)
        )
        do {
            try await ref.setData(try data.toDictionary())
            return .success(data)
        } catch let error {
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    private func buildNewPlayerProfile(given: String, family: String) -> PlayerProfile {
        return PlayerProfile(
            id: ID.string(),
            name: Name(givenName: given, familyName: family),
            rounds: [],
            handicaps: [],
            isPrimary: true
        )
    }
    
    // MARK: - DELETE
    
    func deleteUser(_ user: HackersUser) async {//} -> Result<Bool, Error> {
        // TODO: This user's account should be scrubbed for personal data, including profile, for historics.
        // Their authentication should be deleted. Should they sign up again, create brand new account.
    }
    
    // MARK: - Helpers
    
    /// Query the `Users` collection to see if email is linked to existing document in Cloud Firestore.
    func doesUserExistByEmail(_ value: String) async -> Bool {
        addBreadcrumb("\(#function), \(value)")
        switch await getUserByEmail(value) {
        case .success(_):   return true
        case .failure(_):   return false
        }
    }
    
    /// Query the `Users` collection to see if phone is linked to existing document in Cloud Firestore.
    func doesUserExistByPhone(_ value: String) async -> Bool {
        addBreadcrumb("\(#function), \(value)")
        switch await getUserByPhone(value) {
        case .success(_):   return true
        case .failure(_):   return false
        }
    }
    
    /// Query the `Users` collection to see if username is used by an existing document in Cloud Firestore.
    func doesUserExistByUsername(_ value: String) async -> Bool {
        addBreadcrumb("\(#function), \(value)")
        switch await getUserByUsername(value) {
        case .success(_):   return true
        case .failure(_):   return false
        }
    }
}
