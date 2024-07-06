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

enum RoundTab: String, CaseIterable {
    case games = "Games"
    case leaderboard = "Scorecard"
    case nextHole = "Holes"
    
    var icon: String? {
        switch self {
        case .games:        return "f648".unicode
        case .leaderboard:  return "f303".unicode //f091
        case .nextHole:     return "e3ac".unicode //f178
        }
    }
}

fileprivate enum HoleTips: Tippable {
    case scorecard
    var id: String {
        switch self {
        case .scorecard:    
            return "scorecard"
        }
    }

    var icon: String {
        switch self {
        case .scorecard:    
            return "f672"
        }
    }

    var title: String {
        switch self {
        case .scorecard:    
            return "Keeping score"
        }
    }

    var subtitle: String {
        switch self {
        case .scorecard:
            return "Add your hole-by-hole scores here for any games you play while also keeping true scoring of your round."
        }
    }
}

@MainActor class RoundSession: Hackable {
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
    
    /// Navigation
    @Published var selectedTab: RoundTab = .games
    @Published var showHoleAnimation: Bool = false
    
    /// Holes
    @Published var snapSideGames: Bool = false
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
    
    /// Side game dashboard
    @Published var pendingSideGame: SideGame = .none
    @Published var isGameSearchFocused: Bool = false
    
    /// Side game active
    @Published var sideGame: SideGame = .none
    @Published var sideGameSessions: [SideGameSession] = []
    @Published var chaosTab: String = "team"
    
    /// Hole
    @Published var currentHole: Int = 1
    @Published var numberOfHoles: Int = 18
    @Published var startingHole: Int = 1
    @Published var holeRange: [Int] = Array(1...18)
    @Published var netHoleNumber: Int = 1
    @Published var didStartOnFirstHole: Bool = false
    var numberOfScoredHoles: Int {
       holeRange
            .compactMap { scoringExists(for: $0) ? 1 : 0 }
            .reduce(0, +)
    }
    
    /// Manage
    @Published var isUpdatingPartyCode: Bool = false
    @Published var partyCodeTaken: Bool = false
    @Published var partyCodeNotSaved: Bool = false
    @Published var partyCodeUpdated: Bool = false
    
    /// Tips
    @Published var activeTip: Tip?
    @Published var tips: [Tip] = [
        Tip(
            data: HoleTips.scorecard,
            priority: 1,
            canBeShown: true,
            position: Position()
        ),
        Tip(
            data: HoleTips.scorecard,
            priority: 2,
            canBeShown: true,
            position: Position()
        ),
        Tip(
            data: HoleTips.scorecard,
            priority: 3,
            canBeShown: true,
            position: Position()
        )
    ]
    
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
    }
    
    deinit { print("deinit RoundSession") }
}
