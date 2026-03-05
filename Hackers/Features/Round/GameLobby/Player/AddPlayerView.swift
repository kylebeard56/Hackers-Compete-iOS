//
//  AddPlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/3/25.
//

import SwiftUI

struct AddPlayerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var roundSession: RoundSession
    var groupID: String? = nil
    var teamID: String? = nil
    var onConfirm: CallbackValue<[Player]>?
    
    private var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = [] // List of searched online players
    @State private var isSearchingPlayers = false
    @State private var searchSelectionCount = 0
    @State private var searchFocused = false
    @State private var ignoreNextSearchQuery = false
    
    @State private var prefilledName: Identify<String>? = nil
    @State private var selectedPlayers: [Player] = []
    
    @State private var showManagePlayer = false
    @State private var managingPlayer: Player? = nil // Should this be the participant?
    
    @State private var currentPlayers: [Player] = []
    private var playerCount: Int { currentPlayers.count + selectedPlayers.count }
    
    @State private var isConfirming = false
    @State private var recentPlayers: [Player] = []
    @State private var suggestedPlayers: [Player] = []
    @State private var isLoadingHistory = false
    @State private var roundsPlayedByPlayerID: [String: Int] = [:]

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .task {
            currentPlayers = snapshot.participants.compactMap { Player(playable: $0) }
            await loadPlayerHistory()
        }
        .onReceive(roundSession.$snapshot, perform: { s in
            currentPlayers = s.participants.compactMap { Player(playable: $0) }
            Task { await loadPlayerHistory() }
        })
        .resignKeyboardOnTapGesture()
        .sheet(item: $prefilledName) { text in
            NewOfflinePlayerView(text: text.value){ name in
                var player = Player(name: name)
                player.needsToBeCreated = true
                searchedPlayers.append(player)
                selectedPlayers.append(player)
                ignoreNextSearchQuery = true
                searchText = ""
                prefilledName = nil
            }
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
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    
                    ForEach(searchedPlayers, id: \.self) { player in
                        row(for: player, type: .search)
                        Line()
                    }
                    
                } else {
                    Text("No Hackers players found")
                        .fontStyle(kFontName, size: 15, weight: .medium)
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
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                
                ForEach(selectedPlayers, id: \.self) { player in
                    row(for: player, type: .selection)
                    Line()
                }
                
            } else {
                if isLoadingHistory {
                    SkeletonRow()
                    SkeletonRow()
                } else {
                    if recentPlayers.isPopulated {
                        Text("Recent")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                        ForEach(recentPlayers, id: \.id) { player in
                            row(for: player, type: .search)
                            Line()
                        }
                        Spacer(minLength: 0).frame(height: 16)
                    }
                    if suggestedPlayers.isPopulated {
                        Text("Suggested")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                        ForEach(suggestedPlayers, id: \.id) { player in
                            row(for: player, type: .search)
                            Line()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    enum PlayerRowType { case selection, search }
    
    @ViewBuilder
    private func row(for player: Player, type: PlayerRowType) -> some View {
        let isAlreadyAdded = player.exists(within: currentPlayers)
        let isStaged = player.exists(within: selectedPlayers)
        
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.cardColor)
                    .frame(width: 36, height: 36)
                Text(player.name.initials)
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name.fullName)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    if !player.isOffline {
                        Icon(name: "checkmark.circle.fill", size: 14, weight: .semibold)
                            .foregroundStyle(Color.accentPurple)
                    }
                }
                if player.rounds.count > 0 {
                    let total = player.rounds.count
                    let together = roundsPlayedByPlayerID[player.id] ?? 0
                    let subtitle = together > 0
                        ? "\(total) \(total == 1 ? "round" : "rounds") \(kDot) \(together) together"
                        : "\(total) \(total == 1 ? "round" : "rounds")"
                    Text(subtitle)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
            
            Spacer(minLength: 0)
            
            Button {
                if isAlreadyAdded {
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
            } label: {
                Group {
                    if type == .selection {
                        if isStaged {
                            NavButton(
                                icon: "f00d",
                                size: 14,
                                color: .systemError,
                                background: .systemError.opacity(colorScheme.translucent)
                            )
                            .disabled(true)
                        } else {
                            NavButton(
                                icon: "2b",
                                size: 14,
                                color: palette.backgroundColor,
                                background: palette.foregroundColor
                            )
                            .disabled(true)
                        }
                    }
                    
                    if type == .search {
                        if isAlreadyAdded {
                            Chip(
                                text: "In Lobby",
                                icon: "f00c",
                                iconWeight: .solid,
                                size: .xSmall,
                                style: .fill,
                                tint: .accentPurple
                            )
                        } else if isStaged {
                            NavButton(
                                icon: "f00c",
                                size: 14,
                                color: .white,
                                background: .accentGreen
                            )
                            .disabled(true)
                        } else {
                            NavButton(
                                icon: "2b",
                                size: 14,
                                color: palette.backgroundColor,
                                background: palette.foregroundColor
                            )
                            .disabled(true)
                        }
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
                    .fontStyle(kFontName, size: 24, weight: .semibold)
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
                    handleSearchQuery(for: text)
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
    
    private func handleSearchQuery(for text: String) {
        addBreadcrumb()
        
        // 1. If offline player was set, spoof them into search results and ignore querying since it will reset state.
        if ignoreNextSearchQuery {
            ignoreNextSearchQuery = false
            return
        }
        
        // 2. Avoid duplicate requests
        if searchText == text { return }
        
        // 3. Set search text to debouncer
        searchText = text
        
        // 4. Query DB
        Task {
            await queryPlayers(for: text)
        }
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
    fileprivate func loadPlayerHistory() async {
        guard let primary = await AppData.shared.getPrimaryPlayer() else { return }
        let excludedIDs = Set(snapshot.participants.compactMap(\.playerID))
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        let entries = primary.playerHistory.values.filter { !excludedIDs.contains($0.playerID) }
        roundsPlayedByPlayerID = Dictionary(uniqueKeysWithValues: primary.playerHistory.values.map { ($0.playerID, $0.rounds.count) })
        let recentEntries = entries.sorted { a, b in
            let aLast = a.lastPlayedAt?.unix ?? 0
            let bLast = b.lastPlayedAt?.unix ?? 0
            return aLast > bLast
        }
        let ninetyDaysAgo = (Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast).timeIntervalSince1970
        let suggestedEntries = entries
            .map { entry -> (PlayerHistoryEntry, Int) in
                let count = entry.rounds.filter { $0.playedAt.unix >= ninetyDaysAgo }.count
                return (entry, count)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        let recentIDs = recentEntries.map(\.playerID)
        let suggestedIDs = suggestedEntries.map(\.playerID)
        let allIDs = Array(Set(recentIDs + suggestedIDs))

        guard allIDs.isPopulated else {
            recentPlayers = []
            suggestedPlayers = []
            return
        }

        switch await FirebaseService.shared.getPlayersByIDs(allIDs) {
        case .success(let players):
            let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            recentPlayers = recentIDs.compactMap { byID[$0] }
            suggestedPlayers = suggestedIDs.compactMap { byID[$0] }
        case .failure:
            recentPlayers = []
            suggestedPlayers = []
        }
    }

    fileprivate func queryPlayers(for text: String) async {
        addBreadcrumb()
        if text.isEmpty { return }
        
        let prefix = text.lowercased()
        
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
                addBreadcrumb(message: "No players found via search to add")
                return
            }
            addBreadcrumb(
                level: .error,
                message: "Failed to search players to add to round",
                error: error,
                parameters: [
                    "Search query" : prefix
                ]
            )
        }
    }
}

#Preview {
    Color.backgroundPrimary.sheet(isPresented: .true) {
        AddPlayerView(roundSession: .init())
            .presentationDragIndicator(.visible)
    }
}
