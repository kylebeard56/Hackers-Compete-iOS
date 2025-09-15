//
//  RoundService.swift
//  Hackers
//
//  Created by Kyle Beard on 9/3/25.
//

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
    
    let reference: CollectionReference = Firestore.firestore().collection(Collections.rounds.rawValue)
    let lobbyTypes: [RoundRegistrationType] = [.round, .participants, .segments, .teams, .teeGroups]
    let activeTypes: [RoundRegistrationType] = [.round, .participants, .segments, .scoring, .teams, .teeGroups]
    
    init() { }
    deinit { }
}
