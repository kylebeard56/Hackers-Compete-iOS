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

    enum JoinRoundError: String {
        case primaryPlayerNotFound = "No player profile found for user account."
        case userNotFound = "No user account found."
        case newPlayerNotFound = "No player selected for round."
        case unknown = "Something went wrong. Please try again."
    }
    
    private(set) var roundService: RoundService = .init()

    @Published var round: Round?
    @Published var participants: [RoundParticipant] = []
    @Published var hostName = "player"
    
    @Published var code = ""
    @Published var isLoading = false
    @Published var route = false
    @Published var findRoundError: FindRoundError?
    @Published var joinRoundError: JoinRoundError?

    @Published var claimedParticipant: RoundParticipant?
    @Published var newClaimedPlayer: Player?
    @Published var isPlayerLocked = false
    
    @Published var ephemeralParticipantID: String? = nil
    @Published var completeFlow = false
    
    var currentUser: User? { AuthService.shared.getCurrentUser() }
    
    init(code: String = "") {
        self.code = code
        Task { await findRound() }
    }
    
    deinit { }
    
    func setRoundService(_ rs: RoundService) {
        self.roundService = rs
    }
    
    func findRound() async {
        addBreadcrumb(message: "Find round with code: \(code)")
        guard code.isPopulated else { return }
        
        findRoundError = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. Attempt to find the round by the share code
            let roundToJoin = try await FirebaseService.shared.getRoundByShareCode(code.uppercased()).get()
            printPretty(roundToJoin)
            round = roundToJoin
            
            // 2. Fetch all participants in the round
            participants = try await FirebaseService.shared.getParticipants(for: roundToJoin.id).get()
            if let name = participants.first(where: \.isHost)?.name.fullName { hostName = name }
            printPretty(participants)
            
            // 3. If the user is already logged in, attempt to see if their player account has joined the round yet and auto-select.
            if let user = await AppData.shared.user,
               let players = try? await FirebaseService.shared.getPlayersByIDs(user.players).get(),
               let player = players.first(where: \.isPrimary)
            {
                if let p = participants.first(where: { $0.playerID == player.id }) {
                    claimedParticipant = p
                    isPlayerLocked = true
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
    
    // Scenario 1: Logged in + already in round -> simply enter
    func enterRoundIfAlreadyJoined(isGuest: Bool = false) async {
        addBreadcrumb()
        
        // 1. Ensure claimed participant exists
        guard let p = claimedParticipant else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: claimed participant nil")
            return
        }
        
        // 2. Ensure roundID exists
        guard let roundID = round?.id else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: round ID nil")
            return
        }
        
        // 3. Start round service and set ephemeral if guest, then continue.
        await roundService.start(for: roundID)
        if isGuest {
            ephemeralParticipantID = p.id
        }
        completeFlow = true
    }
    
    // Scenario 2: Logged in + claim existing offline participant
    func claimOfflineParticipant() async {
        addBreadcrumb()
        
        guard let user = await AppData.shared.user else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: user account nil")
            return
        }
        
        guard let p = claimedParticipant else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: claimed participant nil")
            return
        }
        
        do {
            // 1. Fetch players to find the primary profile
            let players = try await FirebaseService.shared.getPlayersByIDs(user.players).get()
            guard let primaryPlayer = players.first(where: \.isPrimary) else {
                joinRoundError = .primaryPlayerNotFound
                return
            }
            
            // 2. Take ownership of the offline participant for this particular user
            var participant = p
            participant.userID = user.id
            participant.playerID = primaryPlayer.id
            participant.name = primaryPlayer.name // Overwrite offline player claimed with player profile name
            try await roundService.update(participant: participant)
            
            // 3. Complete flow and route to round
            completeFlow = true
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to claim offline participant",
                error: error,
                parameters: [
                    "Round ID": round?.id ?? "N/A",
                    "Participant ID": p.id,
                    "User ID": user.id
                ]
            )
            joinRoundError = .unknown
        }
    }
    
    // Scenario 3: Guest claims existing participant + skips login -> ephemeral claim
    func continueAsGuest() async {
        addBreadcrumb()
        await enterRoundIfAlreadyJoined(isGuest: true)
    }
    
    // Scenario 4: Claims new player -> save new player, set as primary player to user if authenticated
    func claimNewPlayerAndEnterRound() async {
        addBreadcrumb()
        
        guard var p = newClaimedPlayer else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: newly claimed player nil")
            return
        }
        
        if await AppData.shared.user?.players.isPopulated ?? false {
            addBreadcrumb(level: .warning, message: "Failed to enter round: primary player already exists")
            return
        }
        
        do {
            // 2a. User exists, so they must have authenticated
            if var user = await AppData.shared.user {
                
                // Map user ID to the player to claim online
                p.userID = user.id
                p.isPrimary = true
                try await roundService.addPlayers([p])
                
                // Update user for new, primary player
                user.players = [p.id]
                user = try await user.put().get()
                await AppData.shared.setUser(user)
                
                completeFlow = true
            }
            // 2b. User didn't exist, so they must have continued as geust
            else {
                try await roundService.addPlayers([p])
                
                if let id = roundService.snapshot.participants.first(where: { $0.playerID == p.id })?.id {
                    ephemeralParticipantID = id
                    completeFlow = true
                } else {
                    addBreadcrumb(
                        level: .error,
                        message: "Failed to claim new player: participant not found on creation",
                        parameters: [
                            "Round ID": round?.id ?? "N/A",
                            "Player ID": p.id
                        ]
                    )
                    joinRoundError = .unknown
                }
            }
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to claim new player",
                error: error,
                parameters: [
                    "Round ID": round?.id ?? "N/A",
                    "Player Name": p.name.fullName
                ]
            )
            joinRoundError = .unknown
        }
    }
}
