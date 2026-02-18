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
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    var preventRoundStart: Binding<Bool> { .false }
    
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
    
    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        ZStack {
            GolfTopology()
                .frame(width: UIScreen.main.bounds.width)
            
            ObservableScrollView(offset: $scrollOffset, axes: .vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    navBarSpacer
                    scrollableContent
                    Padding(.vertical, 120)
                }
            }
            
            navigationBar
                .padding(.horizontal, 16)
                .alignTop()
            
            footerContent
                .alignBottom()
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden)
        .task {
            if let id = appSession.activeRoundID {
                if roundSession.roundID != id || !roundSession.isRunning {
                    await roundSession.start(for: id)
                }
            }
        }
        .resignKeyboardOnTapGesture()
        .onReceive(roundSession.$snapshot, perform: { s in
            handicapsEnabled = s.round.configuration.useHandicaps
            teamsEnabled = s.round.configuration.primaryFormat.configuration.requiresTeams
            
            // When host starts round, all users receive the status update—route everyone to live round
            if s.round.status == .live {
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
                    title: "Start round",
                    tintColor: .accentGreen,
                    isDisabled: .false,
                    isLoading: $roundSession.isStartingLiveRound,
                    onTap: {
                        Task {
                            if await roundSession.activateLiveRound() {
                                appSession.routeTo(.liveRound, replacingCurrent: true)
                            }
                        }
                    }
                )
            }
            .padding(.horizontal, 16)
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

