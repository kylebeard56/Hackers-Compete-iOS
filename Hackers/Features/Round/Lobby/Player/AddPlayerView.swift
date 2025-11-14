//
//  AddPlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/3/25.
//

import SwiftUI

struct AddPlayerResult {
    var online: [Player]
    var offline: [Player]
}

struct AddPlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot
    var onConfirm: CallbackValue<AddPlayerResult>?
    
    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = [] // List of searched online players
    @State private var isSearchingPlayers = false
    
    @State private var stagedOnlinePlayers: [Player] = []
    @State private var stagedOfflinePlayers: [Player] = []
    
    @State private var showAddEditPlayer = false
    @State private var showNewOfflinePlayer = false
    @State private var searchFocused = false
    
    let newOfflinePlayerSourceID = "newOfflinePlayer"
    @Namespace private var newOfflinePlayerTransition
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var existingPlayers: [Player] { snapshot.participants.compactMap { Player(playable: $0) } }
    private var stagedPlayers: [Player] { stagedOnlinePlayers + stagedOfflinePlayers }
    private var playerCount: Int { existingPlayers.count + stagedPlayers.count }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .resignKeyboardOnTapGesture()
        .sheet(isPresented: $showNewOfflinePlayer) {
            NewOfflinePlayerView(onCreate: { name in
                let player = Player(name: name)
                stagedOfflinePlayers.append(player)
            })
            .navigationTransition(.zoom(sourceID: newOfflinePlayerSourceID, in: newOfflinePlayerTransition))
//            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
//        .sheet(isPresented: $showAddEditPlayer) {
//            ManagePlayerView(
//                snapshot: snapshot,
//                onFinish: { data in
//                    stagedParticipants.append(
//                        data.participant(for: snapshot.round.id)
//                    )
//                }
//            )
//            .navigationTransition(.zoom(sourceID: addEditSourceID, in: addEditTransition))
//            .presentationDragIndicator(.visible)
//        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            if isSearchingPlayers {
                
                skeletonView
                Spacer(minLength: 0)
                
            } else if searchText.isPopulated {
                if searchedPlayers.isPopulated {
                    
                    Text("\(searchedPlayers.count) player\(searchedPlayers.count.pluralized) found")
                        .fontStyle(.poppins, size: 13, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    
                    ForEach(searchedPlayers, id: \.self) { player in
                        searchedRow(for: player)
                        Line()
                    }
                    
                } else {
                    
//                    Spacer(minLength: 0)
//                    
//                    Image("GolferIsometric")
//                        .interpolation(.high)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: UIScreen.main.bounds.width * 0.45)
                    
                    Text("No players found")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignCenter()
                    
                    // TODO: Input to NewOfflinePlayerView to create.
                    Text("Add \(searchText) offline")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                        .alignCenter()
                    
                    Spacer(minLength: 0)
                }
            } else {
                // TODO: Add recent or nearby players here (based on location).
//                Text("Search for other Hackers players or add offline")
//                    .fontStyle(.poppins, size: 15, weight: .medium)
//                    .foregroundStyle(Color.neutral)
//                    .alignCenter()
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func searchedRow(for player: Player) -> some View {
        let isAdded = (stagedPlayers + existingPlayers).filter({ $0.playerID == player.id }).isPopulated
        let isHost = player.id == snapshot.participants.first(where: \.isHost)?.playerID
        
        Button(action: {
            Haptics.fire(.light)
            if isHost {
                print("cannot remove host")
                Haptics.fire(.error)
                return
            }
            stagedOnlinePlayers.toggle(player)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(palette.cardColor)
                        .frame(width: 36, height: 36)
                    Text(player.name.initials)
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)
                }
                
                Text(player.name.fullName)
                    .fontStyle(.poppins, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                if isHost {
                    Chip(text: "Host", size: .xSmall, style: .outline)
                }
                
                Spacer(minLength: 0)
                
                if isAdded {
                    Icon(name: "f058", size: 20, weight: .solid)
                        .foregroundStyle(Color.accentGreen)
                } else {
                    Icon(name: "f055", size: 20, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
    }
    
    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            ForEach(0...5, id: \.self) { _ in
                SkeletonRow()
                Line()
            }
        }
    }
    
    private var addOfflineButton: some View {
        PrimaryButton(
            appearance: .fill,
            title: "New offline player",
            icon: "f234",
            iconWeight: .solid,
            labelColor: palette.foregroundColor,
            buttonColor: palette.buttonColor,
            fillWidth: true,
            isDisabled: .false,
            isLoading: .false,
            onTap: {
                showNewOfflinePlayer = true
//                showAddEditPlayer = true
            }
        )
        .matchedTransitionSource(id: newOfflinePlayerSourceID, in: newOfflinePlayerTransition)
    }
    
    // TODO: Add/Edit Player
    // Name (first, last)? or do we split by name
    // Tee (set to default)
    // Handicap (if configured)
    // Tee Group (if configured)
    // Team (if configured)
}

extension AddPlayerView {
    fileprivate var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Add players")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", onTap: { dismiss() })
            }
            
            SearchBar(
                placeholder: "Search players",
                onDebounce: { text in
                    print("onDebounce \(text)")
                    if searchText == text { return }
                    searchText = text
                    Task {
                        await queryPlayers(for: text)
                    }
                },
                onFocusChange: { value in
                    print("onFocusChange \(value)")
                    searchFocused = value
                }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    fileprivate var footer: some View {
        if searchFocused {
            EmptyView()
        } else {
            VStack(spacing: 16) {
                Line()
                
                if stagedPlayers.isEmpty {
                    addOfflineButton
                        .padding(.horizontal, 16)
                } else {
                    HStack(spacing: 16) {
                        PrimaryButton(
                            appearance: .fill,
                            icon: "f234",
                            iconWeight: .solid,
                            buttonColor: palette.buttonColor,
                            theme: palette.theme,
                            fillWidth: false,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { showAddEditPlayer = true }
                        )
                        .matchedTransitionSource(id: newOfflinePlayerSourceID, in: newOfflinePlayerTransition)
                        
                        PrimaryButton(
                            appearance: .fill,
                            title: "Add \(stagedPlayers.count) players",
                            theme: palette.theme,
                            isDisabled: .constant(stagedPlayers.isEmpty),
                            isLoading: .false,
                            onTap: {
                                onConfirm?(
                                    .init(
                                        online: stagedOnlinePlayers,
                                        offline: stagedOfflinePlayers
                                    )
                                )
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

extension AddPlayerView: Loggable {
    fileprivate func queryPlayers(for text: String) async {
        if text.isEmpty { return }
        
        let prefix = text.lowercased()//.alphanumericLowercased
        addBreadcrumb("\(#function), \(prefix)")
        
        self.searchedPlayers = []
        
        isSearchingPlayers = true
        defer { isSearchingPlayers = false }
        
        do {
            self.searchedPlayers = try await FirebaseService.shared.searchPlayersByName(prefix).get()
        } catch {
            if let e = error as? HackersError, e == .documentNotFound {
                addBreadcrumb(.info, .gameLobby, "No players found via search to add")
                return
            }
            addBreadcrumb(.error, .gameLobby, "Failed to search players to add to round", error)
        }
    }
}

#Preview {
    Color.backgroundPrimary.sheet(isPresented: .true) {
        AddPlayerView(snapshot: .mock())
            .presentationDragIndicator(.visible)
    }
}
