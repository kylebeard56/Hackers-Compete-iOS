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

    private enum ParticipantClaimError: Error {
        case userNotFound
        case primaryPlayerNotFound
        case claimedParticipantNotFound
        case roundNotFound
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

    @Published var primaryPlayer: Player?
    @Published var claimedParticipant: RoundParticipant?
    @Published var newClaimedPlayer: Player?
    @Published var isPlayerLocked = false
    
    @Published var ephemeralParticipantID: String? = nil
    @Published var isSpectating = false
    @Published var completeFlow = false
    
    var currentUser: User? { AuthService.shared.getCurrentUser() }
    
    init(code: String = "") {
        self.code = code
    }
    
    deinit { }
    
    func setRoundSession(_ rs: RoundSession) {
        self.roundSession = rs
    }
    
    // MARK: - Find
    
    func findRound() async {
        guard code.isPopulated else { return }
        addBreadcrumb(message: "Find round with token: \(code)")
        addEvent(
            "round.join_search_started",
            eventProps: ["share_code_length": code.count]
        )

        findRoundError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let roundToJoin = try await FirebaseService.shared.resolveRound(byToken: code).get()
            printPretty(roundToJoin)
            try await applyLoadedRound(roundToJoin)
        } catch {
            addBreadcrumb(level: .warning, message: "Failed to resolve round, \(code)", error: error)
            addEvent(
                "round.join_search_failed",
                eventProps: [
                    "share_code_length": code.count,
                    "error": "\(error)"
                ]
            )
            if let err = error as? HackersError, err == .documentNotFound {
                findRoundError = .roundNotFound
            } else {
                findRoundError = .unknown
            }
        }
    }

    /// Loads participants and advances join UI (or auto-enters when already participating).
    func applyLoadedRound(_ roundToJoin: Round) async throws {
        round = roundToJoin

        participants = try await FirebaseService.shared.getParticipants(for: roundToJoin.id).get()
        if let name = participants.first(where: \.isHost)?.name.fullName { hostName = name }
        printPretty(participants)

        await fetchPrimaryPlayer()

        if let name = participants.first(where: \.isHost)?.name.givenName { hostName = name }

        if isPlayerLocked, roundSession != nil {
            addEvent(
                "round.join_search_succeeded",
                eventProps: joinEventProperties(["flow": "existing_participant"])
            )
            await enterRoundIfAlreadyJoined()
            return
        }

        addEvent("round.join_search_succeeded", eventProps: joinEventProperties())
        route = true
    }
    
    func fetchPrimaryPlayer() async {
        if let player = await AppData.shared.getPrimaryPlayer() {
            primaryPlayer = player
            if let p = participants.first(where: { $0.playerID == player.id }) {
                claimedParticipant = p
                isPlayerLocked = true
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
        addEvent(
            "round.join_succeeded",
            eventProps: joinEventProperties([
                "flow": isGuest ? "guest_existing_participant" : "existing_participant"
            ])
        )
        completeFlow = true
    }
    
    // Scenario 2a: Logged in + claim existing offline participant
    func claimOfflineParticipant() async {
        addBreadcrumb()

        do {
            try await claimSelectedParticipantWithPrimaryPlayer(flow: "claim_offline_participant")
            addEvent(
                "round.join_succeeded",
                eventProps: joinEventProperties(["flow": "claim_offline_participant"])
            )
            completeFlow = true
        } catch let error {
            if let claimError = error as? ParticipantClaimError {
                handleParticipantClaimError(claimError, flow: "claim_offline_participant")
                return
            }

            addBreadcrumb(
                level: .error,
                message: "Failed to claim offline participant",
                error: error,
                parameters: [
                    "Round Service exists": roundSession.exists ? "TRUE" : "FALSE",
                    "Round ID": round?.id ?? "N/A",
                    "Participant ID": claimedParticipant?.id ?? "N/A"
                ]
            )
            addEvent(
                "round.join_failed",
                eventProps: joinEventProperties([
                    "flow": "claim_offline_participant",
                    "error": "\(error)"
                ])
            )
            joinRoundError = .unknown
        }
    }
    
    // Scenario 2b: Logs in during claim + adds primary player
    func addPrimaryPlayerToRound() async {
        addBreadcrumb()
        
        guard let user = await AppData.shared.user else {
            addBreadcrumb(level: .warning, message: "Adding primary failed: user nil")
            return
        }
        
        guard let roundID = round?.id else {
            addBreadcrumb(level: .warning, message: "Adding primary failed: round ID nil")
            return
        }
        
        do {
            guard let primary = await AppData.shared.getPrimaryPlayer() else {
                joinRoundError = .primaryPlayerNotFound
                return
            }
            
            await roundSession?.start(for: roundID)
            try await roundSession?.addPlayers([primary])
            
            addEvent(
                "round.join_succeeded",
                eventProps: joinEventProperties(["flow": "add_primary_player"])
            )
            completeFlow = true
        } catch let error {
            addBreadcrumb(
                level: .error,
                message: "Failed to add primary player to round",
                error: error
            )
            addEvent(
                "round.join_failed",
                eventProps: joinEventProperties([
                    "flow": "add_primary_player",
                    "error": "\(error)"
                ])
            )
            joinRoundError = .unknown
        }
    }
    
    // Scenario 3: Guest claims existing participant + skips login -> ephemeral claim
    func continueAsGuest() async {
        addBreadcrumb()
        await enterRoundIfAlreadyJoined(isGuest: true)
    }

    func spectateRound() async {
        addBreadcrumb(message: "Entering round as spectator")
        guard let roundID = round?.id else {
            addBreadcrumb(level: .warning, message: "Failed to spectate: round ID nil")
            return
        }
        await roundSession?.start(for: roundID)
        isSpectating = true
        addEvent(
            "round.join_succeeded",
            eventProps: joinEventProperties(["flow": "spectator"])
        )
        completeFlow = true
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
                TelemetryService.shared.identify(user: user, authUserID: user.id)
                
                addEvent(
                    "round.join_succeeded",
                    eventProps: joinEventProperties(["flow": "claim_new_player_authenticated"])
                )
                completeFlow = true
            }
            // Guest user
            else {
                try await roundSession?.addPlayers([p])
                
                if let id = roundSession?.snapshot.participants.first(where: { $0.playerID == p.id })?.id {
                    ephemeralParticipantID = id
                    addEvent(
                        "round.join_succeeded",
                        eventProps: joinEventProperties(["flow": "claim_new_player_guest"])
                    )
                    completeFlow = true
                } else {
                    addBreadcrumb(
                        level: .error,
                        message: "Failed to claim new player: participant not found on creation"
                    )
                    addEvent(
                        "round.join_failed",
                        eventProps: joinEventProperties(["flow": "claim_new_player_guest"])
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
            addEvent(
                "round.join_failed",
                eventProps: joinEventProperties([
                    "flow": "claim_new_player",
                    "error": "\(error)"
                ])
            )
            joinRoundError = .unknown
        }
    }

    // Scenario 4b: Claim player + existing auth account -> override selection with primary player
    func overrideClaimWithPrimaryPlayer() async {
        addBreadcrumb()
        
        do {
            if claimedParticipant?.seriesMemberID?.isPopulated == true {
                try await claimSelectedParticipantWithPrimaryPlayer(flow: "override_with_primary")
            } else {
                guard await AppData.shared.user != nil else {
                    throw ParticipantClaimError.userNotFound
                }

                guard let roundID = round?.id else {
                    throw ParticipantClaimError.roundNotFound
                }

                guard let primary = await AppData.shared.getPrimaryPlayer() else {
                    throw ParticipantClaimError.primaryPlayerNotFound
                }
                
                await roundSession?.start(for: roundID)
                
                // Remove claimed participant if it exists
                if let claimed = claimedParticipant {
                    try? await roundSession?.remove(participant: claimed)
                }
                
                // Add primary player to the round
                try await roundSession?.addPlayers([primary])
            }
            
            addEvent(
                "round.join_succeeded",
                eventProps: joinEventProperties(["flow": "override_with_primary"])
            )
            completeFlow = true
            
        } catch let error {
            if let claimError = error as? ParticipantClaimError {
                handleParticipantClaimError(claimError, flow: "override_with_primary")
                return
            }

            addBreadcrumb(
                level: .error,
                message: "Failed to override claimed participant",
                error: error
            )
            addEvent(
                "round.join_failed",
                eventProps: joinEventProperties([
                    "flow": "override_with_primary",
                    "error": "\(error)"
                ])
            )
            joinRoundError = .unknown
        }
    }
}

private extension JoinRoundViewModel {
    func joinEventProperties(_ additional: [String: Any] = [:]) -> [String: Any] {
        var props: [String: Any] = [
            "share_code_length": code.count
        ]

        if let roundID = round?.id {
            props["round_id"] = roundID
        }

        additional.forEach { props[$0.key] = $0.value }
        return props
    }

    private func claimSelectedParticipantWithPrimaryPlayer(flow: String) async throws {
        guard let user = await AppData.shared.user else {
            throw ParticipantClaimError.userNotFound
        }

        guard let primary = await AppData.shared.getPrimaryPlayer() else {
            throw ParticipantClaimError.primaryPlayerNotFound
        }

        guard let existingParticipant = claimedParticipant else {
            throw ParticipantClaimError.claimedParticipantNotFound
        }

        guard let roundID = round?.id else {
            throw ParticipantClaimError.roundNotFound
        }

        await roundSession?.start(for: roundID)

        var updatedParticipant = existingParticipant
        updatedParticipant.userID = user.id
        updatedParticipant.playerID = primary.id
        updatedParticipant.name = primary.name
        try await roundSession?.update(participant: updatedParticipant)

        claimedParticipant = updatedParticipant
        participants.upsert(updatedParticipant)
        isPlayerLocked = true

        await syncSeriesMemberAfterClaimIfNeeded(
            participant: updatedParticipant,
            user: user,
            primary: primary,
            flow: flow
        )
    }

    private func syncSeriesMemberAfterClaimIfNeeded(
        participant: RoundParticipant,
        user: HackersUser,
        primary: Player,
        flow: String
    ) async {
        guard let seriesMemberID = participant.seriesMemberID, seriesMemberID.isPopulated else { return }

        do {
            try await FirebaseService.shared.syncSeriesMemberAfterParticipantClaim(
                seriesMemberID: seriesMemberID,
                userID: user.id,
                playerID: primary.id,
                name: primary.name
            )
        } catch {
            addBreadcrumb(
                level: .warning,
                message: "Participant claim succeeded but failed to sync linked series member",
                error: error,
                parameters: [
                    "Participant ID": participant.id,
                    "Series Member ID": seriesMemberID,
                    "Player ID": primary.id,
                    "Flow": flow
                ]
            )
            addEvent(
                "round.join_partial_sync_failed",
                eventProps: joinEventProperties([
                    "flow": flow,
                    "sync_target": "series_member",
                    "series_member_id": seriesMemberID,
                    "player_id": primary.id,
                    "error": "\(error)"
                ])
            )
        }
    }

    private func handleParticipantClaimError(_ error: ParticipantClaimError, flow: String) {
        switch error {
        case .primaryPlayerNotFound:
            joinRoundError = .primaryPlayerNotFound
        case .userNotFound:
            joinRoundError = .userNotFound
        case .claimedParticipantNotFound:
            addBreadcrumb(level: .warning, message: "Failed to \(flow): claimed participant nil")
        case .roundNotFound:
            addBreadcrumb(level: .warning, message: "Failed to \(flow): round ID nil")
        }
    }
}
