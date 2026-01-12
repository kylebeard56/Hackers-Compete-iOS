//
//  JoinRoundViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 9/18/25.
//

import FirebaseAuth
import SwiftUI

@MainActor
final class JoinRoundViewModel: ObservableObject, Loggable {
    enum FindRoundError: String {
        case roundNotFound = "Double-check your code and try again."
        case unknown = "Something went wrong. Please try again."
    }
    
    @Published var snapshot: RoundSnapshot?
    @Published var round: Round?
    @Published var participants: [RoundParticipant] = []
    @Published var hostName = "player"
    
    @Published var code = ""
    @Published var isLoading = false
    @Published var route = false
    @Published var findRoundError: FindRoundError?

    @Published var claimedParticipant: RoundParticipant?
    @Published var playerSelectionDisabled = false
    
    var currentUser: User? { AuthService.shared.getCurrentUser() }
    
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
                if let p = participants.first(where: { $0.playerID == player.id }) {
                    claimedParticipant = p
                    playerSelectionDisabled = true
                }
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
    
    /// Returns boolean for whether to prompt for login prior to dismissal/routing.
    func joinRound() async {
        addBreadcrumb()
        
        // TODO: We will likely want to start the RoundService listeners when we go to join this round to get a headstart.
        
        // 1. User exists, link their ID to the claimed participant
        if let user = await AppData.shared.user {
            claimedParticipant?.userID = user.id
        }
        
        /// 1. Logged in prior AND player in round?
        /// -> directly route to round since all data is set
        
        /// 2. Logged in prior BUT player was added to round
        /// -> fetch primary player from user profile
        /// -> convert player to round participant
        /// -> link participant to the round
        
        /// 3. Authenticated while joining
        /// -> create new user profile
        /// -> prompt to use profile name or claimed player name | syncs name across player profile and round participant
        /// ->
        
        /// 4. Continued as guest (don't call this function)
        /// -> set ephemeralPlayer in appSession for who this guest is controlling and route to round
    }
}
