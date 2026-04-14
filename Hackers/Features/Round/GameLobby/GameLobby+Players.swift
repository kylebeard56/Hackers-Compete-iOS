//
//  GameLobby+Players.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI

// MARK: - Tee Group Slot Row

private struct TeeGroupSlotRow: View {
    let group: TeeTimeGroup
    let slotIndex: Int
    let player: RoundParticipant?
    let palette: DesignPalette
    let playerAvatarSize: CGFloat
    let handicapsEnabled: Bool
    let snapshot: RoundSnapshot
    let teamsEnabled: Bool
    let onAssign: (RoundParticipant, TeeTimeGroup, Int) async -> Void
    let onRemove: (RoundParticipant, TeeTimeGroup) async -> Void
    let onShowAddPlayers: () -> Void
    let onEditPlayer: (RoundParticipant) -> Void

    var body: some View {
        if let player {
            filledSlot(for: player)
        } else {
            emptySlot
        }
    }

    private func filledSlot(for participant: RoundParticipant) -> some View {
        let teamColor = teamsEnabled ? snapshot.teamColor(for: participant) : nil

        return HStack(spacing: 12) {
            Button {
                Haptics.fire(.light)
                onEditPlayer(participant)
            } label: {
                HStack(spacing: 12) {
                    PlayerAvatarView(
                        initials: participant.name.initials,
                        size: playerAvatarSize,
                        fillColor: teamColor,
                        glassTint: Color.neutral6,
                        initialsColor: teamColor != nil ? .white : palette.foregroundColor
                    )
                    .frame(width: playerAvatarSize, height: playerAvatarSize)

                    VStack(spacing: 2) {
                        Text(participant.name.fullName)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()

                        if handicapsEnabled {
                            Text("\(participant.adjustedHandicap) strokes")
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .alignLeading()
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            slotMenuButton
        }
    }

    private var emptySlot: some View {
        Button {
            Haptics.fire(.light)
            onShowAddPlayers()
        } label: {
            Text("Add players")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCardEffect(
                    cornerRadius: 12,
                    tint: palette.whiteGlassButtonColor
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 0)
        }
        .padding(.top, 4)
    }

    private var slotMenuButton: some View {
        Menu {
            if let player {
                Button {
                    Haptics.fire(.light)
                    onEditPlayer(player)
                } label: {
                    Label("Edit player", systemImage: "square.and.pencil")
                }

                Divider()

                Menu("Tee order") {
                    let playersInGroup = snapshot.participants
                        .filter { $0.groupID == group.id }
                        .sorted { ($0.teeOrder ?? 0) < ($1.teeOrder ?? 0) }
                    ForEach(0..<playersInGroup.count, id: \.self) { index in
                        Button("Position \(index + 1)") {
                            Haptics.fire(.light)
                            Task {
                                await onAssign(player, group, index)
                            }
                        }
                    }
                }

                Divider()

                ForEach(snapshot.teeGroups.filter { $0.id != group.id }.sortedForGameLobbyDisplay(), id: \.self) { otherGroup in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            let nextIndex = snapshot.participants.filter { $0.groupID == otherGroup.id }.count
                            await onAssign(player, otherGroup, nextIndex)
                        }
                    } label: {
                        if let subtitle = destinationOccupantsLabel(forGroupID: otherGroup.id) {
                            Text("Move to \(otherGroup.name)")
                            Text(subtitle)
                        } else {
                            Text("Move to \(otherGroup.name)")
                        }
                    }
                }

                Divider()
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task {
                        await onRemove(player, group)
                    }
                } label: {
                    Label("Remove from group", systemImage: "trash")
                }
            }
        } label: {
            NavButton(
                style: .glass,
                icon: "f054",
                size: 14,
                color: palette.foregroundColor,
                onTap: nil
            )
        }
        .menuStyle(.borderlessButton)
    }

    private func destinationOccupantsLabel(forGroupID groupID: String) -> String? {
        let names = snapshot.participants
            .filter { $0.groupID == groupID }
            .sorted { ($0.teeOrder ?? 0) < ($1.teeOrder ?? 0) }
            .map(firstName(for:))
            .filter(\.isPopulated)

        guard names.isPopulated else { return nil }
        let visible = names.prefix(3)
        let overflow = names.count - visible.count
        let base = visible.joined(separator: ", ")
        return overflow > 0 ? "\(base) + \(overflow)" : base
    }

    private func firstName(for participant: RoundParticipant) -> String {
        let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        if given.isPopulated { return given }

        let family = participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if family.isPopulated { return family }

        return participant.name.fullName
    }
}

// MARK: - Player Section

extension GameLobby {
    enum PlayerTab: String, CaseIterable {
        case roster = "Roster"
        case groups = "Tee Groups"
        case teams = "Teams"
        case matchups = "Matchups"

        var name: String { self.rawValue }
    }
    
    enum RosterSortOrder: String, CaseIterable {
        case abc = "ABC"
        case team = "Team"
        case tee = "Tee"
        case hcp = "HCP"
        
        var label: String { self.rawValue }
    }
    
    private var availablePlayerTabs: [PlayerTab] {
        var tabs: [PlayerTab] = [.roster, .groups]
        if teamsEnabled {
            tabs.append(.teams)
        }
        if matchupsEnabled {
            tabs.append(.matchups)
        }
        return tabs
    }
    
    var playerTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availablePlayerTabs, id: \.self) { tab in
                    let isSelected = playerTab == tab
                    Button {
                        Haptics.fire(.light)
                        playerTab = tab
                    } label: {
                        Text(tab.name)
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(isSelected ? palette.foregroundColor : Color.neutral)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .glassCardEffect(
                                shape: .capsule,
                                tint: isSelected ? palette.whiteGlassButtonColor : nil
                            )
//                            .overlay(
//                                Capsule()
//                                    .stroke(Color.accentGreen, lineWidth: isSelected ? 1.5 : 0)
//                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -16)
    }
    
    @ViewBuilder
    var playersSection: some View {
        if playerTab == .roster {
            rosterContent
                .padding(16)
                .glassCardEffect(forceMaterial: true)
        }
        
        if playerTab == .groups {
            teeGroupsContent
        }
        
        if playerTab == .teams {
            teamsContent
        }

        if playerTab == .matchups {
            matchupsContent
        }
    }

    private var isPartnershipScoreEntry: Bool {
        snapshot.configuration.scoreOwnerScope == .partnership
    }

    private var showsRoundPartnerships: Bool {
        isPartnershipScoreEntry || partnershipGroups.isPopulated
    }

    private var partnershipGroups: [RoundScoringGroup] {
        snapshot.scoringGroups
            .filter { $0.kind == .partnership }
            .sorted { lhs, rhs in
                if (lhs.teeGroupID ?? "") != (rhs.teeGroupID ?? "") {
                    return (lhs.teeGroupID ?? "") < (rhs.teeGroupID ?? "")
                }
                if (lhs.teamID ?? "") != (rhs.teamID ?? "") {
                    return (lhs.teamID ?? "") < (rhs.teamID ?? "")
                }
                return (lhs.label ?? lhs.id) < (rhs.label ?? rhs.id)
            }
    }

    private func partnershipGroup(for participantID: String) -> RoundScoringGroup? {
        partnershipGroups.first { $0.memberIDs.contains(participantID) }
    }

    private func partneredPlayers(in group: TeeTimeGroup) -> [RoundScoringGroup] {
        partnershipGroups.filter { $0.teeGroupID == group.id }
    }

    private func pairablePartners(for participant: RoundParticipant, in group: TeeTimeGroup) -> [RoundParticipant] {
        guard participant.groupID == group.id, partnershipGroup(for: participant.id) == nil else { return [] }
        return snapshot.participants
            .filter {
                $0.id != participant.id
                    && $0.groupID == group.id
                    && $0.teamID == participant.teamID
                    && partnershipGroup(for: $0.id) == nil
            }
            .sorted {
                if ($0.teeOrder ?? Int.max) != ($1.teeOrder ?? Int.max) {
                    return ($0.teeOrder ?? Int.max) < ($1.teeOrder ?? Int.max)
                }
                return $0.name.fullName < $1.name.fullName
            }
    }

    private func partnershipLabel(for group: RoundScoringGroup) -> String {
        if let label = group.label, label.isPopulated { return label }
        let members = group.memberIDs.compactMap { id in
            snapshot.participants.first(where: { $0.id == id })
        }
        return members
            .map {
                let firstName = $0.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                return firstName.isPopulated ? firstName : $0.name.fullName
            }
            .joined(separator: " + ")
    }

    private func partnershipMembers(for group: RoundScoringGroup) -> [RoundParticipant] {
        group.memberIDs.compactMap { id in
            snapshot.participants.first(where: { $0.id == id })
        }
    }

    private func partnerChainLabel(after participant: RoundParticipant, nextParticipant: RoundParticipant) -> String? {
        guard let group = partnershipGroup(for: participant.id),
              group.id == partnershipGroup(for: nextParticipant.id)?.id else { return nil }
        return partnershipLabel(for: group)
    }

    // MARK: - Roster Content
    
    var sortedRosterParticipants: [RoundParticipant] {
        let participants = snapshot.participants
        switch rosterSort {
        case .abc:
            return participants.sorted { $0.name.fullName < $1.name.fullName }
        case .team:
            return participants.sorted { a, b in
                let teamA = a.teamID ?? ""
                let teamB = b.teamID ?? ""
                if teamA != teamB { return teamA < teamB }
                if handicapsEnabled {
                    return a.adjustedHandicap < b.adjustedHandicap
                }
                return a.name.fullName < b.name.fullName
            }
        case .tee:
            return participants.sorted { a, b in
                let groupA = a.groupID ?? ""
                let groupB = b.groupID ?? ""
                if groupA != groupB { return groupA < groupB }
                return (a.teeOrder ?? Int.max) < (b.teeOrder ?? Int.max)
            }
        case .hcp:
            return participants.sorted { $0.adjustedHandicap < $1.adjustedHandicap }
        }
    }
    
    private func groupKey(for participant: RoundParticipant) -> String {
        switch rosterSort {
        case .team: return participant.teamID ?? ""
        case .tee: return participant.groupID ?? ""
        default: return ""
        }
    }
    
    private var rosterContent: some View {
        VStack(spacing: 12) {
            Text("\(snapshot.participants.count) players".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            HStack(spacing: 12) {
                Menu {
                    ForEach(RosterSortOrder.allCases, id: \.self) { order in
                        Button {
                            Haptics.fire(.light)
                            rosterSort = order
                        } label: {
                            HStack {
                                Text(order.label)
                                if rosterSort == order {
                                    Icon(name: "f00c", size: 12, weight: .solid)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Icon(name: "chevron.down", size: 11, weight: .semibold)
                            .foregroundStyle(Color.neutral3)
                        
                        Text(rosterSort.label)
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                    .whiteGlassCardShadow(color: palette.shadowColor)
                }
                
//                Text("\(snapshot.participants.count) players")
//                    .fontStyle(kFontName, size: 12, weight: .medium)
//                    .foregroundStyle(Color.neutral)
                
                Spacer(minLength: 0)
                
                if handicapsEnabled {
                    Text("Strokes")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .frame(width: 64) // 48 + 8pt padding each size for handicap field
                }
            }
            
            ForEach(Array(sortedRosterParticipants.enumerated()), id: \.element.id) { index, participant in
                let showGroupDividerBefore = (rosterSort == .team || rosterSort == .tee)
                    && index > 0
                    && groupKey(for: participant) != groupKey(for: sortedRosterParticipants[index - 1])
                let nextStartsNewGroup = index < sortedRosterParticipants.count - 1
                    && (rosterSort == .team || rosterSort == .tee)
                    && groupKey(for: sortedRosterParticipants[index + 1]) != groupKey(for: participant)
                
                if showGroupDividerBefore {
                    Divider()
                        .padding(.vertical, 8)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        Haptics.fire(.light)
                        editingPlayer = participant
                        showEditPlayerView = true
                    }) {
                        playerRow(for: participant, components: [.teeGroup, .teeTime, .defaultTee]) {
                            EmptyView()
                        }
                    }
                    .buttonStyle(.plain)

                    if handicapsEnabled {
                        let seriesLock = seriesHandicapLobbyLockActive
                        let lockedForUser = seriesLock && !isSeriesCommissioner
                        HandicapTextField(
                            id: participant.id,
                            initialValue: participant.adjustedHandicap,
                            focusedField: $focus,
                            palette: palette,
                            onDebouncedEdit: { newValue in
                                if participant.adjustedHandicap == newValue { return }
                                var updated = participant
                                if seriesLock && isSeriesCommissioner {
                                    updated.adjustedHandicap = newValue
                                } else {
                                    updated.originalHandicap = newValue
                                    updated.adjustedHandicap = newValue
                                }
                                Task { try? await roundSession.update(participant: updated) }
                            },
                            isSeriesHandicapLocked: lockedForUser,
                            leagueHandicapBaseline: lockedForUser ? nil : participant.leagueHandicapStrokesAtCreation
                        )
                    }
                }
                .id(participant.id)
                
                if index < sortedRosterParticipants.count - 1 && !nextStartsNewGroup {
                    Divider().opacity(0.25)
                }
            }
            
//            GlassButton(
//                title: "Add players",
//                icon: "2b",
//                iconWeight: .regular,
//                height: 40,
//                fillWidth: false,
//                iconSize: 15,
//                fontSize: 15,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: { showAddPlayersView = true }
//            )
        }
    }
    
    // MARK: - Tee Groups Content
    
    private var teeGroupsContent: some View {
        VStack(spacing: 16) {
            if showsRoundPartnerships {
                partnershipsOverviewCard
            }

            let unassigned = snapshot.participants.filter { $0.groupID == nil }
            if !unassigned.isEmpty {
                unassignedGroupPlayers(for: unassigned)
            }
            
            ForEach(snapshot.teeGroups.sortedForGameLobbyDisplay(), id: \.self) { group in
                teeGroupTile(for: group)
            }
            
            HStack(spacing: 12) {
                if snapshot.teeGroups.count > 0 {
                    GlassButton(
                        title: "Edit",
                        icon: "f044",
                        iconWeight: .solid,
                        height: 40,
                        fillWidth: false,
                        fontSize: 15,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: {
                            playerAssignmentSheetItem = PlayerAssignmentSheetItem(mode: .teeGroups(snapshot.teeGroups.sortedForGameLobbyDisplay()))
                        }
                    )
                }

                GlassButton(
                    title: "Add tee group",
                    icon: "2b",
                    iconWeight: .regular,
                    height: 40,
                    fontSize: 15,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        Task {
                            try? await roundSession.createTeeGroup()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Teams Content
    
    private var teamsContent: some View {
        let isLocked = snapshot.isSharedScoreSource

        return VStack(spacing: 16) {
            if showsRoundPartnerships {
                partnershipsOverviewCard
            }

            if isLocked {
                sharedScoreTeamsBanner
            } else if showTeamShortcuts {
                teamShortcutsBanner
            }

            if !isLocked {
                let unassigned = snapshot.participants.filter { $0.teamID == nil }
                if !unassigned.isEmpty && !snapshot.teams.isEmpty {
                    unassignedTeamPlayers(for: unassigned)
                }
            }
            
            ForEach(snapshot.teams.sortedForGameLobbyDisplay(), id: \.self) { team in
                teamTile(for: team, readOnly: isLocked)
            }
            
            if !isLocked {
                HStack(spacing: 12) {
                    if snapshot.teams.count > 0 {
                        GlassButton(
                            title: "Edit",
                            icon: "f044",
                            iconWeight: .solid,
                            height: 40,
                            fillWidth: false,
                            fontSize: 15,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: {
                                playerAssignmentSheetItem = PlayerAssignmentSheetItem(mode: .teams(snapshot.teams.sortedForGameLobbyDisplay()))
                            }
                        )
                    }

                    let maxLobbyTeams = snapshot.configuration.usesTeamColors
                        ? TeamColor.cycle.count
                        : max(snapshot.participants.count, 2)
                    if snapshot.teams.count < maxLobbyTeams {
                        GlassButton(
                            title: "Add team",
                            icon: "2b",
                            iconWeight: .regular,
                            height: 40,
                            fontSize: 15,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: {
                                Task {
                                    try? await roundSession.createTeam()
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var sharedScoreTeamsBanner: some View {
        HStack(spacing: 12) {
            Icon(name: "f05a", size: 16, weight: .solid)
                .foregroundStyle(Color.neutral)
            Text("Team roster is set to match tee groups")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(forceMaterial: true)
    }

    private var showTeamShortcuts: Bool {
        teamsEnabled
            && snapshot.teams.isEmpty
            && snapshot.participants.count >= 2
    }

    private var showMapTeeGroupsShortcut: Bool {
        showTeamShortcuts && snapshot.teeGroups.isPopulated
    }

    @ViewBuilder
    private var partnershipsOverviewCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Icon(name: "link", size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Round partnerships")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text("\(partnershipGroups.count) pairs saved for this round")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
            }

            Text("Partnerships stay round-local, must share a tee group and team, and can organize the lobby even when score entry is still individual.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .alignLeading()

            HStack(spacing: 8) {
                if let seriesID = appSession.activeSeriesID, seriesID.isPopulated {
                    Button {
                        Haptics.fire(.light)
                        Task { await roundSession.seedPartnershipsFromSeriesPods(seriesID: seriesID) }
                    } label: {
                        Chip(
                            text: "Seed fixed pairs",
                            size: .small,
                            foreground: palette.foregroundColor,
                            background: palette.whiteGlassButtonColor
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Haptics.fire(.light)
                    Task { await roundSession.autoPairPartnershipsByTeeOrder() }
                } label: {
                    Chip(
                        text: "Auto-pair",
                        size: .small,
                        foreground: palette.foregroundColor,
                        background: palette.whiteGlassButtonColor
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.fire(.light)
                    Task { await roundSession.clearPartnerships() }
                } label: {
                    Chip(
                        text: "Clear pairs",
                        size: .small,
                        foreground: .white,
                        background: Color.red
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    @ViewBuilder
    private var teamShortcutsBanner: some View {
        Menu {
            if showMapTeeGroupsShortcut {
                Button {
                    Haptics.fire(.light)
                    Task {
                        try? await roundSession.mapTeeGroupsToTeams()
                    }
                } label: {
                    Label("Mirror tee groups", systemImage: "rectangle.on.rectangle.angled")
                    Text("Copy tee group structure to teams")
                }
            }

            Button {
                Haptics.fire(.light)
                Task {
                    try? await roundSession.randomizeTeams(count: 2)
                }
            } label: {
                Label("Randomize", systemImage: "shuffle")
                Text("Randomly split into 2 teams")
            }

            Button {
                Haptics.fire(.light)
                Task {
                    try? await roundSession.balanceTeams(count: 2)
                }
            } label: {
                Label("Balance", systemImage: "scale.3d")
                Text("Split by handicap for fair teams")
            }
        } label: {
            HStack(spacing: 12) {
                Icon(name: "f0ec", size: 16, weight: .solid)
                    .foregroundStyle(palette.foregroundColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick setup")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("Mirror, randomize, or balance teams")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)
                Icon(name: "chevron.down", size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral3)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Matchups Content

    private var currentMatchupMode: MatchupMode {
        snapshot.configuration.scoreOwnerScope == .individual
            ? (teamsEnabled ? .team : .individual)
            : .scoreOwner
    }

    /// Matchups for the current mode, used for display and editing.
    private var matchupsForCurrentMode: [TeamMatchup] {
        let all = snapshot.roundSegment?.matchups ?? []
        return all.filter { ($0.mode ?? .team) == currentMatchupMode }
    }

    private var displayMatchups: [(matchup: TeamMatchup, isPlaceholder: Bool)] {
        let persisted = matchupsForCurrentMode
        let ownerCount = currentMatchupOwnerCount
        let minMatchups = max(1, (ownerCount + 1) / 2)
        let maxMatchups = max(1, ownerCount / 2)
        var result: [(TeamMatchup, Bool)] = persisted.map { ($0, false) }
        for i in result.count..<max(result.count, minMatchups) {
            result.append((emptyMatchup(index: i), true))
        }
        return Array(result.prefix(maxMatchups))
    }

    private var currentMatchupOwnerCount: Int {
        switch currentMatchupMode {
        case .team:
            return snapshot.teams.count
        case .individual:
            return snapshot.participants.count
        case .scoreOwner:
            return snapshot.scoringGroups.count
        }
    }

    private func emptyMatchup(index: Int) -> TeamMatchup {
        TeamMatchup(
            id: "placeholder-\(index)",
            teamIDs: [],
            participantIDs: currentMatchupMode == .individual ? [] : nil,
            scoreOwnerIDs: currentMatchupMode == .scoreOwner ? [] : nil,
            scoreOwnerScope: currentMatchupMode == .scoreOwner ? snapshot.configuration.scoreOwnerScope : nil,
            mode: currentMatchupMode
        )
    }

    private func availableTeamsForMatchupSlot(matchupIndex: Int, slotIndex: Int) -> [RoundTeam] {
        let matchups = matchupsForCurrentMode
        let usedTeamIDs = Set(matchups.flatMap(\.teamIDs))
        let currentMatchup = matchups[safe: matchupIndex]
        let otherSlotTeamID = currentMatchup.flatMap { m in
            m.teamIDs.count > 1 - slotIndex ? m.teamIDs[1 - slotIndex] : nil
        }
        let currentSlotTeamID = currentMatchup.flatMap { m in
            m.teamIDs.count > slotIndex ? m.teamIDs[slotIndex] : nil
        }
        return snapshot.teams.filter { team in
            let usedElsewhere = usedTeamIDs.contains(team.id) && team.id != currentSlotTeamID
            let isSelfCompetition = team.id == otherSlotTeamID
            return !usedElsewhere && !isSelfCompetition
        }
    }

    private func availableParticipantsForMatchupSlot(matchupIndex: Int, slotIndex: Int) -> [RoundParticipant] {
        let matchups = matchupsForCurrentMode
        let usedParticipantIDs = Set(matchups.flatMap { $0.participantIDs ?? [] })
        let currentMatchup = matchups[safe: matchupIndex]
        let otherSlotParticipantID = currentMatchup.flatMap { m in
            let ids = m.participantIDs ?? []
            return ids.count > 1 - slotIndex ? ids[1 - slotIndex] : nil
        }
        let currentSlotParticipantID = currentMatchup.flatMap { m in
            let ids = m.participantIDs ?? []
            return ids.count > slotIndex ? ids[slotIndex] : nil
        }
        return snapshot.participants.filter { p in
            let usedElsewhere = usedParticipantIDs.contains(p.id) && p.id != currentSlotParticipantID
            let isSelfCompetition = p.id == otherSlotParticipantID
            return !usedElsewhere && !isSelfCompetition
        }
    }

    private func availableScoreOwnersForMatchupSlot(matchupIndex: Int, slotIndex: Int) -> [RoundScoringGroup] {
        let matchups = matchupsForCurrentMode
        let usedScoreOwnerIDs = Set(matchups.flatMap { $0.scoreOwnerIDs ?? [] })
        let currentMatchup = matchups[safe: matchupIndex]
        let otherSlotScoreOwnerID = currentMatchup.flatMap { matchup in
            let ids = matchup.scoreOwnerIDs ?? []
            return ids.count > 1 - slotIndex ? ids[1 - slotIndex] : nil
        }
        let currentSlotScoreOwnerID = currentMatchup.flatMap { matchup in
            let ids = matchup.scoreOwnerIDs ?? []
            return ids.count > slotIndex ? ids[slotIndex] : nil
        }

        return snapshot.scoringGroups.filter { group in
            let usedElsewhere = usedScoreOwnerIDs.contains(group.id) && group.id != currentSlotScoreOwnerID
            let isSelfCompetition = group.id == otherSlotScoreOwnerID
            return !usedElsewhere && !isSelfCompetition
        }
    }

    private var matchupsContent: some View {
        let items = displayMatchups

        return VStack(spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                MatchupCardView(
                    matchup: item.matchup,
                    matchIndex: index,
                    snapshot: snapshot,
                    slotMode: currentMatchupMode,
                    availableTeamsForSlot0: availableTeamsForMatchupSlot(matchupIndex: index, slotIndex: 0),
                    availableTeamsForSlot1: availableTeamsForMatchupSlot(matchupIndex: index, slotIndex: 1),
                    availableParticipantsForSlot0: availableParticipantsForMatchupSlot(matchupIndex: index, slotIndex: 0),
                    availableParticipantsForSlot1: availableParticipantsForMatchupSlot(matchupIndex: index, slotIndex: 1),
                    availableScoreOwnersForSlot0: availableScoreOwnersForMatchupSlot(matchupIndex: index, slotIndex: 0),
                    availableScoreOwnersForSlot1: availableScoreOwnersForMatchupSlot(matchupIndex: index, slotIndex: 1),
                    onAssignTeam: { slotIndex, teamID in
                        assignTeamToMatchupSlot(matchupIndex: index, slotIndex: slotIndex, teamID: teamID)
                    },
                    onAssignParticipant: { slotIndex, participantID in
                        assignParticipantToMatchupSlot(matchupIndex: index, slotIndex: slotIndex, participantID: participantID)
                    },
                    onAssignScoreOwner: { slotIndex, scoreOwnerID in
                        assignScoreOwnerToMatchupSlot(matchupIndex: index, slotIndex: slotIndex, scoreOwnerID: scoreOwnerID)
                    },
                    onSwapTeams: (currentMatchupMode == .team && item.matchup.teamIDs.count == 2) ? { swapMatchupTeams(matchupIndex: index) } : nil,
                    onSwapParticipants: (currentMatchupMode == .individual && (item.matchup.participantIDs?.count ?? 0) == 2) ? { swapMatchupParticipants(matchupIndex: index) } : nil,
                    onSwapScoreOwners: (currentMatchupMode == .scoreOwner && (item.matchup.scoreOwnerIDs?.count ?? 0) == 2) ? { swapMatchupScoreOwners(matchupIndex: index) } : nil
                )
            }

            GlassButton(
                title: "Add matchup",
                icon: "2b",
                iconWeight: .regular,
                height: 40,
                fontSize: 15,
                isDisabled: .constant(!canAddMatchup),
                isLoading: .false,
                onTap: { addMatchup() }
            )
        }
    }

    private var canAddMatchup: Bool {
        let count = currentMatchupOwnerCount
        guard count >= 2 else { return false }
        let matchups = matchupsForCurrentMode
        let maxMatchups = count / 2
        return matchups.count < max(1, maxMatchups)
    }

    /// Persists matchups, merging current-mode matchups with the other mode's preserved matchups.
    private func persistMatchups(_ currentModeMatchups: [TeamMatchup]) {
        let all = snapshot.roundSegment?.matchups ?? []
        let otherMode = all.filter { ($0.mode ?? .team) != currentMatchupMode }
        let merged = otherMode + currentModeMatchups
        Task { await roundSession.setMatchups(merged) }
    }

    private func addMatchup() {
        guard canAddMatchup else { return }
        var matchups = matchupsForCurrentMode
        matchups.append(TeamMatchup(
            id: HackersID.string(),
            teamIDs: currentMatchupMode == .team ? [] : [],
            participantIDs: currentMatchupMode == .individual ? [] : nil,
            scoreOwnerIDs: currentMatchupMode == .scoreOwner ? [] : nil,
            scoreOwnerScope: currentMatchupMode == .scoreOwner ? snapshot.configuration.scoreOwnerScope : nil,
            mode: currentMatchupMode
        ))
        persistMatchups(matchups)
    }

    private func swapMatchupTeams(matchupIndex: Int) {
        var matchups = matchupsForCurrentMode
        guard let m = matchups[safe: matchupIndex], m.teamIDs.count == 2 else { return }
        matchups[matchupIndex] = TeamMatchup(id: m.id, teamIDs: [m.teamIDs[1], m.teamIDs[0]], participantIDs: m.participantIDs, mode: .team)
        persistMatchups(matchups)
    }

    private func swapMatchupParticipants(matchupIndex: Int) {
        var matchups = matchupsForCurrentMode
        guard let m = matchups[safe: matchupIndex], let ids = m.participantIDs, ids.count == 2 else { return }
        matchups[matchupIndex] = TeamMatchup(id: m.id, teamIDs: [], participantIDs: [ids[1], ids[0]], mode: .individual)
        persistMatchups(matchups)
    }

    private func swapMatchupScoreOwners(matchupIndex: Int) {
        var matchups = matchupsForCurrentMode
        guard let matchup = matchups[safe: matchupIndex],
              let ids = matchup.scoreOwnerIDs,
              ids.count == 2 else { return }
        matchups[matchupIndex] = TeamMatchup(
            id: matchup.id,
            teamIDs: [],
            participantIDs: nil,
            scoreOwnerIDs: [ids[1], ids[0]],
            scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
            mode: .scoreOwner
        )
        persistMatchups(matchups)
    }

    private func assignTeamToMatchupSlot(matchupIndex: Int, slotIndex: Int, teamID: String?) {
        var matchups = matchupsForCurrentMode
        while matchups.count <= matchupIndex {
            matchups.append(TeamMatchup(id: HackersID.string(), teamIDs: [], mode: .team))
        }
        var teamIDs = matchups[matchupIndex].teamIDs
        while teamIDs.count <= slotIndex {
            teamIDs.append("")
        }
        teamIDs[slotIndex] = teamID ?? ""
        matchups[matchupIndex] = TeamMatchup(
            id: matchups[matchupIndex].id,
            teamIDs: teamIDs.filter(\.isPopulated),
            participantIDs: nil,
            mode: .team
        )
        persistMatchups(matchups)
    }

    private func assignParticipantToMatchupSlot(matchupIndex: Int, slotIndex: Int, participantID: String?) {
        var matchups = matchupsForCurrentMode
        while matchups.count <= matchupIndex {
            matchups.append(TeamMatchup(id: HackersID.string(), teamIDs: [], participantIDs: [], mode: .individual))
        }
        var participantIDs = matchups[matchupIndex].participantIDs ?? []
        while participantIDs.count <= slotIndex {
            participantIDs.append("")
        }
        participantIDs[slotIndex] = participantID ?? ""
        matchups[matchupIndex] = TeamMatchup(
            id: matchups[matchupIndex].id,
            teamIDs: [],
            participantIDs: participantIDs.filter(\.isPopulated),
            mode: .individual
        )
        persistMatchups(matchups)
    }

    private func assignScoreOwnerToMatchupSlot(matchupIndex: Int, slotIndex: Int, scoreOwnerID: String?) {
        var matchups = matchupsForCurrentMode
        while matchups.count <= matchupIndex {
            matchups.append(
                TeamMatchup(
                    id: HackersID.string(),
                    teamIDs: [],
                    participantIDs: nil,
                    scoreOwnerIDs: [],
                    scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
                    mode: .scoreOwner
                )
            )
        }
        var scoreOwnerIDs = matchups[matchupIndex].scoreOwnerIDs ?? []
        while scoreOwnerIDs.count <= slotIndex {
            scoreOwnerIDs.append("")
        }
        scoreOwnerIDs[slotIndex] = scoreOwnerID ?? ""
        matchups[matchupIndex] = TeamMatchup(
            id: matchups[matchupIndex].id,
            teamIDs: [],
            participantIDs: nil,
            scoreOwnerIDs: scoreOwnerIDs.filter(\.isPopulated),
            scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
            mode: .scoreOwner
        )
        persistMatchups(matchups)
    }
}
    
// MARK: - Player Row
    
extension GameLobby {
    enum PlayerSubtitleComponent {
        case defaultTee, teeGroup, teeTime, handicap, team
    }
    
    struct SubtitleItem: Identifiable {
        let id = UUID()
        let view: AnyView
    }
    
    private func subtitleItems(
        participant: RoundParticipant,
        components: [PlayerSubtitleComponent]
    ) -> [SubtitleItem] {
        var items: [SubtitleItem] = []

        if handicapsEnabled, components.contains(.handicap) {
            items.append(
                SubtitleItem(
                    view: AnyView(
                        Text("\(participant.adjustedHandicap) strokes")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    )
                )
            )
        }

        if let group = snapshot.teeGroups.first(where: { $0.id == participant.groupID }) {
            if let teeTime = group.teeTime, components.contains(.teeTime) {
                items.append(
                    SubtitleItem(
                        view: AnyView(
                            Text(teeTime.formattedTeeTime)
                                .fontStyle(kFontName, size: 13)
                                .foregroundStyle(Color.neutral)
                        )
                    )
                )
            }

            if components.contains(.teeGroup) {
                items.append(
                    SubtitleItem(
                        view: AnyView(
                            Text(group.name)
                                .fontStyle(kFontName, size: 13)
                                .foregroundStyle(Color.neutral)
                        )
                    )
                )
            }
        }
        
        if let defaultTee = snapshot.defaultTee,
           participant.teeBoxID != defaultTee.id,
           components.contains(.defaultTee),
           let participantTee = snapshot.tees.first(where: { $0.id == participant.teeBoxID }) {
            items.append(
                SubtitleItem(
                    view: AnyView(
                        Text("\(participantTee.name) tees")
                            .fontStyle(kFontName, size: 13)
                            .foregroundStyle(Color.neutral)
                    )
                )
            )
        }

        if let team = snapshot.teams.first(where: { $0.id == participant.teamID }),
           components.contains(.team) {
            items.append(
                SubtitleItem(
                    view: AnyView(
                        Text(team.name)
                            .fontStyle(kFontName, size: 13)
                            .foregroundStyle(Color.neutral)
                    )
                )
            )
        }

        return items
    }

    @ViewBuilder
    fileprivate func playerRow<Content: View>(
        for participant: RoundParticipant,
        tint: Color? = nil,
        team: RoundTeam? = nil,
        components: [PlayerSubtitleComponent] = [],
        badgeIcon: String? = nil,
        @ViewBuilder callToAction: () -> Content = { EmptyView() }
    ) -> some View {
        let teamColor: Color? = teamsEnabled ? snapshot.teamColor(for: participant) : nil
        let circleTint: Color = tint ?? palette.glassButtonColor

        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: participant.name.initials,
                size: playerAvatarSize,
                fillColor: teamColor,
                glassTint: circleTint,
                badgeIcon: badgeIcon,
                badgeIconColor: Color.neutral,
                badgeBackgroundColor: Color.clear,//accentGreen.opacity(0.25),
                initialsColor: teamColor != nil ? .white : nil
            )
            .frame(width: playerAvatarSize, height: playerAvatarSize)
            
            VStack(spacing: 2) {
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                if components.isPopulated {
                    let items = subtitleItems(participant: participant, components: components)

                    HStack(spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Circle()
                                    .fill(Color.neutral)
                                    .frame(width: 3, height: 3)
                            }

                            item.view
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            callToAction()
        }
    }
    
}

// MARK: - Tee Groups

extension GameLobby {
    @ViewBuilder
    fileprivate func teeGroupTile(for group: TeeTimeGroup) -> some View {
        let players = snapshot.participants
            .filter { $0.groupID == group.id }
            .sorted { ($0.teeOrder ?? 0) < ($1.teeOrder ?? 0) }

        let totalHCP = players.reduce(0) { $0 + $1.adjustedHandicap }
        
        VStack(spacing: 12) {
            header(for: group, totalHCP: totalHCP)
            
            Line()
            
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                teeGroupSlotRow(
                    group: group,
                    slotIndex: index,
                    player: player
                )

                if let nextPlayer = players[safe: index + 1],
                   let label = partnerChainLabel(after: player, nextParticipant: nextPlayer) {
                    partnershipLinkIndicator(label: label)
                }
            }

            if isPartnershipScoreEntry {
                teeGroupPartnershipEditor(for: group, players: players)
            }
            
            teeGroupSlotRow(
                group: group,
                slotIndex: players.count,
                player: nil
            )
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    @ViewBuilder
    private func teeGroupSlotRow(
        group: TeeTimeGroup,
        slotIndex: Int,
        player: RoundParticipant?
    ) -> some View {
        TeeGroupSlotRow(
            group: group,
            slotIndex: slotIndex,
            player: player,
            palette: palette,
            playerAvatarSize: playerAvatarSize,
            handicapsEnabled: handicapsEnabled,
            snapshot: snapshot,
            teamsEnabled: teamsEnabled,
            onAssign: assign(player:to:at:),
            onRemove: remove(player:from:),
            onShowAddPlayers: { showAddPlayersView = true },
            onEditPlayer: { editingPlayer = $0 }
        )
    }
    
    @ViewBuilder
    private func header(for group: TeeTimeGroup, totalHCP: Int) -> some View {
        let startingHoleLabel = group.startingHoleDisplayLabel(in: snapshot.teeGroups)

        HStack(spacing: 24) {
            Menu {
                Button {
                    Haptics.fire(.light)
                    print("show tee group modification view")
                } label: {
                    Label("Modify group", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task { try? await roundSession.removeTeeGroup(group) }
                } label: {
                    Label("Remove tee group", systemImage: "trash")
                }
            } label: {
                VStack(spacing: 2) {
                    Text(group.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    if handicapsEnabled {
                        Text("\(totalHCP) total strokes")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(.neutral)
                            .alignLeading()
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 2))
            }
            
            Spacer()
            
            // Starting hole
            Menu {
                let start = snapshot.holeRange?.startHole ?? 1
                let end = snapshot.holeRange?.endHole ?? 18
                
                ForEach(start...end, id: \.self) { hole in
                    Button("Hole \(hole)") {
                        Haptics.fire(.light)
                        Task {
                            var g = group
                            g.startingHole = hole
                            try? await roundSession.update(g)
                        }
                    }
                }
            } label: {
                StackedSubtitle(
                    value: startingHoleLabel,
                    label: "start on",
                    size: 15
                )
            }
            
            // Tee time
            Button {
                Haptics.fire(.light)
                editingTeeGroup = group
                showTeeTimePicker = true
            } label: {
                StackedSubtitle(
                    value: group.teeTime.map { $0.formattedTeeTime } ?? "-",
                    label: "tee time",
                    size: 15
                )
            }
        }
    }

    @ViewBuilder
    private func teeGroupPartnershipEditor(for group: TeeTimeGroup, players: [RoundParticipant]) -> some View {
        let partnerships = partneredPlayers(in: group)
        let unpairedPlayers = players.filter { partnershipGroup(for: $0.id) == nil }

        VStack(spacing: 10) {
            if partnerships.isPopulated {
                ForEach(partnerships, id: \.id) { partnership in
                    let members = partnershipMembers(for: partnership)
                    HStack(spacing: 10) {
                        Icon(name: "link", size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(partnershipLabel(for: partnership))
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)

                            Text(members.map(\.name.fullName).joined(separator: ", "))
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Button {
                            Haptics.fire(.light)
                            Task { await roundSession.removePartnership(groupID: partnership.id) }
                        } label: {
                            Chip(
                                text: "Unpair",
                                size: .small,
                                foreground: palette.foregroundColor,
                                background: palette.whiteGlassButtonColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.neutral6.opacity(0.28))
                    )
                }
            }

            ForEach(unpairedPlayers, id: \.id) { player in
                let partners = pairablePartners(for: player, in: group)
                if partners.isPopulated {
                    Menu {
                        ForEach(partners, id: \.id) { partner in
                            Button(partner.name.fullName) {
                                Haptics.fire(.light)
                                Task {
                                    await roundSession.createOrReplacePartnership(
                                        memberIDs: [player.id, partner.id]
                                    )
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Icon(name: "link", size: 12, weight: .semibold)
                                .foregroundStyle(Color.neutral)
                            Text("Pair \(player.name.fullName)")
                                .fontStyle(kFontName, size: 13, weight: .medium)
                                .foregroundStyle(palette.foregroundColor)
                            Spacer(minLength: 0)
                            Text("Choose partner")
                                .fontStyle(kFontName, size: 12, weight: .medium)
                                .foregroundStyle(Color.neutral)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(palette.borderColor, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if partnerships.isEmpty && unpairedPlayers.count < 2 {
                Text("Add teammates to this tee group to create a partnership.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }
        }
    }

    @ViewBuilder
    private func partnershipLinkIndicator(label: String) -> some View {
        HStack(spacing: 10) {
            Line()
                .frame(height: 1)
            HStack(spacing: 6) {
                Icon(name: "link", size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                Text(label)
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral)
            }
            Line()
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private func unassignedGroupPlayers(for players: [RoundParticipant]) -> some View {
        VStack(spacing: 12) {
            Button {
                Haptics.fire(.light)
                expandUnassignedPlayersGroup.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text("Player to assign")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(.neutral)
                    
                    Spacer()
                    
                    Text("\(players.count) left")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(.neutral)
                    
                    Icon(name: "chevron.\(expandUnassignedPlayersGroup ? "down" : "right")", size: 13, weight: .solid)
                        .foregroundStyle(.neutral3)
                }
            }
            
            if expandUnassignedPlayersGroup {
                ForEach(players, id: \.self) { player in
                    Menu {
                        ForEach(snapshot.teeGroups.sortedForGameLobbyDisplay(), id: \.self) { group in
                            Button(group.name) {
                                Haptics.fire(.light)
                                Task {
                                    let index = snapshot.participants.filter { $0.groupID == group.id }.count
                                    await assign(player: player, to: group, at: index)
                                }
                            }
                        }
                    } label: {
                        playerRow(for: player, tint: .neutral6, components: [.handicap, .defaultTee])
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }
    
    private func assign(
        player: RoundParticipant,
        to group: TeeTimeGroup,
        at slotIndex: Int
    ) async {
        let currentPlayers = snapshot.participants
            .filter { $0.groupID == group.id && $0.id != player.id }
            .sorted { ($0.teeOrder ?? 0) < ($1.teeOrder ?? 0) }

        var ordered = currentPlayers.map { $0.id }
        let clampedIndex = min(slotIndex, ordered.count)
        ordered.insert(player.id, at: clampedIndex)

        var p = player
        p.groupID = group.id
        p.teeOrder = clampedIndex
        try? await roundSession.update(participant: p)

        for (index, participantID) in ordered.enumerated() where participantID != player.id {
            guard let participant = snapshot.participants.first(where: { $0.id == participantID }),
                  participant.teeOrder != index
            else { continue }
            var updated = participant
            updated.teeOrder = index
            try? await roundSession.update(participant: updated)
        }
    }

    private func remove(player: RoundParticipant, from group: TeeTimeGroup) async {
        var p = player
        p.groupID = nil
        p.teeOrder = nil
        try? await roundSession.update(participant: p)
        await normalizeOrders(in: group)
    }
    
    private func normalizeOrders(in group: TeeTimeGroup) async {
        let players = snapshot.participants
            .filter { $0.groupID == group.id }
            .sorted { ($0.teeOrder ?? 0) < ($1.teeOrder ?? 0) }

        for (index, player) in players.enumerated() {
            if player.teeOrder != index {
                var p = player
                p.teeOrder = index
                try? await roundSession.update(participant: p)
            }
        }
    }
}

// MARK: - Team Slot Row

private struct TeamSlotRow: View {
    let team: RoundTeam
    let player: RoundParticipant?
    let palette: DesignPalette
    let playerAvatarSize: CGFloat
    let handicapsEnabled: Bool
    let snapshot: RoundSnapshot
    let teamsEnabled: Bool
    var readOnly: Bool = false
    let onAssign: (RoundParticipant, RoundTeam) async -> Void
    let onRemove: (RoundParticipant, RoundTeam) async -> Void
    let onShowAddPlayers: () -> Void
    let onEditPlayer: (RoundParticipant) -> Void

    var body: some View {
        if let player {
            filledSlot(for: player)
        } else if !readOnly {
            emptySlot
        }
    }

    private func filledSlot(for participant: RoundParticipant) -> some View {
        let teamColor = teamsEnabled ? snapshot.teamColor(for: participant) : nil

        return HStack(spacing: 12) {
            Button {
                Haptics.fire(.light)
                if !readOnly { onEditPlayer(participant) }
            } label: {
                HStack(spacing: 12) {
                    PlayerAvatarView(
                        initials: participant.name.initials,
                        size: playerAvatarSize,
                        fillColor: teamColor,
                        glassTint: .neutral6,
                        initialsColor: teamColor != nil ? .white : nil
                    )
                    .frame(width: playerAvatarSize, height: playerAvatarSize)

                    VStack(spacing: 2) {
                        Text(participant.name.fullName)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()

                        if handicapsEnabled {
                            Text("\(participant.adjustedHandicap) strokes")
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .alignLeading()
                        }

                        if !readOnly, let group = snapshot.teeGroups.first(where: { $0.id == participant.groupID }) {
                            Text(group.name)
                                .fontStyle(kFontName, size: 13)
                                .foregroundStyle(Color.neutral)
                                .alignLeading()
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if !readOnly {
                slotMenuButton
            }
        }
    }

    private var emptySlot: some View {
        Button {
            Haptics.fire(.light)
            onShowAddPlayers()
        } label: {
            Text("Add players")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCardEffect(
                    cornerRadius: 12,
                    tint: palette.whiteGlassButtonColor
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 0)
        }
        .padding(.top, 4)
    }

    private var slotMenuButton: some View {
        Menu {
            if let player {
                Button {
                    Haptics.fire(.light)
                    onEditPlayer(player)
                } label: {
                    Label("Edit player", systemImage: "square.and.pencil")
                }

                Divider()

                ForEach(snapshot.teams.filter { $0.id != team.id }.sortedForGameLobbyDisplay(), id: \.self) { otherTeam in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            await onAssign(player, otherTeam)
                        }
                    } label: {
                        if let subtitle = destinationOccupantsLabel(forTeamID: otherTeam.id) {
                            Text("Move to \(otherTeam.name)")
                            Text(subtitle)
                        } else {
                            Text("Move to \(otherTeam.name)")
                        }
                    }
                }

                Divider()
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task {
                        await onRemove(player, team)
                    }
                } label: {
                    Label("Remove from team", systemImage: "trash")
                }
            }
        } label: {
            NavButton(
                style: .glass,
                icon: "f054",
                size: 14,
                color: palette.foregroundColor,
                onTap: nil
            )
        }
        .menuStyle(.borderlessButton)
    }

    private func destinationOccupantsLabel(forTeamID teamID: String) -> String? {
        let names = snapshot.participants
            .filter { $0.teamID == teamID }
            .sorted { $0.name.fullName < $1.name.fullName }
            .map(firstName(for:))
            .filter(\.isPopulated)

        guard names.isPopulated else { return nil }
        let visible = names.prefix(3)
        let overflow = names.count - visible.count
        let base = visible.joined(separator: ", ")
        return overflow > 0 ? "\(base) + \(overflow)" : base
    }

    private func firstName(for participant: RoundParticipant) -> String {
        let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        if given.isPopulated { return given }

        let family = participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if family.isPopulated { return family }

        return participant.name.fullName
    }
}

// MARK: - Teams

extension GameLobby {
    @ViewBuilder
    private func teamTile(for team: RoundTeam, readOnly: Bool = false) -> some View {
        let players = teamPlayers(for: team)

        let totalHCP = players.reduce(0) { $0 + $1.adjustedHandicap }
        let showTeamHandicap = readOnly && handicapsEnabled

        VStack(spacing: 12) {
            teamHeader(for: team, totalHCP: totalHCP, readOnly: readOnly, showTeamHandicap: showTeamHandicap)

            Line()

            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                let showHandicap = readOnly ? (index == 0 && handicapsEnabled) : handicapsEnabled
                TeamSlotRow(
                    team: team,
                    player: player,
                    palette: palette,
                    playerAvatarSize: playerAvatarSize,
                    handicapsEnabled: showHandicap,
                    snapshot: snapshot,
                    teamsEnabled: teamsEnabled,
                    readOnly: readOnly,
                    onAssign: assign(player:to:),
                    onRemove: remove(player:from:),
                    onShowAddPlayers: { showAddPlayersView = true },
                    onEditPlayer: { editingPlayer = $0 }
                )

                if let nextPlayer = players[safe: index + 1],
                   let label = partnerChainLabel(after: player, nextParticipant: nextPlayer) {
                    partnershipLinkIndicator(label: label)
                }
            }

            if !readOnly {
                TeamSlotRow(
                    team: team,
                    player: nil,
                    palette: palette,
                    playerAvatarSize: playerAvatarSize,
                    handicapsEnabled: handicapsEnabled,
                    snapshot: snapshot,
                    teamsEnabled: teamsEnabled,
                    readOnly: false,
                    onAssign: assign(player:to:),
                    onRemove: remove(player:from:),
                    onShowAddPlayers: { showAddPlayersView = true },
                    onEditPlayer: { _ in }
                )
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    private func teamPlayers(for team: RoundTeam) -> [RoundParticipant] {
        let members = snapshot.participants.filter { $0.teamID == team.id }
        guard isPartnershipScoreEntry else {
            return members.sorted { $0.name.fullName < $1.name.fullName }
        }

        return members.sorted { lhs, rhs in
            let lhsGroup = lhs.groupID ?? ""
            let rhsGroup = rhs.groupID ?? ""
            if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

            let lhsPair = partnershipGroup(for: lhs.id)?.id ?? lhs.id
            let rhsPair = partnershipGroup(for: rhs.id)?.id ?? rhs.id
            if lhsPair != rhsPair { return lhsPair < rhsPair }

            if (lhs.teeOrder ?? Int.max) != (rhs.teeOrder ?? Int.max) {
                return (lhs.teeOrder ?? Int.max) < (rhs.teeOrder ?? Int.max)
            }
            return lhs.name.fullName < rhs.name.fullName
        }
    }

    private func teamHeaderNameColor(for team: RoundTeam) -> Color {
        if snapshot.configuration.usesTeamColors, let c = team.displaySwatchColor { return c }
        return palette.foregroundColor
    }

    @ViewBuilder
    private func teamHeader(for team: RoundTeam, totalHCP: Int, readOnly: Bool = false, showTeamHandicap: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button {
                    guard !readOnly else { return }
                    Haptics.fire(.light)
                    teamRenameDraft = team.name
                    teamRenameTarget = team
                } label: {
                    Text(team.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(teamHeaderNameColor(for: team))
                        .alignLeading()
                }
                .buttonStyle(.plain)
                .disabled(readOnly)

                if showTeamHandicap {
                    Text("Team HCP")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(.neutral)
                        .alignLeading()
                } else if handicapsEnabled {
                    Text("\(totalHCP) total strokes")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(.neutral)
                        .alignLeading()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !readOnly {
                Menu {
                    Button(role: .destructive) {
                        Haptics.fire(.light)
                        Task { try? await roundSession.removeTeam(team) }
                    } label: {
                        Label("Delete team", systemImage: "trash")
                    }
                } label: {
                    NavButton(
                        style: .glass,
                        icon: "f141",
                        size: 14,
                        color: palette.foregroundColor,
                        onTap: nil
                    )
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    @ViewBuilder
    private func unassignedTeamPlayers(for players: [RoundParticipant]) -> some View {
        VStack(spacing: 12) {
            Button {
                Haptics.fire(.light)
                expandUnassignedPlayersTeam.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text("Players to assign")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(.neutral)
                    
                    Spacer()
                    
                    Text("\(players.count) left")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(.neutral)
                    
                    Icon(name: "chevron.\(expandUnassignedPlayersTeam ? "down" : "right")", size: 13, weight: .solid)
                        .foregroundStyle(.neutral3)
                }
            }

            if expandUnassignedPlayersTeam {
                ForEach(players, id: \.self) { player in
                    Menu {
                        ForEach(snapshot.teams.sortedForGameLobbyDisplay(), id: \.self) { team in
                            Button(team.name) {
                                Haptics.fire(.light)
                                Task {
                                    await assign(player: player, to: team)
                                }
                            }
                        }
                    } label: {
                        playerRow(for: player, tint: .neutral6, components: [.handicap, .defaultTee])
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(forceMaterial: true)
    }

    private func assign(player: RoundParticipant, to team: RoundTeam) async {
        var p = player
        p.teamID = team.id
        try? await roundSession.update(participant: p)
    }

    private func remove(player: RoundParticipant, from team: RoundTeam) async {
        var p = player
        p.teamID = nil
        try? await roundSession.update(participant: p)
    }
}
