//
//  Auth+Google.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
@preconcurrency import FirebaseAuth
import Foundation
@preconcurrency import GoogleSignIn

// MARK: - Sign in with Google

extension AuthService {
    func signInWithGoogle() async throws -> HackersUserCreation {
        addBreadcrumb()
        
        if let clientID = FirebaseApp.app()?.options.clientID, let root = UIApplication.shared.rootViewController {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            
            do {
                let user = try await GIDSignIn.sharedInstance.signIn(withPresenting: root).user
                let email = user.profile?.email ?? ""
                let givenName = user.profile?.givenName ?? ""
                let familyName = user.profile?.familyName ?? ""

                await Defaults.shared.setUserEmail(email)
                await Defaults.shared.setUserGivenName(givenName)
                await Defaults.shared.setUserFamilyName(familyName)
                await Defaults.shared.setGoogleAuthID(user.userID ?? "")
                
                let idToken = user.idToken?.tokenString ?? ""
                let accessToken = user.accessToken.tokenString
                
                return try await self.signInFromProvider(
                    with: GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken),
                    provider: .google,
                    email: email,
                    givenName: givenName,
                    familyName: familyName
                )
            } catch let error {
                if let e = error as? GIDSignInError, e.code == .canceled {
                    throw AuthError.userCancelledFlow
                }
                self.addBreadcrumb(level: .error, message: "Sign in with Google failed", error: error)
                throw error
            }
        } else {
            self.addBreadcrumb(
                level: .error,
                message: "Google client ID \(FirebaseApp.app()?.options.clientID ?? "N/A") or root missing"
            )
            throw AuthError.googleSignInFailed
        }
    }
}
