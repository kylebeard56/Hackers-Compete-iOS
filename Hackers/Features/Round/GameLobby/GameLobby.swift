//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import AlertToast
import Flow
import SwiftUI

/// Carries mode at presentation time so fullScreenCover receives correct columns (teams vs tee groups).
struct PlayerAssignmentSheetItem: Identifiable {
    let id = UUID()
    let mode: PlayerAssignmentMode
}

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
    @State var showFormatSelectionView = false

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
    @State var teamColorsEnabled: Bool = true
    @State var matchupsEnabled: Bool = false
    @State var sequentialTeeStartsEnabled: Bool = false
    @State var secretScoringEnabled: Bool = false
    
    /// Handicap mutation
    @State var handicapString = ""
    @FocusState var focus: String?
    
    /// Tee Groups
    @State var showTeeTimePicker = false
    @State var editingTeeGroup: TeeTimeGroup? = nil
    
    /// Unassigned players
    @State var expandUnassignedPlayersGroup = false
    @State var expandUnassignedPlayersTeam = false
    
    /// Quick assign grid — use item so mode is captured at presentation time
    @State var playerAssignmentSheetItem: PlayerAssignmentSheetItem?
    
    /// Matched Geometry
    @Namespace var qrTransition
    @Namespace var courseTransition
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isCurrentUserHost = false
    @State private var previousRoundStatus: RoundStatus?
    @State private var didTrackLobbyView = false
    @State private var isSyncingTeams = false

    /// Series context for league-handicap lobby lock (client-side only).
    @State var isSeriesCommissioner = false
    @State var seriesLeagueHandicapsEnabled = false

    @State var teamRenameTarget: RoundTeam?
    @State var teamRenameDraft: String = ""

    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    private var teeGroupSyncKey: String {
        guard snapshot.isSharedScoreSource else { return "" }
        let groups = snapshot.teeGroups.sorted { $0.index < $1.index }.map(\.id).joined(separator: ",")
        let assignments = snapshot.participants.sorted { $0.id < $1.id }.map { "\($0.id):\($0.groupID ?? "")" }.joined(separator: ",")
        return "\(groups)|\(assignments)"
    }

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
        .captureScreen("game_lobby")
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
        .task(id: appSession.activeSeriesID) {
            guard let sid = appSession.activeSeriesID, sid.isPopulated else {
                await MainActor.run {
                    isSeriesCommissioner = false
                    seriesLeagueHandicapsEnabled = false
                }
                return
            }
            async let seriesResult = FirebaseService.shared.fetchSeries(id: sid)
            async let members = FirebaseService.shared.fetchSeriesMembers(seriesID: sid)
            let user = await AppData.shared.user
            let handicapsOn: Bool
            switch await seriesResult {
            case .success(let series):
                handicapsOn = series.handicapConfig.isEnabled
            case .failure:
                handicapsOn = false
            }
            let memberList = await members
            let isComm: Bool = {
                guard let uid = user?.id else { return false }
                return memberList.contains { $0.userID == uid && $0.role == .commissioner }
            }()
            await MainActor.run {
                seriesLeagueHandicapsEnabled = handicapsOn
                isSeriesCommissioner = isComm
            }
        }
        .task {
            TelemetryService.shared.setContext(roundID: appSession.activeRoundID, seriesID: appSession.activeSeriesID)
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
            teamColorsEnabled = s.configuration.usesTeamColors
            matchupsEnabled = s.configuration.resolvedCompetitionScope == .matchup
            sequentialTeeStartsEnabled = s.configuration.usesSequentialTeeStarts
            secretScoringEnabled = s.isSecretScoring
            Task { @MainActor in
                if let user = await AppData.shared.user {
                    isCurrentUserHost = s.participants.contains { $0.userID == user.id && $0.isHost }
                }
            }

            trackLobbyViewedIfNeeded(snapshot: s)

            guard s.round.id == appSession.activeRoundID else { return }
            if s.round.status == .live {
                appSession.routeTo(.liveRound, replacingCurrent: true)
            }
        })
        .alert("Rename team", isPresented: Binding(
            get: { teamRenameTarget != nil },
            set: { if !$0 { teamRenameTarget = nil } }
        )) {
            TextField("Team name", text: $teamRenameDraft)
            Button("Cancel", role: .cancel) {
                teamRenameTarget = nil
            }
            Button("Save") {
                let trimmed = teamRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let t = teamRenameTarget, trimmed.isPopulated else {
                    teamRenameTarget = nil
                    return
                }
                Task {
                    var u = t
                    u.name = trimmed
                    try? await roundSession.update(u)
                    await MainActor.run { teamRenameTarget = nil }
                }
            }
        } message: {
            Text("Shown to everyone in this round.")
        }
        .onChange(of: teeGroupSyncKey) {
            guard !teeGroupSyncKey.isEmpty, !isSyncingTeams else { return }
            isSyncingTeams = true
            Task {
                try? await roundSession.syncTeamsToTeeGroups()
                await MainActor.run { isSyncingTeams = false }
            }
        }
        .sheet(isPresented: $showShareCodeView) {
            ShareRoundView(snapshot: roundSession.snapshot)
                .navigationTransition(.zoom(sourceID: "qr", in: qrTransition))
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $playerAssignmentSheetItem) { item in
            PlayerAssignmentGridView(
                mode: item.mode,
                participants: snapshot.participants,
                snapshot: snapshot,
                onAssignmentChange: { participant, columnID, slotIndex in
                    var p = participant
                    if case .teams = item.mode {
                        p.teamID = columnID
                    } else if case .teeGroups = item.mode {
                        p.groupID = columnID
                        p.teeOrder = slotIndex
                    }
                    Task { try? await roundSession.update(participant: p) }
                },
                onUnassign: { participant, columnID in
                    var p = participant
                    if case .teams = item.mode {
                        p.teamID = nil
                    } else if case .teeGroups = item.mode {
                        p.groupID = nil
                        p.teeOrder = nil
                    }
                    Task { try? await roundSession.update(participant: p) }
                },
                onAdd: {
                    if case .teams = item.mode {
                        Task { try? await roundSession.createTeam() }
                    } else if case .teeGroups = item.mode {
                        Task { try? await roundSession.createTeeGroup() }
                    }
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFormatSelectionView) {
            FormatSelectionView(
                currentTemplateID: snapshot.configuration.formatSummary?.templateID ?? FormatTemplateRegistry.strokePlayGross.id,
                requiresTeams: snapshot.requiresTeams,
                onSelect: { template in
                    Task { await roundSession.setFormat(template) }
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCourseModificationView) {
            CourseSelectionView(
                viewModel: .init(course: snapshot.course, tee: snapshot.defaultTee, holeSegment: snapshot.holeSegment),
                presentationType: .sheet,
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
            .interactiveDismissDisabled()
        }
        .sheet(item: $editingPlayer) { player in
            ManagePlayerView(
                roundSession: roundSession,
                participant: player,
                seriesHandicapLockActive: seriesHandicapLobbyLockActive,
                isSeriesCommissioner: isSeriesCommissioner
            )
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

private extension GameLobby {
    func trackLobbyViewedIfNeeded(snapshot: RoundSnapshot) {
        guard !didTrackLobbyView else { return }
        guard snapshot.round.id.isPopulated else { return }
        didTrackLobbyView = true
        addEvent(
            "round_setup.lobby_viewed",
            eventProps: telemetryRoundProperties(
                snapshot: snapshot,
                extra: [
                    "is_edit_mode": isEditMode
                ]
            )
        )
    }
}

// MARK: - Navigation Bar & Footer

extension GameLobby {
    /// Series round in app session + league handicaps on (drives client-side stroke lock for non-commissioners).
    var seriesHandicapLobbyLockActive: Bool {
        guard let sid = appSession.activeSeriesID, sid.isPopulated else { return false }
        return seriesLeagueHandicapsEnabled
    }

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
                GlassButton(
                    title: "Add",
                    icon: "f234",
                    iconWeight: .solid,
                    height: 48,
                    fillWidth: false,
                    iconSize: 20,
                    fontSize: 17,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showAddPlayersView = true }
                )
                
                PrimaryButton(
                    appearance: .fill,
                    title: isEditMode ? "Done" : (isCurrentUserHost ? "Start round" : "Waiting for host..."),
                    labelColor: .white,
                    buttonColor: (isEditMode || isCurrentUserHost) ? .accentGreen : .neutral3,
                    theme: palette.theme,
                    height: 52,
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
//            let canGoUp = currentIndex > 0
//            let canGoDown = currentIndex < roster.count - 1

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

#Preview("16 Players with Matchups") {
    GameLobby.LobbyPreview(snapshot: MockLobbySixteenWithTeams.snapshotWithMatchups)
}

#Preview("Duo") {
    GameLobby.LobbyPreview(snapshot: MockLobbyDuo.snapshot)
}

#Preview("4 Teams with Matchups") {
    GameLobby.LobbyPreview(snapshot: MockLobbyMatchups.snapshot)
}
