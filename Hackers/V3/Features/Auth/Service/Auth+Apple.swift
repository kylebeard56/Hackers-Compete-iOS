//
//  Auth+Apple.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import AuthenticationServices
import CryptoKit
@preconcurrency import FirebaseAuth
import Foundation

// MARK: - Sign in with Apple

extension AuthService {
    func signInWithApple() async throws -> HackersUser {
        addBreadcrumb(#function)
        let manager = SignInWithAppleManager()
        do {
            let auth = try await manager.signInWithApple()
            
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                addBreadcrumb(.error, .auth, "Apple ID credential not found")
                throw AuthError.appleSignInFailed
            }
            
            guard let nonce = manager.currentNonce else {
                addBreadcrumb(.error, .auth, "Apple nonce missing")
                throw AuthError.appleSignInFailed
            }
            
            guard let identityTokenData = credential.identityToken else {
                addBreadcrumb(.error, .auth, "Apple identity token data missing")
                throw AuthError.appleSignInFailed
            }
            
            guard let idToken = String(data: identityTokenData, encoding: .utf8) else {
                addBreadcrumb(.error, .auth, "Apple identity token couldn't be decoded")
                throw AuthError.appleSignInFailed
            }
            
            /// Apple will only pass email and full name data on the first Apple ID auth, afterwards it'll be nil.
            /// This can be reset at appleid.apple.com > Sign in with Apple > App Name > Stop using Apple ID
            let email = credential.email ?? ""
            let givenName = credential.fullName?.givenName ?? ""
            let familyName = credential.fullName?.familyName ?? ""

            await Defaults.shared.setUserEmail(email)
            await Defaults.shared.setUserGivenName(givenName)
            await Defaults.shared.setUserFamilyName(familyName)
            await Defaults.shared.setAppleAuthID(credential.user)
            
            return try await signInFromProvider(
                with: OAuthProvider.credential(providerID: .apple, idToken: idToken, rawNonce: nonce),
                provider: .apple,
                email: email,
                givenName: givenName,
                familyName: familyName
            )
        } catch let error {
            self.addBreadcrumb(.error, .auth, "Sign in with Apple failed", error)
            throw error
        }
    }
}

// MARK: - Apple Manager (for delegate)

@MainActor
final class SignInWithAppleManager {
    var currentNonce: String?
    
    init() { }
    
    func signInWithApple() async throws -> ASAuthorization {
        let nonce = randomNonceString()
        self.currentNonce = nonce
        let hashedNonce = sha256(nonce)
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            objc_setAssociatedObject(controller, "delegateKey", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }
}

// MARK: - Apple Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first ?? UIWindow()
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Crypto

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }
        
        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
    return hashString
}

