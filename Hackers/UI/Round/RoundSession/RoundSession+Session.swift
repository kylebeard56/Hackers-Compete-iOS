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
        
        /// 3. Build player and teams
        self.players = s.players.compactMap({ Player(session: $0) }).filter({ $0.isPlaying })
        self.teams = s.players.compactMap({ $0.team }).uniques.filter({ !$0.isEmpty })
        
        /// 4. Set the # of holes, starting hole, and build hole range. This will never change during a session so only do once.
        if !sessionLoaded {
            
            self.numberOfHoles = s.numberOfHoles
            self.startingHole = s.startingHole
            self.currentHole = s.startingHole
            self.didStartOnFirstHole = (s.startingHole == 10 && s.numberOfHoles == 9) || s.startingHole == 1
            
            /// Construct a linear range for the hole numbers to be played for index calculation purposes.
            /// ex: If starting on 4 and playing 18, it would be 4...18 + 1...3 in this exact order
            self.holeRange = s.startingHole == 1 ? Array(1...18) : Array(startingHole...18) + Array(1...(startingHole - 1))
            if s.numberOfHoles != 18 {
                /// If playing nine holes, filter out the side which users aren't playing from our sequenced range.
                self.holeRange = s.startingHole <= 9 ? holeRange.filter(\.isFrontNine) : holeRange.filter(\.isBackNine)
            }
            
            /// If player scores have been entered, navigate to the last scored hole where they might have left off.
//            let scoredHoles = players.compactMap({ $0.score.keys })
//            let largestIndex = scoredHoles.compactMap({ holeRange.firstIndex(of: $0) }).max() ?? 0
//            self.currentHole = self.holeRange[largestIndex]
        }
        
        /// 5. Fetch the last side game in the array since they're appended as they're changed. This controls order.
        self.sideGameSessions = s.sideGames
        if let sg = s.sideGames.last {
            self.sideGame = SideGame(rawValue: sg.game) ?? .none
//            if !sessionLoaded {
//                self.currentHole = sg.holes.last ?? s.startingHole
//                /// NOTE: When the session is initially loaded, we could make the current hole be the last index in active
//            }
        }
        
//        self.updatenextActiveHole(for: players, on: currentHole)
        
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
