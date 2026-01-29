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
    
    var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

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
                if roundSession.roundID != id || !roundSession.isRunning {
                    await roundSession.start(for: id)
                }
            }
        }
        .resignKeyboardOnTapGesture()
        .onReceive(roundSession.$snapshot, perform: { s in
            // This is the real-time updater
            print("SNAPSHOT UPDATED")
            handicapsEnabled = s.round.configuration.useHandicaps
            teamsEnabled = s.round.configuration.primaryFormat.configuration.requiresTeams
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
                    // TODO: handle error display here before dismissing?
                    print("BUG CHECKPOINT | Adding players to the round on completion from AddPlayerView.")
                    printPretty(players)
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
                    // TODO: Handle errors here
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
                    // TODO: Handle errors here
                    try? await roundSession.clearAllTeams()
                }
            }
            Button("Cancel", role: .cancel) { }
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
//                        try? await roundSession.update(participant: handicapParticipant)
//                        showHandicapEntry = false
//                    }
//                }
//            )
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//            .presentationCompactAdaptation(.none)
//        }
    }
    
    // MARK: - Content
    
    private var scrollableContent: some View {
        VStack(spacing: 32) {
            if roundSession.isLoadingLobbyListeners {
                
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
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Start round",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .false,
                        isLoading: $roundSession.isStartingLiveRound,
                        onTapAsync: {
                            if await roundSession.activateLiveRound() {
                                appSession.routeTo(.liveRound)
                            }
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

struct GameLobby_Previews: PreviewProvider {
    static var previews: some View {
        GameLobby()
            .environmentObject(AppSession())
    }
}
