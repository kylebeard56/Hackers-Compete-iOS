//
//  RoundSession.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import Combine
import SwiftUI

typealias HoleDictionary = [Int: String]

@MainActor
class RoundSession: Hackable {
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
    private var sessionSubscription = Set<AnyCancellable>()
    
    /// Hole footer
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
    
    /// Stroke Play (Medal, Stableford, Football)
    @State var strokeScoringFormat: StrokeScoringFormat = .medal
    @State var isPlayingTwoBall: Bool = false
    
    /// Vegas
    /// ... I don't think we need to compute anything here...
    
    /// Best Ball
    /// ... I don't think we need to compute anything here...
    
    /// Nines
    /// ... I don't think we need to compute anything here...
    
    /// Bingo Bango Bongo
    
    /// Cards of Chaos
    
    /// Monkey in the Middle
    
    /// Banker
    
    /// Wolf
    
    /// TBD... Hammer, Hot Potato, Survivor
    
    init() {
        print("init RoundSession")
        
        /// SIDE GAME BRAIN DUMP
        /// 1. If the user goes 2+ holes beyond the last scored hole (or starting hole), we show "play through" and let them know they skipped.
        ///    This will essentially opt the user in to wanting to play on that hole, such as adding index or draw Chaos cards for example.
        /// 2. If the user enters a score on a specific hole AND requires to play through, we add that index range to the side game session.
        
        /// Schedulers for requesting session persistence
        _ = $players
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { data in
                if data.compactMap(\.toSession) == self.session?.players { return }
                self.requestSessionPersistence()
            })
        
        _ = $currentHole
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { hole in
                self.updateHoleLogic(for: hole)
            })
        
        _ = $sideGameSessions
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { data in
                if data == self.session?.sideGames { return }
                self.requestSessionPersistence()
            })
        
        /// Debounce filter for persistence request
        $sessionPersistenceRequest
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.debounceFulfillment = value
                if let self { Task(operation: persistSession) }
            })
            .store(in: &sessionSubscription)
        
        $scrollChangeCounter
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.animateFooter(true)
            })
            .store(in: &footerSubscription)
    }
    
    deinit { print("deinit RoundSession") }
}
