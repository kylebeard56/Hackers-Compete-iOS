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
    @Published var players: [Player] = []
    
    /// Rules
    @Published var allRules: [Rule] = []
    @Published var ruleMap: [String: Rule] = [:]
    
    /// Hole
    @Published var currentHole: Int = 1
    
    /// Gameplay
    @Published var teamDifficulty: GameDifficulty = .medium
    @Published var teamRedrawCount: Int = 3
    @Published var teamRules: HoleRuleDictionary = [:]
    @Published var playerRules: [String: HoleRuleDictionary] = [:]
    
    /// Tracking
    @Published var rulesRevealed: [Bool] = Array(repeating: false, count: 18)
    @Published var isDrawing: Bool = false
    
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
    }
    
    deinit { print("deinit RoundViewModel") }
    
    // MARK: - Reload
    
    func reload(for rules: [Rule]) {
        self.allRules = rules
        self.ruleMap = rules.reduce(into: [:], { $0[$1.id] =  $1 })
    }
}

// MARK: - Drawing

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
        
        await computeRules()
        rulesRevealed[currentHole] = false
    }
    
    private func computeRules() async {
        await drawTeamRule()
        for player in players {
            await drawPlayerRule(for: player)
        }
    }
    
    func drawTeamRule() async {
        print(#function)
        let rules = teamRules.compactMap({ ruleMap[$0.value] })
        let newRule = drawRule(from: rules, with: .team, and: teamDifficulty.randomRuleDifficulty)
        teamRules.updateValue(newRule.id, forKey: currentHole)
        printPretty(teamRules)
    }
    
    func drawPlayerRule(for player: Player) async {
        let currentRules = playerRules[player.id]?.compactMap({ ruleMap[$0.value] }) ?? []
        let newRule = drawRule(from: currentRules, with: .player, and: player.difficulty.randomRuleDifficulty)
//        playerRules[player.id] = [currentHole : newRule.id]
        playerRules[player.id]?.updateValue(newRule.id, forKey: currentHole)
        printPretty(playerRules)
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
        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
    }
    
    @Sendable func redrawTeamCard() async {
        if teamRedrawCount < 6 {
            teamRedrawCount -= 1
        }
        await drawTeamRule()
    }
    
    @Sendable func redrawCard(for p: Player) async throws {
        if let i = players.firstIndex(where: { p.id == $0.id }) {
            if players[i].redrawCount < 6 {
                players[i].redrawCount -= 1
            }
            await drawPlayerRule(for: p)
        } else {
            throw HackersError.redrawFailed
        }
    }
    
    func clearHoleRule() {
        rulesRevealed[currentHole] = true
        teamRules[currentHole] = nil
        players.forEach({ p in playerRules[p.id]?.removeValue(forKey: currentHole) })
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
