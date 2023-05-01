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
    @Published var canContinueRound: Bool = false
    @Published var existingSessionID: String = ""
    @Published var existingSessionCode: String = ""
    @Published var continueSubtitle: String?
    
    // MARK: - Load
    
    @Published var isLoading: Bool = false
    @Published var isReady: Bool = false
    
    // MARK: - Players
    
    @Published var players: [Player] = kDefaultPlayers { //[kPlayerKyle, kPlayerSarah, kPlayerMurphy] {
        didSet {
            arePlayersEmpty = players.compactMap({ !$0.name.isEmpty }).filter({ $0 }).isEmpty
        }
    }
    @Published var arePlayersEmpty: Bool = true
    
    // MARK: - Details & Menu
    
    @Published var holes: [Hole] = kDefaultHoles
    
    // MARK: - Packs
    
    @Published var gameTab: Int = 0
    @Published var packs: [Pack] = []
    @Published var gameplayPack: Pack = Pack()
    @Published var drinkingPack: Pack = Pack()
    @Published var isLoadingPacks: Bool = false
    
    // MARK: - Rules
    
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
        await getPacks()
        await getRules()
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
    
    func checkSessionState() async {
        self.canContinueRound = false
        self.existingSessionID = ""
        self.continueSubtitle = nil
        
        if let sessionID = UserDefaults.standard.string(forKey: kSessionID) {
            if sessionID.isEmpty {
                print("session ID empty")
                return
            }
            
            print("existing session id \(sessionID)")
            
            do {
                let s = try await FirebaseService.shared.getSession(by: sessionID).get()
                FirebaseService.shared.observeSession(for: s.id)
                self.existingSessionID = sessionID
                self.canContinueRound = true
                self.sessionCode = self.session?.code ?? ""
                self.session = s
                if let m = s.gameplay.teamRule.keys.max() {
                    self.continueSubtitle = "Thru \(m) with \(s.playerNames)"
                } else {
                    self.continueSubtitle = s.playerNames
                }
                printPretty(s)
                print("previous session fetched by user default ID \(sessionID)")
            } catch let error {
                print("error getting session, \(error)")
            }
        } else {
            print("session ID doesn't exist in user defaults")
        }
    }
    
    @Sendable
    func getPacks() async {
        isLoadingPacks = true
        defer { isLoadingPacks = false }
        do {
            self.packs = try await FirebaseService.shared.getPacks().get()
            self.gameplayPack = self.packs.first(where: { $0.id == PackName.gameplay.rawValue }) ?? kGameplayPack
            self.drinkingPack = self.packs.first(where: { $0.id == PackName.drinking.rawValue }) ?? kDrinkingPack
        } catch let error {
            print("couldn't load packs, \(error)")
            self.addBreadcrumb(.error, .session, "couldn't GET packs", error)
        }
    }
    
    @Sendable
    func getRules() async {
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
    
    func startNewRound() async {
        let session = Session(
            id: "",
            ended: false,
            code: "",
            host: players.first?.id ?? "",
            activeGame: HackersGame.traditional.rawValue,
            teamDifficulty: GameDifficulty.medium.rawValue,
            teamRedrawCount: 3,
            players: players.compactMap({ PlayerSession(player: $0) }),
            arrangement: ChaosCardArrangement.combo.rawValue,
            gameplay: GameplaySession(),
            createdAt: Time(),
            lastUpdatedAt: Time())
        
        do {
            let s = try await session.post().get()
            printPretty(s)
            FirebaseService.shared.observeSession(for: s.id)
            UserDefaults.standard.set(s.id, forKey: kSessionID)
            self.session = s
            FirebaseEvent.shareCodeRedeemed.log()
            self.goToRoundPlay()
        } catch let error {
            print("error starting round, \(error)")
        }
    }
    
    func continueSession() async {
        print(#function)
        
        if let s = self.session {
            FirebaseService.shared.observeSession(for: s.id)
            UserDefaults.standard.set(s.id, forKey: kSessionID)
            FirebaseEvent.continueRoundStarted.log()
            self.goToRoundPlay()
        }
    }
    
    func verify(partyCode: String) async -> Result<Session, Error> {
        print(#function)
        
        do {
            _ = try await FirebaseService.shared.getSession(using: partyCode).get()
            return .failure(HackersError.partyCodeTaken)
        } catch let error {
            if let e = error as? HackersError, e == .documentNotFound {
                self.session?.code = partyCode
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
    
    func fetchSessionFromPartyCode() async {
        print(#function)
        
        do {
            let s = try await FirebaseService.shared.getSession(using: self.sessionCode).get()
            printPretty(s)
            /// If previous round detected and IDs differ from party code, end previous session.
            if canContinueRound && s.id != existingSessionID {
                await self.endSession()
            }
            FirebaseService.shared.observeSession(for: s.id)
            UserDefaults.standard.set(s.id, forKey: kSessionID)
            self.session = s
            self.sessionCode = s.code
            FirebaseEvent.shareCodeRedeemed.log()
            self.goToRoundPlay()
        } catch let error {
            print("error session not found, \(error)")
            Haptics.fire(.error)
            showSessionCodeToast = true
        }
    }
}

extension AppSession {
    
    // MARK: - Ending Round
    
    @Sendable func clearRound() async {
        print(#function)
        players = kDefaultPlayers
        holes = kDefaultHoles
        gameTab = 0
        AppStoreReviewManager.requestReview()
        await checkSessionState()
        self.goToLanding()
    }
    
    @Sendable func endRound() async {
        print(#function)
        await self.clearRound()
        await self.endSession()
        UserDefaults.standard.set("", forKey: kSessionID)
    }
    
    @Sendable func endSession() async {
        print(#function)
        print("ending session with ID: [\(self.session?.id ?? "N/A")]")
        
        // Stop session observation first to prevent triggering "Round complete" false positive.
        FirebaseService.shared.stopSessionObservation()
        
        self.session?.ended = true
        await self.session?.put()
        self.session = nil
        self.sessionCode = ""
        self.existingSessionID = ""
        self.canContinueRound = false
        UserDefaults.standard.set("", forKey: kSessionID)
        self.goToLanding()
    }
}
