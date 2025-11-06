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
    
    init() { }
    deinit { }
    
    func findRound() async {
        addBreadcrumb(#function)
        guard code.isPopulated else { return }
        
        guard let user = await AppData.shared.user,
              let players = try? await FirebaseService.shared.getPlayersByIDs(user.players).get(),
              let player = players.first(where: \.isPrimary)
        else {
            addBreadcrumb(.error, .joinRound, "Failed to find user's primary player")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let r = try await FirebaseService.shared.getRoundByShareCode(code.uppercased()).get()
            printPretty(r)
            round = r
            
            let p = try await FirebaseService.shared.getParticipants(for: r.id).get()
            printPretty(p)
            participants = p
            claimedParticipant = p.first(where: { $0.playerID == player.id })
            if let n = p.first(where: \.isHost)?.name.givenName { hostName = n }
            
            route = true
        } catch {
            addBreadcrumb(.warning, .joinRound, "Failed to find round by share code, \(code)", error)
            if let err = error as? HackersError, err == .documentNotFound {
                findRoundError = .roundNotFound
            } else {
                findRoundError = .unknown
            }
        }
    }
}
