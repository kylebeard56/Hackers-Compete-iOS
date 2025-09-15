//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import SwiftUI

// TODO: Read below
// 1. Set round ID to app session's active round ID within course selection
// 2. On course selection dismiss, check if active round ID is populated and route if so
// 3. Skeleton load game lobby to fetch round snapshot
// 4. Delineate functionality for game lobby VM, use round manager to fetch snapshot and handle all CRUD

struct GameLobby: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    
    /// RM handles all remote setting of the round info
    @StateObject var roundService = RoundService()
    
    /// VM handles UI state and any helpers/builders to drive RM model
    @StateObject var viewModel = GameLobbyViewModel()
    
    var body: some View {
        VStack {
            Text("Game lobby")
        }
        .task {
            if let id = appSession.activeRoundID {
                print("loading round with ID: \(id)")
                // TODO: Load ID into view model and fetch round while skeleton
            }
        }
    }
}

#Preview {
    GameLobby()
}
