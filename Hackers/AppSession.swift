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
    
    // MARK: - Navigation
    
    @Published var path = NavigationPath()
    
    // MARK: - Session
    
    @Published var session: Session?
    @Published var sessionCode: String = ""
    @Published var canContinueRound: Bool = false
    @Published var continueSubtitle: String = ""
    
    // MARK: - Load
    
    @Published var isLoading: Bool = false
    @Published var isReady: Bool = false
    
    // MARK: - Players
    
    @Published var players: [Player] = kDefaultPlayers {
        didSet {
            arePlayersEmpty = players.compactMap({ !$0.name.isEmpty }).filter({ $0 }).isEmpty
        }
    }
    @Published var arePlayersEmpty: Bool = true
    
    // MARK: - Details & Menu
    
    @Published var holes: [Hole] = kDefaultHoles
    
    // MARK: - Packs
    
    @Published var activePack: Int = 0
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

    // MARK: - Toast
    
    @Published var sessionCodeToast: ToastObserver = ToastObserver(success: "", failure: "Party code not found")
    
    init() {
        print("init AppSession")
        Task(operation: load)
    }
    
    deinit { print("deinit AppSession") }
    
    @Sendable
    private func load() async {
        await loginAnonymously()
        await checkSessionState()
        await getPacks()
        await getRules()
        self.isReady = true
    }
    
//    private func testPrintStatementsBecauseImTooLazyToSetupUnitTestsWithoutGettingStupidAssBuildErrors() {
//        var easyMode: [RuleDifficulty] = []
//        var mediumMode: [RuleDifficulty] = []
//        var hardMode: [RuleDifficulty] = []
//        let x = 18
//        for _ in 1...x {
//            easyMode.append(GameDifficulty.easy.randomRuleDifficulty)
//            mediumMode.append(GameDifficulty.medium.randomRuleDifficulty)
//            hardMode.append(GameDifficulty.hard.randomRuleDifficulty)
//        }
//        print("Easy Favor: \(easyMode.filter({ $0 == .favor }).count) / \(x)")
//        print("Medium Favor: \(mediumMode.filter({ $0 == .favor }).count) / \(x)")
//        print("Hard Favor: \(hardMode.filter({ $0 == .favor }).count) / \(x)")
//    }
    
    private func loginAnonymously() async {
        do {
            let user = try await FirebaseService.shared.loginAnonymously().get()
            print("logged in anonymously for id: \(user.uid)")
        } catch let error {
            print("couldn't login anonymously, \(error)")
        }
    }
    
    private func checkSessionState() async {
        self.canContinueRound = false
        if let sessionID = UserDefaults.standard.string(forKey: kSessionID) {
            if sessionID.isEmpty {
                print("session ID empty")
                return
            }
            
            print("existing session id \(sessionID)")
            
            do {
                self.session = try await FirebaseService.shared.getSession(by: sessionID).get()
                self.canContinueRound = true
                self.sessionCode = self.session?.code ?? ""
                if let m = self.session?.gameplay.teamRule.keys.max() {
                    self.continueSubtitle = " (Thru \(m))"
                }
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
    
    func goToRoundSummary() {
        path.append(Destination.roundSummary)
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
            teamDifficulty: GameDifficulty.medium.rawValue,
            teamRedrawCount: 3,
            players: players.compactMap({ PlayerSession(player: $0) }),
            gameplay: GameplaySession(),
            createdAt: Time(),
            lastUpdatedAt: Time())
        
        do {
            let s = try await session.post().get()
            printPretty(s)
            UserDefaults.standard.set(s.id, forKey: kSessionID)
            self.session = s
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
            FirebaseService.shared.observeSession(for: s.id)
            UserDefaults.standard.set(s.id, forKey: kSessionID)
            self.session = s
            self.sessionCode = s.code
            self.goToRoundPlay()
        } catch let error {
            print("error session not found, \(error)")
            Haptics.fire(.error)
            sessionCodeToast.present(.failure)
        }
    }
}

extension AppSession {
    
    // MARK: - Ending Round
    
    func endRound() {
        print(#function)
        endSession()
        players = kDefaultPlayers
        holes = kDefaultHoles
        activePack = 0
        UserDefaults.standard.set("", forKey: kSessionID)
        self.goToLanding()
    }
    
    func endSession() {
        print(#function)
        Task {
            self.session?.ended = true
            await self.session?.put()
            self.session = nil
            self.sessionCode = ""
            self.canContinueRound = false
            UserDefaults.standard.set("", forKey: kSessionID)
            self.goToRoundSummary()
        }
    }
}
