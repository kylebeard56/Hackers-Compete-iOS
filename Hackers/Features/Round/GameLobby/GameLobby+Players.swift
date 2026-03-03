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
                        badgeIcon: "\(slotIndex + 1).circle.fill",
                        badgeIconColor: palette.foregroundColor,
                        badgeBackgroundColor: Color.accentGreen.opacity(0.25),
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

                ForEach(snapshot.teeGroups.filter { $0.id != group.id }, id: \.self) { otherGroup in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            let nextIndex = snapshot.participants.filter { $0.groupID == otherGroup.id }.count
                            await onAssign(player, otherGroup, nextIndex)
                        }
                    } label: {
                        if let subtitle = destinationOccupantsLabel(forGroupID: otherGroup.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Move to \(otherGroup.name)")
                                Text(subtitle)
                            }
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
        PlayerTab.allCases.filter { teamsEnabled ? true : $0 != .teams }
    }
    
    var playerTabPicker: some View {
        Picker("", selection: $playerTab) {
            ForEach(availablePlayerTabs, id: \.self) { tab in
                Text(tab.name).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    var playersSection: some View {
        if playerTab == .roster {
            rosterContent
                .padding(16)
                .glassCardEffect()
        }
        
        if playerTab == .groups {
            teeGroupsContent
        }
        
        if playerTab == .teams {
            teamsContent
        }
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
                    .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
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
                        HandicapTextField(
                            id: participant.id,
                            initialValue: participant.adjustedHandicap,
                            focusedField: $focus,
                            palette: palette,
                            onDebouncedEdit: { newValue in
                                if participant.adjustedHandicap == newValue { return }
                                var updated = participant
                                updated.originalHandicap = newValue
                                updated.adjustedHandicap = newValue
                                Task { try? await roundSession.update(participant: updated) }
                            }
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
            let unassigned = snapshot.participants.filter { $0.groupID == nil }
            if !unassigned.isEmpty {
                unassignedGroupPlayers(for: unassigned)
            }
            
            ForEach(snapshot.teeGroups.sorted(by: { $1.index > $0.index }), id: \.self) { group in
                teeGroupTile(for: group)
            }
            
            HStack(spacing: 12) {
                if snapshot.teeGroups.count > 0 {
                    GlassButton(
                        title: "Clear all",
                        labelColor: .systemError,
                        height: 40,
                        fillWidth: false,
                        fontSize: 15,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showClearTeeGroupsAlert = true }
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
        VStack(spacing: 16) {
            let unassigned = snapshot.participants.filter { $0.teamID == nil }
            if !unassigned.isEmpty {
                unassignedTeamPlayers(for: unassigned)
            }
            
            ForEach(snapshot.teams.sorted(by: { $1.index > $0.index }), id: \.self) { team in
                teamTile(for: team)
            }
            
            HStack(spacing: 12) {
                if snapshot.teams.count > 0 {
                    GlassButton(
                        title: "Clear all",
                        labelColor: .systemError,
                        height: 40,
                        fillWidth: false,
                        fontSize: 15,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showClearTeamsAlert = true }
                    )
                }
                
                if snapshot.teams.count < TeamColor.cycle.count {
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
                            Text("\(teeTime)")
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
        let teamColor: Color? = teamsEnabled
            ? (team?.teamColor.value ?? snapshot.teamColor(for: participant))
            : nil
        let circleTint: Color = tint ?? palette.glassButtonColor

        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: participant.name.initials,
                size: playerAvatarSize,
                fillColor: teamColor,
                glassTint: circleTint,
                badgeIcon: badgeIcon,
                badgeIconColor: palette.foregroundColor,
                badgeBackgroundColor: Color.accentGreen.opacity(0.25),
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
            }
            
            teeGroupSlotRow(
                group: group,
                slotIndex: players.count,
                player: nil
            )
        }
        .padding(16)
        .glassCardEffect()
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
                    value: "\(group.startingHole)",
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
                    value: group.teeTime ?? "-",
                    label: "tee time",
                    size: 15
                )
            }
        }
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
                        ForEach(snapshot.teeGroups, id: \.self) { group in
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
        .glassCardEffect()
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
    let onAssign: (RoundParticipant, RoundTeam) async -> Void
    let onRemove: (RoundParticipant, RoundTeam) async -> Void
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
        let teamColor = team.teamColor.value

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
                        glassTint: .neutral6
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

                        if let group = snapshot.teeGroups.first(where: { $0.id == participant.groupID }) {
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

                ForEach(snapshot.teams.filter { $0.id != team.id }, id: \.self) { otherTeam in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            await onAssign(player, otherTeam)
                        }
                    } label: {
                        if let subtitle = destinationOccupantsLabel(forTeamID: otherTeam.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Move to \(otherTeam.name)")
                                Text(subtitle)
                            }
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
    private func teamTile(for team: RoundTeam) -> some View {
        let players = snapshot.participants
            .filter { $0.teamID == team.id }
            .sorted { $0.name.fullName < $1.name.fullName }

        let totalHCP = players.reduce(0) { $0 + $1.adjustedHandicap }

        VStack(spacing: 12) {
            teamHeader(for: team, totalHCP: totalHCP)

            Line()

            ForEach(players, id: \.id) { player in
                TeamSlotRow(
                    team: team,
                    player: player,
                    palette: palette,
                    playerAvatarSize: playerAvatarSize,
                    handicapsEnabled: handicapsEnabled,
                    snapshot: snapshot,
                    teamsEnabled: teamsEnabled,
                    onAssign: assign(player:to:),
                    onRemove: remove(player:from:),
                    onShowAddPlayers: { showAddPlayersView = true },
                    onEditPlayer: { editingPlayer = $0 }
                )
            }

            TeamSlotRow(
                team: team,
                player: nil,
                palette: palette,
                playerAvatarSize: playerAvatarSize,
                handicapsEnabled: handicapsEnabled,
                snapshot: snapshot,
                teamsEnabled: teamsEnabled,
                onAssign: assign(player:to:),
                onRemove: remove(player:from:),
                onShowAddPlayers: { showAddPlayersView = true },
                onEditPlayer: { _ in }
            )
        }
        .padding(16)
        .glassCardEffect()
    }

    @ViewBuilder
    private func teamHeader(for team: RoundTeam, totalHCP: Int) -> some View {
        HStack(spacing: 24) {
            Menu {
                Button {
                    Haptics.fire(.light)
                    print("modify team UI")
                } label: {
                    Label("Modify team", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task { try? await roundSession.removeTeam(team) }
                } label: {
                    Label("Delete team", systemImage: "trash")
                }
                
            } label: {
                VStack(spacing: 2) {
                    Text(team.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(team.teamColor.value)
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
            
            Spacer(minLength: 0)
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
                        ForEach(snapshot.teams.sorted(by: { $0.index < $1.index }), id: \.self) { team in
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
        .glassCardEffect()
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

