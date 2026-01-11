//
//  JoinRoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 9/18/25.
//

import SwiftUI

@MainActor
final class JoinRoundViewModel: ObservableObject, Loggable {
    enum FindRoundError: String {
        case roundNotFound = "Double-check your code and try again."
        case unknown = "Something went wrong. Please try again."
    }
    
    @Published var round: Round?
    @Published var participants: [RoundParticipant] = []
    @Published var hostName = "player"
    
    @Published var code = ""
    @Published var isLoading = false
    @Published var route = false
    @Published var findRoundError: FindRoundError?

    @Published var claimedParticipant: RoundParticipant?
    @Published var playerSelectionDisabled = false
    
    init(code: String = "") {
        self.code = code
        Task { await findRound() }
    }
    
    deinit { }
    
    func findRound() async {
        addBreadcrumb(message: "Find round with code: \(code)")
        guard code.isPopulated else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            /// 1. Attempt to find the round by the share code
            let roundToJoin = try await FirebaseService.shared.getRoundByShareCode(code.uppercased()).get()
            printPretty(roundToJoin)
            round = roundToJoin
            
            /// 2. If the user is already logged in, attempt to see if their player account has joined the round yet and auto-select.
            if let user = await AppData.shared.user,
               let players = try? await FirebaseService.shared.getPlayersByIDs(user.players).get(),
               let player = players.first(where: \.isPrimary)
            {
                participants = try await FirebaseService.shared.getParticipants(for: roundToJoin.id).get()
                printPretty(participants)
                claimedParticipant = participants.first(where: { $0.playerID == player.id })
                if let name = participants.first(where: \.isHost)?.name.givenName { hostName = name }
            }
            
            route = true
        } catch {
            addBreadcrumb(level: .warning, message: "Failed to find round by share code, \(code)", error: error)
            if let err = error as? HackersError, err == .documentNotFound {
                findRoundError = .roundNotFound
            } else {
                findRoundError = .unknown
            }
        }
    }
    
    func setPlayerAutomarticallyIfPossible() async {
        addBreadcrumb()
        guard let user = await AppData.shared.user else { return }
        
        if let p = participants.first(where: { $0.userID == user.id }) {
            claimedParticipant = p
            playerSelectionDisabled = true
        }
    }
}
