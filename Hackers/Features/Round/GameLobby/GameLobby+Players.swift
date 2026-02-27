//
//  GameLobby+Players.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Participant Drag Payload

struct ParticipantDragPayload: Codable, Transferable {
    var participantID: String
    var sourceGroupID: String?
    var sourceTeamID: String?
    var firstName: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .participantDrag)
    }
}

/// Shared state for drag operations so only one drop target shows and we can personalize the label.
final class LobbyDragState: ObservableObject {
    @Published var draggingParticipantID: String?
    @Published var draggingFirstName: String?
    @Published var sourceGroupID: String?
    @Published var sourceTeamID: String?
    @Published var activeTargetSlotKey: String?

    private var endDragTask: Task<Void, Never>?

    func startDrag(participantID: String, firstName: String, sourceGroupID: String?, sourceTeamID: String?) {
        endDragTask?.cancel()
        draggingParticipantID = participantID
        draggingFirstName = firstName
        self.sourceGroupID = sourceGroupID
        self.sourceTeamID = sourceTeamID
    }

    func setActiveTarget(_ key: String?) {
        if key != nil {
            endDragTask?.cancel()
        }
        activeTargetSlotKey = key
        if key == nil {
            scheduleEndDrag()
        }
    }

    func endDrag() {
        endDragTask?.cancel()
        draggingParticipantID = nil
        draggingFirstName = nil
        sourceGroupID = nil
        sourceTeamID = nil
        activeTargetSlotKey = nil
    }

    private func scheduleEndDrag() {
        endDragTask?.cancel()
        endDragTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self.endDrag() }
        }
    }

    func isSourceSlot(playerID: String?) -> Bool {
        guard let dragging = draggingParticipantID, let player = playerID else { return false }
        return dragging == player
    }
}

extension UTType {
    static var participantDrag: UTType {
        UTType(exportedAs: "com.hackers.participant-drag")
    }
}

// MARK: - Tee Group Slot Row

private struct TeeGroupSlotRow: View {
    let group: TeeTimeGroup
    let slotIndex: Int
    let player: RoundParticipant?
    let isPlaceholder: Bool
    let palette: DesignPalette
    let playerAvatarSize: CGFloat
    let handicapsEnabled: Bool
    let snapshot: RoundSnapshot
    let teamsEnabled: Bool
    let dragState: LobbyDragState
    let getParticipant: (String) -> RoundParticipant?
    let onAssign: (RoundParticipant, TeeTimeGroup, Int) async -> Void
    let onRemove: (RoundParticipant, TeeTimeGroup) async -> Void
    let onShowAddPlayers: () -> Void
    let buildSections: ([RoundParticipant], GameLobby.SlotType, RoundSnapshot) -> [(title: String, items: [RoundParticipant])]

    @State private var isDropTargeted = false

    private var slotKey: String { "tee-\(group.id)-\(slotIndex)" }

    private func dropHerePlaceholderRow(firstName: String?) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .foregroundStyle(.neutral3)
            .frame(maxWidth: .infinity)
            .frame(height: playerAvatarSize + 8)
            .overlay {
                Text(firstName != nil ? "Drop \(firstName!) here" : "Drop here")
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(.neutral2)
            }
            .padding(.vertical, 4)
    }

    var body: some View {
        let showPlaceholder = isDropTargeted
            && !dragState.isSourceSlot(playerID: player?.id)
            && dragState.activeTargetSlotKey == slotKey

        Group {
            if showPlaceholder {
                dropHerePlaceholderRow(firstName: dragState.draggingFirstName)
            } else {
                slotContent
            }
        }
        .dropDestination(for: ParticipantDragPayload.self) { items, _ in
            guard let payload = items.first,
                  let participant = getParticipant(payload.participantID) else {
                dragState.endDrag()
                return false
            }
            Task {
                await onAssign(participant, group, slotIndex)
                await MainActor.run { dragState.endDrag() }
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
            dragState.setActiveTarget(targeted ? slotKey : nil)
        }
    }

    @ViewBuilder
    private var slotContent: some View {
        HStack(spacing: 12) {
            if let player {
                draggablePlayerRow(for: player)
            } else {
                placeholderRow
            }

            Spacer(minLength: 0)

            slotMenuButton
        }
    }

    private func draggablePlayerRow(for participant: RoundParticipant) -> some View {
        let teamColor = teamsEnabled ? snapshot.teamColor(for: participant) : nil
        let circleTint = Color.neutral6
        let payload = ParticipantDragPayload(
            participantID: participant.id,
            sourceGroupID: participant.groupID,
            sourceTeamID: participant.teamID,
            firstName: participant.name.givenName.isEmpty ? participant.name.familyName : participant.name.givenName
        )

        return HStack(spacing: 12) {
            PlayerAvatarView(
                initials: participant.name.initials,
                size: playerAvatarSize,
                fillColor: teamColor,
                glassTint: circleTint,
                badgeIcon: "\(slotIndex + 1).circle.fill",
                badgeIconColor: teamColor ?? .neutral2,
                badgeBackgroundColor: palette.backgroundColor,
                badgeBorderColor: palette.foregroundColor,
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
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.1) {
            dragState.startDrag(
                participantID: participant.id,
                firstName: payload.firstName,
                sourceGroupID: participant.groupID,
                sourceTeamID: participant.teamID
            )
        }
        .draggable(payload) {
            dragPreviewContent(participant: participant, teamColor: teamColor, circleTint: circleTint)
        }
    }

    private func dragPreviewContent(participant: RoundParticipant, teamColor: Color?, circleTint: Color) -> some View {
        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: participant.name.initials,
                size: playerAvatarSize,
                fillColor: teamColor,
                glassTint: circleTint,
                badgeIcon: "\(slotIndex + 1).circle.fill",
                badgeIconColor: teamColor ?? .neutral2,
                badgeBackgroundColor: palette.backgroundColor,
                badgeBorderColor: palette.foregroundColor,
                initialsColor: teamColor != nil ? .white : palette.foregroundColor
            )
            .frame(width: playerAvatarSize, height: playerAvatarSize)

            VStack(spacing: 2) {
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                if handicapsEnabled {
                    Text("\(participant.adjustedHandicap) strokes")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minWidth: 200)
        .glassCardEffect(cornerRadius: 12, tint: palette.glassButtonColor, shadowOpacity: 0.2)
    }

    private var placeholderRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(.neutral4, lineWidth: 1.5)
                    .frame(width: playerAvatarSize, height: playerAvatarSize)
                Icon(name: "2b", size: 15, weight: .solid)
                    .foregroundStyle(.neutral2)
            }
            Text("Add player")
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(.neutral2)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var slotMenuButton: some View {
        Menu {
            if player == nil {
                Button {
                    Haptics.fire(.light)
                    onShowAddPlayers()
                } label: {
                    Label("Add new player", systemImage: "plus")
                }
                Divider()
            }

            let candidates = snapshot.participants.filter { $0.groupID != group.id }

            if let player {
                ForEach(snapshot.teeGroups.filter { $0.id != group.id }, id: \.self) { otherGroup in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            let nextIndex = snapshot.participants.filter { $0.groupID == otherGroup.id }.count
                            await onAssign(player, otherGroup, nextIndex)
                        }
                    } label: {
                        Text("Move to \(otherGroup.name)")
                    }
                }
            } else {
                ForEach(buildSections(candidates, .teeTimeGroup, snapshot), id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.items, id: \.self) { candidate in
                            Button {
                                Haptics.fire(.light)
                                Task {
                                    await onAssign(candidate, group, slotIndex)
                                }
                            } label: {
                                Text("\(section.title == "Unassigned" ? "Add" : "Move") \(candidate.name.fullName)")
                            }
                        }
                    }
                }
            }

            if let player {
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
    
    private var sortedRosterParticipants: [RoundParticipant] {
        let participants = snapshot.participants
        switch rosterSort {
        case .abc:
            return participants.sorted { $0.name.fullName < $1.name.fullName }
        case .team:
            return participants.sorted { ($0.teamID ?? "") < ($1.teamID ?? "") }
        case .tee:
            return participants.sorted { ($0.groupID ?? "") < ($1.groupID ?? "") }
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
                    Icon(name: "f0dc", size: 16, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .frame(width: playerAvatarSize, height: playerAvatarSize)
                }
                
                Text("\(snapshot.participants.count) players")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                
                Spacer(minLength: 0)
                
                if handicapsEnabled {
                    Text("Strokes")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .frame(width: 48, alignment: .trailing)
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
                                    Task { try? await roundSession.update(participant: updated) }
                                }
                            )
                        }
                    }
                }
                
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
                badgeIconColor: teamColor ?? .neutral2,
                badgeBackgroundColor: palette.backgroundColor,
                badgeBorderColor: palette.borderColor,
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
    
    private func placeholderRow() -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(.neutral4, lineWidth: 1.5)
                    .frame(width: playerAvatarSize, height: playerAvatarSize)
                
                Icon(name: "2b", size: 15, weight: .solid)
                    .foregroundStyle(.neutral2)
            }

            Text("Add player")
                .fontStyle(kFontName, size: 15, weight: .medium)
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
                teeGroupSlotRow(
                    group: group,
                    slotIndex: index,
                    player: player,
                    isPlaceholder: false
                )
            }
            
            // Placeholder slots (visual only)
            if emptySlots > 0 {
                ForEach(0..<emptySlots, id: \.self) { i in
                    teeGroupSlotRow(
                        group: group,
                        slotIndex: filledCount + i,
                        player: nil,
                        isPlaceholder: true
                    )
                }
            }
            
            // Always allow adding beyond 4
            if filledCount >= maxVisibleSlots {
                teeGroupSlotRow(
                    group: group,
                    slotIndex: filledCount,
                    player: nil,
                    isPlaceholder: true
                )
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    @ViewBuilder
    private func teeGroupSlotRow(
        group: TeeTimeGroup,
        slotIndex: Int,
        player: RoundParticipant?,
        isPlaceholder: Bool
    ) -> some View {
        TeeGroupSlotRow(
            group: group,
            slotIndex: slotIndex,
            player: player,
            isPlaceholder: isPlaceholder,
            palette: palette,
            playerAvatarSize: playerAvatarSize,
            handicapsEnabled: handicapsEnabled,
            snapshot: snapshot,
            teamsEnabled: teamsEnabled,
            dragState: lobbyDragState,
            getParticipant: { id in roundSession.snapshot.participants.first(where: { $0.id == id }) },
            onAssign: assign(player:to:at:),
            onRemove: remove(player:from:),
            onShowAddPlayers: { showAddPlayersView = true },
            buildSections: buildSections(for:of:with:)
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
    let dragState: LobbyDragState
    let getParticipant: (String) -> RoundParticipant?
    let onAssign: (RoundParticipant, RoundTeam) async -> Void
    let onRemove: (RoundParticipant, RoundTeam) async -> Void
    let onShowAddPlayers: () -> Void
    let buildSections: ([RoundParticipant], GameLobby.SlotType, RoundSnapshot) -> [(title: String, items: [RoundParticipant])]

    @State private var isDropTargeted = false

    private var slotKey: String { "team-\(team.id)-\(player?.id ?? "empty")" }

    private func dropHerePlaceholderRow(firstName: String?) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .foregroundStyle(.neutral3)
            .frame(maxWidth: .infinity)
            .frame(height: playerAvatarSize + 8)
            .overlay {
                Text(firstName != nil ? "Drop \(firstName!) here" : "Drop here")
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(.neutral2)
            }
            .padding(.vertical, 4)
    }

    var body: some View {
        let showPlaceholder = isDropTargeted
            && !dragState.isSourceSlot(playerID: player?.id)
            && dragState.activeTargetSlotKey == slotKey

        Group {
            if showPlaceholder {
                dropHerePlaceholderRow(firstName: dragState.draggingFirstName)
            } else {
                slotContent
            }
        }
        .dropDestination(for: ParticipantDragPayload.self) { items, _ in
            guard let payload = items.first,
                  let participant = getParticipant(payload.participantID) else {
                dragState.endDrag()
                return false
            }
            Task {
                await onAssign(participant, team)
                await MainActor.run { dragState.endDrag() }
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
            dragState.setActiveTarget(targeted ? slotKey : nil)
        }
    }

    @ViewBuilder
    private var slotContent: some View {
        HStack(spacing: 12) {
            if let player {
                draggablePlayerRow(for: player)
            } else {
                placeholderRow
            }

            Spacer(minLength: 0)

            slotMenuButton
        }
    }

    private func draggablePlayerRow(for participant: RoundParticipant) -> some View {
        let teamColor = team.teamColor.value
        let firstName = participant.name.givenName.isEmpty ? participant.name.familyName : participant.name.givenName
        let payload = ParticipantDragPayload(
            participantID: participant.id,
            sourceGroupID: participant.groupID,
            sourceTeamID: participant.teamID,
            firstName: firstName
        )

        return HStack(spacing: 12) {
            PlayerAvatarView(
                initials: participant.name.initials,
                size: playerAvatarSize,
                fillColor: teamColor,
                glassTint: .neutral6,
                badgeIcon: nil,
                badgeIconColor: nil,
                badgeBackgroundColor: palette.backgroundColor,
                badgeBorderColor: palette.borderColor,
                initialsColor: .white
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
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.1) {
            dragState.startDrag(
                participantID: participant.id,
                firstName: firstName,
                sourceGroupID: participant.groupID,
                sourceTeamID: participant.teamID
            )
        }
        .draggable(payload) {
            teamDragPreviewContent(participant: participant, teamColor: teamColor)
        }
    }

    private func teamDragPreviewContent(participant: RoundParticipant, teamColor: Color) -> some View {
        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: participant.name.initials,
                size: playerAvatarSize,
                fillColor: teamColor,
                glassTint: .neutral6,
                badgeIcon: nil,
                badgeIconColor: nil,
                badgeBackgroundColor: palette.backgroundColor,
                badgeBorderColor: palette.borderColor,
                initialsColor: .white
            )
            .frame(width: playerAvatarSize, height: playerAvatarSize)

            VStack(spacing: 2) {
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                if handicapsEnabled {
                    Text("\(participant.adjustedHandicap) strokes")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minWidth: 200)
        .glassCardEffect(cornerRadius: 12, tint: palette.glassButtonColor, shadowOpacity: 0.2)
    }

    private var placeholderRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(.neutral4, lineWidth: 1.5)
                    .frame(width: playerAvatarSize, height: playerAvatarSize)
                Icon(name: "2b", size: 15, weight: .solid)
                    .foregroundStyle(.neutral2)
            }
            Text("Add player")
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(.neutral2)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var slotMenuButton: some View {
        Menu {
            if player == nil {
                Button {
                    Haptics.fire(.light)
                    onShowAddPlayers()
                } label: {
                    Label("Add new player", systemImage: "plus")
                }
                Divider()
            }

            let candidates = snapshot.participants.filter { $0.teamID != team.id }

            if let player {
                ForEach(snapshot.teams.filter { $0.id != team.id }, id: \.self) { otherTeam in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            await onAssign(player, otherTeam)
                        }
                    } label: {
                        Text("Move to \(otherTeam.name)")
                    }
                }
            } else {
                ForEach(buildSections(candidates, .team, snapshot), id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.items, id: \.self) { candidate in
                            Button {
                                Haptics.fire(.light)
                                Task {
                                    await onAssign(candidate, team)
                                }
                            } label: {
                                Text("\(section.title == "Unassigned" ? "Add" : "Move") \(candidate.name.fullName)")
                            }
                        }
                    }
                }
            }

            if let player {
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
                TeamSlotRow(
                    team: team,
                    player: player,
                    palette: palette,
                    playerAvatarSize: playerAvatarSize,
                    handicapsEnabled: handicapsEnabled,
                    snapshot: snapshot,
                    teamsEnabled: teamsEnabled,
                    dragState: lobbyDragState,
                    getParticipant: { id in roundSession.snapshot.participants.first(where: { $0.id == id }) },
                    onAssign: assign(player:to:),
                    onRemove: remove(player:from:),
                    onShowAddPlayers: { showAddPlayersView = true },
                    buildSections: buildSections(for:of:with:)
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
                dragState: lobbyDragState,
                getParticipant: { id in roundSession.snapshot.participants.first(where: { $0.id == id }) },
                onAssign: assign(player:to:),
                onRemove: remove(player:from:),
                onShowAddPlayers: { showAddPlayersView = true },
                buildSections: buildSections(for:of:with:)
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

