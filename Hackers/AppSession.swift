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
 [] Add haptics to buttons on quick draw, customize, and newest buttons
 [] Excel to JSON to Model to Firebase
 [] Add (2) packs from Mock
 [] Add hole details to rules (line for par and line for 
 [] Add gameplay rules
 [] Work on pulling down rules and randomly assigning
    - Focus on not repeating
 [] Start tweaking algorithm
    - Random draw index for non-repeat
    - Take hole details into account
 [] Rinse and repeat for drinking rules
 [] Add paywall to drinking rules
 [] Extensive test
 [] SHIP!
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
    @Published var activeHole: Hole = Hole()
    
    // MARK: - Packs
    
    @Published var activePack: Int = 0
    @Published var packs: [Pack] = []
    @Published var gameplayPack: Pack = Pack()
    @Published var drinkingPack: Pack = Pack()
    @Published var isLoadingPacks: Bool = false
    
    // MARK: - Rules
    
    @Published var rules: [Rule] = []
    @Published var isLoadingRules: Bool = false
    
    // MARK: - Control
    
    @Published var shouldEndRound: Bool = false
    
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
        players = kDefaultPlayers
        holes = kDefaultHoles
        activeHole = Hole()
        activePack = 0
        shouldEndRound = true
    }
}
