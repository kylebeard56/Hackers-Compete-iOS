//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Combine
import FirebaseAuth
import SwiftUI

@MainActor
class AppSession: Hackable {
    
    // MARK: - Legal
    
    @Published var showTerms: Bool = false
    
    // MARK: - Navigation
    
    @Published var path = NavigationPath()
    
    // MARK: - Session
    
    @Published var session: Session?
    @Published var sessionCode: String = ""
    @Published var currentSessions: [Session] = []
    @Published var pastSessions: [Session] = []
    
    // MARK: - Load
    
    @Published var isLoading: Bool = false
    @Published var isReady: Bool = false
    
    // MARK: - Players
    
    @Published var players: [Player] = kDefaultPlayers
    @Published var arePlayersEmpty: Bool = true
    
    // MARK: - Cards of Chaos Rules
    
    @Published var rules: [Rule] = []
    @Published var isLoadingRules: Bool = false
    
    // MARK: - Reveal
    
    @Published var revealCards: Bool = false
    @Published var revealScore: Bool = false
    @Published var revealTab: String = "team"
    
    // MARK: - Toast
    
    @Published var showSessionCodeToast: Bool = false
    
    init() {
        print("init AppSession")
        Task(operation: load)
    }
    
    deinit { print("deinit AppSession") }
    
    @Sendable private func load() async {
        await loginAnonymously()
        await getLatestTermsVersion()
        await checkSessionState()
        
       
//        await getChaosRules()

        self.isReady = true
    }
    
    private func loginAnonymously() async {
        do {
            let user = try await FirebaseService.shared.loginAnonymously().get()
            FirebaseService.shared.observeMinimumAppVersion()
            print("logged in anonymously for id: \(user.uid)")
        } catch let error {
            print("couldn't login anonymously, \(error)")
        }
    }
    
    private func getLatestTermsVersion() async {
        do {
            let v = try await FirebaseService.shared.getLatestTermsVersion().get()
            print("latest terms version: \(v)")
            let compare = deviceDefaults.lastKnownTermsVersion.versionCompare(v)
            if compare == .orderedAscending || !deviceDefaults.acceptedTerms {
                deviceDefaults.lastKnownTermsVersion = v
                showTerms = true
            }
        } catch let error {
            print("couldn't get latest terms version, \(error)")
        }
    }
    
    // TODO: Only load this if the user wants to play Cards of Chaos?
    @Sendable func getChaosRules() async {
        isLoadingRules = true
        defer { isLoadingRules = false }
        do {
            self.rules = try await FirebaseService.shared.getRules().get()
        } catch let error {
            print("couldn't load rules, \(error)")
            self.addBreadcrumb(.error, .session, "couldn't GET rule", error)
        }
    }
}

extension AppSession {
    
    // MARK: - Navigation
    
    func goToPlayers() {
        path.append(Destination.players)
    }
    
    func goToRoundPlay() {
        path.append(Destination.roundPlay)
    }
    
    func goToLanding() {
        path.removeLast(path.count)
    }
}

extension AppSession {
    
    // MARK: - Session
    
    func checkSessionState() async {
        print(#function)
        
        let sessionIDs = deviceDefaults.sessionHistory
        currentSessions.removeAll()
        pastSessions.removeAll()
        
        if sessionIDs.isEmpty {
            print("no existing session IDs cached to device")
            return
        }
        
        for id in sessionIDs {
            if let s = try? await FirebaseService.shared.getSession(by: id).get() {
                if s.createdAt.unix < Date().timeIntervalSince1970 - 86400 {
                    pastSessions.append(s)
                } else {
                    currentSessions.append(s)
                }
            } else {
                self.addBreadcrumb(.warning, .session, "couldn't get session by id [\(id)]")
            }
        }
    }
    
    func startRound(for session: Session) {
        print(#function)
        printPretty(session)
        
        FirebaseService.shared.observeSession(for: session.id)
        self.session = session
        self.sessionCode = session.partyCode
        self.cacheSession(by: session.id)
        self.goToRoundPlay()
    }
    
    func startNewRound() async {
        print(#function)
        
        let session = Session(
            id: "",
            partyCode: "",
            players: players.compactMap({ PlayerSession(player: $0) }),
            sideGames: [],
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
        
        do {
            self.startRound(for: try await session.post().get())
        } catch let error {
            self.addBreadcrumb(.error, .session, "couldn't start new round", error)
        }
    }
    
    func verify(partyCode: String) async -> Result<Session, Error> {
        print(#function)
        
        do {
            _ = try await FirebaseService.shared.getSession(using: partyCode).get()
            return .failure(HackersError.partyCodeTaken)
        } catch let error {
            if let e = error as? HackersError, e == .documentNotFound {
                self.session?.partyCode = partyCode
                do {
                    if let s = try await self.session?.put().get() {
                        self.sessionCode = partyCode
                        return .success(s)
                    } else {
                        return .failure(HackersError.sessionWriteFailed)
                    }
                } catch let error {
                    return .failure(error)
                }
            } else {
                return .failure(error)
            }
        }
    }
    
    /// Fetch a session by the party code manually entered by a user.
    func fetchSessionFromPartyCode() async {
        print(#function)
        
        do {
            let s = try await FirebaseService.shared.getSession(using: self.sessionCode).get()
            self.startRound(for: s)
        } catch let error {
            self.addBreadcrumb(.warning, .session, "couldn't find session by party code [\(self.sessionCode)]", error)
            Haptics.fire(.error)
            showSessionCodeToast = true
        }
    }
    
    /// Store the session ID to device cache
    private func cacheSession(by id: String) {
        var ids = deviceDefaults.sessionHistory
        ids.append(id)
        ids = ids.uniques
        deviceDefaults.sessionHistory = ids
    }
    
    /// Remove the session ID from cache, losing it forever (but keeping it in DB for metric purposes).
    func removeCachedSession(by id: String) {
        print(#function)
        var ids = deviceDefaults.sessionHistory
        if let i = ids.firstIndex(where: { $0 == id }) {
            ids.remove(at: i)
            ids = ids.uniques
            deviceDefaults.sessionHistory = ids
            print("Session [\(id)] removed from device history")
        } else {
            print("Cached session not found in device history")
        }
    }
}

extension AppSession {
    
    // MARK: - Finishing Round

    @Sendable func leaveRound() async {
        print(#function)
        
        // 1. Stop observing current session
        FirebaseService.shared.stopSessionObservation()
        
        // 2. Reload sessions for future selection on landing page
        await checkSessionState()
        
        // 3. Navigate back to the landing page
        self.goToLanding()
        
        // 4. Clear out player scores and teams, but preserve name, color, and HCP in current app memory.
        players = players.compactMap({ $0.stripped() })
        
        // 5. Check to see if we can ask user if they're liking Hackers
        AppStoreReviewManager.requestReview()
    }
}
