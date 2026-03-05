//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import AlertToast
import Flow
import SwiftUI

struct GameLobby: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @CappedScaledMetric(relativeTo: .body) var playerAvatarSize: CGFloat = 48
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    var preventRoundStart: Binding<Bool> { .false }
    var isEditMode: Bool = false
    
    /// Sheets
    @State var showShareCodeView = false
    @State var showCourseModificationView = false

    /// Player Management
    @State var playerTab: PlayerTab = .roster
    @State var rosterSort: RosterSortOrder = .abc
    @State var showAddPlayersView = false
    @State var showEditPlayerView = false
    @State var editingPlayer: RoundParticipant?
    @State var draggingPlayer: RoundParticipant?

    /// Toggles
    @State var handicapsEnabled: Bool = false
    @State var teamsEnabled: Bool = false
    
    /// Handicap mutation
    @State var handicapString = ""
    @FocusState var focus: String?
    
    /// Tee Groups
    @State var showTeeTimePicker = false
    @State var editingTeeGroup: TeeTimeGroup? = nil
    
    /// Unassigned players
    @State var expandUnassignedPlayersGroup = false
    @State var expandUnassignedPlayersTeam = false
    
    /// Clearing alerts
    @State var showClearTeeGroupsAlert = false
    @State var showClearTeamsAlert = false
    
    /// Matched Geometry
    @Namespace var qrTransition
    @Namespace var courseTransition
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isCurrentUserHost = false

    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .green)
            
            ObservableScrollView(offset: $scrollOffset, axes: .vertical, showsIndicators: false) {
                ScrollViewReader { proxy in
                    VStack(spacing: 16) {
                        navBarSpacer
                        scrollableContent
                        Padding(.vertical, 120)
                    }
                    .onChange(of: focus) {
                        if let id = focus, playerTab == .roster, handicapsEnabled {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            navigationBar
                .padding(.horizontal, 16)
                .alignTop()
            
            footerContent
                .alignBottom()
        }
        .navigationBarBackButtonHidden()
        .resignKeyboardOnTapGesture()
//        .toolbar(.hidden)
//        .toolbar {
//            ToolbarItemGroup(placement: .keyboard) {
//                if handicapsEnabled, playerTab == .roster {
//                    let roster = sortedRosterParticipants
//                    let currentIndex = roster.firstIndex { $0.id == focus } ?? 0
//
//                    Button {
//                        Haptics.fire(.light)
//                        if currentIndex > 0 {
//                            focus = roster[currentIndex - 1].id
//                        }
//                    } label: {
//                        Image(systemName: "chevron.up")
//                            .fontWeight(.semibold)
//                    }
//                    .disabled(currentIndex == 0)
//
//                    Button {
//                        Haptics.fire(.light)
//                        if currentIndex < roster.count - 1 {
//                            focus = roster[currentIndex + 1].id
//                        }
//                    } label: {
//                        Image(systemName: "chevron.down")
//                            .fontWeight(.semibold)
//                    }
//                    .disabled(currentIndex == roster.count - 1)
//
//                    Spacer()
//
//                    Button { focus = nil } label: {
//                        Image(systemName: "keyboard.chevron.compact.down")
//                    }
//                }
//            }
//        }
        .task {
            if let id = appSession.activeRoundID {
                if roundSession.roundID != id || !roundSession.isRunning {
                    await roundSession.start(for: id)
                }
                if let preQueued = appSession.preQueuedPlayerIDs, !preQueued.isEmpty {
                    switch await FirebaseService.shared.getPlayersByIDs(preQueued) {
                    case .success(let players):
                        try? await roundSession.addPlayers(players, teeGroupSize: 4)
                    case .failure:
                        break
                    }
                    appSession.preQueuedPlayerIDs = nil
                }
            }
        }
        .resignKeyboardOnTapGesture(exceptWhen: focus != nil)
        .onReceive(roundSession.$snapshot, perform: { s in
            handicapsEnabled = s.round.configuration.useHandicaps
            teamsEnabled = s.round.configuration.primaryFormat.configuration.requiresTeams
            Task { @MainActor in
                if let user = await AppData.shared.user {
                    isCurrentUserHost = s.participants.contains { $0.userID == user.id && $0.isHost }
                }
            }
            
            if s.round.status == .live {
                Task {
                    if let playerID = await AppData.shared.getPrimaryPlayer()?.id {
                        await FirebaseService.shared.updatePlayerHistoryAndCourseHistory(
                            playerID: playerID,
                            roundID: s.round.id,
                            participants: s.participants,
                            courseInfo: s.courseInfo,
                            currentPlayerID: playerID
                        )
                    }
                }
                appSession.routeTo(.liveRound, replacingCurrent: true)
            }
        })
        .sheet(isPresented: $showShareCodeView) {
            ShareRoundView(snapshot: roundSession.snapshot)
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
            AddPlayerView(roundSession: roundSession) { players in
                Task {
                    try? await roundSession.addPlayers(players, teeGroupSize: 4)
                    showAddPlayersView = false
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingPlayer) { player in
            ManagePlayerView(roundSession: roundSession, participant: player)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTeeTimePicker) {
            TeeTimePicker(group: $editingTeeGroup) { time in
                guard var group = editingTeeGroup else { return }
                Task {
                    group.teeTime = time
                    try? await roundSession.update(group)
                    showTeeTimePicker = false
                }
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(360)])
        }
        .sheet(isPresented: $roundSession.showRoundActivationErrors) {
            RoundActivationErrorView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
        .alert(
            "Are you sure you want to remove all tee groups?",
            isPresented: $showClearTeeGroupsAlert
        ) {
            Button("Yes, remove", role: .destructive) {
                Task {
                    try? await roundSession.clearAllTeeGroups()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(
            "Are you sure you want to remove all teams?",
            isPresented: $showClearTeamsAlert
        ) {
            Button("Yes, remove", role: .destructive) {
                Task {
                    try? await roundSession.clearAllTeams()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Content
    
    private var scrollableContent: some View {
        VStack(spacing: 16) {
            if roundSession.isLoadingLobbyListeners {
                
                // TODO: Skeleton view for course info
                
            } else {
                courseSection
                gameFormatSection
                gameConfigurationSection
                playerTabPicker
                playersSection
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Navigation Bar & Footer

extension GameLobby {
    fileprivate var navBarSpacer: some View {
        glassTitleCard
            .disabled(true)
            .opacity(0)
            .accessibilityHidden(true)
    }
    
    fileprivate var navigationBar: some View {
        HStack(spacing: 12) {
            NavButton(
                style: .glass,
                icon: "f00d",
                color: palette.foregroundColor,
                onTap: { dismiss() }
            )
            
            Spacer(minLength: 0)
            
            glassTitleCard
            
            Spacer(minLength: 0)
            
            NavButton(
                style: .glass,
                icon: "f029",
                color: palette.foregroundColor,
                onTap: { showShareCodeView = true }
            )
            .matchedTransitionSource(id: "qr", in: qrTransition)
        }
    }
    
    private var glassTitleCard: some View {
        VStack(spacing: 2) {
            Text("Game Lobby".uppercased())
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if let hostName = snapshot.hostName {
                Text("Hosted by \(hostName.fullName)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 24)
        .glassCardEffect()
    }
    
    @ViewBuilder
    fileprivate var footerContent: some View {
        if focus.doesNotExist {
            HStack(spacing: 12) {
//                Button {
//                    Haptics.fire(.light)
//                    showAddPlayersView = true
//                } label: {
//                    Icon(name: "f234", size: 17, weight: .solid)
//                        .foregroundStyle(palette.foregroundColor)
//                }
//                .frame(width: 48, height: 48)
//                .glassCardEffect(shape: .circle, material: .bar, shadowOpacity: 0)
                
                GlassButton(
                    //title: "Add players",
                    icon: "f234",
                    iconWeight: .solid,
                    height: 48,
                    fillWidth: false,
                    iconSize: 20,
                    fontSize: 20,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showAddPlayersView = true }
                )
                
                GlassButton(
                    title: isEditMode ? "Confirm changes" : (isCurrentUserHost ? "Start round" : "Waiting for host..."),
                    tintColor: .accentGreen,
                    isDisabled: .constant(!isEditMode && !isCurrentUserHost),
                    isLoading: $roundSession.isStartingLiveRound,
                    onTap: {
                        if isEditMode {
                            dismiss()
                        } else if isCurrentUserHost {
                            Task {
                                if await roundSession.activateLiveRound() {
                                    appSession.routeTo(.liveRound, replacingCurrent: true)
                                }
                            }
                        }
                    }
                )
            }
            .padding(.horizontal, 16)
        } else {
            let roster = sortedRosterParticipants
            let currentIndex = roster.firstIndex { $0.id == focus } ?? 0
            let canGoUp = currentIndex > 0
            let canGoDown = currentIndex < roster.count - 1

            HStack(spacing: 16) {
//                NavButton(
//                    style: .glass,
//                    icon: "chevron.up",
//                    color: canGoUp ? palette.foregroundColor : Color.neutral3,
//                    onTap: {
//                        if canGoUp {
//                            focus = roster[currentIndex - 1].id
//                        }
//                    }
//                )
//                .disabled(!canGoUp)
//
//                NavButton(
//                    style: .glass,
//                    icon: "chevron.down",
//                    color: canGoDown ? palette.foregroundColor : Color.neutral3,
//                    onTap: {
//                        if canGoDown {
//                            focus = roster[currentIndex + 1].id
//                        }
//                    }
//                )
//                .disabled(!canGoDown)

                Spacer(minLength: 0)

                NavButton(
                    style: .glass,
                    icon: "keyboard.chevron.compact.down",
                    color: palette.foregroundColor,
                    onTap: { focus = nil }
                )
            }
            .padding(16)
        }
    }
}

#Preview("Foursome (No Teams)") {
    GameLobby.LobbyPreview(snapshot: MockLobbyFoursome.snapshot)
}

#Preview("16 Players (4 Teams)") {
    GameLobby.LobbyPreview(snapshot: MockLobbySixteenWithTeams.snapshot)
}

#Preview("Duo") {
    GameLobby.LobbyPreview(snapshot: MockLobbyDuo.snapshot)
}

