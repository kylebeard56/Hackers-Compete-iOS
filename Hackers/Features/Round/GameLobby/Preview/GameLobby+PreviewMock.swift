//
//  GameLobby+PreviewMock.swift
//  Hackers
//
//  Created by Kyle Beard on 2/16/26.
//

import SwiftUI

extension GameLobby {
    @MainActor
    enum Mock {
        static func appSession(
            participantID: String? = nil,
            playerID: String? = nil,
            snapshot: RoundSnapshot? = nil
        ) -> AppSession {
            let session = AppSession()
            
            if let participantID {
                session.ephemeralParticipantID = participantID
            } else if let playerID, let snapshot,
                      let participant = snapshot.participants.first(where: { $0.playerID == playerID }) {
                session.ephemeralParticipantID = participant.id
            }
            
            return session
        }
        
        static func roundSession(using snapshot: RoundSnapshot) -> RoundSession {
            let session = RoundSession()
            session.snapshot = snapshot
            return session
        }
    }
    
    @MainActor
    struct LobbyPreview: View {
        @StateObject private var appSession: AppSession
        @StateObject private var roundSession: RoundSession
        
        private let snapshot: RoundSnapshot
        
        init(snapshot: RoundSnapshot) {
            self.snapshot = snapshot
            _appSession = StateObject(
                wrappedValue: GameLobby.Mock.appSession(
                    participantID: snapshot.participants.first?.id,
                    snapshot: snapshot
                )
            )
            _roundSession = StateObject(
                wrappedValue: GameLobby.Mock.roundSession(using: snapshot)
            )
        }
        
        var body: some View {
            GameLobby()
                .environmentObject(appSession)
                .environmentObject(roundSession)
        }
    }
}
