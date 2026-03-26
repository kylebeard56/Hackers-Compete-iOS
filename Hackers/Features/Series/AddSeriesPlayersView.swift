//
//  AddSeriesPlayersView.swift
//  Hackers
//

import SkeletonUI
import SwiftUI

// TODO: expose league invite actions (Invite button + Pending chip) when ready for release
private let kShowLeagueInviteActions = false

struct AddSeriesPlayersView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    var onDismiss: () -> Void

    @State private var searchText = ""
    @State private var searchedPlayers: [Player] = []
    @State private var isSearching = false
    @State private var actioningPlayerIDs: Set<String> = []

    @State private var recentPlayers: [Player] = []
    @State private var suggestedPlayers: [Player] = []
    @State private var recentVisibleCount = 5
    @State private var suggestedVisibleCount = 5
    @State private var isLoadingHistory = true
    @State private var hasLoadedInitialHistory = false
    @State private var showAddOfflinePlayer = false
    @State private var searchFocused = false
    /// Players successfully added to the league during this sheet (not pre-existing roster), in add order.
    @State private var playersAddedThisSession: [Player] = []

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var canCompleteFlow: Bool { playersAddedThisSession.isPopulated }

    private var excludedPlayerIDs: Set<String> {
        var ids = Set(viewModel.activeMembers.compactMap(\.playerID))
        if let current = viewModel.currentPlayerID {
            ids.insert(current)
        }
        return ids
    }

    private var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var addedPlayerIDs: Set<String> {
        Set(playersAddedThisSession.map(\.id))
    }

    private var recentPlayersForDisplay: [Player] {
        recentPlayers.filter { !addedPlayerIDs.contains($0.id) }
    }

    private var suggestedPlayersForDisplay: [Player] {
        suggestedPlayers.filter { !addedPlayerIDs.contains($0.id) }
    }

    private var searchedPlayersForDisplay: [Player] {
        searchedPlayers.filter { !addedPlayerIDs.contains($0.id) }
    }

    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showAddOfflinePlayer) {
            NewOfflinePlayerView { name in
                showAddOfflinePlayer = false
                Task { @MainActor in
                    let beforeIDs = Set(viewModel.activeMembers.compactMap(\.playerID))
                    await viewModel.addOfflineMember(name: name)
                    let afterIDs = Set(viewModel.activeMembers.compactMap(\.playerID))
                    let newIDs = afterIDs.subtracting(beforeIDs)
                    for id in newIDs {
                        switch await FirebaseService.shared.getPlayersByIDs([id]) {
                        case .success(let players):
                            if let player = players.first {
                                appendToAddedSession(player)
                            }
                        case .failure:
                            break
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await loadPlayerHistory()
            hasLoadedInitialHistory = true
        }
        .resignKeyboardOnTapGesture()
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add league players")
                        .fontStyle(kFontName, size: 24, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                        .alignLeading()
                    Text("Search Hackers profiles and add them to the roster, or use Add offline below.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    NavButton(icon: "f00d", onTap: {
                        onDismiss()
                        dismiss()
                    })
                    if canCompleteFlow {
                        NavButton(
                            icon: "f00c",
                            color: palette.backgroundColor,
                            background: palette.foregroundColor,
                            onTap: { completeFlow() }
                        )
                    }
                }
            }

            SearchBar(
                placeholder: "Search players by name",
                callToAction: "Cancel",
                autocapitalization: .words,
                milliseconds: 250,
                onDebounce: { text in
                    await handleDebouncedSearch(text)
                },
                onFocusChange: { searchFocused = $0 }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var footer: some View {
        if searchFocused {
            EmptyView()
        } else {
            VStack(spacing: 16) {
                Line()
                
                HStack(alignment: .center, spacing: 16) {
                    PrimaryButton(
                        appearance: .fill,
                        title: "Add offline",
                        labelColor: palette.foregroundColor,
                        buttonColor: Color.neutral6,
                        theme: palette.theme,
                        fillWidth: true,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showAddOfflinePlayer = true }
                    )
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Done",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        fillWidth: true,
                        isDisabled: .constant(!canCompleteFlow),
                        isLoading: .constant(false),
                        onTap: { completeFlow() }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var addedSection: some View {
        if playersAddedThisSession.isPopulated {
            Text("Added (\(playersAddedThisSession.count))")
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(Color.neutral)
                .alignLeading()
            VStack(alignment: .leading, spacing: 10) {
                ForEach(playersAddedThisSession, id: \.id) { player in
                    searchResultRow(player)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {
            addedSection

            if searchText.isPopulated {
                if trimmedSearchQuery.count < 2 {
                    Text("Type at least two characters to find players.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else if isSearching {
                    skeletonView
                } else if searchedPlayers.isPopulated {
                    Text("\(searchedPlayers.count) player\(searchedPlayers.count.pluralized) found")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(searchedPlayersForDisplay, id: \.id) { player in
                            searchResultRow(player)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No matching players found.")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignCenter()
                        Text("Use Add offline below.")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                if isLoadingHistory {
                    skeletonView
                } else if recentPlayersForDisplay.isPopulated || suggestedPlayersForDisplay.isPopulated {
                    if recentPlayersForDisplay.isPopulated {
                        Text("Recent")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(recentPlayersForDisplay.prefix(recentVisibleCount)), id: \.id) { player in
                                searchResultRow(player)
                            }
                        }
                        if recentPlayersForDisplay.count > recentVisibleCount {
                            Button("See more") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    recentVisibleCount = min(recentVisibleCount + 10, recentPlayersForDisplay.count)
                                }
                            }
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                        }
                        Spacer(minLength: 0).frame(height: 16)
                    }
                    if suggestedPlayersForDisplay.isPopulated {
                        Text("Suggested")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(suggestedPlayersForDisplay.prefix(suggestedVisibleCount)), id: \.id) { player in
                                searchResultRow(player)
                            }
                        }
                        if suggestedPlayersForDisplay.count > suggestedVisibleCount {
                            Button("See more") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    suggestedVisibleCount = min(suggestedVisibleCount + 10, suggestedPlayersForDisplay.count)
                                }
                            }
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                        }
                    }
                } else if !playersAddedThisSession.isPopulated {
                    EmptyStateView(
                        imageName: EmptyStatePreset.playerHistory.imageName,
                        title: "Find players for your league",
                        subtitle: "Search by name or browse people you've played with recently."
                    )
                    .alignMiddle()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .animation(.easeInOut(duration: 0.2), value: searchText)
    }

    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: palette.skeletonColor,
                            background: palette.skeletonBackground
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.5, 2: 0.25]
                    )
                    .frame(width: 120, height: 14)
                ForEach(0...5, id: \.self) { _ in
                    SkeletonRow()
                }
            }
        }
    }

    private func searchResultRow(_ player: Player) -> some View {
        let isMember = viewModel.activeMembers.contains { $0.playerID == player.id }
        let pendingInvite = viewModel.invites.first { invite in
            guard invite.status == .pending else { return false }
            let matchesPlayerID = player.id.isPopulated && invite.invitedPlayerID == player.id
            let matchesUserID = (player.userID?.isPopulated == true) && invite.invitedUserID == player.userID
            return matchesPlayerID || matchesUserID
        }
        let isActioning = actioningPlayerIDs.contains(player.id)

        return SeriesSheetRow {
            HStack(spacing: 12) {
                PlayerAvatarView(initials: player.name.initials, size: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if isMember {
                        Text("On league roster")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.neutral)
                    } else if pendingInvite != nil {
                        Text("Invite already sent")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.accentGreen)
                    } else {
                        Text(player.userID?.isPopulated == true ? "Hackers user" : "Offline user")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }

                Spacer(minLength: 0)

                if isActioning {
                    ProgressView()
                        .tint(Color.accentGreen)
                } else if isMember {
                    if viewModel.isCommissioner {
                        Button {
                            Task { await removeMember(player) }
                        } label: {
                            Chip(
                                text: "Remove",
                                size: .xSmall,
                                foreground: .systemError,
                                background: Color.systemError.opacity(colorScheme.translucent)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Chip(
                            text: "Member",
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: Color.neutral5
                        )
                    }
                } else if kShowLeagueInviteActions {
                    HStack(spacing: 8) {
                        Button {
                            Task { await addPlayer(player) }
                        } label: {
                            Chip(
                                text: pendingInvite == nil ? "Add" : "Add now",
                                size: .xSmall,
                                foreground: .white,
                                background: Color.accentGreen
                            )
                        }
                        .buttonStyle(.plain)

                        if pendingInvite == nil {
                            Button {
                                Task { await invitePlayer(player) }
                            } label: {
                                Chip(
                                    text: "Invite",
                                    size: .xSmall,
                                    foreground: palette.foregroundColor,
                                    background: Color.neutral5
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Chip(
                                text: "Pending",
                                size: .xSmall,
                                foreground: Color.accentGreen,
                                background: Color.accentGreen.opacity(colorScheme.translucent)
                            )
                        }
                    }
                } else {
                    Button {
                        Task { await addPlayer(player) }
                    } label: {
                        Chip(
                            text: pendingInvite == nil ? "Add" : "Add now",
                            size: .xSmall,
                            foreground: .white,
                            background: Color.accentGreen
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func handleDebouncedSearch(_ text: String) async {
        guard searchText != text else { return }
        searchText = text
        await performSearch()
    }

    private func completeFlow() {
        onDismiss()
        dismiss()
    }

    private func appendToAddedSession(_ player: Player) {
        guard !playersAddedThisSession.contains(where: { $0.id == player.id }) else { return }
        playersAddedThisSession.append(player)
    }

    private func removeFromAddedSession(_ player: Player) {
        playersAddedThisSession.removeAll { $0.id == player.id }
    }

    @MainActor
    private func addPlayer(_ player: Player) async {
        actioningPlayerIDs.insert(player.id)
        defer { actioningPlayerIDs.remove(player.id) }
        Haptics.fire(.light)
        let wasOnRoster = viewModel.activeMembers.contains { $0.playerID == player.id }
        await viewModel.addMember(player)
        let isOnRoster = viewModel.activeMembers.contains { $0.playerID == player.id }
        if !wasOnRoster, isOnRoster {
            appendToAddedSession(player)
        }
    }

    @MainActor
    private func removeMember(_ player: Player) async {
        actioningPlayerIDs.insert(player.id)
        defer { actioningPlayerIDs.remove(player.id) }
        Haptics.fire(.light)
        let wasOnRoster = viewModel.activeMembers.contains { $0.playerID == player.id }
        await viewModel.removeMember(playing: player)
        let stillOnRoster = viewModel.activeMembers.contains { $0.playerID == player.id }
        if wasOnRoster, !stillOnRoster {
            removeFromAddedSession(player)
        }
    }

    @MainActor
    private func invitePlayer(_ player: Player) async {
        actioningPlayerIDs.insert(player.id)
        defer { actioningPlayerIDs.remove(player.id) }
        Haptics.fire(.light)
        await viewModel.createInvite(for: player)
    }

    @MainActor
    private func performSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchedPlayers = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        switch await FirebaseService.shared.searchPlayersByName(trimmed) {
        case .success(let results):
            searchedPlayers = results
                .filter { $0.id != viewModel.currentPlayerID }
                .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
        case .failure:
            searchedPlayers = []
        }
    }

    @MainActor
    private func loadPlayerHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        guard let primary = await AppData.shared.getPrimaryPlayer() else {
            recentPlayers = []
            suggestedPlayers = []
            recentVisibleCount = 5
            suggestedVisibleCount = 5
            return
        }

        let excludedIDs = excludedPlayerIDs
        let entries = primary.playerHistory.values.filter { !excludedIDs.contains($0.playerID) }
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
        let recentIDsSet = Set(recentIDs)
        let suggestedIDs = suggestedEntries
            .map(\.playerID)
            .filter { !recentIDsSet.contains($0) }
        let allIDs = Array(Set(recentIDs + suggestedIDs))

        guard allIDs.isPopulated else {
            recentPlayers = []
            suggestedPlayers = []
            recentVisibleCount = 5
            suggestedVisibleCount = 5
            return
        }

        switch await FirebaseService.shared.getPlayersByIDs(allIDs) {
        case .success(let players):
            let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            recentPlayers = recentIDs.compactMap { byID[$0] }
            suggestedPlayers = suggestedIDs.compactMap { byID[$0] }
            recentVisibleCount = 5
            suggestedVisibleCount = 5
        case .failure:
            recentPlayers = []
            suggestedPlayers = []
            recentVisibleCount = 5
            suggestedVisibleCount = 5
        }
    }
}
