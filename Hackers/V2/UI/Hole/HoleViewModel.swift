//
//  HoleViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 7/9/23.
//

import Foundation

// TODO: Read below
/// Add rule editor for Cards of Chaos to admin settings
/// Cards of Chaos results for favor vs. challenge cards (# drawn and strokes gained per difficulty)

@MainActor class HoleViewModel: Hackable {
    @Published var roundThru: Int = 0
    @Published var sideGameThru: Int = 0
    
    @Published var teams: [String] = []
    
    @Published var lastScrollOffset: CGFloat = 0.0
    
    @Published var sideGame: SideGame = .none
    @Published var sideGameSession: SideGameSession = SideGameSession()
    
    @Published var results: [SideGameSession] = []
    
    /// For each hole, this ViewModel will contain data for the specific side game that is being played.
    /// When a hole is scored, if it's the next sequential hole, add current hole to side game hole array, otherwise present
    /// tile for side game saying "you skipped holes x-x, would you like to play through?"
    
    /// Chaos
    @Published var chaosRules: [Rule] = []
    @Published var chaosRuleMap: [String: Rule] = [:]
    @Published var isLoadingRules: Bool = false
    @Published var isDrawing: Bool = false
    
    private var easyTeamRules: [Rule] {
        chaosRules.filter({ $0.isTeamRule && $0.isFavor })
    }
    private var hardTeamRules: [Rule] {
        chaosRules.filter({ $0.isTeamRule && $0.isChallenge })
    }
    private var teamNormalizer: CGFloat {
        CGFloat(hardTeamRules.count / easyTeamRules.count)
    }
    private var easyPlayerRules: [Rule] {
        chaosRules.filter({ $0.isPlayerRule && $0.isFavor })
    }
    private var hardPlayerRules: [Rule] {
        chaosRules.filter({ $0.isPlayerRule && $0.isChallenge })
    }
    private var playerNormalizer: CGFloat {
        CGFloat(hardPlayerRules.count / easyPlayerRules.count)
    }
    
    init() { print("init HoleViewModel") }
    deinit { print("deinit HoleViewModel") }
}

// MARK: - Cards of Chaos

extension HoleViewModel {

    /// Shorthand reference to the side game session chaos session
    private var chaos: ChaosSession? { sideGameSession.chaos }
    
    /// =====================================================================
    /// FETCHING DATA
    /// =====================================================================
    
    @Sendable func reloadChaosRules() async {
        print(#function)
        isLoadingRules = true
        defer { isLoadingRules = false }
        
        do {
            let rules = try await FirebaseService.shared.getRules().get()
            self.chaosRules = rules
            self.chaosRuleMap = rules.reduce(into: [:], { $0[$1.id] = $1 })
        } catch let error {
            self.addBreadcrumb(.error, .session, "couldn't load chaos rules", error)
        }
    }
    
    func getTeamRule(for hole: Int) -> Rule? {
        return chaosRuleMap[chaos?.teamRule[hole] ?? ""]
    }
    
    func getRule(for id: String, on hole: Int) -> Rule? {
        return chaosRuleMap[chaos?.playerRules[id]?[hole] ?? ""]
    }
    
    /// =====================================================================
    /// DRAWING RULES
    /// =====================================================================
    
    /// Will draw card for team or specific player if it doesn't exist on a certain hole.
    @Sendable func attemptDraw(for players: [Player], on hole: Int, forceRedraw: Bool = false) async {
        print("\(#function) from \(chaosRules.count) rules")
        isDrawing = true
        defer { isDrawing = false }
        
        guard let arrangement = ChaosCardsArrangement(rawValue: chaos?.arrangement ?? "") else {
            print("CHAOS ERROR: Couldn't find arrangement from session")
            return
        }
        
        if arrangement == .team || arrangement == .combo {
            if ruleDoesNotExists(for: "team", on: hole) || forceRedraw {
                await drawTeamRule(on: hole)
            }
            /// Ensure no player rules are lingering from a customization update
            if arrangement == .team {
                clearRules(team: false, players: players, on: hole)
            }
        }
        
        if arrangement == .player || arrangement == .combo {
            for p in players {
                if ruleDoesNotExists(for: p.id, on: hole) || forceRedraw {
                    await drawPlayerRule(for: p, on: hole)

                }
            }
            /// Ensure no team rule is lingering from a customization update
            if arrangement == .player {
                clearRules(team: true, players: [], on: hole)
            }
        }
        
        /// This will ensure with near 100% accuracy that the initial draw of cards won't contains duplicates where two players
        /// get the same card. Redrawing a single card could still product duplicates, however.
        await redrawPlayerRulesForUniqueness(for: players, on: hole)
    }
    
    private func redrawPlayerRulesForUniqueness(
        for players: [Player],
        on hole: Int,
        count: Int = 0,
        stop: Int = 3
    ) async {
        if count > stop { return }
        
        let teamRule: String = chaos?.teamRule[hole] ?? ""
        var playerRules: [(Player, String)] = chaos?.playerRules.compactMap({
            let id = $0.key
            let player = players.first(where: { $0.id == id }) ?? Player()
            let ruleID = $0.value[hole] ?? ""
            return (player, ruleID)
        }) ?? []
        
        var swap: Int = 0
        for i in 0..<playerRules.count {
            let p = playerRules[i]
            
            /// Buld map of other players rules
            let otherRules = playerRules.filter({ $0.0.id != p.0.id }).compactMap({ $0.1 })
            
            /// If this player's rule is the same as team rule (by name) or another player's (by ID), redraw for that player.
            if otherRules.contains(p.1) || chaosRuleMap[teamRule]?.name == chaosRuleMap[p.1]?.name {
                let newRule = await drawPlayerRule(for: p.0, on: hole)
                playerRules[i].1 = newRule?.id ?? ""
                swap += 1
            }
        }
        
        if swap == 0 { return }
        await redrawPlayerRulesForUniqueness(for: players, on: hole, count: count + 1, stop: stop)
    }
    
    func drawTeamRule(on hole: Int) async {
        print(#function)
        
        guard let r = chaos?.teamRule, let d = ChaosCardsDifficulty(rawValue: chaos?.difficulty ?? "") else {
            print("CHAOS ERROR: Couldn't find team rule and difficulty from session")
            return
        }
        
        let rules = r.compactMap({ chaosRuleMap[$0.value] })
        let newRule = drawRule(omitting: rules, with: .team, and: d.randomRuleDifficulty(with: teamNormalizer))
        sideGameSession.chaos?.teamRule.updateValue(newRule.id, forKey: hole)
    }
    
    @discardableResult func drawPlayerRule(for player: Player, on hole: Int) async -> Rule? {
        print(#function)
        
        guard let r = chaos?.playerRules, let d = ChaosCardsDifficulty(rawValue: chaos?.difficulty ?? "") else {
            print("CHAOS ERROR: Couldn't find player rule and difficulty from session")
            return nil
        }
        
        var playerRules = r[player.id] ?? [:]
        let drawnRules = playerRules.compactMap { chaosRuleMap[$0.value] }
        let newRule = drawRule(omitting: drawnRules, with: .player, and: d.randomRuleDifficulty(with: playerNormalizer))
        
        playerRules.updateValue(newRule.id, forKey: hole)
        sideGameSession.chaos?.playerRules.updateValue(playerRules, forKey: player.id)
        
        return newRule
    }
    
    func clearRules(team: Bool = true, players: [Player] = [], on hole: Int) {
        print(#function)
        sideGameSession.chaos?.teamRule.updateValue("", forKey: hole)
        for p in players {
            if let r = sideGameSession.chaos?.playerRules[p.id] {
                var rules = r
                rules.updateValue("", forKey: hole)
                sideGameSession.chaos?.playerRules.updateValue(rules, forKey: p.id)
            }
        }
    }
    
    /// =====================================================================
    /// PRIVATE FUNCTIONS
    /// =====================================================================

    private func ruleDoesNotExists(for id: String, on hole: Int) -> Bool {
        if id == "team" {
            return chaos?.teamRule[hole]?.isEmpty ?? true
        } else {
            return (chaos?.playerRules.first(where: { $0.key == id })?.value[hole] ?? "").isEmpty
        }
    }
    
    private func drawRule(omitting data: [Rule], with type: RuleType, and difficulty: RuleDifficulty) -> Rule {
        print(#function)
        /// 1. Build dictionary of previously used IDs (faster for filtering in step 2).
        let usedIDs = Dictionary(uniqueKeysWithValues: data.map { ($0.id, "") })
        
        /// 2. Filter possible rules to choose from based on type, difficulty, and availability.
        let availableRules: [Rule] = chaosRules.filter {
            $0.type == type.rawValue && $0.difficulty == difficulty.rawValue && usedIDs[$0.id] == nil
        }
        
        /// 3. Return a random available rule
        if availableRules.count == 0 { return Rule() }
        return availableRules[Int.random(in: 0...(availableRules.count - 1))]
    }
}
