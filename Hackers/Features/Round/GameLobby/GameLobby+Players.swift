//
//  GameLobby+Players.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI

// MARK: - Player Section

extension GameLobby {
    enum PlayerTab: String, CaseIterable {
        case roster = "Roster"
        case groups = "Tee Groups"
        case teams = "Teams"
        
        var name: String { self.rawValue }
    }
    
    @ViewBuilder
    var playersSection: some View {
        Text("Players".uppercased())
            .fontStyle(.poppins, size: 20, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .alignCenter()
        
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            ForEach(PlayerTab.allCases.filter { teamsEnabled ? true : $0 != .teams }, id: \.self) { tab in
                underlineTab(for: tab)
            }
            Spacer(minLength: 0)
        }
        
        VStack(spacing: 16) {
            if playerTab == .roster {
                // TODO: Add sort here for players (ABC, Strokes Given, Group, Team)
                
                // TODO: Add a dot for color next to the name
                // TODO: Make this dynamic to cycle between HCP, tee group, team
                // If handicap, subtitle is group with team dot
                // If tee group, subtitle is strokes
                // If team, subtitle is team and strokes
                HStack {
                    Text("\(snapshot.participants.count) players")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)

                    Spacer(minLength: 0)
                    
                    Text("Strokes".uppercased())
                        .fontStyle(.poppins, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .padding(.trailing, 16)
                }
                
                ForEach(snapshot.participants, id: \.self) { participant in
                    Button(action: {
                        Haptics.fire(.light)
                        editingPlayer = participant
                        showEditPlayerView = true
                    }) {
                        playerRow(for: participant, components: [.teeGroup, .teeTime, .defaultTee]) {
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
                                        print("update handicap to \(newValue)")
                                        Task { try? await roundService.update(participant: updated) }
                                    }
                                )
                            }
                        }
                    }
                    .tileEffect(for: palette)
                }
                
                PrimaryButton(
                    appearance: .fill,
                    title: "Add players".uppercased(),
                    icon: "2b",
                    iconWeight: .regular,
                    buttonColor: .neutral6,
                    theme: palette.theme,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showAddPlayersView = true }
                )
            }
            
            if playerTab == .groups {
                let unassigned = snapshot.participants.filter { $0.groupID == nil }
                if !unassigned.isEmpty {
                    unassignedGroupPlayers(for: unassigned)
                }
                
                ForEach(snapshot.teeGroups.sorted(by: { $1.index > $0.index }), id: \.self) { group in
                    teeGroupTile(for: group)
                }
                
                HStack(spacing: 16) {
                    if snapshot.teeGroups.count > 0 {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Clear all",
                            labelColor: .systemError,
                            buttonColor: .neutral6,
                            theme: palette.theme,
                            fillWidth: false,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { showClearTeeGroupsAlert = true }
                        )
                    }
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Add tee group".uppercased(),
                        icon: "2b",
                        iconWeight: .regular,
                        buttonColor: .neutral6,
                        theme: palette.theme,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: {
                            // TODO: Handle errors here
                            Task { try? await roundService.createTeeGroup() }
                        }
                    )
                }
            }
            
            if playerTab == .teams {
                let unassigned = snapshot.participants.filter { $0.teamID == nil }
                if !unassigned.isEmpty {
                    unassignedTeamPlayers(for: unassigned)
                }
                
                ForEach(snapshot.teams.sorted(by: { $1.index > $0.index }), id: \.self) { team in
                    teamTile(for: team)
                }
                
                HStack(spacing: 16) {
                    if snapshot.teams.count > 0 {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Clear all",
                            labelColor: .systemError,
                            buttonColor: .neutral6,
                            theme: palette.theme,
                            fillWidth: false,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: {
                                // TODO: Handle errors here
                                Task { try? await roundService.clearAllTeams() }
                            }
                        )
                    }
                    
                    if snapshot.teams.count < TeamColor.cycle.count {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Add team".uppercased(),
                            icon: "2b",
                            iconWeight: .regular,
                            buttonColor: .neutral6,
                            theme: palette.theme,
                            isDisabled: .false,
                            isLoading: .false,
                            onTap: { showClearTeamsAlert = true }
                        )
                    }
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
                            .fontStyle(.poppins, size: 14, weight: .regular)
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
                                .fontStyle(.poppins, size: 13)
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
                                .fontStyle(.poppins, size: 13)
                                .foregroundStyle(Color.neutral)
                        )
                    )
                )
            }
            
            if let tee = snapshot.defaultTee, participant.teeBoxID != tee.id, components.contains(.defaultTee) {
                items.append(
                    SubtitleItem(
                        view: AnyView(
                            Text("\(tee.name) tees")
                                .fontStyle(.poppins, size: 13)
                                .foregroundStyle(Color.neutral)
                        )
                    )
                )
            }
        }

        if let team = snapshot.teams.first(where: { $0.id == participant.teamID }),
           components.contains(.team) {
            items.append(
                SubtitleItem(
                    view: AnyView(
                        Text(team.name)
                            .fontStyle(.poppins, size: 13)
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
        @ViewBuilder callToAction: () -> Content = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                let teamColor: Color? = teamsEnabled
                ? (team?.teamColor.value ?? snapshot.teamColor(for: participant))
                : nil
                
                Circle()
                    .fill(teamColor ?? tint ?? palette.backgroundColor)
                    .frame(width: 36, height: 36)
                Text(participant.name.initials)
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(teamColor != nil ? .white : palette.foregroundColor)
            }
            
            VStack(spacing: 2) {
                Text(participant.name.fullName)
                    .fontStyle(.poppins, size: 15, weight: .semibold)
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
    
    private func placeholderRow() -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(.neutral4, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                
                Icon(name: "2b", size: 15, weight: .solid)
                    .foregroundStyle(.neutral2)
            }

            Text("Add player")
                .fontStyle(.poppins, size: 15, weight: .medium)
                .foregroundStyle(.neutral2)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Slot Menu

extension GameLobby {
    enum SlotType { case teeTimeGroup, team }
    
    @ViewBuilder
    private func slotMenu<Content: View>(
        content: @escaping () -> Content,
        type: SlotType,
        group: TeeTimeGroup? = nil,
        team: RoundTeam? = nil,
        currentPlayer: RoundParticipant? = nil,
        slotIndex: Int = 0
    ) -> some View {
        Menu {
            // TODO: AddPlayersViews needs more robust data for bulk adding to tee group or team
            if currentPlayer == nil {
                Button {
                    Haptics.fire(.light)
                    showAddPlayersView = true
                } label: {
                    Label("Add new player", systemImage: "plus")
                }
                
                Divider()
            }
            
            // Candidates (assigned elsewhere or unassigned)
            let candidates = snapshot.participants.filter {
                switch type {
                case .teeTimeGroup:     return $0.groupID != group?.id
                case .team:             return $0.teamID != team?.id
                }
            }
            
            if let currentPlayer {
                if let group, type == .teeTimeGroup {
                    ForEach(snapshot.teeGroups.filter({ $0.id != group.id }), id: \.self) { group in
                        Button {
                            Haptics.fire(.light)
                            Task {
                                let nextIndex = snapshot.participants.filter { $0.groupID == group.id }.count
                                await assign(player: currentPlayer, to: group, at: nextIndex)
                            }
                        } label: {
                            Text("Move to \(group.name)")
                        }
                    }
                }
                
                if let team, type == .team {
                    ForEach(snapshot.teams.filter({ $0.id != team.id }), id: \.self) { team in
                        Button {
                            Haptics.fire(.light)
                            Task {
                                await assign(player: currentPlayer, to: team)
                            }
                        } label: {
                            Text("Move to \(team.name)")
                        }
                    }
                }
            } else {
                ForEach(buildSections(for: candidates, of: type, with: snapshot), id: \.title ) { section in
                    Section(section.title) {
                        ForEach(section.items, id: \.self) { candidate in
                            Button {
                                Haptics.fire(.light)
                                Task {
                                    if let group, type == .teeTimeGroup {
                                        await assign(player: candidate, to: group, at: slotIndex)
                                    }
                                    if let team, type == .team {
                                        await assign(player: candidate, to: team)
                                    }
                                }
                            } label: {
                                Text("\(section.title == "Unassigned" ? "Add" : "Move") \(candidate.name.fullName)")
                            }
                        }
                    }
                }
//
//                ForEach(candidates, id: \.self) { candidate in
//                    Button {
//                        Haptics.fire(.light)
//                        Task {
//                            if let group, type == .teeTimeGroup {
//                                await assign(player: candidate, to: group, at: slotIndex)
//                            }
//                            if let team, type == .team {
//                                await assign(player: candidate, to: team)
//                            }
//                        }
//                    } label: {
//                        Text("Add \(candidate.name.fullName)")
//                    }
//                }
            }
            
            if let currentPlayer {
                Divider()
                
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task {
                        if let group, type == .teeTimeGroup {
                            await remove(player: currentPlayer, from: group)
                        }
                        if let team, type == .team {
                            await remove(player: currentPlayer, from: team)
                        }
                    }
                } label: {
                    if let group, type == .teeTimeGroup {
                        Label("Remove from group", systemImage: "trash")
                    }
                    if let team, type == .team {
                        Label("Remove from team", systemImage: "trash")
                    }
                }
            }
            
        } label: {
            content()
                .contentShape(RoundedRectangle(cornerRadius: 2))
        }
    }
    
    private func buildSections(
        for candidates: [RoundParticipant],
        of type: SlotType,
        with snapshot: RoundSnapshot
    ) -> [(title: String, items: [RoundParticipant])] {
        switch type {
        case .teeTimeGroup:
            let grouped = Dictionary(grouping: candidates, by: { $0.groupID })

            var sections: [(String, [RoundParticipant])] = []

            // Unassigned
            if let unassigned = grouped[nil], !unassigned.isEmpty {
                sections.append(("Unassigned", unassigned))
            }

            // Assigned groups
            for group in snapshot.teeGroups {
                if let items = grouped[group.id], !items.isEmpty {
                    sections.append((group.name, items))
                }
            }

            return sections
        case .team:
            let grouped = Dictionary(grouping: candidates, by: { $0.teamID })

            var sections: [(String, [RoundParticipant])] = []

            // Unassigned
            if let unassigned = grouped[nil], !unassigned.isEmpty {
                sections.append(("Unassigned", unassigned))
            }

            // Assigned teams
            for team in snapshot.teams.sorted(by: { $0.index < $1.index }) {
                if let items = grouped[team.id], !items.isEmpty {
                    sections.append((team.name, items))
                }
            }

            return sections
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
        
        let totalHCP = players.reduce(0, { $0 + $1.adjustedHandicap })
        
        VStack(spacing: 12) {
            header(for: group, totalHCP: totalHCP)
            
            Line()
            
            let maxVisibleSlots = 4
            let filledCount = players.count
            let emptySlots = max(0, maxVisibleSlots - filledCount)
            
            // Filled slots
            ForEach(Array(players.enumerated()), id: \.element) { index, player in
                slotMenu(
                    content: {
                        playerRow(for: player, tint: .neutral6, components: [.handicap, .defaultTee]) {
                            Icon(name: "\(index + 1).circle", size: 20)
                                .foregroundStyle(.neutral2)
                        }
                    },
                    type: .teeTimeGroup,
                    group: group,
                    currentPlayer: player,
                    slotIndex: index
                )
            }
            
            // Placeholder slots (visual only)
            if emptySlots > 0 {
                ForEach(0..<emptySlots, id: \.self) { i in
                    slotMenu(
                        content: { placeholderRow() },
                        type: .teeTimeGroup,
                        group: group,
                        slotIndex: filledCount + i
                    )
                }
            }
            
            // Always allow adding beyond 4
            if filledCount >= maxVisibleSlots {
                slotMenu(
                    content: { placeholderRow() },
                    type: .teeTimeGroup,
                    group: group,
                    slotIndex: filledCount
                )
            }
        }
        .outlineEffect(for: palette)
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
                    Task { try? await roundService.removeTeeGroup(group) }
                } label: {
                    Label("Remove tee group", systemImage: "trash")
                }
            } label: {
                VStack(spacing: 2) {
                    Text(group.name)
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    if handicapsEnabled {
                        Text("\(totalHCP) total strokes")
                            .fontStyle(.poppins, size: 15, weight: .medium)
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
                            try? await roundService.update(g)
                        }
                    }
                }
            } label: {
                stackedSubtitle(
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
                stackedSubtitle(
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
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(.neutral)
                    
                    Spacer()
                    
                    Text("\(players.count) left")
                        .fontStyle(.poppins, size: 15, weight: .regular)
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
        .outlineEffect(for: palette)
    }
    
    private func nextTeeOrder(in group: TeeTimeGroup) -> Int {
        snapshot.participants
            .filter { $0.groupID == group.id }
            .compactMap(\.teeOrder)
            .max()
            .map { $0 + 1 } ?? 0
    }

    private func assign(
        player: RoundParticipant,
        to group: TeeTimeGroup,
        at slotIndex: Int
    ) async {
        var p = player
        p.groupID = group.id
        p.teeOrder = nextTeeOrder(in: group)
        try? await roundService.update(participant: p)
    }

    private func remove(player: RoundParticipant, from group: TeeTimeGroup) async {
        var p = player
        p.groupID = nil
        p.teeOrder = nil
        try? await roundService.update(participant: p)
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
                try? await roundService.update(participant: p)
            }
        }
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

            ForEach(players, id: \.self) { player in
                slotMenu(
                    content: { playerRow(for: player, team: team, components: [.handicap, .teeGroup, .defaultTee]) },
                    type: .team,
                    team: team,
                    currentPlayer: player
                )
            }
            
            slotMenu(
                content: { placeholderRow() },
                type: .team,
                team: team
            )
        }
        .outlineEffect(for: palette)
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
                    Task { try? await roundService.removeTeam(team) }
                } label: {
                    Label("Delete team", systemImage: "trash")
                }
                
            } label: {
                VStack(spacing: 2) {
                    Text(team.name)
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(team.teamColor.value)
                        .alignLeading()
                    
                    if handicapsEnabled {
                        Text("\(totalHCP) total strokes")
                            .fontStyle(.poppins, size: 15, weight: .medium)
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
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(.neutral)
                    
                    Spacer()
                    
                    Text("\(players.count) left")
                        .fontStyle(.poppins, size: 15, weight: .regular)
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
        .outlineEffect(for: palette)
    }

    private func assign(player: RoundParticipant, to team: RoundTeam) async {
        var p = player
        p.teamID = team.id
        try? await roundService.update(participant: p)
    }

    private func remove(player: RoundParticipant, from team: RoundTeam) async {
        var p = player
        p.teamID = nil
        try? await roundService.update(participant: p)
    }
}

