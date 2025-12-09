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
                Text("Strokes".uppercased())
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignTrailing()
                
                ForEach(snapshot.participants, id: \.self) { participant in
                    Button(action: {
                        Haptics.fire(.light)
                        print("show sheet popup to manage or edit")
                        editingPlayer = participant
                        showEditPlayerView = true
                    }) {
                        playerRow(for: participant) {
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
                    icon: "f234",
                    iconWeight: .regular,
                    buttonColor: .neutral6,
                    theme: palette.theme,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showAddPlayersView = true }
                )
            }
            
            // TODO: Creating new group, managing players, assigning players newly added.
            
            // TODO: When new players are added, they need to go into the next available group (assuming 4 spots).
            // As players are added in sequential order, we need a central function to addPlayers(data: [Player]) that
            // does all the work needed to add these players to participant profiles and increment through tee groups.
            
            if playerTab == .groups {
                ForEach(snapshot.teeGroups.sorted(by: { $1.index > $0.index }), id: \.self) { group in
                    teeGroupTile(for: group)
                }
                
                PrimaryButton(
                    appearance: .outline,
                    outlineStyle: .dotted,
                    title: "Add tee group".uppercased(),
                    icon: "f450",
                    iconWeight: .regular,
                    buttonColor: .neutral6,
                    theme: palette.theme,
                    fillWidth: true,
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
            // TODO: Display for adding team by color and then selecting players from the master list.
            // Ability to change team color or see team tallies so you have balanced teams. See total strokes.
            // ^ this view could be done for tee groups but let's A/B test as TML trio.
            
            PrimaryButton(
                appearance: .fill,
                title: "Add team".uppercased(),
                icon: "e6d7",
                iconWeight: .regular,
                buttonColor: .neutral6,
                theme: palette.theme,
                fillWidth: false,
                isDisabled: .false,
                isLoading: .false,
                onTap: { print("add new team") }
            )
        }
    }
    
    fileprivate func playerRow<Content: View>(
        for participant: RoundParticipant,
        @ViewBuilder callToAction: () -> Content = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.backgroundColor) // TODO: Make this the team color if using and on team, otherwise card.
                    .frame(width: 36, height: 36)
                Text(participant.name.initials)
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            VStack(spacing: 2) {
                // TODO: Show some differentiation if playing from different tee?
                Text(participant.name.fullName)
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                // TODO: Set group # and optional time if it exists
                Text("Tee Group X \(kDot) XX:XX am")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
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
                    content: { playerRow(player, index: index) },
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
                        group: group,
                        currentPlayer: nil,
                        slotIndex: filledCount + i
                    )
                }
            }

            // Always allow adding beyond 4
            if filledCount >= maxVisibleSlots {
                slotMenu(
                    content: { placeholderRow() },
                    group: group,
                    currentPlayer: nil,
                    slotIndex: filledCount
                )
            }
        }
        .outlineEffect(for: palette)
    }

    // MARK: - Header

    @ViewBuilder
    private func header(for group: TeeTimeGroup, totalHCP: Int) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text(group.name)
                    .fontStyle(.poppins, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                if handicapsEnabled {
                    Text("\(totalHCP) total strokes")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(.neutral)
                }
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

    // MARK: - Slot Menu

    @ViewBuilder
    private func slotMenu<Content: View>(
        content: @escaping () -> Content,
        group: TeeTimeGroup,
        currentPlayer: RoundParticipant?,
        slotIndex: Int
    ) -> some View {
        Menu {
            // Add new player always available
            Button {
                Haptics.fire(.light)
                showAddPlayersView = true
            } label: {
                Label("Add new player", systemImage: "plus")
            }

            Divider()

            // Candidates (assigned elsewhere or unassigned)
            ForEach(snapshot.participants.filter { $0.groupID != group.id }, id: \.self) { candidate in
                Button {
                    Haptics.fire(.light)
                    Task { await assign(player: candidate, to: group, at: slotIndex) }
                } label: {
                    Text("Add \(candidate.name.fullName)")
                }
            }

            // Remove current
            if let currentPlayer {
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task { await remove(player: currentPlayer, from: group) }
                } label: {
                    Label("Remove player", systemImage: "trash")
                }
            }

        } label: {
            content()
                .contentShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Rows

    private func playerRow(_ player: RoundParticipant, index: Int) -> some View {
        HStack(spacing: 8) {
            Icon(name: "\(index + 1).circle", size: 22)
                .foregroundStyle(.accentGreen)

            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text(player.name.fullName)
                        .fontStyle(.poppins, size: 17, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)

                    Circle()
                        .fill(.clear)
                        .frame(width: 4, height: 4)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    if handicapsEnabled {
                        Text("\(player.adjustedHandicap) strokes")
                            .fontStyle(.poppins, size: 13, weight: .medium)
                            .foregroundStyle(.neutral)
                    }

                    if let tee = snapshot.tees.first(where: { $0.id == player.teeBoxID }),
                       tee.id != snapshot.defaultTee?.id {
                        Text("\(tee.name) tees")
                            .fontStyle(.poppins, size: 13, weight: .medium)
                            .foregroundStyle(.neutral)
                    }

                    Spacer(minLength: 0)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func placeholderRow() -> some View {
        HStack(spacing: 8) {
            Icon(name: "plus.circle.dashed", size: 22)

            Text("Add player")
                .fontStyle(.poppins, size: 17, weight: .medium)

            Spacer()
        }
        .foregroundStyle(.neutral2)
        .padding(.vertical, 4)
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
    
}
