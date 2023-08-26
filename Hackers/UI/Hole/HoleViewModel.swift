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
        }
        
        if arrangement == .player || arrangement == .combo {
            for p in players {
                if ruleDoesNotExists(for: p.id, on: hole) || forceRedraw {
                    await drawPlayerRule(for: p, on: hole)
                }
            }
        }
    }
    
    func drawTeamRule(on hole: Int) async {
        print(#function)
        
        guard let r = chaos?.teamRule, let d = ChaosCardsDifficulty(rawValue: chaos?.difficulty ?? "") else {
            print("CHAOS ERROR: Couldn't find team rule and difficulty from session")
            return
        }
        
        let rules = r.compactMap({ chaosRuleMap[$0.value] })
        let newRule = drawRule(omitting: rules, with: .team, and: d.randomRuleDifficulty)
        sideGameSession.chaos?.teamRule.updateValue(newRule.id, forKey: hole)
    }
    
    func drawPlayerRule(for player: Player, on hole: Int) async {
        print(#function)
        
        guard let r = chaos?.playerRules, let d = ChaosCardsDifficulty(rawValue: chaos?.difficulty ?? "") else {
            print("CHAOS ERROR: Couldn't find player rule and difficulty from session")
            return
        }
        
        var playerRules = r[player.id] ?? [:]
        let drawnRules = playerRules.compactMap { chaosRuleMap[$0.value] }
        let newRule = drawRule(omitting: drawnRules, with: .player, and: d.randomRuleDifficulty)
        
        playerRules.updateValue(newRule.id, forKey: hole)
        sideGameSession.chaos?.playerRules.updateValue(playerRules, forKey: player.id)
    }
    
    func clearRules(for players: [Player], on hole: Int) {
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
