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
    case results = "Results"
    case nextHole = "Holes"
    
    var icon: String? {
        switch self {
        case .games:        return "f648".unicode
        case .leaderboard:  return "f303".unicode
        case .results:      return "e561".unicode
        case .nextHole:     return "e3ac".unicode
        }
    }
}

fileprivate enum HoleTips: String, Tippable {
    case games, scorecard, holes, editGames, editScorecard
    
    var id: String { self.rawValue }

    var icon: String { return "f672" }

    var title: String {
        switch self {
        case .games:            return "Playing games"
        case .scorecard:        return "Keeping score"
        case .holes:            return "Navigating holes"
        case .editGames:        return "Manage games"
        case .editScorecard:    return "Manage scorecard"
        }
    }

    var subtitle: String {
        switch self {
        case .games:
            return "Pick and choose fun golf and scoring games to play aside to your normal round here."
        case .scorecard:
            return "Add your hole-by-hole scores for any games you play while also keeping true scoring of your round here."
        case .holes:
            return "Navigate between holes and view your round progress here."
        case .editGames:
            return "Customize gameplay, view rules, or change to another game whenever you want here."
        case .editScorecard:
            return "Edit players, set or modify teams, and manage handicaps here."
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
    @Published var animateCurrentHole: Int = 0
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
//    @Published var activeTip: Tooltip?
//    @Published var tips: [Tooltip] = [
////        Tooltip(
////            data: HoleTips.games,
////            priority: 1,
////            canBeShown: true,
////            position: Position(
////                x: (UIScreen.main.bounds.width - 0) * 1 / 6,
////                y: UIScreen.main.bounds.height - 60,
////                width: 20,
////                height: 20
////            )
////        ),
////        Tooltip(
////            data: HoleTips.scorecard,
////            priority: 2,
////            canBeShown: true,
////            position: Position(
////                x: UIScreen.main.bounds.width / 2,
////                y: UIScreen.main.bounds.height - 60,
////                width: 20,
////                height: 20
////            )
////        ),
////        Tooltip(
////            data: HoleTips.holes,
////            priority: 3,
////            canBeShown: true,
////            position: Position(
////                x: (UIScreen.main.bounds.width - 0) * 5 / 6,
////                y: UIScreen.main.bounds.height - 60,
////                width: 20,
////                height: 20
////            )
////        ),
//        Tooltip(
//            data: HoleTips.editGames,
//            priority: 4,
//            canBeShown: true,
//            position: Position()
//        ),
//        Tooltip(
//            data: HoleTips.editScorecard,
//            priority: 4,
//            canBeShown: true,
//            position: Position()
//        )
//    ]
    
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
