//
//  AddPlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/3/25.
//

import SwiftUI

struct Identify<T>: Identifiable {
    var id = UUID()
    private(set) var value: T
    
    init(value: T) {
        self.id = UUID()
        self.value = value
    }
//    
//    /// Requires calling this explicit function to change the ID, triggering `sheet(item: $Identity<T>)` to show/hide.
//    mutating func set(value: T) {
//        self.id = UUID()
//        self.value = value
//    }
}

struct AddPlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var roundService: RoundService
    var groupID: String? = nil
    var teamID: String? = nil
    var onConfirm: CallbackValue<[Player]>?
    
    private var snapshot: RoundSnapshot { roundService.snapshot }
    
    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = [] // List of searched online players
    @State private var isSearchingPlayers = false
    @State private var searchSelectionCount = 0
    
    @State private var prefilledName: Identify<String>? = nil
    @State private var selectedPlayers: [Player] = []
    
    @State private var showManagePlayer = false
    @State private var managingPlayer: Player? = nil // Should this be the participant?
    @State private var searchFocused = false
    
    @State private var currentPlayers: [Player] = []
    private var playerCount: Int { currentPlayers.count + selectedPlayers.count }
    
    @State private var isConfirming = false
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .task {
            // TODO: The IDs are inconsistent for players vs roundparticipants and player_id being nil and not matching.
            print("SNAPSHOT PARTICIPANTS:")
            printPretty(snapshot.participants)
            currentPlayers = snapshot.participants.compactMap { Player(playable: $0) }
            print("CONVERSION TO PLAYERS:")
            printPretty(currentPlayers)
        }
        .onReceive(roundService.$snapshot, perform: { s in
            currentPlayers = s.participants.compactMap { Player(playable: $0) }
        })
        .resignKeyboardOnTapGesture()
        .sheet(item: $prefilledName) { text in
            NewOfflinePlayerView(text: text.value, onCreate: { name in
                var player = Player(name: name)
                player.needsToBeCreated = true
                selectedPlayers.append(player)
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
                        row(for: player, type: .search)
                        Line()
                    }
                    
                } else {
                    Text("No Hackers players found")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignCenter()
                    
                    GlassButton(
                        title: "Add \(searchText) offline",
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { prefilledName = .init(value: searchText)  }
                    )

                    Spacer(minLength: 0)
                }
            } else if selectedPlayers.isPopulated {
                let count = selectedPlayers.count
                Text("\(count) player\(count.pluralized) selected")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                
                ForEach(selectedPlayers, id: \.self) { player in
                    row(for: player, type: .selection)
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
    
    enum PlayerRowType { case selection, search }
    
    @ViewBuilder
    private func row(for player: Player, type: PlayerRowType) -> some View {
        let isAlreadyAdded = player.exists(within: currentPlayers)
        let isStaged = player.exists(within: selectedPlayers)
//        let isHost = player.isHost(in: snapshot)
        
        Button {
            if isAlreadyAdded { // isHost {
                Haptics.fire(.warning)
                return
            }
            Haptics.fire(.light)
            
            if let i = selectedPlayers.firstIndex(of: player) {
                selectedPlayers.remove(at: i)
                searchSelectionCount -= 1
            } else {
                selectedPlayers.append(player)
                searchSelectionCount += 1
            }
//            selectedPlayers.toggle(player)
        } label: {
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
                
//                if isHost {
//                    Chip(text: "Host", size: .xSmall, style: .outline)
//                }
                
                Spacer(minLength: 0)
                
                if type == .selection {
                    if isStaged {
                        Icon(name: "f00d", size: 13, weight: .solid) // xmark
                            .foregroundStyle(Color.systemError)
                    } else {
                        Icon(name: "2b", size: 20, weight: .regular) // plus
                            .foregroundStyle(Color.neutral)
                    }
                }
                
                if type == .search {
                    if isAlreadyAdded {
                        Chip(text: "Already Added", size: .xSmall, style: .outline, tint: .accentPurple)
                    } else if isStaged {
                        Icon(name: "f00c", size: 20, weight: .solid) // checkmark
                            .foregroundStyle(Color.accentGreen)
                    } else {
                        Icon(name: "2b", size: 20, weight: .regular) // plus
                            .foregroundStyle(Color.neutral)
                    }
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
                
                if selectedPlayers.isPopulated {
                    NavButton(
                        icon: "f00c",
                        color: palette.backgroundColor,
                        background: palette.foregroundColor,
                        onTap: { onConfirm?(selectedPlayers) }
                    )
                }
            }
            
            // TODO: Add banner saying all players added will be in tee group or team inputted
            
            SearchBar(
                placeholder: "Search players",
                callToAction: searchSelectionCount > 0 ? "Done" : "Cancel",
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
                    searchSelectionCount = 0
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
                        icon: "2b",
                        iconWeight: .solid,
                        buttonColor: palette.buttonColor,
                        theme: palette.theme,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { prefilledName = .init(value: "") }
                    )
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Add \(selectedPlayers.count) players",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .constant(selectedPlayers.isEmpty),
                        isLoading: $isConfirming,
                        onTap: {
                            isConfirming = true
                            onConfirm?(selectedPlayers)
                        }
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
        AddPlayerView(roundService: .init())
            .presentationDragIndicator(.visible)
    }
}
