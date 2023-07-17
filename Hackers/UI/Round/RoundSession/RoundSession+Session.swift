//
//  RoundSession+Session.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

extension RoundSession {
    
    // MARK: - Load
    
    func loadSession(_ s: Session) {
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
        self.sideGameSessions = s.sideGames
        if let sg = s.sideGames.last {
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
        
        self.session = Session(
            id: sessionID,
            partyCode: partyCode,
            players: players.filter({ $0.isPlaying }).compactMap({ PlayerSession(player: $0) }),
            numberOfHoles: numberOfHoles,
            staringHole: startingHole,
            sideGames: sideGameSessions,
            createdAt: createdAt,
            lastUpdatedAt: Time()
        )
        
        if let session {
            await session.put()
            print(session)
        }
    }
}
