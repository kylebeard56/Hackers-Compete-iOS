//
//  LiveRound+PreviewMock.swift
//  Hackers
//
//  Created by Kyle Beard on 2/13/26.
//

import SwiftUI

extension LiveRound {
    @MainActor
    enum Mock {
        static func appSesssion(
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
    struct DelayedHydrationPreview: View {
        @StateObject private var appSession: AppSession
        @StateObject private var locationService: LocationService = .init()
        @StateObject private var roundSession: RoundSession = .init()
        
        private let hydratedSnapshot: RoundSnapshot
        private let simulatedLoadDelay: TimeInterval
        
        init(hydratedSnapshot: RoundSnapshot, simulatedLoadDelay: TimeInterval) {
            _appSession = StateObject(
                wrappedValue: LiveRound.Mock.appSesssion(
                    participantID: hydratedSnapshot.participants.first?.id,
                    snapshot: hydratedSnapshot
                )
            )
            self.hydratedSnapshot = hydratedSnapshot
            self.simulatedLoadDelay = simulatedLoadDelay
        }
        
        var body: some View {
            LiveRound()
                .environmentObject(appSession)
                .environmentObject(locationService)
                .environmentObject(roundSession)
                .task {
                    guard roundSession.snapshot.participants.isEmpty else { return }
                    try? await Task.sleep(for: .milliseconds(Int(simulatedLoadDelay * 1_000)))
                    roundSession.snapshot = hydratedSnapshot
                }
        }
    }
}
