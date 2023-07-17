//
//  SpectateViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 7/17/23.
//

import SwiftUI

@MainActor
class SpectateViewModel: Hackable {
    /// Code
    @Published var code: String = ""
    
    /// Session
    @Published var session: Session = Session()
    @Published var lastUpdatedAt: Time = Time().beginningOfTime
    
    /// View data
    @Published var players: [Player] = []
    @Published var currentHole: Int = 1
    @Published var lastScoredHole: Int = 1
    @Published var numberOfHoles: Int = 18
    @Published var startingHole: Int = 1
    @Published var holeRange: [Int] = Array(1...18)
    @Published var roundThru: Int = 1
    
    @Published var loadLock: Bool = false
    @Published var isLoading: Bool = false
    @Published var sessionNotFound: Bool = false
    
    init() {
        print("init SpectateViewModel")
    }
    
    deinit {
        print("deinit SpectateViewModel")
    }
    
    @Sendable func spectateSession() async {
        isLoading = true
        sessionNotFound = false
        defer { isLoading = false }
        
        do {
            let s = try await FirebaseService.shared.getSession(using: code).get()
            load(s)
        } catch let error {
            print("error spectating session, \(error)")
            self.sessionNotFound = true
        }
    }
    
    func load(_ s: Session) {
        self.session = s
        self.lastUpdatedAt = Time()
        self.players = s.players.compactMap({ Player(session: $0) }).filter({ $0.isPlaying })
        
        self.numberOfHoles = s.numberOfHoles
        self.startingHole = s.startingHole
        self.holeRange = HoleUtil.buildRange(starting: s.startingHole, playing: s.numberOfHoles)
        
        if !loadLock {
            self.currentHole = s.startingHole
            self.loadLock = true
        }
        
        computeHoleLogic(for: loadLock ? currentHole : s.startingHole)
    }
    
    func stop() {
        self.code = ""
        
        self.session = Session()
        self.lastUpdatedAt = Time().beginningOfTime
        
        self.players = []
        self.currentHole = 1
        self.numberOfHoles = 18
        self.startingHole = 1
        self.holeRange = Array(1...18)
        self.roundThru = 1
        
        self.loadLock = false
    }
    
    func computeHoleLogic(for hole: Int) {
        var count: Int = 0
        for h in self.holeRange {
            count += 1
            if h == hole { break }
        }
        self.roundThru = count
        
        var lastScored: Int = 1
        for h in self.holeRange {
            let scores = self.players.compactMap({ $0.score[h] })
            if scores.isEmpty {
                lastScored = h
                break
            }
        }
        self.lastScoredHole = lastScored
    }
}
