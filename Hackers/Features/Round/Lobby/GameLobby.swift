//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import AlertToast
import Flow
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

    @StateObject var roundService = RoundService()
    
    private var snapshot: RoundSnapshot { roundService.snapshot }
    private var configuration: RoundConfiguration { snapshot.round.configuration }
    private var participants: [RoundParticipant] { snapshot.participants }
    private var roundSegment: RoundSegment? { snapshot.segments.first }
    
    private var courseSegment: CourseSegment? { configuration.courses.first }
    private var courseInfo: CourseInfo? { courseSegment?.courseInfo }
    private var holeRange: HoleRange? { configuration.courses.first?.holeRange }
    private var holeSegment: HoleSegment { holeRange?.segment ?? .full18 }
    private var defaultTee: Tee? { courseInfo?.teeMap[courseSegment?.defaultTee ?? ""] }
    
    private var hostName: Name? { participants.first(where: \.isHost)?.name }
    
    private var preventRoundStart: Binding<Bool> { .true }
    
    @State private var showShareCodeView = false
    @State private var showDefaultTeeSelection = false
    @State private var showPlayerManagementView = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                NavButton(
                    icon: "f00d",
                    color: .systemBlack,
                    background: Color.buttonSecondary,
                    onTap: { dismiss() }
                )
                
                VStack(spacing: 2) {
                    Text("Game Lobby")
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .alignCenter()
                    
                    if let hostName {
                        Text("Hosted by \(hostName.fullName)")
                            .fontStyle(.poppins, size: 11, weight: .regular)
                            .foregroundStyle(Color.hackersGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .alignCenter()
                    }
                }

                NavButton(
                    icon: "f029",
                    color: .systemBlack,
                    background: Color.buttonSecondary,
                    onTap: { print("show qr code popup") }
                )
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                content
                    .padding(.horizontal, 16)
            }
            
            PrimaryButton(
                appearance: .fill,
                title: "Start round",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: preventRoundStart,
                isLoading: .false,
                onTap: {
                    print("start round")
                }
            )
            .padding(.horizontal, 16)
        }
        .background(Color.backgroundSecondary)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden)
        .task {
            if let id = appSession.activeRoundID {
                await roundService.initialize(for: id)
            }
        }
        .toast(isPresenting: $roundService.isLoadingLobbyListeners) { .loader() }
        .sheet(isPresented: $showDefaultTeeSelection) {
            TeeSelectionSheet(
                selectedTee: defaultTee,
                maleTees: courseInfo?.tees.male ?? [],
                femaleTees: courseInfo?.tees.female ?? [],
                segment: holeRange?.segment ?? .full18,
                onChange: { tee in
                    showDefaultTeeSelection = false
                    Task {
                        await roundService.setDefaultTee(to: tee.id)
                    }
                }
            )
            .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Course")
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()
                
                if let courseSegment {
                    tile(for: courseSegment)
                }
            }

            VStack(spacing: 8) {
                Text("Game")
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()
                
                gameFormatTile()
            }
            
            VStack(spacing: 8) {
                Text("Players")
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()
                
                playersTile()
            }

            // TODO: Player management (players, tee groups, teams)
            // Players
            // List of roster
            // [Initials w/ team color] Name <--spacer--> [Action (HCP, Tee Group, Team)]
            // Initials are in team color
            // Option to group by tee group, handicap, or team, or ABC?
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Course
    
    @ViewBuilder
    private func tile(for courseSegment: CourseSegment) -> some View {
        let info = courseSegment.courseInfo
        
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.accentGreen.opacity(0.2))
                        .frame(width: 30, height: 30)
                    Icon(name: "f3c5", size: 17, weight: .regular)
                        .foregroundStyle(.accentGreen)
                }

                
                VStack(spacing: 0) {
                    Text(info.name)
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .alignLeading()
                    
                    HStack(spacing: 12) {
                        if let loc = info.location, let city = loc.city, let state = loc.state {
                            Text("\(city), \(state)")
                                .fontStyle(.poppins, size: 13, weight: .regular)
                                .foregroundStyle(Color.systemGray)
                            
                            Dot()
                        }
                        
                        if let defaultTee {
                            Text("Par \(courseSegment.par(for: defaultTee))")
                                .fontStyle(.poppins, size: 13, weight: .regular)
                                .foregroundStyle(Color.systemGray)
                        }
                        
                        Dot()
                        
                        Text("\(info.totalHoles) holes")
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.systemGray)
                        
                        Spacer(minLength: 0)
                    }
                }
            }

            VStack(spacing: 8) {
                TeeDropdown(
                    tee: defaultTee,
                    segment: courseSegment.holeSegment,
                    showGender: true,
                    onTap: { showDefaultTeeSelection = true }
                )
                
                Text("Default tee for all players. Modify per-player in roster below.")
                    .fontStyle(.poppins, size: 11, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .alignLeading()
            }
        }
        .tileEffect()
    }
    
    // MARK: - Format
    
    private var gameFormat: GameFormat { snapshot.round.configuration.primaryFormat }
    private var requiresTeams: Bool { roundSegment?.gameFormat.configuration.requiresTeams ?? false }
    
    @State private var handicapsEnabled: Bool = false
    @State private var teamsEnabled: Bool = false
    
    @ViewBuilder
    private func gameFormatTile() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Format")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text(gameFormat.type.displayName)
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.systemBlack)
                    .chevronChip()
            }
            .alignLeading()

            Toggle(isOn: $handicapsEnabled, label: {
                Text("Handicaps")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.systemBlack)
            })
            .tint(.accentPurple)
            
            Toggle(isOn: requiresTeams ? .true : $teamsEnabled, label: {
                Text("Teams")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.systemBlack)
            })
            .tint(.accentPurple)
            
            if requiresTeams {
                Text("This game requires teams.")
                    .fontStyle(.poppins, size: 11, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .alignLeading()
            }
        }
        .tileEffect()
        .onAppear() {
            teamsEnabled = requiresTeams
        }
    }
    
    // MARK: - Player Mgmt
    
    private enum PlayerTab: String, CaseIterable {
        case roster = "Roster"
        case groups = "Tee Groups"
        case teams = "Teams"
        
        var name: String { self.rawValue }
    }
    
    private enum PlayerCTA: String, CaseIterable {
        case ellipse = "Manage"
        case handicap = "Handicap"
        case group = "Tee group"
        case team = "Team"
        
        var name: String { self.rawValue }
    }
    
    @State private var playerTab: PlayerTab = .roster
    @State private var playerCTA: PlayerCTA = .ellipse
    
    @ViewBuilder
    private func playersTile() -> some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(PlayerTab.allCases, id: \.self) { tab in
                        let match = tab == playerTab
                        Button(action: {
                            Haptics.fire(.light)
                            playerTab = tab
                        }) {
                            Chip(
                                text: tab.name,
                                foreground: match ? .white : .hackersForeground,
                                background: match ? .hackersGreen : .hackersGray6
                            )
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }

            HStack {
                Text("\(participants.count) player\(participants.count.pluralized)")
                    .fontStyle(.poppins, size: 13, weight: .semibold)
                    .foregroundStyle(Color.hackersGray)
                
                Spacer(minLength: 0)
                
//                Button(action: {
//                    Haptics.fire(.light)
//                    nextCTA()
//                }) {
//                    Text(playerCTA.name)
//                        .fontStyle(.poppins, size: 13, weight: .medium)
//                        .foregroundStyle(Color.hackersGray)
//                        .caretChip()
//                }
            }
            
            ForEach(participants, id: \.self) { participant in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.hackersGray6)
                            .frame(width: 36, height: 36)
                        Text(participant.name.initials)
                            .fontStyle(.poppins, size: 15, weight: .medium)
                            .foregroundStyle(Color.systemBlack)
                    }
                    VStack(spacing: 2) {
                        Text(participant.name.fullName)
                            .fontStyle(.poppins, size: 15, weight: .semibold)
                            .foregroundStyle(Color.systemBlack)
                            .alignLeading()
                        
                        Text("Subtitle (HCP / Tee / Teams)")
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.hackersGray)
                            .alignLeading()
                    }
                    
                    Spacer(minLength: 0)
                    
                    Menu {
                        Button(action: { }) {
                            Text("Edit name")
                            Text("View name in leaderboard")
                        }
                        
                        if let tees = courseSegment?.courseInfo.tees {
                            Menu("Tee box") {
                                Text("\(tees.male.count) Men's / \(tees.female.count) Women's")
                                Menu("Men's") {
                                    ForEach(tees.male.sortedByDifficulty(for: holeSegment), id: \.self) { tee in
                                        let y = tee.yardage(for: holeSegment)
                                        let c = tee.prettyRating(for: holeSegment)
                                        let s = tee.slope(for: holeSegment)
                                        
                                        Button(action: { print("change player tee to \(tee.name)") }) {
                                            Text(tee.name)
                                            Text("\(y) yards \(kDot) \(c ?? "?") / \(s ?? 0)")
                                        }
                                    }
                                }
                                Menu("Women's") {
                                    ForEach(tees.female.sortedByDifficulty(for: holeSegment), id: \.self) { tee in
                                        let y = tee.yardage(for: holeSegment)
                                        let c = tee.prettyRating(for: holeSegment)
                                        let s = tee.slope(for: holeSegment)
                                        
                                        Button(action: { print("change player tee to \(tee.name)") }) {
                                            Text(tee.name)
                                            Text("\(y) yards \(kDot) \(c ?? "?") / \(s ?? 0)")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Button(action: { }) {
                            Text("Handicap")
                            Text("Set or modify strokes")
                        }
                        
                        Button(action: { }) {
                            Text("Tee Group")
                        }
                        
                        Button(action: { }) {
                            Text("Team")
                        }
                        
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.hackersGray6)
                                .frame(width: 22, height: 22)
                            Icon(name: "f142", size: 15, weight: .solid)
                                .foregroundStyle(Color.hackersGray)
                        }
                    }
                }
            }
            
            SecondaryButton(
                text: "Add players",
                icon: "f055",
                weight: .regular,
                labelColor: .accentPurple,
                buttonColor: .accentPurple.opacity(0.2),
                isDisabled: .false,
                isLoading: .false,
                onTap: { showPlayerManagementView = true }
            )
            
//            Button(action: {
//                Haptics.fire(.light)
//                showPlayerManagementView = true
//            }) {
//                HStack(spacing: 12) {
//                    Icon(name: "f055", size: 20, weight: .regular)
//                        .foregroundStyle(Color.accentPurple)
//                    
//                    Text("Add players")
//                        .fontStyle(.poppins, size: 20, weight: .semibold)
//                        .foregroundStyle(Color.accentPurple)
//                    
//                    Spacer(minLength: 0)
//                }
//                .padding(.horizontal, 16)
//            }
        }
        .tileEffect()
    }
    
    private func nextCTA() {
        switch playerCTA {
        case .ellipse:
            playerCTA = handicapsEnabled ? .handicap : .group
        case .handicap:
            playerCTA = .group
        case .group:
            playerCTA = teamsEnabled ? .team : .ellipse
        case .team:
            playerCTA = .ellipse
        }
    }
}

// MARK: - Extended View Modifiers

fileprivate extension View {
    func tileEffect() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.surfaceSecondary)
            .cornerRadius(radius: 10)
    }
    
    func chevronChip() -> some View {
        HStack(spacing: 6) {
            self
            Image(systemName: "chevron.up.chevron.down")
                .fontStyle(.system, size: 13, weight: .medium)
                .foregroundStyle(Color.hackersGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.hackersGray6)
        .clipShape(Capsule())
    }
    
    func caretChip() -> some View {
        HStack(spacing: 6) {
            self
            Image(systemName: "chevron.down")
                .fontStyle(.system, size: 13, weight: .medium)
                .foregroundStyle(Color.hackersGray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.hackersGray6)
        .clipShape(Capsule())
    }
}

struct GameLobby_Previews: PreviewProvider {
    static var previews: some View {
        GameLobby()
            .environmentObject(AppSession())
    }
}
