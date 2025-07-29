//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

@MainActor
final class AppSession: ObservableObject, Sendable, Loggable {
    @Published var path = NavigationPath()
    @Published var isLoading = true
    @Published var joinRoundID: String?
    @Published var authType: AuthType?
    
    @Published var currentTermsVersion = ""
    @Published var currentPolicyVersion = ""
    @Published var promptForLegalAcceptance = false
    
    @Published var isRouting = false
    @Published var isSigningApple = false
    @Published var isSigningGoogle = false
    @Published var isAcceptingTerms = false
    @Published var isSavingProfile = false
    
    init() {
        print("init AppSession")
        Task {
            await self.load()
        }
    }
    
    deinit { print("deinit AppSession") }
    
    func load() async {
        addBreadcrumb(#function)
        
        self.isLoading = true
        defer {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.isLoading = false
            }
        }
        
        /// 1. Ensure app version is sufficient, will route automatically if not
        await FirebaseService.shared.observeMinimumAppVersion()
        
        /// 2. Check if they need legal
        /// If authenticating, you'll get hit with the popup if you haven't saved
        self.promptForLegalAcceptance = await requiresLegalAcceptance(for: .local)
        
        /// 3. Check if current user exists, go to auth otherwise
        guard let u = AuthService.shared.getCurrentUser() else {
            routeTo(.auth)
            return
        }
        
        /// 3. Get the latest user record and re-check remote legal
        do {
            let user = try await FirebaseService.shared.getUserByEmail(u.email ?? "").get()
            await AppData.shared.setUser(user)
            self.promptForLegalAcceptance = await requiresLegalAcceptance(for: .both)
            printPretty(user)
        } catch let error {
            addBreadcrumb(.error, .auth, "User not fetched during load", error)
        }
        
        /// 4. If a user has authenticated, but hasn't created their profile yet, we can handle that when they do their first round.
        routeTo(.dashboard)
    }
    
    private enum LegalScope { case both, local, remote }
    
    private func requiresLegalAcceptance(for scope: LegalScope) async -> Bool {
        if scope == .both || scope == .local {
            let t = await Defaults.shared.getAcceptedTermsOfUse().last ?? ""
            let p = await Defaults.shared.getAcceptedPrivacyPolicy().last ?? ""
            if t.isEmpty && p.isEmpty { return true }
        }
        
        if scope == .both || scope == .remote,
           let legal = await AppData.shared.user?.legal,
           let terms = try? await FirebaseService.shared.fetchLatestTermsVersion(),
           let privacy = try? await FirebaseService.shared.fetchLatestPolicyVersion() {
            
            let termsUpToDate = legal.isTermsUpToDate(for: terms)
            let privacyUpToDate = legal.isPolicyUpToDate(for: privacy)
            return !termsUpToDate || !privacyUpToDate
        } else {
            self.addBreadcrumb(.error, .legal, "Failed to check legal from missing user or failed firebase call")
        }
        
        return true
    }
    
    func reset() {
        addBreadcrumb(#function)
        path.removeLast(path.count)
        Task { await AppData.shared.clearUser() }
        routeTo(.auth)
    }
}

// MARK: - Authentication

extension AppSession {
    func signInWithApple() async {
        addBreadcrumb(#function)
        
        isSigningApple = true
        defer { isSigningApple = false }
        
        authType = .apple
        if promptForLegalAcceptance {
            // TODO: Present popup that they need to accept terms.
            // Any future terms will be a notification banner on the home screen.
            return
        }
        
        do {
            let user = try await AuthService.shared.signInWithApple()
            await AppData.shared.setUser(user)
            await load()
        } catch let error {
            addBreadcrumb(.error, .auth, "Sign in with Apple failed", error)
            // TODO: Toast
        }
    }
    
    func signInWithGoogle() async {
        addBreadcrumb(#function)
        
        isSigningGoogle = true
        defer { isSigningGoogle = false }
        
        authType = .google
        if promptForLegalAcceptance {
            // TODO: Present popup that they need to accept terms.
            // Any future terms will be a notification banner on the home screen.
            return
        }
        
        do {
            let user = try await AuthService.shared.signInWithGoogle()
            await AppData.shared.setUser(user)
            await load()
        } catch let error {
            addBreadcrumb(.error, .auth, "Sign in with Google failed", error)
            // TODO: Toast
        }
    }
}

extension AppSession {
    
    // MARK: - Navigation
    
    /// Route to a destination and optional pre-qeueue a list of views prior.
    /// Ex: If routing to .birthday for onboarding, you may want to add the prior onboarding steps for clean navigation.
    func routeTo(_ destination: Destination, prequeue: [Destination] = []) {
        addBreadcrumb(.info, .routing, "route to \(destination)")
        
        // TODO: Add ability to signify the view is a "major" "where you can dismiss routing back last major spot.
        
//        if isLoading {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
//                withAnimation(.easeInOut(duration: 0.2)) {
//                    self.isLoading = false
//                }
//            })
//        }
        
        UIApplication.shared.endEditing()
        
        for p in prequeue {
            path.append(p)
        }
        
        if destination == .auth {
            path.removeLast(path.count)
        } else {
            path.append(destination)
        }
    }
}
