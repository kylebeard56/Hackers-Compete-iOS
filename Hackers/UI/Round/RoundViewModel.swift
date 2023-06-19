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

enum HackersGame: String {
    case chaos, football, stableford, traditional, vegas, wolf
    
    var icon: String {
        switch self {
        case .chaos:            return "f71d"
        case .football:         return "f44e"
        case .stableford:       return "f8c3"
        case .traditional:      return "f450"
        case .vegas:            return "e3ed"
        case .wolf:             return "e414"
        }
    }
    
    var name: String {
        switch self {
        case .chaos:            return "Cards of Chaos"
        case .football:         return "Football"
        case .stableford:       return "Stableford"
        case .traditional:      return "Traditional"
        case .vegas:            return "Vegas Style"
        case .wolf:             return "Wolf Hammer"
        }
    }
    
    var description: String {
        switch self {
        case .chaos:            return "Draw cards with amusing fortunes for how your party is allowed to play each hole."
        case .football:         return "Alternative point scoring based on shot outcomes for each player."
        case .stableford:       return "Score points against your party based on your hole performance."
        case .traditional:      return "A classic round of golf true to the rules with individual or team scoring."
        case .vegas:            return "Alternative point scoring based on shot outcomes for each player."
        case .wolf:             return "An intense game of best ball where team structure influences scoring strategy."
        }
    }
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
    @Published var players: [Player] = [] //[kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
    @Published var teams: [Team] = [Team(name: "Team One", players: []), Team(name: "Team Two", players: [])]
    
    /// Games
    @Published var activeGame: HackersGame = .traditional
    @Published var showGameSelector: Bool = false
    @Published var showTraditionalLeaderboard: Bool = false
    @Published var showStablefordLeaderboard: Bool = false
    @Published var showVegasLeaderboard: Bool = false
    // TODO: How do we handle teams that change hole to hole?
    // TODO: How will we compute and store vegas score?
    
    /// Rules
    @Published var allRules: [Rule] = []
    @Published var ruleMap: [String: Rule] = [:]
    
    /// Hole
    @Published var currentHole: Int = 1
//    @Published var holeDetails: [Int: HoleDetails] = [:]
    
    /// Cards of Cards -> Move this to `SideGameViewModel`
    @Published var arrangement: ChaosCardsArrangement = .combo
    @Published var difficulty: ChaosCardsDifficulty = .medium
    @Published var redraws: Bool = true
    @Published var teamRules: HoleRuleDictionary = [:]  
    @Published var playerRules: [String: HoleRuleDictionary] = [:]
    @Published var isDrawing: Bool = false
    
    init() {
        print("init RoundViewModel")
        createdAt = Time()
        
        /// Schedulers for requesting session persistence
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in
                self.requestSessionPersistence()
                self.buildTeams()
            })
        _ = $activeGame
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        _ = $difficulty
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

// MARK: - Cards of Chaos

extension RoundViewModel {
    
    func chaosCardsIsLive() -> Bool {
        !teamRules.isEmpty || playerRules.values.compactMap({ $0.keys.isEmpty }).contains(false)
    }
    
    func getTeamRule(for hole: Int? = nil) -> Rule? {
        let h = hole ?? currentHole
        return ruleMap[teamRules[h] ?? ""]
    }
    
    func getPlayerRule(for id: String, for hole: Int? = nil) -> Rule? {
        let h = hole ?? currentHole
        return ruleMap[playerRules[id]?[h] ?? ""]
    }
    
    func doesRuleExist(for hole: Int) -> Bool {
        teamRules.keys.contains(hole) || playerRules.values.compactMap( { $0.keys.contains(hole) }).contains(true)
    }
    
    @Sendable func draw() async {
        isDrawing = true
        defer {
            self.isDrawing = false
        }
        
        if arrangement == .team || arrangement == .combo {
            await drawTeamRule()
        }
        if arrangement == .player || arrangement == .combo {
            for p in players {
                await drawPlayerRule(for: p)
            }
        }
    }
    
    func drawTeamRule() async {
        print(#function)
        let rules = teamRules.compactMap({ ruleMap[$0.value] })
        let newRule = drawRule(from: rules, with: .team, and: difficulty.randomRuleDifficulty)
        teamRules.updateValue(newRule.id, forKey: currentHole)
    }
    
    func drawPlayerRule(for player: Player) async {
        print(#function)
        let currentRules = playerRules[player.id]?.compactMap({ ruleMap[$0.value] }) ?? []
        let difficulty = difficulty.randomRuleDifficulty
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
        await drawTeamRule()
    }
    
    @Sendable func redrawCard(for p: Player) async throws {
        await drawPlayerRule(for: p)
    }
    
    func clearHoleRule() {
        teamRules[currentHole] = nil
        players.forEach({ p in playerRules[p.id]?.removeValue(forKey: currentHole) })
    }
}

// MARK: - Teams

extension RoundViewModel {
    
    fileprivate func buildTeams() {
        self.teams = []
        for p in self.players {
            if p.team.isEmpty { continue }
            if let i = self.teams.firstIndex(where: { $0.name == p.team }) {
                var team = self.teams[i]
                team.players.append(p.id)
                team.players = team.players.uniques
                self.teams[i] = team
            } else {
                self.teams.append(Team(name: p.team, players: [p.id]))
            }
        }
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
    
    func holesScored() -> Int {
        var total: Int = 0
        for i in 1...18 { total += scoringExists(for: i) ? 1 : 0 }
        return total
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
        self.sessionCode = s.partyCode
        self.hostID = s.host
        self.activeGame = HackersGame(rawValue: s.activeGame) ?? .traditional
        self.createdAt = s.createdAt
        self.lastUpdatedAt = s.lastUpdatedAt
        self.sessionEnded = s.ended // someone else ended the session
        
        self.players = s.players.compactMap({ Player(session: $0) }).filter({ $0.isPlaying })
        self.buildTeams()
        
        self.arrangement = ChaosCardsArrangement(rawValue: s.chaosSession.arrangement) ?? .combo
        self.difficulty = ChaosCardsDifficulty(rawValue: s.chaosSession.difficulty) ?? .medium
        
        withAnimation(.linear(duration: 0.125)) {
            self.teamRules = s.chaosSession.teamRule
            self.playerRules = s.chaosSession.playerRules
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
        
        let chaosSession = ChaosSession(
            active: [],
            arrangement: arrangement.rawValue,
            difficulty: difficulty.rawValue,
            redraws: redraws,
            teamRule: teamRules,
            playerRules: playerRules)
        
        self.session = Session(
            id: sessionID,
            ended: sessionEnded,
            code: sessionCode,
            host: hostID,
            activeGame: activeGame.rawValue,
            players: players.filter({ $0.isPlaying }).compactMap({ PlayerSession(player: $0) }),
            chaosSession: chaosSession,
            createdAt: createdAt ?? Time(),
            lastUpdatedAt: Time()
        )
        
        Task {
            await self.session?.put()
            printPretty(self.session)
        }
    }
}

// MARK: - Waitlist

extension RoundViewModel {
    
//    @Sendable func joinWaitlist() async {
//        isJoiningWaitlist = true
//        defer { isJoiningWaitlist = false }
//
//        if !self.waitlistEmail.isValidEmail {
//            self.waitlistToast.present(.failure)
//            return
//        }
//
//        let w = Waitlist(id: "", email: self.waitlistEmail, reason: "future games", time: Time())
//
//        do {
//            try await w.post().get()
//            self.waitlistToast.present(.success)
//            deviceDefaults.joinedDrinkingWaitlist = true
//            Haptics.fire(.success)
//            withAnimation(.linear(duration: 0.2)) {
//                self.isOnWaitlist = true
//            }
//        } catch let error {
//            print("error joining waitlist, \(error)")
//            self.addBreadcrumb(.warning, .waitlist, "joining waitlist", error)
//        }
//    }
}
