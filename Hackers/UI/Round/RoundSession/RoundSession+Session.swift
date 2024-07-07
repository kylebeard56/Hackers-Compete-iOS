//
//  RoundSession+Session.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

extension RoundSession {
    
    // MARK: - Load
    
    func loadSession(_ s: Session, isPro: Bool? = nil) {
        print(#function)
        printPretty(s)
        
        /// 1. Data race lock to prevent infinite data loop of setting values in this function that publish to persist session.
        self.sessionLock = true
        defer { self.sessionLock = false }

        /// 2. Load in the session for reference
        self.session = s
        self.sessionID = s.id
        self.partyCode = s.partyCode
        self.createdAt = s.createdAt
        
        /// Self-latching boolean to set and keep `TRUE` if at least one player in the party is Pro subscriber.
        self.hasUnlockedPro = (isPro ?? false) || s.unlockedPro
        
        /// 3. Set the # of holes, starting hole, and build hole range. This will never change during a session so only do once.
        if !sessionLoaded {
            self.numberOfHoles = s.numberOfHoles
            self.startingHole = s.startingHole
            self.currentHole = s.startingHole
            self.didStartOnFirstHole = (s.startingHole == 10 && s.numberOfHoles == 9) || s.startingHole == 1
            self.holeRange = HoleUtil.buildRange(starting: s.startingHole, playing: s.numberOfHoles)
        }
        
        /// 4. Build player and teams
        self.players = s.players.compactMap({ Player(session: $0) }).filter({ $0.isPlaying })
        self.teams = s.players.compactMap({ $0.team[s.startingHole] }).uniques.filter({ !$0.isEmpty })
        
        /// 5. Fetch the last side game in the array since they're appended as they're changed. This controls order.
        self.sideGameSessions = prune(s.sideGames)
        if let sg = s.sideGames.first(where: { $0.holes.contains(s.startingHole) }) {
            self.sideGame = SideGame(rawValue: sg.game) ?? .none
        }
        
        /// 6. Session has been loaded
        self.sessionLoaded = true
    }
    
    @Sendable func fetchSession() async {
        do {
            let s = try await FirebaseService.shared.getSession(by: self.sessionID).get()
            self.loadSession(s)
        } catch let error {
            print("error fetching session, \(error)")
        }
    }
    
    // MARK: - Perisistence
    
    func requestSessionPersistence() {
        if sessionLock { return }
        sessionPersistenceRequest += 1
    }
    
    @Sendable func persistSession() async {
        print(#function)
        if sessionID.isEmpty { return }
        
        self.lastUpdatedAt = Time()
        
        self.session = Session(
            id: sessionID,
            partyCode: partyCode,
            players: players.filter({ $0.isPlaying }).compactMap({ PlayerSession(player: $0) }),
            unlockedPro: hasUnlockedPro,
            numberOfHoles: numberOfHoles,
            staringHole: startingHole,
            sideGames: prune(sideGameSessions),
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt
        )
        
        if let session {
            await session.put()
            print(session)
        }
    }
    
    private func prune(_ sideGameSessions: [SideGameSession]) -> [SideGameSession] {
        /// 1. Remove empty instances of any game
        var session = sideGameSessions
        
        /// 2. Consolidate `none` game into single instance to ensure starting new game populates all holes.
        var none = SideGameSession()
        for s in session {
            if s.game != SideGame.none.rawValue { continue }
            if none.id == "" {
                none = s
            } else {
                let h = s.holes + none.holes
                none.holes = h.sorted(by: { $0 < $1 }).uniques
            }
        }
        
        session = session.filter({ $0.game != SideGame.none.rawValue })
        session.append(none)
        session.removeAll(where: { $0.id.isEmpty || $0.holes.isEmpty || $0.game.isEmpty })
        
        return session
    }
}
