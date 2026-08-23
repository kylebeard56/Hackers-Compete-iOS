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
            snapshot: RoundSnapshot? = nil,
            activeSeriesID: String? = nil
        ) -> AppSession {
            let session = AppSession()
            
            if let participantID {
                session.ephemeralParticipantID = participantID
            } else if let playerID, let snapshot,
                      let participant = snapshot.participants.first(where: { $0.playerID == playerID }) {
                session.ephemeralParticipantID = participant.id
            }

            session.activeSeriesID = activeSeriesID
            
            return session
        }

        static func viewModel(
            seriesID: String? = nil,
            isCommissioner: Bool = false
        ) -> LiveRoundViewModel {
            let viewModel = LiveRoundViewModel()
            if seriesID != nil || isCommissioner {
                viewModel.seriesAccessOverride = .init(seriesID: seriesID, isCommissioner: isCommissioner)
            }
            return viewModel
        }
        
        static func roundSession(using snapshot: RoundSnapshot) -> RoundSession {
            let session = RoundSession()
            session.snapshot = snapshot
            return session
        }
    }
    
    /// Injects mock snapshot at init (like GameLobby.LobbyPreview). Use for reliable previews with mock data.
    @MainActor
    struct ImmediatePreview: View {
        @StateObject private var appSession: AppSession
        @StateObject private var liveRoundCompanion: LiveRoundCompanionCoordinator = .init()
        @StateObject private var locationService: LocationService = .init()
        @StateObject private var roundSession: RoundSession
        @StateObject private var viewModel: LiveRoundViewModel

        init(
            snapshot: RoundSnapshot,
            participantID: String? = nil,
            useFirstParticipantIfMissing: Bool = true,
            seriesID: String? = nil,
            isCommissioner: Bool = false
        ) {
            let resolvedParticipantID = participantID ?? (useFirstParticipantIfMissing ? snapshot.participants.first?.id : nil)
            _appSession = StateObject(
                wrappedValue: LiveRound.Mock.appSesssion(
                    participantID: resolvedParticipantID,
                    snapshot: snapshot,
                    activeSeriesID: seriesID
                )
            )
            _roundSession = StateObject(
                wrappedValue: LiveRound.Mock.roundSession(using: snapshot)
            )
            _viewModel = StateObject(
                wrappedValue: LiveRound.Mock.viewModel(seriesID: seriesID, isCommissioner: isCommissioner)
            )
        }

        var body: some View {
            LiveRound(viewModel: viewModel)
                .environmentObject(appSession)
                .environmentObject(liveRoundCompanion)
                .environmentObject(locationService)
                .environmentObject(roundSession)
        }
    }

    /// Delays snapshot injection to simulate loading (skeleton). Use for testing loading states.
    @MainActor
    struct DelayedHydrationPreview: View {
        @StateObject private var appSession: AppSession
        @StateObject private var liveRoundCompanion: LiveRoundCompanionCoordinator = .init()
        @StateObject private var locationService: LocationService = .init()
        @StateObject private var roundSession: RoundSession = .init()
        @StateObject private var viewModel: LiveRoundViewModel = .init()

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
            LiveRound(viewModel: viewModel)
                .environmentObject(appSession)
                .environmentObject(liveRoundCompanion)
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
