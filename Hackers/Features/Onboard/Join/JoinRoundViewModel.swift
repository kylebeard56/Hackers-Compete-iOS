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
    
    private(set) var roundSession: RoundSession?

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
    
    func setRoundSession(_ rs: RoundSession) {
        self.roundSession = rs
    }
    
    // MARK: - Find
    
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
    
    // MARK: - Join
    
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
        await roundSession?.start(for: roundID)
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
        
        guard let roundID = round?.id else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: round ID nil")
            return
        }
        
        do {
            // 1. Fetch players to find the primary profile
            let players = try await FirebaseService.shared.getPlayersByIDs(user.players).get()
            guard let primaryPlayer = players.first(where: \.isPrimary) else {
                joinRoundError = .primaryPlayerNotFound
                return
            }
            
            // 2. Start round service before making DB updates
            await roundSession?.start(for: roundID)
            
            // 3. Take ownership of the offline participant for this particular user
            // This will override if authenticated prior to claim flow, or if new account via auth after claim.
            var participant = p
            participant.userID = user.id
            participant.playerID = primaryPlayer.id
            participant.name = primaryPlayer.name // Overwrite offline player claimed with player profile name
            try await roundSession?.update(participant: participant)
            
            // 4. Complete flow and route to round
            completeFlow = true
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to claim offline participant",
                error: error,
                parameters: [
                    "Round Service exists": roundSession.exists ? "TRUE" : "FALSE",
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
    
    // Scenario 4a: Claims new player + new auth account -> save new player, set as primary player to user (if authed)
    func claimNewPlayerAndEnterRound() async {
        addBreadcrumb()
        
        guard var p = newClaimedPlayer else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: newly claimed player nil")
            return
        }
        
        guard let roundID = round?.id else {
            addBreadcrumb(level: .warning, message: "Failed to enter round: round ID nil")
            return
        }
        
        do {
            await roundSession?.start(for: roundID)
            
            // Authenticated user (new account)
            if var user = await AppData.shared.user {
                p.userID = user.id
                p.isPrimary = true
                
                try await roundSession?.addPlayers([p])
                
                user.players = [p.id]
                user = try await user.put().get()
                await AppData.shared.setUser(user)
                
                completeFlow = true
            }
            // Guest user
            else {
                try await roundSession?.addPlayers([p])
                
                if let id = roundSession?.snapshot.participants.first(where: { $0.playerID == p.id })?.id {
                    ephemeralParticipantID = id
                    completeFlow = true
                } else {
                    addBreadcrumb(
                        level: .error,
                        message: "Failed to claim new player: participant not found on creation"
                    )
                    joinRoundError = .unknown
                }
            }
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to claim new player",
                error: error
            )
            joinRoundError = .unknown
        }
    }

    // Scenario 4b: Claim player + existing auth account -> override selection with primary player
    func overrideClaimWithPrimaryPlayer() async {
        addBreadcrumb()
        
        guard let user = await AppData.shared.user else {
            addBreadcrumb(level: .warning, message: "Override failed: user nil")
            return
        }
        
        guard let roundID = round?.id else {
            addBreadcrumb(level: .warning, message: "Override failed: round ID nil")
            return
        }
        
        do {
            let players = try await FirebaseService.shared.getPlayersByIDs(user.players).get()
            
            guard let primaryPlayer = players.first(where: \.isPrimary) else {
                joinRoundError = .primaryPlayerNotFound
                return
            }
            
            await roundSession?.start(for: roundID)
            
            // Remove claimed participant if it exists
            if let claimed = claimedParticipant {
                try? await roundSession?.remove(participant: claimed)
            }
            
            // Add primary player to the round
            try await roundSession?.addPlayers([primaryPlayer])
            
            completeFlow = true
            
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to override claimed participant",
                error: error
            )
            joinRoundError = .unknown
        }
    }

}
