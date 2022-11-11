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
 [] Add haptics to buttons
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
    
    // MARK: - Players
    
    @Published var players: [Player] = [
        Player(color: .systemBlue),
        Player(color: .systemGreen),
        Player(color: .systemPurple),
        Player(color: .systemRed),
        Player(color: .systemOrange)
    ] { didSet { arePlayersEmpty = players.compactMap({ !$0.name.isEmpty }).filter({ $0 }).isEmpty }}
    @Published var arePlayersEmpty: Bool = false
    
    // MARK: - Details & Menu
    
    @Published var holes: [Hole] = Array(repeating: Hole(), count: 18)
    @Published var activeHole: Hole = Hole()
    @Published var holeNumber: Int = 1
    
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
    
    init() { print("init AppSession") }
    deinit { print("deinit AppSession") }
    
    func load() {
        Task {
            await getPacks()
            await getRules()
        }
    }
    
    private func getPacks() async {
        isLoadingPacks = true
        defer { isLoadingPacks = false}
        do {
            self.packs = try await FirebaseService.shared.getPacks().get()
            self.gameplayPack = self.packs.first(where: { $0.id == PackName.gameplay.rawValue }) ?? kGameplayPack
            self.drinkingPack = self.packs.first(where: { $0.id == PackName.drinking.rawValue }) ?? kDrinkingPack
        } catch let error {
            print("couldn't load packs, \(error)")
            self.addBreadcrumb(.error, .session, "couldn't GET packs", error)
        }
    }
    
    private func getRules() async {
        isLoadingRules = true
        defer { isLoadingRules = false}
        do {
            self.rules = try await FirebaseService.shared.getRules().get()
        } catch let error {
            print("couldn't load rules, \(error)")
            self.addBreadcrumb(.error, .session, "couldn't GET rule", error)
        }
    }
    
    func endRound() {
        players = []
        holes = Array(repeating: Hole(), count: 18)
        activeHole = Hole()
        shouldEndRound = true
    }
}
