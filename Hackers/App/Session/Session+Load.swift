//
//  Session+Load.swift
//  Hackers
//
//  Created by Kyle Beard on 9/15/25.
//

import SwiftUI

extension AppSession {
    func load() async {
        addBreadcrumb(#function)
        
        self.isLoading = true
        defer { self.isLoading = false }
        
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
}

extension AppSession {
    fileprivate enum LegalScope { case both, local, remote }
    
    fileprivate func requiresLegalAcceptance(for scope: LegalScope) async -> Bool {
        if scope == .both || scope == .local {
            let t = await Defaults.shared.getAcceptedTermsOfUse().last ?? ""
            let p = await Defaults.shared.getAcceptedPrivacyPolicy().last ?? ""
            if t.isEmpty && p.isEmpty { return true }
        }
        
        var currentTermsVersion = await AppData.shared.currentTermsVersion
        var currentPolicyVersion = await AppData.shared.currentPolicyVersion
        
        if scope == .both || scope == .remote,
           let legal = await AppData.shared.user?.legal {
            
            // Only fetch from Firebase if AppData doesn't have the versions
            if currentTermsVersion == nil {
                currentTermsVersion = try? await FirebaseService.shared.fetchLatestTermsVersion()
            }
            
            if currentPolicyVersion == nil {
                currentPolicyVersion = try? await FirebaseService.shared.fetchLatestPolicyVersion()
            }
            
            // Ensure we have both versions before proceeding
            guard let terms = currentTermsVersion,
                  let policy = currentPolicyVersion else {
                self.addBreadcrumb(.error, .legal, "Failed to get legal versions from AppData or Firebase")
                return true
            }
            
            await AppData.shared.setLegalVersions(terms: terms, policy: policy)
            
            let termsUpToDate = legal.isTermsUpToDate(for: terms)
            let privacyUpToDate = legal.isPolicyUpToDate(for: policy)
            return !termsUpToDate || !privacyUpToDate
        } else {
            self.addBreadcrumb(.error, .legal, "Failed to check legal from missing user")
        }
        
        return true
    }
}
