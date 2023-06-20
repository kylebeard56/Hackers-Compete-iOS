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
    @Published var sessionCodeError: SessionCodeError = .none
    
    // MARK: - Load
    
//    @Published var isLoading: Bool = false
    @Published var isJoiningWithPartyCode: Bool = false
    @Published var isVerifyingPartyCode: Bool = false
    @Published var partyCodeError: PartyCodeError = .none
    @Published var isReady: Bool = false
    
    // MARK: - Setup your Round
    
    @Published var numberOfHoles: Int = 18
    @Published var startingSide: String = "front"
    @Published var startingHole: Int = 1
    
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
    
    init() {
        print("init AppSession")
        Task(operation: load)
        
        _ = $startingSide
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { s in self.updateRoundSetup(for: s) })
        
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { p in self.updatePlayerValues(for: p) })
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
    
    private func updateRoundSetup(for side: String) {
        if side == "front" && startingHole > 9 {
            startingHole = 1
        }
        if side == "back" && startingHole < 10 {
            startingHole = 10
        }
    }
    
    private func updatePlayerValues(for players: [Player]) {
        arePlayersEmpty = players.compactMap({ !$0.name.isEmpty }).filter({ $0 }).isEmpty
    }
}

extension AppSession {
    
    // MARK: - Navigation
    
    func goToRoundSetup() {
        path.append(Destination.roundSetup)
    }
    
    func goToPlayers() {
        path.append(Destination.players)
    }
    
    func goToSideGames() {
        path.append(Destination.sideGames)
    }
    
    func goToPartyCode() {
        path.append(Destination.partyCode)
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
        
        /// 1. Fetch session IDs from device cache
        let sessionIDs = deviceDefaults.sessionHistory
        currentSessions.removeAll()
        pastSessions.removeAll()
        
        if sessionIDs.isEmpty {
            print("no existing session IDs cached to device")
            return
        }
        
        /// 2. Fetch the session data for each cached ID (either from Realm or Firebase)
        for id in sessionIDs {
            if let s = try? await FirebaseService.shared.getSession(by: id).get() {
                /// 2a. If the round was created more than 24 hours ago, we consider it expired and no longer editable
                if s.createdAt.unix < Date().timeIntervalSince1970 - activeSessionTimeInterval {
                    pastSessions.append(s)
                } else {
                    currentSessions.append(s)
                }
            } else {
                self.addBreadcrumb(.warning, .session, "couldn't get session by id [\(id)]")
            }
        }
        
        /// 3. Sort by newest to oldest for future data display
        currentSessions = currentSessions.sorted(by: { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix })
        pastSessions = pastSessions.sorted(by: { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix })
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
    
    func verifyPartyCode(_ code: String) async {
        print(#function)
        
        if await FirebaseService.shared.isCodeAvailableForSession(code) {
            self.partyCodeError = .taken
            return
        } else {
            self.session?.partyCode = code
            guard let s = try? await self.session?.put().get() else {
                self.partyCodeError = .saveFailed
                return
            }
            self.sessionCode = code
            self.goToRoundPlay()
        }
    }
    
//    func verify(partyCode: String) async -> Result<Session, Error> {
//        print(#function)
//
//        do {
//            _ = try await FirebaseService.shared.getSession(using: partyCode).get()
//            return .failure(HackersError.partyCodeTaken)
//        } catch let error {
//            if let e = error as? HackersError, e == .documentNotFound {
//                self.session?.partyCode = partyCode
//                do {
//                    if let s = try await self.session?.put().get() {
//                        self.sessionCode = partyCode
//                        return .success(s)
//                    } else {
//                        return .failure(HackersError.sessionWriteFailed)
//                    }
//                } catch let error {
//                    return .failure(error)
//                }
//            } else {
//                return .failure(error)
//            }
//        }
//    }
    
    /// Fetch a session by the party code manually entered by a user.
    @Sendable func fetchSessionFromPartyCode() async {
        print(#function)
        
        sessionCodeError = .none
        isJoiningWithPartyCode = true
        defer { isJoiningWithPartyCode = false }
        
        do {
            let s = try await FirebaseService.shared.getSession(using: self.sessionCode).get()
            if s.createdAt.unix < Date().timeIntervalSince1970 - activeSessionTimeInterval {
                Haptics.fire(.error)
                self.sessionCodeError = .expired
            } else {
                self.startRound(for: s)
            }
        } catch let error {
            self.addBreadcrumb(.warning, .session, "couldn't find session by party code [\(self.sessionCode)]", error)
            Haptics.fire(.error)
            self.sessionCodeError = .notFound
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
