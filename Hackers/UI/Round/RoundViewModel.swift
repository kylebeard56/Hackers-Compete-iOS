//
//  RoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import Combine
import SwiftUI

// TODO: Read below
/// 1. Player needs to choose who is the host
/// 2. Update modififcations to where only individual players can edit their own stuff if claimed, host otherwise.
/// 3. Bug fixes around ending a round.

typealias HoleRuleDictionary = [Int: String]

enum ChaosCardArrangement {
    case team, player, both
}

@MainActor
class RoundViewModel: Hackable {
    /// Session
    @Published var session: Session?
    @Published var sessionID: String = ""
    @Published var sessionCode: String = ""
    @Published var hostID: String = ""
    @Published var currentPlayerID: String = ""
    @Published var createdAt: Time?
    @Published var lastUpdatedAt: Time?
    @Published var sessionEnded: Bool = false
    
    // Session Debouncer
    @Published var sessionLock: Bool = false
    @Published var sessionPersistenceRequest: Int = 0
    @Published var debounceFulfillment: Int = 0
    private var subscription = Set<AnyCancellable>()
    
    /// Players
    @Published var players: [Player] = []//[kPlayerKyle, kPlayerSarah, kPlayerMurphy]
    
    /// Games
    @Published var chaosFlipped: Bool = false
    
    /// Rules
    @Published var allRules: [Rule] = []
    @Published var ruleMap: [String: Rule] = [:]
    
    /// Hole
    @Published var currentHole: Int = 1
    
    /// Chaos Cards
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = kRedrawCountDefault
    @Published var teamRules: HoleRuleDictionary = [:]  
    @Published var playerRules: [String: HoleRuleDictionary] = [:]
    @Published var arrangement: ChaosCardArrangement = .team // TODO: Add to session
    @Published var isDrawing: Bool = false
    
    /// Waitlist
    @Published var isOnWaitlist: Bool = false
    @Published var waitlistEmail: String = ""
    @Published var isJoiningWaitlist: Bool = false
    @Published var waitlistToast: ToastObserver = ToastObserver(
        success: "You're on the list!",
        failure: "Review email and try again"
    )
    
    init() {
        print("init RoundViewModel")
        createdAt = Time()
        
        /// Schedulers for requesting session persistence
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        _ = $teamDifficulty
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        _ = $teamRedrawCount
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        _ = $teamRules
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        _ = $playerRules
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        
        /// Debounce filter for persistence request
        $sessionPersistenceRequest
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.debounceFulfillment = value
                self?.persistSession()
            })
            .store(in: &subscription)
        
        self.isOnWaitlist = deviceDefaults.joinedDrinkingWaitlist
    }
    
    deinit { print("deinit RoundViewModel") }
    
    // MARK: - Reload
    
    func reload(for rules: [Rule]) {
        self.allRules = rules
        self.ruleMap = rules.reduce(into: [:], { $0[$1.id] =  $1 })
    }
}

// MARK: - Chaos Cards

extension RoundViewModel {
    
    func getTeamRule() -> Rule? {
        ruleMap[teamRules[currentHole] ?? ""]
    }
    
    func getPlayerRule(for id: String) -> Rule? {
        ruleMap[playerRules[id]?[currentHole] ?? ""]
    }
    
    func doesRuleExist(for hole: Int) -> Bool {
        return teamRules.keys.contains(hole)
    }
    
    @Sendable func draw() async {
        isDrawing = true
        defer {
            self.isDrawing = false
        }
        
        if arrangement == .team || arrangement == .both {
            await drawTeamRule()
        }
        if arrangement == .player || arrangement == .both {
            for p in players {
                await drawPlayerRule(for: p)
            }
        }
    }
    
    func drawTeamRule() async {
        print(#function)
        let rules = teamRules.compactMap({ ruleMap[$0.value] })
        let newRule = drawRule(from: rules, with: .team, and: teamDifficulty.randomRuleDifficulty)
        teamRules.updateValue(newRule.id, forKey: currentHole)
    }
    
    func drawPlayerRule(for player: Player) async {
        print(#function)
        let currentRules = playerRules[player.id]?.compactMap({ ruleMap[$0.value] }) ?? []
        
        // NOTE: [Beard May 2023]
        // This was overriden when we made team difficulty also be the player's difficulties.
        let difficulty = teamDifficulty.randomRuleDifficulty //player.difficulty.randomRuleDifficulty
        let newRule = drawRule(from: currentRules, with: .player, and: difficulty)
        
        if playerRules.keys.contains(player.id) {
            playerRules[player.id]?.updateValue(newRule.id, forKey: currentHole)
        } else {
            playerRules[player.id] = [currentHole : newRule.id]
        }
    }
    
    private func drawRule(from data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
        let usedIDs = Dictionary(uniqueKeysWithValues: data.map { ($0.id, "") })
        
        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
        let availableRules: [Rule] = allRules.filter({
            $0.type == type.rawValue
            && $0.difficulty == difficulty.rawValue
            && usedIDs[$0.id] == nil
        })
        
        /// 3. Return a random available rule
        if availableRules.count == 0 { return Rule() }
        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
    }
    
    @Sendable func redrawTeamCard() async {
        if teamRedrawCount < kInfiniteRedraws {
            teamRedrawCount -= 1
        }
        await drawTeamRule()
    }
    
    @Sendable func redrawCard(for p: Player) async throws {
        if let i = players.firstIndex(where: { p.id == $0.id }) {
            if players[i].redrawCount < kInfiniteRedraws {
                players[i].redrawCount -= 1
            }
            await drawPlayerRule(for: p)
        } else {
            throw HackersError.redrawFailed
        }
    }
    
    func clearHoleRule() {
        teamRules[currentHole] = nil
        players.forEach({ p in playerRules[p.id]?.removeValue(forKey: currentHole) })
    }
}

// MARK: - Scoring

extension RoundViewModel {
    
    var holeScoringHeight: CGFloat {
        return 200.0 + CGFloat(players.count) * 60.0
    }
    
    func scoringExists(for hole: Int) -> Bool {
        for p in players {
            if let s = PlayerScore(rawValue: p.score[hole] ?? "") {
                if s == .none { continue }
                return true
            }
        }
        return false
    }
    
    func metricsAvailable() -> Bool {
        for i in 1...18 {
            if scoringExists(for: i) {
                return true
            } else {
                continue
            }
        }
        return false
    }
}

// MARK: - Session

extension RoundViewModel {
    
    // MARK: - Load
    
    func loadSession(_ s: Session) {
        print(#function)

        printPretty(s)
        self.sessionLock = true
        defer { self.sessionLock = false }
        
        self.session = s
        self.sessionID = s.id
        self.sessionCode = s.code
        self.hostID = s.host
        self.createdAt = s.createdAt
        self.lastUpdatedAt = s.lastUpdatedAt
        self.sessionEnded = s.ended // someone else ended the session
        
        self.players = s.players.compactMap({ Player(session: $0) }).filter({ $0.isPlaying })
        
        self.teamDifficulty = GameDifficulty(rawValue: s.teamDifficulty) ?? .medium
        self.teamRedrawCount = s.teamRedrawCount
        
        withAnimation(.linear(duration: 0.125)) {
            self.teamRules = s.gameplay.teamRule
            self.playerRules = s.gameplay.playerRules
        }
    }
    
    @Sendable
    func fetchSession() async {
        do {
            let s = try await FirebaseService.shared.getSession(by: self.sessionID).get()
            self.loadSession(s)
        } catch let error {
            print("error fetching session, \(error)")
        }
    }
    
    // MARK: - Save
    
    func requestSessionPersistence() {
        if sessionLock { return }
        sessionPersistenceRequest += 1
    }
    
    func persistSession() {
        print(#function)
        if sessionID.isEmpty { return }
        
        self.session = Session(
            id: sessionID,
            ended: sessionEnded,
            code: sessionCode,
            host: hostID,
            teamDifficulty: teamDifficulty.rawValue,
            teamRedrawCount: teamRedrawCount,
            players: players.filter({ $0.isPlaying }).compactMap({ PlayerSession(player: $0) }),
            gameplay: GameplaySession(teamRule: teamRules, playerRules: playerRules),
            createdAt: createdAt ?? Time(),
            lastUpdatedAt: Time())
        
        Task {
            await self.session?.put()
            printPretty(self.session)
        }
    }
}

// MARK: - Waitlist

extension RoundViewModel {
    
    @Sendable func joinWaitlist() async {
        isJoiningWaitlist = true
        defer { isJoiningWaitlist = false }
        
        if !self.waitlistEmail.isValidEmail {
            self.waitlistToast.present(.failure)
            return
        }
        
        let w = Waitlist(id: "", email: self.waitlistEmail, reason: "future games", time: Time())
        
        do {
            try await w.post().get()
            self.waitlistToast.present(.success)
            deviceDefaults.joinedDrinkingWaitlist = true
            Haptics.fire(.success)
            withAnimation(.linear(duration: 0.2)) {
                self.isOnWaitlist = true
            }
        } catch let error {
            print("error joining waitlist, \(error)")
            self.addBreadcrumb(.warning, .waitlist, "joining waitlist", error)
        }
    }
}
