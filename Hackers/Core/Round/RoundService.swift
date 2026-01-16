//
//  RoundService.swift
//  Hackers
//
//  Created by Kyle Beard on 9/3/25.
//

import Combine
import Firebase
import FirebaseFirestoreCombineSwift
import SwiftUI

@MainActor
final class RoundService: ObservableObject, Loggable {
    @Published var roundID: String?
    @Published var snapshot: RoundSnapshot = .init()
    
    @Published var roundListener: ListenerRegistration?
    @Published var participantListener: ListenerRegistration?
    @Published var segmentListener: ListenerRegistration?
    @Published var scoringListener: ListenerRegistration?
    @Published var teamListener: ListenerRegistration?
    @Published var teeGroupListener: ListenerRegistration?
    
    @Published var isLoadingLobbyListeners = false
    @Published var isLoadingActiveListeners = false
    
    @Published var isAddingPlayers = false
    
    let reference: CollectionReference = Firestore.firestore().collection(Collections.rounds.rawValue)
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
//        $snapshot
//            .receive(on: DispatchQueue.main)
//            .subscribe(on: DispatchQueue.main)
//            .sink(receiveValue: { snapshot in
//                print("UPDATED SNAPSHOT:")
//                printPretty(snapshot)
//            })
//            .store(in: &subscriptions)
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopListeners()
        }
    }
    
    func fetchSingleInstance(for roundID: String) async throws -> RoundSnapshot {
        addBreadcrumb()
        
        do {
            return .init(
                round:          try await FirebaseService.shared.getRoundByID(roundID).get(),
                participants:   try await FirebaseService.shared.getParticipants(for: roundID).get(),
                teams:          try await FirebaseService.shared.getTeams(for: roundID).get(),
                teeGroups:      try await FirebaseService.shared.getTeeGroups(for: roundID).get(),
                segments:       try await FirebaseService.shared.getSegments(for: roundID).get(),
                scoring:        try await FirebaseService.shared.getScores(for: roundID).get()
            )
        } catch {
            throw error
        }
    }
    
    func start(for roundID: String) async {
        addBreadcrumb()
        stopListeners()
        self.roundID = roundID
        await startListeners()
    }
}
