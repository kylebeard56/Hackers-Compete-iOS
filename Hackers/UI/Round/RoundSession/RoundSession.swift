//
//  RoundSession.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import Combine
import SwiftUI

typealias HoleDictionary = [Int: String]

let kHeaderHeight: CGFloat = 64

@MainActor
class RoundSession: Hackable {
    /// Session
    @Published var session: Session?
    @Published var sessionID: String = ""
    @Published var partyCode: String = ""
    @Published var hasUnlockedPro: Bool = false // applies to the entire group (beyond purchase store)
    @Published var createdAt: Time = Time()
    @Published var lastUpdatedAt: Time = Time()
    
    /// Session debouncer
    @Published var sessionLoaded: Bool = false
    @Published var sessionLock: Bool = false
    @Published var sessionPersistenceRequest: Int = 0
    @Published var debounceFulfillment: Int = 0
    private var sessionSubscription = Set<AnyCancellable>()
    
    /// Holes
    @Published var snapSideGames: Bool = false
    @Published var holeHeaderVisible: Bool = true
    @Published var scrollBiasApplied: Bool = false
    @Published var headerOffset: CGFloat = 0
    
    /// Spectate
    @Published var spectatorCode: String = ""
    
    /// Hole header + footer
    @Published var headerBounceLock: Bool = true
    @Published var scrollChangeCounter: Int = 0
    @Published var showFooter: Bool = true
    private var footerSubscription = Set<AnyCancellable>()
    
    /// Leaderboard
    @Published var players: [Player] = []
    @Published var teams: [String] = []
    @Published var teamRowDisplay: Bool = true
    
    /// Side Games
    @Published var sideGame: SideGame = .none
    @Published var sideGameSessions: [SideGameSession] = []
    @Published var chaosTab: String = "team"
    // TODO: Do further side game shit here.
    
    /// Hole
    @Published var currentHole: Int = 1
    @Published var numberOfHoles: Int = 18
    @Published var startingHole: Int = 1
    @Published var holeRange: [Int] = Array(1...18)
    @Published var netHoleNumber: Int = 1
    @Published var didStartOnFirstHole: Bool = false
    
    /// Manage
    @Published var isUpdatingPartyCode: Bool = false
    @Published var partyCodeTaken: Bool = false
    @Published var partyCodeNotSaved: Bool = false
    @Published var partyCodeUpdated: Bool = false
    
    /// Returns TRUE if the session change was caused from a local change and is already in synchronization.
    var isInSync: Bool { self.lastUpdatedAt.unix <= Time().unix }
    
    /// Returns TRUE if any of the players have a single handicap set
    var usingHandicaps: Bool { !players.filter({ $0.handicapIndex > 0 }).isEmpty }
    
    init() {
        print("init RoundSession")
        
        /// Schedulers for requesting session persistence
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] data in
                if data.compactMap(\.toSession) == self?.session?.players { return }
                self?.requestSessionPersistence()
            })
        
        _ = $currentHole
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] hole in
                self?.updateHoleLogic(for: hole)
            })
        
        _ = $sideGameSessions
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] data in
                if data == self?.session?.sideGames { return }
                self?.requestSessionPersistence()
            })
        
        /// Debounce filter for persistence request
        $sessionPersistenceRequest
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.debounceFulfillment = value
                if let self { Task(operation: persistSession) }
            })
            .store(in: &sessionSubscription)
        
//        $scrollChangeCounter
//            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
//            .sink(receiveValue: { [weak self] _ in
//                self?.animateFooter(true)
//            })
//            .store(in: &footerSubscription)
    }
    
    deinit { print("deinit RoundSession") }
}
