//
//  AuthViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/25.
//

import Firebase
@preconcurrency import FirebaseAuth
import Foundation

enum AuthError: String, Error {
    case appleSignInFailed = "Apple authentication failed"
    case googleSignInFailed = "Google authentication failed"
}

@MainActor
final class AuthService: NSObject, Loggable {
    static let shared = AuthService()
    var nonce = ""
    
    override init() {
        print("init AuthService")
        super.init()
    }

    deinit {
        print("deinit AuthService")
    }
    
    // MARK: - Current user
    
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
    
    // MARK: - Provider Sign In

    @discardableResult func signInFromProvider(
        with credential: AuthCredential,
        provider: AuthProviderID,
        email: String,
        givenName: String,
        familyName: String
    ) async throws -> HackersUser {
        print(#function)
        do {
            /// Sign in to Google Authentiction
            let user = try await Auth.auth().signIn(with: credential).user
            
            /// Use Auth user to create or update DB record for user account
            return try await updateHackersUserRecord(
                uid: user.uid,
                email: user.email ?? email,
                givenName: givenName,
                familyName: familyName
            )
        } catch let error {
            self.addBreadcrumb(.error, .auth, "Cannot sign in with credential for \(provider)", error)
            throw error
        }
    }
    
    private func updateHackersUserRecord(
        uid: String,
        email: String,
        givenName: String,
        familyName: String
    ) async throws -> HackersUser {
        print(#function)
        switch await FirebaseService.shared.getUserByEmail(email) {
        case .success(let u):
            /// User already existed, updated metadata and continue.
            return await self.updateUserMetadata(for: u)
        case .failure(let error):
            /// Check if user doesn't exist yet and create new record.
            guard let e = error as? HackersError, e == .documentNotFound else { throw error }
            return try await self.createNewUser(uid, email, givenName, familyName)
        }
    }
    
    private func createNewUser(
        _ id: String,
        _ email: String,
        _ givenName: String,
        _ familyName: String
    ) async throws -> HackersUser {
        print(#function)
        do {
            return try await FirebaseService.shared.postUser(
                for: id,
                email: email,
                givenName: givenName,
                familyName: familyName
            ).get()
        } catch let error {
            throw error
        }
    }
    
    @discardableResult
    func updateUserMetadata(for account: HackersUser) async -> HackersUser {
        print(#function)
        do {
            var user = account
            user.metadata.update(includeLastLogin: true)
            return try await user.put().get()
        } catch let error {
            print("couldn't update user metadata")
            addBreadcrumb(.warning, .auth, "Couldn't update user metadata", error)
            return HackersUser()
        }
    }
    
    // MARK: - Linking Accounts
    
    private func link(user: User?, with credential: AuthCredential?) async -> Result<User, Error> {
        print(#function)
        guard let linkUser = user else { return .failure(HackersError.linkableUserNotFound) }
        guard let linkCredential = credential else { return .failure(HackersError.linkableCredentialNotFound) }
        do {
            let response = try await linkUser.link(with: linkCredential)
            return .success(response.user)
        } catch let error {
            print("error linking user into Firebase, \(error)")
            self.addBreadcrumb(.error, .auth, "Cannot link user", error)
            return .failure(error)
        }
    }
    
    // MARK: - Logout
    
    func logout() throws {
        do {
            try Auth.auth().signOut()
            BoxFoxNotification.triggerLogout.send()
        } catch let error {
            addBreadcrumb(.error, .auth, "Error attempting log out", error)
            throw error
        }
    }
}
