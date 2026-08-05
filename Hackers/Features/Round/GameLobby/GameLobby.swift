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

struct StablefordPointsEditorItem: Identifiable {
    let id = "stableford-points"
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
    @State var handicapEntryFormat: HandicapEntryFormat = .strokes
    @State var handicapNormalizationMode: HandicapNormalizationMode = .off
    @State var handicapStrokeBasis: SeriesHandicapStrokeBasis?
    
    /// Handicap mutation
    @State var handicapString = ""
    @State var sharedScoreAllowanceText = ""
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
    @State private var currentUserID: String?
    @State private var previousRoundStatus: RoundStatus?
    @State private var didTrackLobbyView = false
    @State private var isSyncingTeams = false
    @State private var isCorrectingMissingCourseHandicapData = false
    @State private var isShowingRoundNameAlert = false
    @State private var roundNameDraft = ""

    /// Series context for league-handicap lobby lock (client-side only).
    @State var isSeriesCommissioner = false
    @State var seriesLeagueHandicapsEnabled = false
    @State var seriesLeagueHandicapMaximum: Int?

    @State var teamEditorTarget: RoundTeam?
    @State var stablefordPointsEditorItem: StablefordPointsEditorItem?

    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    private var teeGroupSyncKey: String {
        guard snapshot.shouldAutoMirrorTeeGroupsToTeams else { return "" }
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
                    seriesLeagueHandicapMaximum = nil
                }
                return
            }
            async let seriesResult = FirebaseService.shared.fetchSeries(id: sid)
            async let members = FirebaseService.shared.fetchSeriesMembers(seriesID: sid)
            let user = await AppData.shared.user
            let handicapsOn: Bool
            let handicapMaximum: Int?
            switch await seriesResult {
            case .success(let series):
                handicapsOn = series.handicapConfig.isEnabled
                handicapMaximum = series.handicapConfig.config.maximumHandicap
            case .failure:
                handicapsOn = false
                handicapMaximum = nil
            }
            let memberList = await members
            let isComm: Bool = {
                guard let uid = user?.id else { return false }
                return memberList.contains { $0.userID == uid && $0.role == .commissioner }
            }()
            await MainActor.run {
                seriesLeagueHandicapsEnabled = handicapsOn
                seriesLeagueHandicapMaximum = handicapsOn ? handicapMaximum : nil
                isSeriesCommissioner = isComm
            }
        }
        .task {
            TelemetryService.shared.setContext(roundID: appSession.activeRoundID, seriesID: appSession.activeSeriesID)
            currentUserID = await AppData.shared.user?.id
            if let id = appSession.activeRoundID {
                await roundSession.activate(roundID: id, profile: .lobby)
                if !isEditMode {
                    appSession.persistRoundResume(destination: .lobby)
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
        .onReceive(HackersNotification.appSceneDidBecomeActive.publisher()) { _ in
            guard let id = appSession.activeRoundID else { return }
            Task { await roundSession.activate(roundID: id, profile: .lobby) }
        }
        .resignKeyboardOnTapGesture(exceptWhen: focus != nil)
        .onReceive(roundSession.$snapshot, perform: { s in
            handicapsEnabled = s.round.configuration.useHandicaps
            teamsEnabled = s.round.configuration.primaryFormat.configuration.requiresTeams
            teamColorsEnabled = s.configuration.usesTeamColors
            matchupsEnabled = s.configuration.resolvedCompetitionScope == .matchup
            sequentialTeeStartsEnabled = s.configuration.usesSequentialTeeStarts
            secretScoringEnabled = s.isSecretScoring
            handicapEntryFormat = s.configuration.handicapEntryFormat
            handicapNormalizationMode = s.configuration.handicapNormalizationMode
            handicapStrokeBasis = s.configuration.handicapStrokeBasis
            if s.configuration.handicapEntryFormat == .courseHandicap,
               !HandicapCalculator.hasCourseHandicapData(courseSegment: s.courseSegment) {
                handicapEntryFormat = .strokes
                if !isCorrectingMissingCourseHandicapData {
                    isCorrectingMissingCourseHandicapData = true
                    Task {
                        await roundSession.setHandicapEntryFormat(.strokes, maximumHandicap: effectiveSeriesLeagueHandicapMaximum)
                        await MainActor.run { isCorrectingMissingCourseHandicapData = false }
                    }
                }
            } else {
                isCorrectingMissingCourseHandicapData = false
            }
            sharedScoreAllowanceText = Self.allowanceText(
                from: s.configuration.sharedScoreHandicapConfig ?? s.resolvedActiveTemplate.requirements.defaultHandicapConfig
            )
            if let currentUserID {
                isCurrentUserHost = s.participants.contains { $0.userID == currentUserID && $0.isHost }
            } else {
                isCurrentUserHost = false
            }

            trackLobbyViewedIfNeeded(snapshot: s)

            guard s.round.id == appSession.activeRoundID else { return }
            if s.round.status == .live {
                appSession.routeTo(.liveRound, replacingCurrent: true)
            }
        })
        .alert("Round name", isPresented: $isShowingRoundNameAlert) {
            TextField("Tap to name", text: $roundNameDraft)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                Task { await roundSession.setRoundName(roundNameDraft) }
            }
        } message: {
            Text("Shown in this lobby and round history.")
        }
        .onChange(of: roundNameDraft) { _, newValue in
            guard newValue.count > Round.nameCharacterLimit else { return }
            roundNameDraft = String(newValue.prefix(Round.nameCharacterLimit))
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
                snapshot: snapshot,
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
                onModification: { s in setCourseSegment(to: s) },
                onRemoveModification: { unsetCourseSegment() }
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
                isSeriesCommissioner: isSeriesCommissioner,
                seriesHandicapMaximum: effectiveSeriesLeagueHandicapMaximum
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $teamEditorTarget) { team in
            RoundTeamEditorSheet(roundSession: roundSession, team: team)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $stablefordPointsEditorItem) { _ in
            RoundStablefordPointsEditorSheet(
                roundSession: roundSession,
                points: snapshot.configuration.resolvedStablefordPoints
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

extension GameLobby {
    static func allowanceText(from config: HandicapConfiguration) -> String {
        guard let percentages = config.positionPercentages, percentages.isPopulated else { return "" }
        return percentages.map { percentage in
            let whole = percentage * 100
            if abs(whole - whole.rounded()) < 0.000_001 {
                return "\(Int(whole.rounded()))"
            }
            return String(format: "%.1f", whole)
        }
        .joined(separator: ",")
    }

    static func allowancePercentages(from text: String) -> [Double] {
        text
            .split(separator: ",")
            .compactMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let value = Double(trimmed), value >= 0 else { return nil }
                return value > 1 ? value / 100 : value
            }
    }

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
        if let sid = appSession.activeSeriesID, sid.isPopulated {
            return seriesLeagueHandicapsEnabled || snapshot.configuration.leagueHandicapMaximum != nil
        }
        return snapshot.configuration.leagueHandicapMaximum != nil
    }

    var effectiveSeriesLeagueHandicapMaximum: Int? {
        seriesLeagueHandicapMaximum ?? snapshot.configuration.leagueHandicapMaximum
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
                onTap: {
                    if !isEditMode {
                        appSession.clearRoundResume()
                    }
                    dismiss()
                }
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
        Button(action: showRoundNameEditor) {
            VStack(spacing: 2) {
                Text(snapshot.round.name ?? "Tap to name")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Game Lobby")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 24)
            .glassCardEffect()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Round name")
        .accessibilityValue(snapshot.round.name ?? "Tap to name")
        .accessibilityHint("Double tap to edit the round name.")
    }

    private func showRoundNameEditor() {
        Haptics.fire(.light)
        roundNameDraft = snapshot.round.name ?? ""
        isShowingRoundNameAlert = true
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

private struct RoundTeamEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var roundSession: RoundSession
    let team: RoundTeam

    @State private var name = ""
    @State private var color: TeamColor = .red
    @State private var lastPreset: TeamColor = .red
    @State private var useCustomColor = false
    @State private var customBaseColor = Color.red
    @State private var customBrightnessAdjust: CGFloat = 0
    @State private var isSaving = false

    @FocusState private var nameFieldFocused: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var effectiveCustomColor: Color {
        if customBrightnessAdjust > 0 {
            return customBaseColor.lighten(by: customBrightnessAdjust)
        }
        if customBrightnessAdjust < 0 {
            return customBaseColor.darken(by: -customBrightnessAdjust)
        }
        return customBaseColor
    }

    private var customChipForeground: Color {
        guard useCustomColor else { return palette.foregroundColor }
        return AccessibleTeamColorStyle.resolve(
            teamColor: effectiveCustomColor,
            palette: palette,
            colorScheme: colorScheme,
            surface: .solidFill
        ).solidFillText
    }

    private var customChipBackground: Color {
        useCustomColor
            ? effectiveCustomColor
            : palette.cardEmbeddedRowBackground.opacity(colorScheme == .dark ? 0.35 : 0.65)
    }

    private var fallbackName: String {
        if useCustomColor { return "Custom Team" }
        if TeamColor.cycle.contains(color) { return "\(color.name) Team" }
        return "Team \(max(team.index, 1))"
    }

    private var savedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isPopulated ? trimmed : fallbackName
    }

    private var savedColorToken: String {
        if useCustomColor {
            return ColorValue(color: effectiveCustomColor).hex ?? TeamColor.red.rawValue
        }
        return color.rawValue
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Edit Team",
                    subtitle: "Name and color apply only to this round.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    TextField("Team name", text: $name)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .borderedContentStyle(
                            isActive: nameFieldFocused,
                            theme: palette.theme,
                            fill: palette.cardEmbeddedRowBackground
                        )
                        .accessibilityLabel("Team name")

                    SeriesSheetCard(palette: palette) {
                        Text("Team color".uppercased())
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(TeamColor.cycle, id: \.rawValue) { option in
                                    Button {
                                        useCustomColor = false
                                        color = option
                                        lastPreset = option
                                        Haptics.fire(.light)
                                    } label: {
                                        let style = AccessibleTeamColorStyle.resolve(
                                            teamColor: option.value,
                                            palette: palette,
                                            colorScheme: colorScheme,
                                            surface: .solidFill
                                        )
                                        Chip(
                                            text: option.name,
                                            size: .small,
                                            foreground: !useCustomColor && color == option ? style.solidFillText : style.readableText,
                                            background: !useCustomColor && color == option ? option.value : option.value.opacity(colorScheme.translucent)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(option.name) team color")
                                    .accessibilityAddTraits(selectionTraits(!useCustomColor && color == option))
                                }

                                Button {
                                    if !useCustomColor {
                                        customBaseColor = (color == .none || color == .unknown) ? lastPreset.value : color.value
                                        customBrightnessAdjust = 0
                                    }
                                    useCustomColor = true
                                    Haptics.fire(.light)
                                } label: {
                                    Chip(
                                        text: "Custom",
                                        size: .small,
                                        foreground: customChipForeground,
                                        background: customChipBackground
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Custom team color")
                                .accessibilityAddTraits(selectionTraits(useCustomColor))

                                Button {
                                    useCustomColor = false
                                    color = .none
                                    Haptics.fire(.light)
                                } label: {
                                    let noneFill = Color.neutral4
                                    Chip(
                                        text: "None",
                                        size: .small,
                                        foreground: !useCustomColor && color == .none
                                            ? Color.accessibleLabelOnSolidBackground(background: noneFill, colorScheme: colorScheme)
                                            : palette.foregroundColor,
                                        background: !useCustomColor && color == .none
                                            ? noneFill
                                            : palette.cardEmbeddedRowBackground.opacity(colorScheme == .dark ? 0.35 : 0.65)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("No team color")
                                .accessibilityAddTraits(selectionTraits(!useCustomColor && color == .none))
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)

                        if useCustomColor {
                            customColorControls
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(palette.foregroundColor)
                            }
                            Text(isSaving ? "Saving..." : "Save Team")
                                .fontStyle(kFontName, size: 16, weight: .semibold)
                                .foregroundStyle(isSaving ? palette.foregroundColor : palette.backgroundColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSaving ? Color.neutral3 : palette.foregroundColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .task(id: team.id) {
            loadTeam()
        }
    }

    @ViewBuilder
    private var customColorControls: some View {
        VStack(spacing: 10) {
            SeriesSheetRow(palette: palette) {
                HStack {
                    Text("Color")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Spacer(minLength: 0)
                    ColorPicker("", selection: $customBaseColor, supportsOpacity: false)
                        .labelsHidden()
                        .accessibilityLabel("Custom team color picker")
                }
            }

            SeriesSheetRow(palette: palette) {
                HStack {
                    Text("Brightness")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        Button {
                            customBrightnessAdjust = max(-100, customBrightnessAdjust - 5)
                            Haptics.fire(.light)
                        } label: {
                            Icon(name: "f056", size: 20, maxSize: 20, weight: .regular)
                                .foregroundStyle(customBrightnessAdjust == -100 ? Color.neutral3 : palette.foregroundColor)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Darken custom team color")

                        Text("\(Int(customBrightnessAdjust))")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(minWidth: 36)
                            .accessibilityLabel("Brightness \(Int(customBrightnessAdjust))")

                        Button {
                            customBrightnessAdjust = min(100, customBrightnessAdjust + 5)
                            Haptics.fire(.light)
                        } label: {
                            Icon(name: "f055", size: 20, maxSize: 20, weight: .regular)
                                .foregroundStyle(customBrightnessAdjust == 100 ? Color.neutral3 : palette.foregroundColor)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Lighten custom team color")
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func loadTeam() {
        name = team.name
        customBrightnessAdjust = 0

        let raw = team.color.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            useCustomColor = true
            customBaseColor = ColorValue(hex: raw).color
            color = .none
            lastPreset = .red
            return
        }

        useCustomColor = false
        if raw == TeamColor.none.rawValue {
            color = .none
            lastPreset = .red
        } else if let teamColor = TeamColor(rawValue: raw), TeamColor.cycle.contains(teamColor) {
            color = teamColor
            lastPreset = teamColor
            customBaseColor = teamColor.value
        } else {
            color = .none
            lastPreset = .red
            customBaseColor = TeamColor.red.value
        }
    }

    private func selectionTraits(_ isSelected: Bool) -> AccessibilityTraits {
        isSelected ? .isSelected : AccessibilityTraits()
    }

    private func save() async {
        guard !isSaving else { return }
        await MainActor.run { isSaving = true }

        var updatedTeam = team
        updatedTeam.name = savedName
        updatedTeam.color = savedColorToken
        updatedTeam.lastUpdatedAt = .init()

        do {
            try await roundSession.update(updatedTeam)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run { isSaving = false }
        }
    }
}

private struct RoundStablefordPointsEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var roundSession: RoundSession
    let points: RoundStablefordPoints

    @State private var draft = RoundStablefordPoints.classic
    @State private var isSaving = false

    @FocusState private var focusedPoint: StablefordPointBucket?

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var selectedPreset: RoundStablefordPointsPreset? {
        RoundStablefordPointsPreset.matching(draft)
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Stableford Points",
                    subtitle: "These values apply only to this round.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    presetChips

                    SeriesSheetCard(palette: palette) {
                        stablefordPointRow(
                            title: "Albatross+",
                            score: "-3 or better",
                            value: $draft.albatrossOrBetter,
                            bucket: .albatross
                        )
                        stablefordPointRow(title: "Eagle", score: "-2", value: $draft.eagle, bucket: .eagle)
                        stablefordPointRow(title: "Birdie", score: "-1", value: $draft.birdie, bucket: .birdie)
                        stablefordPointRow(title: "Par", score: "0", value: $draft.par, bucket: .par)
                        stablefordPointRow(title: "Bogey", score: "+1", value: $draft.bogey, bucket: .bogey)
                        stablefordPointRow(title: "Double bogey", score: "+2", value: $draft.doubleBogey, bucket: .doubleBogey)
                        stablefordPointRow(title: "Triple bogey", score: "+3", value: $draft.tripleBogeyOrWorse, bucket: .tripleBogey)
                        stablefordPointRow(
                            title: "Quadruple+",
                            score: "+4 or worse",
                            value: $draft.quadrupleBogeyOrWorse,
                            bucket: .quadrupleBogey
                        )
                    }

                    Text("Saved values clamp from \(RoundStablefordPoints.minimumPointValue) to \(RoundStablefordPoints.maximumPointValue).")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    HStack(spacing: 12) {
                        if focusedPoint != nil {
                            Button {
                                focusedPoint = nil
                                Haptics.fire(.light)
                            } label: {
                                Icon(name: "keyboard.chevron.compact.down", size: 20, weight: .regular)
                                    .foregroundStyle(palette.foregroundColor)
                                    .frame(width: 52, height: 52)
                                    .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                                    .whiteGlassCardShadow(color: palette.shadowColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Dismiss keyboard")
                        }

                        Button {
                            Task { await save() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(palette.foregroundColor)
                                }
                                Text(isSaving ? "Saving..." : "Save points")
                                    .fontStyle(kFontName, size: 16, weight: .semibold)
                                    .foregroundStyle(isSaving ? palette.foregroundColor : palette.backgroundColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSaving ? Color.neutral3 : palette.foregroundColor)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .task(id: points) {
            draft = points
        }
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RoundStablefordPointsPreset.allCases) { preset in
                    Button {
                        draft = preset.points
                        focusedPoint = nil
                        Haptics.fire(.light)
                    } label: {
                        Chip(
                            text: preset.name,
                            size: .small,
                            foreground: selectedPreset == preset ? palette.backgroundColor : palette.foregroundColor,
                            background: selectedPreset == preset
                                ? palette.foregroundColor
                                : palette.cardEmbeddedRowBackground.opacity(colorScheme == .dark ? 0.35 : 0.65)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.name) Stableford preset")
                    .accessibilityAddTraits(selectionTraits(selectedPreset == preset))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    private func stablefordPointRow(
        title: String,
        score: String,
        value: Binding<Int>,
        bucket: StablefordPointBucket
    ) -> some View {
        SeriesSheetRow(palette: palette) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text(score)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    pointStepButton(systemName: "minus", label: "Decrease \(title) points") {
                        value.wrappedValue = clampedPointValue(value.wrappedValue - 1)
                    }

                    TextField("0", value: value, format: .number)
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .focused($focusedPoint, equals: bucket)
                        .frame(width: 56)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(palette.cardEmbeddedRowBackground)
                        )
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(title) points")
                        .accessibilityValue("\(value.wrappedValue)")

                    pointStepButton(systemName: "plus", label: "Increase \(title) points") {
                        value.wrappedValue = clampedPointValue(value.wrappedValue + 1)
                    }
                }
            }
        }
    }

    private func pointStepButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            Haptics.fire(.light)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.cardEmbeddedRowBackground))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func clampedPointValue(_ value: Int) -> Int {
        min(RoundStablefordPoints.maximumPointValue, max(RoundStablefordPoints.minimumPointValue, value))
    }

    private func selectionTraits(_ isSelected: Bool) -> AccessibilityTraits {
        isSelected ? .isSelected : AccessibilityTraits()
    }

    private func save() async {
        guard !isSaving else { return }
        focusedPoint = nil
        await MainActor.run { isSaving = true }
        await roundSession.setStablefordPoints(draft.clamped)
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }
}

private enum StablefordPointBucket: Hashable {
    case albatross
    case eagle
    case birdie
    case par
    case bogey
    case doubleBogey
    case tripleBogey
    case quadrupleBogey
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
