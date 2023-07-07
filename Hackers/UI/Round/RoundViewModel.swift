//
//  RoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import Combine
import SwiftUI

typealias HoleDictionary = [Int: String]

//enum HackersGame: String {
//    case chaos, football, stableford, traditional, vegas, wolf
//
//    var icon: String {
//        switch self {
//        case .chaos:            return "f71d"
//        case .football:         return "f44e"
//        case .stableford:       return "f8c3"
//        case .traditional:      return "f450"
//        case .vegas:            return "e3ed"
//        case .wolf:             return "e414"
//        }
//    }
//
//    var name: String {
//        switch self {
//        case .chaos:            return "Cards of Chaos"
//        case .football:         return "Football"
//        case .stableford:       return "Stableford"
//        case .traditional:      return "Traditional"
//        case .vegas:            return "Vegas Style"
//        case .wolf:             return "Wolf Hammer"
//        }
//    }
//
//    var description: String {
//        switch self {
//        case .chaos:            return "Draw cards with amusing fortunes for how your party is allowed to play each hole."
//        case .football:         return "Alternative point scoring based on shot outcomes for each player."
//        case .stableford:       return "Score points against your party based on your hole performance."
//        case .traditional:      return "A classic round of golf true to the rules with individual or team scoring."
//        case .vegas:            return "Alternative point scoring based on shot outcomes for each player."
//        case .wolf:             return "An intense game of best ball where team structure influences scoring strategy."
//        }
//    }
//}

@MainActor
class RoundViewModel: Hackable {
    /// Session
    @Published var session: Session?
    @Published var sessionID: String = ""
    @Published var partyCode: String = ""
    @Published var createdAt: Time = Time()
    
    // Session Debouncer
    @Published var sessionLoaded: Bool = false
    @Published var sessionLock: Bool = false
    @Published var sessionPersistenceRequest: Int = 0
    @Published var debounceFulfillment: Int = 0
    private var subscription = Set<AnyCancellable>()
    
    /// Leaderboard
    @Published var players: [Player] = []
    @Published var teams: [String] = []
//    @Published var teams: [Team] = []
    
    /// Side Games
    @Published var sideGame: SideGame = .none
    @Published var sideGameSession: [SideGameSession] = []
    // TODO: Do further side game shit here.
    
    /// Games
//    @Published var activeGame: HackersGame = .traditional
//    @Published var showGameSelector: Bool = false
//    @Published var showTraditionalLeaderboard: Bool = false
//    @Published var showStablefordLeaderboard: Bool = false
//    @Published var showVegasLeaderboard: Bool = false
    // TODO: How do we handle teams that change hole to hole?
    // TODO: How will we compute and store vegas score?
    
    /// Rules
//    @Published var allRules: [Rule] = []
//    @Published var ruleMap: [String: Rule] = [:]
    
    /// Hole
    @Published var currentHole: Int = 1
    @Published var numberOfHoles: Int = 18
    @Published var startingHole: Int = 1
    @Published var holeRange: [Int] = Array(1...18)
    @Published var netHoleNumber: Int = 1
    @Published var didStartOnFirstHole: Bool = false

//    @Published var holeDetails: [Int: HoleDetails] = [:]
    
    /// Cards of Cards -> Move this to `SideGameViewModel`
//    @Published var arrangement: ChaosCardsArrangement = .combo
//    @Published var difficulty: ChaosCardsDifficulty = .medium
//    @Published var redraws: Bool = true
//    @Published var teamRules: HoleDictionary = [:]
//    @Published var playerRules: [String: HoleDictionary] = [:]
//    @Published var isDrawing: Bool = false
    
    /// Manage
    @Published var isUpdatingPartyCode: Bool = false
    @Published var partyCodeTaken: Bool = false
    @Published var partyCodeNotSaved: Bool = false
    @Published var partyCodeUpdated: Bool = false
    
    init() {
        print("init RoundViewModel")
        
        /// Schedulers for requesting session persistence
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { _ in
                self.requestSessionPersistence()
            })
        
        _ = $currentHole
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { hole in
                var count: Int = 0
                for h in self.holeRange {
                    count += 1
                    if h == hole { break }
                }
                self.netHoleNumber = count
            })
        
//        _ = $difficulty
//            .subscribe(on: DispatchQueue.main)
//            .sink(receiveValue: { _ in self.requestSessionPersistence() })
//        _ = $teamRules
//            .subscribe(on: DispatchQueue.main)
//            .sink(receiveValue: { _ in self.requestSessionPersistence() })
//        _ = $playerRules
//            .subscribe(on: DispatchQueue.main)
//            .sink(receiveValue: { _ in self.requestSessionPersistence() })
        
        /// Debounce filter for persistence request
        $sessionPersistenceRequest
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.debounceFulfillment = value
                if let self { Task(operation: persistSession) }
//                self?.persistSession()
            })
            .store(in: &subscription)
    }
    
    deinit { print("deinit RoundViewModel") }
    
    // MARK: - Reload
    
//    func reload(for rules: [Rule]) {
//        self.allRules = rules
//        self.ruleMap = rules.reduce(into: [:], { $0[$1.id] =  $1 })
//    }
}

// MARK: - Party Code

extension RoundViewModel {
    func updatePartyCode(to code: String) async {
        print(#function)
        self.partyCodeTaken = false
        self.partyCodeNotSaved = false
        self.partyCodeUpdated = false
        
        self.isUpdatingPartyCode = true
        defer { self.isUpdatingPartyCode = false }
        
        /// 1. If party code is populated, ensure it's unique and not taken
        if !code.isEmpty, await FirebaseService.shared.isPartyCodeTaken(code) {
            self.partyCodeTaken = true
            return
        }
        
        /// 2. Store session with party code and update.
        do {
            self.session?.partyCode = code
            _ = try await self.session?.put().get()
            self.partyCodeUpdated = true
        } catch let error {
            self.addBreadcrumb(.error, .session, "Party code not saved", error)
            self.partyCodeNotSaved = true
        }
    }
}

// MARK: - Session

extension RoundViewModel {
    
    // MARK: - Load
    
    func loadSession(_ s: Session) {
        print(#function)
        printPretty(s)
        
        /// 1. Data race lock to prevent infinite data loop of setting values in this function that publish to persist session.
        self.sessionLock = true
        defer { self.sessionLock = false }

        /// 2. Load in the session for reference
        self.session = s
        self.sessionID = s.id
        self.partyCode = s.partyCode
        self.createdAt = s.createdAt
        
        /// 3. Build player and teams
        self.players = s.players.compactMap({ Player(session: $0) }).filter({ $0.isPlaying })
        self.teams = s.players.compactMap({ $0.team }).uniques.filter({ !$0.isEmpty })
        
        /// 4. Set the # of holes, starting hole, and build hole range. This will never change during a session so only do once.
        if !sessionLoaded {
            
            self.numberOfHoles = s.numberOfHoles
            self.startingHole = s.startingHole
            self.currentHole = s.startingHole
            self.didStartOnFirstHole = (s.startingHole == 10 && s.numberOfHoles == 9) || s.startingHole == 1
            
            /// Construct a linear range for the hole numbers to be played for index calculation purposes.
            /// ex: If starting on 4 and playing 18, it would be 4...18 + 1...3 in this exact order
            self.holeRange = s.startingHole == 1 ? Array(1...18) : Array(startingHole...18) + Array(1...(startingHole - 1))
            if s.numberOfHoles != 18 {
                /// If playing nine holes, filter out the side which users aren't playing from our sequenced range.
                self.holeRange = s.startingHole <= 9 ? holeRange.filter(\.isFrontNine) : holeRange.filter(\.isBackNine)
            }
        }
        
        /// 5. Fetch the last side game in the array since they're appended as they're changed. This controls order.
        self.sideGameSession = s.sideGames
        if let sg = s.sideGames.last {
            self.sideGame = SideGame(rawValue: sg.game) ?? .none
            if !sessionLoaded {
                self.currentHole = sg.holes.last ?? s.startingHole
                /// NOTE: When the session is initially loaded, we could make the current hole be the last index in active
            }
        }
        
        /// 6. Session has been loaded
        self.sessionLoaded = true
    }
    
    @Sendable func fetchSession() async {
        do {
            let s = try await FirebaseService.shared.getSession(by: self.sessionID).get()
            self.loadSession(s)
        } catch let error {
            print("error fetching session, \(error)")
        }
    }
    
    // MARK: - Perisistence
    
    func requestSessionPersistence() {
        if sessionLock { return }
        sessionPersistenceRequest += 1
    }
    
    @Sendable fileprivate func persistSession() async {
        print(#function)
        if sessionID.isEmpty { return }
        
        self.session = Session(
            id: sessionID,
            partyCode: partyCode,
            players: players.filter({ $0.isPlaying }).compactMap({ PlayerSession(player: $0) }),
            numberOfHoles: numberOfHoles,
            staringHole: startingHole,
            sideGames: sideGameSession,
            createdAt: createdAt,
            lastUpdatedAt: Time()
        )
        
        if let session {
            await session.put()
            print(session)
        }
    }
}

// MARK: - Cards of Chaos

//extension RoundViewModel {
//
//    func chaosCardsIsLive() -> Bool {
//        !teamRules.isEmpty || playerRules.values.compactMap({ $0.keys.isEmpty }).contains(false)
//    }
//
//    func getTeamRule(for hole: Int? = nil) -> Rule? {
//        let h = hole ?? currentHole
//        return ruleMap[teamRules[h] ?? ""]
//    }
//
//    func getPlayerRule(for id: String, for hole: Int? = nil) -> Rule? {
//        let h = hole ?? currentHole
//        return ruleMap[playerRules[id]?[h] ?? ""]
//    }
//
//    func doesRuleExist(for hole: Int) -> Bool {
//        teamRules.keys.contains(hole) || playerRules.values.compactMap( { $0.keys.contains(hole) }).contains(true)
//    }
//
//    @Sendable func draw() async {
//        isDrawing = true
//        defer {
//            self.isDrawing = false
//        }
//
//        if arrangement == .team || arrangement == .combo {
//            await drawTeamRule()
//        }
//        if arrangement == .player || arrangement == .combo {
//            for p in players {
//                await drawPlayerRule(for: p)
//            }
//        }
//    }
//
//    func drawTeamRule() async {
//        print(#function)
//        let rules = teamRules.compactMap({ ruleMap[$0.value] })
//        let newRule = drawRule(from: rules, with: .team, and: difficulty.randomRuleDifficulty)
//        teamRules.updateValue(newRule.id, forKey: currentHole)
//    }
//
//    func drawPlayerRule(for player: Player) async {
//        print(#function)
//        let currentRules = playerRules[player.id]?.compactMap({ ruleMap[$0.value] }) ?? []
//        let difficulty = difficulty.randomRuleDifficulty
//        let newRule = drawRule(from: currentRules, with: .player, and: difficulty)
//
//        if playerRules.keys.contains(player.id) {
//            playerRules[player.id]?.updateValue(newRule.id, forKey: currentHole)
//        } else {
//            playerRules[player.id] = [currentHole : newRule.id]
//        }
//    }
//
//    private func drawRule(from data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
//        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
//        let usedIDs = Dictionary(uniqueKeysWithValues: data.map { ($0.id, "") })
//
//        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
//        let availableRules: [Rule] = allRules.filter({
//            $0.type == type.rawValue
//            && $0.difficulty == difficulty.rawValue
//            && usedIDs[$0.id] == nil
//        })
//
//        /// 3. Return a random available rule
//        if availableRules.count == 0 { return Rule() }
//        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
//    }
//
//    @Sendable func redrawTeamCard() async {
//        await drawTeamRule()
//    }
//
//    @Sendable func redrawCard(for p: Player) async throws {
//        await drawPlayerRule(for: p)
//    }
//
//    func clearHoleRule() {
//        teamRules[currentHole] = nil
//        players.forEach({ p in playerRules[p.id]?.removeValue(forKey: currentHole) })
//    }
//}

// MARK: - Teams

extension RoundViewModel {
    
//    func buildTeams() {
//        print(#function)
//
//        self.teams = self.players.compactMap({ $0.team }).uniques
//
//        for p in self.players {
//            if p.team.isEmpty { continue }
//            if let i = self.teams.firstIndex(where: { $0.name == p.team }) {
//                var team = self.teams[i]
//                team.players.append(p.id)
//                team.players = team.players.uniques
//                self.teams[i] = team
//            } else {
//                self.teams.append(Team(name: p.team, players: [p.id]))
//            }
//        }
//    }
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
    
//    func holesScored() -> Int {
//        var total: Int = 0
//        for i in 1...18 { total += scoringExists(for: i) ? 1 : 0 }
//        return total
//    }
    
//    func metricsAvailable() -> Bool {
//        for i in 1...18 {
//            if scoringExists(for: i) {
//                return true
//            } else {
//                continue
//            }
//        }
//        return false
//    }
}
