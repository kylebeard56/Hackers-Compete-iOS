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

typealias HoleRuleDictionary = [Int: Rule]

@MainActor
class RoundViewModel: Hackable {
    /// Session
    @Published var session: Session?
    @Published var sessionID: String = ""
    @Published var sharableCode: String = ""
    @Published var hostID: String = ""
    @Published var currentPlayerID: String = ""
    @Published var createdAt: Time?
    @Published var lastUpdatedAt: Time?
    
    // Session Debouncer
    @Published var sessionPersistenceRequest: Int = 0
    @Published var debounceFulfillment: Int = 0
    private var subscription = Set<AnyCancellable>()
    
    /// Players
    @Published var players: [Player] = [] // { didSet { requestSessionPersistence() }  }
    
    /// Rules
    @Published var allRules: [Rule] = []
    @Published var ruleMap: [String: Rule] = [:]
    
    /// Hole
    @Published var currentHole: Int = 1
    
    /// Gameplay
    @Published var teamDifficulty: GameDifficulty = .medium // { didSet { requestSessionPersistence() }  }
    @Published var teamRedrawCount: Int = 3 // { didSet { requestSessionPersistence() }  }
    @Published var teamRules: HoleRuleDictionary = [:] // { didSet { requestSessionPersistence() }  }
    @Published var playerRules: [HoleRuleDictionary] = [] // { didSet { requestSessionPersistence() }  }
    
    /// Tracking
    @Published var rulesExist: [Int: Bool] = [:]
    @Published var rulesRevealed: [Bool] = Array(repeating: false, count: 18)
    @Published var isDrawing: Bool = false
    
    init() {
        print("init RoundViewModel")
        createdAt = Time()
        for i in 1..<kHoleCount {
            rulesExist[i] = false
        }
        
        /// Schedulers for requesting session persistence
        $players.sink(receiveValue: { _ in self.requestSessionPersistence() })
        $teamDifficulty.sink(receiveValue: { _ in self.requestSessionPersistence() })
        $teamRedrawCount.sink(receiveValue: { _ in self.requestSessionPersistence() })
        $teamRules.sink(receiveValue: { _ in self.requestSessionPersistence() })
        $playerRules.sink(receiveValue: { _ in self.requestSessionPersistence() })
        
        /// Debounce filter for persistence request
        $sessionPersistenceRequest
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                print("debounce")
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
    
    // MARK: - Rules
    
    @Sendable
    func draw() async {
        isDrawing = true
        defer {
            self.isDrawing = false
        }
        
        await computeRules()
        rulesExist[currentHole] = true
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
        let rules = teamRules.compactMap({ $0.value })
        let newRule = drawRule(from: rules, with: .team, and: teamDifficulty.randomRuleDifficulty)
        teamRules.updateValue(newRule, forKey: currentHole)
    }
    
    func drawPlayerRule(for player: Player) async {
        if playerRules.isEmpty {
            var blankDictionary: HoleRuleDictionary = [:]
            for i in 0..<kHoleCount { blankDictionary.updateValue(Rule(), forKey: i) }
            players.forEach { _ in playerRules.append(blankDictionary) }
        }
        
        if let i = players.firstIndex(where: { $0.id == player.id }) {
            let rules = playerRules[i].filter({ !$0.value.id.isEmpty }).compactMap({ $0.value })

            let newRule = drawRule(from: rules, with: .player, and: player.difficulty.randomRuleDifficulty)
            playerRules[i].updateValue(newRule, forKey: currentHole)
        }
    }
    
    private func drawRule(from data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
        print(#function)
        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
        let usedIDs = Dictionary(uniqueKeysWithValues: data.map { ($0.id, "") })
        
        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
        let availableRules: [Rule] = allRules.filter({
            $0.type == type.rawValue
            && $0.difficulty == difficulty.rawValue
            && usedIDs[$0.id] == nil
        })
        
        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
    }
    
    // MARK: - Get
    
    func getPlayerRule(for id: String) -> Rule? {
        if let i = players.firstIndex(where: { $0.id == id }) {
            return playerRules[i][currentHole]
        }
        return nil
    }
    
    func getTeamRule() -> Rule? {
        return teamRules[currentHole]
    }
    
    // MARK: - Redraw
    
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
    
    // MARK: - Clear
    
    func clearHoleRule() {
        rulesRevealed[currentHole] = true
        rulesExist[currentHole] = false
    }
}

// MARK: - Session

extension RoundViewModel {
    
    // MARK: - Save
    
    func requestSessionPersistence() {
        print(#function)
        sessionPersistenceRequest += 1
    }
    
    func persistSession() {
        print(#function)
        self.session = Session(
            id: sessionID,
            code: sharableCode,
            host: hostID,
            teamDifficulty: teamDifficulty.rawValue,
            teamRedrawCount: teamRedrawCount,
            players: players.compactMap({ PlayerSession(player: $0) }),
            gameplay: buildGameplaySession(),
            createdAt: createdAt ?? Time(),
            lastUpdatedAt: Time())
        
        Task {
            await self.session?.put()
        }
    }
    
    private func buildGameplaySession() -> GameplaySession {
        return GameplaySession(
            teamRule: teamRules.reduce(into: [:], { $0[$1.key] = $1.value.id }),
            playerRules: playerRules.compactMap({ $0.reduce(into: [:], { $0[$1.key] = $1.value.id }) })
        )
    }
    
    // MARK: - Load
    
    func loadSession(_ s: Session) {
        print(#function)
        self.session = s
        self.sessionID = s.id
        self.sharableCode = s.code
        self.hostID = s.host
        self.createdAt = s.createdAt
        self.lastUpdatedAt = s.lastUpdatedAt
        
        self.players = s.players.compactMap({ Player(session: $0) })
        
        self.teamDifficulty = GameDifficulty(rawValue: s.teamDifficulty) ?? .medium
        self.teamRedrawCount = s.teamRedrawCount
        
        self.teamRules = s.gameplay.teamRule.reduce(into: [:], { $0[$1.key] = ruleMap[$1.value] ?? Rule() })
        self.playerRules = s.gameplay.playerRules.compactMap({
            $0.reduce(into: [:], { $0[$1.key] = ruleMap[$1.value] ?? Rule() })
        })
        
        // TODO: Implement a way to ensure rulesExist based of populated keys.
        rulesExist = teamRules.reduce(into: [:], { $0[$1.key] != nil })
    }
    
    @Sendable
    func fetchSession() async {
        print(#function)
        do {
            let s = try await FirebaseService.shared.getSession(by: self.sessionID).get()
            self.loadSession(s)
        } catch let error {
            print("error fetching session, \(error)")
        }
    }
    
    // MARK: - End Session
    
    func endSession() async {
        print("todo: \(#function)")
        if let currentSession = self.session {
            var s = currentSession
            s.ended = true
            await s.put()
        }
    }
}
