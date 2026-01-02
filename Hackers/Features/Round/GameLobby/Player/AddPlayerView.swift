//
//  AddPlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/3/25.
//

import SwiftUI

//struct AddPlayerResult {
//    var online: [Player]
//    var offline: [Player]
//}

struct AddPlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot
    // TODO: Allow input for group or tee time
    var onConfirm: CallbackValue<[Player]>?
    
    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = [] // List of searched online players
    @State private var isSearchingPlayers = false
    
    @State private var prefilledName = ""
    @State private var stagedPlayers: [Player] = []
    
    @State private var showManagePlayer = false
    @State private var managingPlayer: Player? = nil // Should this be the participant?
    @State private var showNewOfflinePlayer = false
    @State private var searchFocused = false
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private var existingPlayers: [Player] { snapshot.participants.compactMap { Player(playable: $0) } }
    private var playerCount: Int { existingPlayers.count + stagedPlayers.count }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .resignKeyboardOnTapGesture()
        .sheet(isPresented: $showNewOfflinePlayer, onDismiss: { prefilledName = "" }) {
            NewOfflinePlayerView(text: prefilledName, onCreate: { name in
                var player = Player(name: name)
                player.needsToBeCreated = true
                stagedPlayers.append(player)
                showNewOfflinePlayer = false
                searchText = ""
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            if isSearchingPlayers {
                
                skeletonView
                Spacer(minLength: 0)
                
            } else if searchText.isPopulated {
                if searchedPlayers.isPopulated {
                    
                    Text("\(searchedPlayers.count) player\(searchedPlayers.count.pluralized) found")
                        .fontStyle(.poppins, size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    
                    ForEach(searchedPlayers, id: \.self) { player in
                        row(for: player)
                        Line()
                    }
                    
                } else {
                    Text("No Hackers players found")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignCenter()
                    
                    Button(action: {
                        Haptics.fire(.light)
                        prefilledName = searchText
                        showNewOfflinePlayer = true
                    }) {
                        Text("Add \(searchText) offline")
                            .fontStyle(.poppins, size: 15, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                            .alignCenter()
                    }

                    Spacer(minLength: 0)
                }
            } else if stagedPlayers.isPopulated {
                
                ForEach(stagedPlayers, id: \.self) { player in
                    row(for: player)
                    Line()
                }
                
            } else {
                Text("Recent (coming soon)")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                
                SkeletonRow()
                SkeletonRow()
                
                Spacer(minLength: 0)
                    .frame(height: 16)
                
                Text("Nearby (coming soon)")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                
                SkeletonRow()
                SkeletonRow()
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func row(for player: Player) -> some View {
        let isAdded = player.exists(within: stagedPlayers + existingPlayers)
        let isHost = player.isHost(in: snapshot)
        
        Button(action: {
            Haptics.fire(.light)
            if isHost {
                print("cannot remove host")
                Haptics.fire(.error)
                return
            }
            
            stagedPlayers.toggle(player)
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
    
    @ViewBuilder
    private func stagedRow(for player: Player) -> some View {
        // TODO: Existing players is not showing here
        
        let isAdded = player.exists(within: stagedPlayers + existingPlayers)
        let isHost = player.isHost(in: snapshot)
        
        Button(action: {
            Haptics.fire(.light)
            if isHost {
                print("cannot remove host")
                Haptics.fire(.error)
                return
            }
            stagedPlayers.toggle(player)
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
                
                if stagedPlayers.isPopulated {
                    NavButton(
                        icon: "f00c",
                        color: palette.backgroundColor,
                        background: palette.foregroundColor,
                        onTap: { onConfirm?(stagedPlayers) }
                    )
                }
            }
            
            SearchBar(
                placeholder: "Search players",
                autocapitalization: .words,
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
                
                HStack(spacing: 16) {
                    PrimaryButton(
                        appearance: .fill,
//                        title: "Add new",
                        icon: "2b",
                        iconWeight: .solid,
                        buttonColor: palette.buttonColor,
                        theme: palette.theme,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showNewOfflinePlayer = true }
                    )
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Add \(stagedPlayers.count) players",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .constant(stagedPlayers.isEmpty),
                        isLoading: .false,
                        onTap: { onConfirm?(stagedPlayers) }
                    )
                }
                .padding(.horizontal, 16)
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
            self.searchedPlayers = self.searchedPlayers
                .filter(\.isActive)
                .sorted(by: { $0.name.fullName < $1.name.fullName })
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
