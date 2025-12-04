//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import AlertToast
import Flow
import SwiftUI

// TODO: Read below.
// 1. Quick HCP stroke entry within player row
// 2. Tee group view (tiles for each group, tapping edit is generic player selector view with title, subtitle)
// 3. Team view

struct GameLobby: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    
    @StateObject var roundService = RoundService()
    
    private var snapshot: RoundSnapshot { roundService.snapshot }
    
    private var preventRoundStart: Binding<Bool> { .true }
    
    @State private var showShareCodeView = false
    @State private var showCourseModificationView = false
    @State private var showTeeInfoPopover = false

    
    @State private var playerTab: PlayerTab = .roster
    @State private var showPlayerConfirmationDialog = false
    @State private var showAddPlayersView = false
    @State private var showEditPlayerView = false
    @State private var editingPlayer: RoundParticipant?
    
    @State private var showHandicapEntry = false
    @State private var handicapParticipant: RoundParticipant = .init()

    @State private var handicapsEnabled: Bool = false
    @State private var teamsEnabled: Bool = false
    
    @Namespace private var qrTransition
    @Namespace private var courseTransition
    @Namespace private var playersTransition
    @Namespace private var handicapTransition
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private let mockSnapshot: RoundSnapshot?
    
    init?(mockSnapshot: RoundSnapshot? = nil) {
        self.mockSnapshot = mockSnapshot
    }
    
    var body: some View {
        StickyScrollView(
            header: { headerContent },
            content: { scrollableContent },
            footer: { footerContent },
            theme: palette.theme,
            onScroll: { _ in }
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden)
        .task {
            if let id = appSession.activeRoundID {
                await roundService.initialize(for: id)
            } else if let mockSnapshot {
                roundService.snapshot = mockSnapshot
            }
        }
        .resignKeyboardOnTapGesture()
        .onReceive(roundService.$snapshot, perform: { s in
            // This is the real-time updater
            print("SNAPSHOT UPDATED")
            handicapsEnabled = s.round.configuration.useHandicaps
            teamsEnabled = s.round.configuration.primaryFormat.configuration.requiresTeams
        })
        .sheet(isPresented: $showShareCodeView) {
            ShareRoundView(snapshot: roundService.snapshot)
                .navigationTransition(.zoom(sourceID: "qr", in: qrTransition))
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCourseModificationView) {
            CourseSelectionView(
                viewModel: .init(course: snapshot.course, tee: snapshot.defaultTee),
                onModification: { s in setCourseSegment(to: s) }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPlayersView) {
            AddPlayerView(
                snapshot: snapshot,
                onConfirm: { players in
                    Task {
                        // TODO: handle error display here before dismissing?
                        try? await roundService.addPlayers(players)
                        showAddPlayersView = false
                    }
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditPlayerView) {
            ManagePlayerView(
                snapshot: snapshot,
                participant: editingPlayer,
                onFinish: { p in
                    Task {
                        // TODO: handle error display here before dismissing?
                        try? await roundService.update(participant: p)
                        showEditPlayerView = false
                    }
                },
                onRemove: {
                    Task {
                        if let editingPlayer {
                            // TODO: handle error display here before dismissing?
                            try? await roundService.remove(participant: editingPlayer)
                            showEditPlayerView = false
                        }
                    }
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTeeTimePicker) {
            TeeTimePicker(group: $editingTeeGroup) { time in
                guard var group = editingTeeGroup else { return }
                Task {
                    group.teeTime = time
                    try? await roundService.update(group)
                    showTeeTimePicker = false
                }
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(360)])
        }
//        .sheet(isPresented: $showHandicapEntry) {
//            HandicapEntryView(
//                participant: $handicapParticipant,
//                holes: snapshot.holeSegment.holeCount,
//                onComplete: { value in
//                    handicapParticipant.originalHandicap = value
//                    handicapParticipant.adjustedHandicap = value
//                    print("todo: set \(handicapParticipant.name.fullName) handicap to \(value)")
//                    Task {
//                        try? await roundService.update(participant: handicapParticipant)
//                        showHandicapEntry = false
//                    }
//                }
//            )
//            .navigationTransition(.zoom(sourceID: "handicap", in: handicapTransition))
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//            .presentationCompactAdaptation(.none)
//        }
    }
    
    // MARK: - Content
    
    private var scrollableContent: some View {
        VStack(spacing: 32) {
            if roundService.isLoadingLobbyListeners {
                
                // TODO: Skeleton view for course info
                
            } else {
                courseSection
                Line()
                gameFormatSection
                Line()
                playersSection
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Course Info
    
    @ViewBuilder
    private var courseSection: some View {
        if let courseSegment = snapshot.courseSegment {
            Text(courseSegment.courseInfo.name.uppercased())
                .fontStyle(.poppins, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .alignCenter()
            
            HStack(spacing: 32) {
                Spacer(minLength: 0)
                
                stackedSubtitle(value: numberOfHolesLabel(for: courseSegment), label: "holes")
                
                if let defaultTee = snapshot.defaultTee {
                    stackedSubtitle(value: "\(courseSegment.par(for: defaultTee))", label: "par")
                    stackedSubtitle(value: "\(defaultTee.name)", label: "tee")
                    stackedSubtitle(value: "\(defaultTee.yardage(for: snapshot.holeSegment))", label: "yards")
                } else {
                    stackedSubtitle(value: "???", label: "par")
                    stackedSubtitle(value: "???", label: "tee")
                    stackedSubtitle(value: "???", label: "yards")
                }
                
                Spacer(minLength: 0)
            }
            
            PrimaryButton(
                appearance: .fill,
                title: "Modify course".uppercased(),
                icon: "f303",
                iconWeight: .regular,
                buttonColor: .neutral6,
                theme: palette.theme,
                height: 40,
                fillWidth: false,
                iconSize: 15,
                fontSize: 15,
                isDisabled: .false,
                isLoading: .false,
                onTap: { showCourseModificationView = true }
            )
            .matchedTransitionSource(id: "course", in: courseTransition)
        } else {
            // TODO: What do we put here if the course isn't set (highly unlikely) ??
        }
    }
    
    private func numberOfHolesLabel(for courseSegment: CourseSegment) -> String {
        let holes = courseSegment.courseInfo.totalHoles
        switch (holes, snapshot.holeSegment) {
        case (9, .front9):  return "Front 9"
        case (9, .back9):   return "Back 9"
        default:            return "\(holes)"
        }
    }
    
    private var teeAlertLabel: String {
        guard let defaultTee = snapshot.defaultTee else { return "" }
        var str = "\(defaultTee.yardage(for: snapshot.holeSegment)) yards\n"
        
        if let slope = defaultTee.slope(for: snapshot.holeSegment) {
            str += "\(slope) slope rating\n"
        }
        
        if let course = defaultTee.prettyRating(for: snapshot.holeSegment) {
            str += "\(course) course rating\n"
        }
        
        str += "\(defaultTee.difficultyScore(for: snapshot.holeSegment)) difficulty (out of 100)"
        
        return str
    }
    
    private func stackedSubtitle(value: String, label: String, size: CGFloat = 17) -> some View {
        VStack(spacing: 4) {
            Text(value.uppercased())
                .fontStyle(.poppins, size: size, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            Text(label.uppercased())
                .fontStyle(.poppins, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }
    
    // MARK: - Format
    
    @ViewBuilder
    private var gameFormatSection: some View {
        Text("Game format".uppercased())
            .fontStyle(.poppins, size: 20, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .alignCenter()
        
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentGreen)
                    .frame(width: 80, height: 80)
                
                Icon(name: "f450", size: 40, weight: .regular)
                    .foregroundStyle(.white)
            }
            
            Text(snapshot.gameFormat.type.displayName.uppercased())
                .fontStyle(.poppins, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        
        VStack(spacing: 16) {
            Toggle(isOn: $handicapsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Handicaps".uppercased())
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Allocate strokes for each player")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            })
            .tint(.accentGreen)
            .tileEffect(for: palette)
            .onChange(of: handicapsEnabled) {
                Task {
                    await roundService.toggleHandicaps(handicapsEnabled)
                }
            }
            
            Toggle(isOn: snapshot.requiresTeams ? .true : $teamsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Teams".uppercased())
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Organize and compete as groups")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            })
            .tint(.accentGreen)
            .tileEffect(for: palette)
            .onChange(of: teamsEnabled) {
                Task {
                    await roundService.toggleTeams(teamsEnabled)
                }
            }
        }
    }
    
    // MARK: - Player Mgmt
    
    private enum PlayerTab: String, CaseIterable {
        case roster = "Roster"
        case groups = "Tee Groups"
        case teams = "Teams"
        
        var name: String { self.rawValue }
    }
    
    private enum PlayerCTA: String, CaseIterable {
        case ellipse = "Manage"
        case handicap = "Handicap"
        case group = "Tee group"
        case team = "Team"
        
        var name: String { self.rawValue }
    }
    
    @State private var handicapString = ""
    @FocusState private var focus: String?
    
    @State private var handicapDebouncers: [String: Debounce<Int>] = [:]
    
    @ViewBuilder
    private var playersSection: some View {
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
            
            // TODO: When new players are added, they need to go into the next available group (assuming 4 spots).
            
            if playerTab == .groups {
                ForEach(snapshot.teeGroups, id: \.self) { group in
                    teeGroupTile(for: group)
                }
                
                PrimaryButton(
                    appearance: .fill,
                    title: "Add tee group".uppercased(),
                    icon: "f450",
                    iconWeight: .regular,
                    buttonColor: .neutral6,
                    theme: palette.theme,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { print("add new group") }
                )
            }
        }

        if playerTab == .teams {
            // TODO: Team display here by players
            
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
    
    private func playerRow<Content: View>(
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
    
    // TODO: Move me
    @State private var showTeeTimePicker = false
    @State private var editingTeeGroup: TeeTimeGroup? = nil
    
//    @ViewBuilder
//    private func teeGroupTile(for group: TeeTimeGroup) -> some View {
//        let players = snapshot.participants.filter({ $0.groupID == group.id })
//        let totalHCP = players.reduce(0, { $0 + $1.adjustedHandicap })
//        
//        VStack(spacing: 12) {
//            HStack(spacing: 24) {
//                VStack(spacing: 2) {
//                    Text(group.name)
//                        .fontStyle(.poppins, size: 17, weight: .semibold)
//                        .foregroundStyle(palette.foregroundColor)
//                        .alignLeading()
//                    
//                    if handicapsEnabled {
//                        Text("\(totalHCP) total strokes")
//                            .fontStyle(.poppins, size: 15, weight: .medium)
//                            .foregroundStyle(Color.neutral)
//                            .alignLeading()
//                    }
//                }
//                
//                Spacer(minLength: 0)
//                
//                Menu {
//                    let start = snapshot.holeRange?.startHole ?? 1
//                    let end = snapshot.holeRange?.endHole ?? 18
//                    ForEach(start...end, id: \.self) { hole in
//                        Button(action: {
//                            Haptics.fire(.light)
//                            Task {
//                                var g = group
//                                g.startingHole = hole
//                                try? await roundService.update(g)
//                            }
//                        }) {
//                            Text("Hole \(hole)")
//                        }
//                    }
//                } label: {
//                    stackedSubtitle(value: "\(group.startingHole)", label: "start on")
//                }
//                .onTapGesture {
//                    Haptics.fire(.light)
//                }
//                
//                Button(action: {
//                    Haptics.fire(.light)
//                    editingTeeGroup = group
//                    showTeeTimePicker = true
//                }) {
//                    stackedSubtitle(value: group.teeTime ?? "-", label: "tee time")
//                }
//                
////                Button(action: {
////                    Haptics.fire(.light)
////                    print("todo: showGroupEditor = true")
////                }) {
////                    Chip(
////                        text: "Edit",
////                        weight: .medium,
////                        icon: "f303",
////                        iconWeight: .regular,
////                        iconColor: nil,
////                        size: .xSmall,
////                        style: .fill,
////                        foreground: palette.foregroundColor,
////                        background: Color.neutral6,
////                        theme: palette.theme
////                    )
////                }
//            }
//            
//            Line()
//            
//            ForEach(Array(players.enumerated()), id: \.element) { index, player in
//                HStack(spacing: 8) {
//                    Icon(name: "\(index + 1).circle", size: 15)
//                    
//                    VStack(spacing: 2) {
//                        Text(player.name.fullName)
//                            .fontStyle(.poppins, size: 15, weight: .medium)
//                        
//                        // TODO: Wrap in VStack with subtitle of tee, handicap, or team dot?
//                    }
//
//                    Spacer(minLength: 0)
//                }
//                .foregroundStyle(palette.foregroundColor)
//                .padding(.vertical, 4)
//            }
//            
//            let placeholderCount = max(1, 4 - players.count) // Always ensure you can add another player beyond 4
//            ForEach(0..<placeholderCount, id: \.self) { _ in
//                HStack(spacing: 8) {
//                    Icon(name: "e105", size: 15) // was f055
//                    
//                    Text("Add player")
//                        .fontStyle(.poppins, size: 15, weight: .medium)
//                    
//                    Spacer(minLength: 0)
//                }
//                .foregroundStyle(Color.neutral)
//                .padding(.vertical, 4)
//            }
//        }
//        .outlineEffect(for: palette)
//    }
    
    @ViewBuilder
    private func teeGroupTile(for group: TeeTimeGroup) -> some View {
        let players = snapshot.participants.filter({ $0.groupID == group.id })
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

            // Placeholder slots up to 4
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

            // If 4+ players, always show ONE extra placeholder
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

    //////////////////////////////////////////////////////////
    // MARK: - Header
    //////////////////////////////////////////////////////////

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
                        .foregroundStyle(Color.neutral)
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
                stackedSubtitle(value: "\(group.startingHole)", label: "start on", size: 15)
            }

            // Tee time picker
            Button {
                Haptics.fire(.light)
                editingTeeGroup = group
                showTeeTimePicker = true
            } label: {
                stackedSubtitle(value: group.teeTime ?? "-", label: "tee time", size: 15)
            }
        }
    }

    //////////////////////////////////////////////////////////
    // MARK: - Slot Menu Wrapper
    //////////////////////////////////////////////////////////

    @ViewBuilder
    private func slotMenu<Content: View>(
        content: @escaping () -> Content,
        group: TeeTimeGroup,
        currentPlayer: RoundParticipant?,
        slotIndex: Int
    ) -> some View {

        Menu {
            // Candidates not in this group
            ForEach(snapshot.participants.filter { $0.groupID != group.id }, id: \.self) { candidate in
                Button {
                    Haptics.fire(.light)
                    Task { await assign(player: candidate, to: group, at: slotIndex) }
                } label: {
                    Text("Add \(candidate.name.fullName)")
                }
            }

            // Option to remove the current player
            if let currentPlayer {
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    Task { await remove(player: currentPlayer, from: group) }
                } label: {
                    Text("Remove player")
                }
            }

        } label: {
            content()
                .contentShape(Rectangle())
        }
    }

    //////////////////////////////////////////////////////////
    // MARK: - Player Row
    //////////////////////////////////////////////////////////

    private func playerRow(_ player: RoundParticipant, index: Int) -> some View {
        HStack(spacing: 8) {
            Icon(name: "\(index + 1).circle", size: 15)

            VStack(spacing: 2) {
                Text(player.name.fullName)
                    .fontStyle(.poppins, size: 15, weight: .medium)
            }

            Spacer()
        }
        .foregroundStyle(palette.foregroundColor)
        .padding(.vertical, 4)
    }

    //////////////////////////////////////////////////////////
    // MARK: - Placeholder Row
    //////////////////////////////////////////////////////////

    private func placeholderRow() -> some View {
        HStack(spacing: 8) {
            Icon(name: "plus.circle.dashed", size: 15)
            
            Text("Add player")
                .fontStyle(.poppins, size: 15, weight: .medium)
            
            Spacer()
        }
        .foregroundStyle(Color.neutral)
        .padding(.vertical, 4)
    }

    //////////////////////////////////////////////////////////
    // MARK: - Assign / Remove
    //////////////////////////////////////////////////////////

    private func assign(player: RoundParticipant, to group: TeeTimeGroup, at index: Int) async {
        var p = player
        p.groupID = group.id
        try? await roundService.update(participant: p)
    }

    private func remove(player: RoundParticipant, from group: TeeTimeGroup) async {
        var p = player
        p.groupID = nil
        try? await roundService.update(participant: p)
    }
    
    // MARK: - Tab Styles
    
    @ViewBuilder
    private func underlineTab(for tab: PlayerTab) -> some View {
        let isSelected = tab == playerTab
        
        Button(action: {
            Haptics.fire(.light)
            withAnimation(.linear(duration: 0.2)) {
                playerTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Text(tab.name.uppercased())
                    .fontStyle(.poppins, size: 17, weight: isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? palette.foregroundColor : .neutral)
                
                RoundedRectangle(cornerRadius: 2)
                    .foregroundStyle(Color.accentGreen)
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
    }
    
//    private func nextCTA() {
//        switch playerCTA {
//        case .ellipse:
//            playerCTA = handicapsEnabled ? .handicap : .group
//        case .handicap:
//            playerCTA = .group
//        case .group:
//            playerCTA = teamsEnabled ? .team : .ellipse
//        case .team:
//            playerCTA = .ellipse
//        }
//    }
}

// MARK: - Header & Footer

extension GameLobby {
    fileprivate var headerContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                NavButton(
                    icon: "f00d",
                    color: palette.foregroundColor,
                    theme: palette.theme,
                    onTap: { dismiss() }
                )
                
                VStack(spacing: 2) {
                    Text("Game Lobby".uppercased())
                        .fontStyle(.poppins, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                    
                    if let hostName = snapshot.hostName {
                        Text("Hosted by \(hostName.fullName)")
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .alignCenter()
                    }
                }

                NavButton(
                    icon: "f029",
                    color: palette.foregroundColor,
                    theme: palette.theme,
                    onTap: { showShareCodeView = true }
                )
                .matchedTransitionSource(id: "qr", in: qrTransition)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    fileprivate var footerContent: some View {
        if focus.doesNotExist {
            VStack(spacing: 16) {
                Line()
                
                HStack(spacing: 16) {
                    PrimaryButton(
                        appearance: .fill,
                        icon: "f234",
                        iconWeight: .solid,
                        buttonColor: .neutral6,
                        theme: palette.theme,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { showAddPlayersView = true }
                    )
                    //.matchedTransitionSource(id: "players", in: playersTransition)
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Start round",
                        theme: palette.theme,
                        isDisabled: preventRoundStart,
                        isLoading: .false,
                        onTap: {
                            print("start round")
                        }
                    )
                }
                .padding(.horizontal, 16)
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - View Callers

extension GameLobby {
    func setCourseSegment(to segment: CourseSegment) {
        addBreadcrumb("\(#function) in game lobby")
        printPretty(segment)
        Task {
            await roundService.setCourseSegment(to: segment)
            showCourseModificationView = false
        }
    }
}

// MARK: - Extended View Modifiers

fileprivate extension View {
//    func tileEffect(for palette: DesignPalette) -> some View {
//        self
//            .padding(.vertical, 12)
//            .padding(.horizontal, 16)
//            .background(palette.cardColor)
//            .cornerRadius(radius: 10)
//    }
    
    func tileEffect(for palette: DesignPalette) -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(palette.cardColor)
            .cornerRadius(radius: 12)
    }
    
    func outlineEffect(for palette: DesignPalette) -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .border(palette.borderColor, width: 3, cornerRadius: 12)
            .cornerRadius(radius: 12)
    }
    
    func chevronChip() -> some View {
        HStack(spacing: 6) {
            self
            Image(systemName: "chevron.up.chevron.down")
                .fontStyle(.system, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.neutral6)
        .clipShape(Capsule())
    }
    
    func caretChip() -> some View {
        HStack(spacing: 6) {
            self
            Image(systemName: "chevron.down")
                .fontStyle(.system, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.neutral6)
        .clipShape(Capsule())
    }
}

private enum Mock {
    static var snapshot: RoundSnapshot {
        .init(
            round: MockRound.strokePlay,
            participants: MockParticipants.all,
            teams: MockTeams.all,
            teeGroups: MockTeeGroups.all,
            segments: [MockSegments.mainSegment],
            scoring: []
        )
    }
}

struct GameLobby_Previews: PreviewProvider {
    static var previews: some View {
        GameLobby(mockSnapshot: Mock.snapshot)
            .environmentObject(AppSession())
    }
}
