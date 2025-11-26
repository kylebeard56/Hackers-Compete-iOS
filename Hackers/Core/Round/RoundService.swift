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
    
    func initialize(for roundID: String) async {
        self.roundID = roundID
        await startListeners()
    }
}
