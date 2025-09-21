//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import AlertToast
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
            content
        }
        .padding(.horizontal, 16)
        .background(Color.hackersBackground)
        .task {
            if let id = appSession.activeRoundID {
                await roundService.initialize(for: id)
            }
            //roundService.snapshot = MockRoundSnapshot.strokePlaySnapshot
        }
        .toast(isPresenting: $roundService.isLoadingLobbyListeners) { .loader() }
    }
    
    private var courseInfo: CourseInfo? {
        roundService.snapshot.round.configuration.courses.first?.courseInfo
    }
    
    private var defaultTee: String? {
        roundService.snapshot.round.configuration.defaultTee
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                NavButton(icon: "f00d", onTap: { dismiss() })
                
                Text("Game Lobby")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .alignCenter()
                
                NavButton(icon: "f029", onTap: { dismiss() })
            }
            
            Text("Course")
                .fontStyle(.poppins, size: 20, weight: .semibold)
                .foregroundStyle(Color.systemBlack)
                .alignLeading()
            
            if let courseInfo {
                VStack(spacing: 16) {
                    Text(courseInfo.name)
                        .fontStyle(.poppins, size: 20, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .alignLeading()
                    
                    HStack(spacing: 12) {
                        Text("\(courseInfo.totalHoles) holes")
                            .fontStyle(.poppins, size: 15, weight: .semibold)
                            .foregroundStyle(Color.systemGray)
                        
                        if let defaultTee, let tee = courseInfo.tees[defaultTee] {
                            Dot()
                            
                            Text("Par \(tee.par)")
                                .fontStyle(.poppins, size: 15, weight: .semibold)
                                .foregroundStyle(Color.systemGray)
                        }
                    }
                    
                    CourseMapView(
                        latitude: 0,
                        longitude: 0,
                        meters: 600
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .border(Color.hackersGray5, width: 1.5, cornerRadius: 10)
            }
            
            // TODO: Selected course tile
            // VStack
            // Course title
            // Course info (holes, par (from default tee), yardage, tee difficulty)
            // HStack - map
            
            // TODO: Selected game format
            // Format
            // Stroke play default
            // Toggle for handicaps
            // Subtitle saying this allows for team play (CTA for teams)
            
            // TODO: Player management (players, tee groups, teams)
            // Players
            // List of roster
            // [Initials w/ team color] Name <--spacer--> [Action (HCP, Tee Group, Team)]
            // Initials are in team color
            // Option to group by tee group, handicap, or team, or ABC?
            
            Spacer(minLength: 0)
        }
        .navigationBarBackButtonHidden()
    }
}

struct GameLobby_Previews: PreviewProvider {
    static var previews: some View {
        GameLobby()
            .environmentObject(AppSession())
    }
}
