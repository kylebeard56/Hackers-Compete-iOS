//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Combine
import FirebaseAuth
import SwiftUI

/**
 GROCERY LIST:
 [] When redrawing from game mode, the animation for rule hints stops.
 [] Player entry keyboard (x) doesnt work and keyboard resigns too quickly
 [] Copy logic from rule hints to the marquee tiles and make them bigger
 [] Make card reveal show and hide like the bottom card?
 [] Rinse and repeat for drinking rules
 [] Add paywall to drinking rules
 [] Extensive test
 [] SHIP!
 
 --
 [] Save unfinished rounds in realm to pre-load (save player and hole rules essentially)
 */

@MainActor
class AppSession: Hackable {
    
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
    //@Published var holeDrawn: [Bool] = Array(repeating: false, count: 18)
    //@Published var activeHole: Hole = Hole()
    
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
    @Published var revealedView: RevealedView = .gameplay
    
    // MARK: - Control
    
    @Published var startRound: Bool = false
    
    init() {
        print("init AppSession")
        Task(operation: load)
    }
    deinit { print("deinit AppSession") }
    
    @Sendable
    private func load() async {
        await loginAnonymously()
        await getPacks()
        await getRules()
        self.isReady = true
    }
    
    private func testPrintStatementsBecauseImTooLazyToSetupUnitTestsWithoutGettingStupidAssBuildErrors() {
        var easyMode: [RuleDifficulty] = []
        var mediumMode: [RuleDifficulty] = []
        var hardMode: [RuleDifficulty] = []
        let x = 18
        for _ in 1...x {
            easyMode.append(GameDifficulty.easy.randomRuleDifficulty)
            mediumMode.append(GameDifficulty.medium.randomRuleDifficulty)
            hardMode.append(GameDifficulty.hard.randomRuleDifficulty)
        }
        print("Easy Favor: \(easyMode.filter({ $0 == .favor }).count) / \(x)")
        print("Medium Favor: \(mediumMode.filter({ $0 == .favor }).count) / \(x)")
        print("Hard Favor: \(hardMode.filter({ $0 == .favor }).count) / \(x)")
    }
    
    private func loginAnonymously() async {
        do {
            let user = try await FirebaseService.shared.loginAnonymously().get()
            print("logged in anonymously for id: \(user.uid)")
        } catch let error {
            print("couldn't login anonymously, \(error)")
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
    
    func endRound() {
        print(#function)
        self.startRound = false
        players = kDefaultPlayers
        holes = kDefaultHoles
        //activeHole = Hole()
        activePack = 0
    }
}
