//
//  GameLobby.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import AlertToast
import Flow
import SwiftUI


// TODO: Tee Groups
// 1. Add default group 1 on creation
// 2. Once 5+ players added, group 2
// 3. Repeat every interval of 4 + 1

// TODO: Teams
// 1. If a user flips on teams, we need to create two teams (red vs blue) and expand to green, yellow, orange, purple
// MVP is team color (max of 5 teams -> Red, Blue, Green, Purple, Orange)

struct GameLobby: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    
    @StateObject var roundService = RoundService()
    
    private var snapshot: RoundSnapshot { roundService.snapshot }
    
    private var preventRoundStart: Binding<Bool> { .true }
    
//    private var course: Course? {
//        guard let info = snapshot.courseInfo else { return nil }
//        return Course(info: info)
//    }
    
    @State private var showShareCodeView = false
    @State private var showCourseModificationView = false
    @State private var showTeeInfoPopover = false
    @State private var showPlayerManagementView = false
    
    @Namespace private var qrTransition
    @Namespace private var courseTransition
    @Namespace private var playersTransition
    
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
        .sheet(isPresented: $showShareCodeView) {
            ShareRoundView(snapshot: snapshot)
                .navigationTransition(.zoom(sourceID: "qr", in: qrTransition))
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCourseModificationView) {
            CourseSelectionView(
                viewModel: .init(course: snapshot.course, tee: snapshot.defaultTee),
                onModification: { s in setCourseSegment(to: s) }
            )
            .navigationTransition(.zoom(sourceID: "course", in: courseTransition))
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlayerManagementView) {
            AddPlayerView(
                snapshot: snapshot,
                onConfirm: { players in printPretty(players) }
            )
            .navigationTransition(.zoom(sourceID: "players", in: playersTransition))
            .presentationDragIndicator(.visible)
        }
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
    
    private func stackedSubtitle(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value.uppercased())
                .fontStyle(.poppins, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            Text(label.uppercased())
                .fontStyle(.poppins, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }
    
    // MARK: - Format
    
    @State private var handicapsEnabled: Bool = false
    @State private var teamsEnabled: Bool = false
    
    @ViewBuilder
    private var gameFormatSection: some View {
        Text("Game format".uppercased())
            .fontStyle(.poppins, size: 20, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .alignCenter()
        
        //            Text("No game selected")
        //                .fontStyle(.poppins, size: 15, weight: .regular)
        //                .foregroundStyle(Color.neutral)
        
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
        }
        
        //        PrimaryButton(
        //            appearance: .fill,
        //            title: "Pick game".uppercased(), // TODO: "Change game" if set
        //            icon: "f303",
        //            iconWeight: .regular,
        //            buttonColor: .neutral6,
        //            theme: palette.theme,
        //            fillWidth: false,
        //            isDisabled: .false,
        //            isLoading: .false,
        //            onTap: { showCourseModificationView = true }
        //        )
    }
    
    //    @ViewBuilder
    //    private func gameFormatTile() -> some View {
    //        VStack(spacing: 16) {
    //            HStack {
    //                Text("Format")
    //                    .fontStyle(.poppins, size: 15, weight: .medium)
    //                    .foregroundStyle(palette.foregroundColor)
    //
    //                Spacer(minLength: 0)
    //
    //                Text(gameFormat.type.displayName)
    //                    .fontStyle(.poppins, size: 15, weight: .medium)
    //                    .foregroundStyle(palette.foregroundColor)
    //                    .chevronChip()
    //            }
    //            .alignLeading()
    //
    //            Toggle(isOn: $handicapsEnabled, label: {
    //                Text("Handicaps")
    //                    .fontStyle(.poppins, size: 15, weight: .medium)
    //                    .foregroundStyle(palette.foregroundColor)
    //            })
    //            .tint(.accentPurple)
    //
    //            Toggle(isOn: requiresTeams ? .true : $teamsEnabled, label: {
    //                Text("Teams")
    //                    .fontStyle(.poppins, size: 15, weight: .medium)
    //                    .foregroundStyle(palette.foregroundColor)
    //            })
    //            .tint(.accentPurple)
    //
    //            if requiresTeams {
    //                Text("This game requires teams.")
    //                    .fontStyle(.poppins, size: 11, weight: .regular)
    //                    .foregroundStyle(Color.neutral)
    //                    .lineLimit(1)
    //                    .minimumScaleFactor(0.6)
    //                    .alignLeading()
    //            }
    //        }
    //        //.tileEffect(for: palette)
    //        .onAppear() {
    //            teamsEnabled = requiresTeams
    //        }
    //    }
    
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
    
    @State private var playerTab: PlayerTab = .roster
    @State private var playerCTA: PlayerCTA = .ellipse
    
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
        
        // TODO: Make this some styled selector
//        HStack(spacing: 16) {
//            HStack {
//                Icon(name: "list", size: 15, weight: .regular)
//                    .foregroundStyle(Color.neutral) // foreground is selected with outline?
//                Text("List")
//                    .fontStyle(.poppins, size: 15, weight: .semibold)
//                    .foregroundStyle(Color.neutral)
//            }
//            
//            HStack {
//                Icon(name: "grid", size: 15, weight: .regular)
//                    .foregroundStyle(Color.neutral)
//                Text("Grid")
//                    .fontStyle(.poppins, size: 15, weight: .semibold)
//                    .foregroundStyle(Color.neutral)
//            }
//        }
        
        ForEach(snapshot.participants, id: \.self) { participant in
            playerRow(for: participant) {
                switch playerTab {
                case .roster:
                    if handicapsEnabled {
                        HStack(spacing: 4) {
                            Text("Stroke")
                                .fontStyle(.poppins, size: 13, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                            
                            Text("\(participant.originalHandicap)")
                                .fontStyle(.poppins, size: 20, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                        }
                        
                        Text("Stroke entry")
                    }
                case .groups:
                    Text("Tee group menu")
                case .teams:
                    Text("Team menu")
                }
            }
            .tileEffect(for: palette)
        }
        
        PrimaryButton(
            appearance: .fill,
            title: "Add players".uppercased(),
            icon: "f303",
            iconWeight: .regular,
            buttonColor: .neutral6,
            theme: palette.theme,
            fillWidth: false,
            isDisabled: .false,
            isLoading: .false,
            onTap: { showPlayerManagementView = true }
        )
        .matchedTransitionSource(id: "players", in: playersTransition)
    }
    
    private func playerRow<Content: View>(
        for participant: RoundParticipant,
        @ViewBuilder callToAction: () -> Content = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.cardColor) // TODO: Make this the team color if using and on team, otherwise card.
                    .frame(width: 36, height: 36)
                Text(participant.name.initials)
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            VStack(spacing: 2) {
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
    
    @ViewBuilder
    private func playersTile() -> some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(PlayerTab.allCases.filter { teamsEnabled ? true : $0 != .teams }, id: \.self) { tab in
                        let match = tab == playerTab
                        Button(action: {
                            Haptics.fire(.light)
                            playerTab = tab
                        }) {
                            Chip(
                                text: tab.name,
                                foreground: match ? .white : palette.foregroundColor,
                                background: match ? .accentGreen : .neutral6
                            )
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }

            HStack {
                Text("\(snapshot.participants.count) player\(snapshot.participants.count.pluralized)")
                    .fontStyle(.poppins, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                
                Spacer(minLength: 0)
                
//                Button(action: {
//                    Haptics.fire(.light)
//                    nextCTA()
//                }) {
//                    Text(playerCTA.name)
//                        .fontStyle(.poppins, size: 13, weight: .medium)
//                        .foregroundStyle(Color.hackersGray)
//                        .caretChip()
//                }
            }
            
            ForEach(snapshot.participants, id: \.self) { participant in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.neutral6)
                            .frame(width: 36, height: 36)
                        Text(participant.name.initials)
                            .fontStyle(.poppins, size: 15, weight: .medium)
                            .foregroundStyle(palette.foregroundColor)
                    }
                    
                    // TODO: Tapping name shows player view with config for everything
                    // Name (option to rename)
                    // Tee box dropdown
                    // Tee group and who they're playing with
                    // Team and group
                    VStack(spacing: 2) {
                        Text(participant.name.fullName)
                            .fontStyle(.poppins, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()
                        
                        Text("Strokes \(kDot) group")
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                    }
                    
                    Spacer(minLength: 0)
                    
                    Menu {
                        Button(action: { }) {
                            Text("Edit player")
                            Text("Change name and more")
                        }
                        
                        Button(action: { }) {
                            Text("Handicap")
                            Text("Set or modify strokes")
                        }
                        
                        if let tees = snapshot.courseSegment?.courseInfo.tees {
                            Menu("Tee Box") {
                                Menu("Men's") {
                                    ForEach(tees.male.sortedByDifficulty(for: snapshot.holeSegment), id: \.self) { tee in
                                        let y = tee.yardage(for: snapshot.holeSegment)
                                        let c = tee.prettyRating(for: snapshot.holeSegment)
                                        let s = tee.slope(for: snapshot.holeSegment)
                                        
                                        Button(action: { print("change player tee to \(tee.name)") }) {
                                            Text(tee.name)
                                            Text("\(y) yards \(kDot) \(c ?? "?") / \(s ?? 0)")
                                        }
                                    }
                                }
                                Menu("Women's") {
                                    ForEach(tees.female.sortedByDifficulty(for: snapshot.holeSegment), id: \.self) { tee in
                                        let y = tee.yardage(for: snapshot.holeSegment)
                                        let c = tee.prettyRating(for: snapshot.holeSegment)
                                        let s = tee.slope(for: snapshot.holeSegment)
                                        
                                        Button(action: { print("change player tee to \(tee.name)") }) {
                                            Text(tee.name)
                                            Text("\(y) yards \(kDot) \(c ?? "?") / \(s ?? 0)")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Menu("Tee Group") {
                            Text("Coming Soon")
                        }
                        
                        Menu("Teams") {
                            Text("Coming Soon")
                        }
                        
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.neutral5)
                                .frame(width: 30, height: 30)
                            Icon(name: "f142", size: 15, weight: .solid)
                                .foregroundStyle(Color.neutral)
                        }
                    }
                }
            }
            
            SecondaryButton(
                text: "Add players",
                icon: "f055",
                weight: .regular,
                labelColor: .accentPurple,
                buttonColor: .accentPurple.opacity(0.2),
                isDisabled: .false,
                isLoading: .false,
                onTap: { showPlayerManagementView = true }
            )
            
//            Button(action: {
//                Haptics.fire(.light)
//                showPlayerManagementView = true
//            }) {
//                HStack(spacing: 12) {
//                    Icon(name: "f055", size: 20, weight: .regular)
//                        .foregroundStyle(Color.accentPurple)
//                    
//                    Text("Add players")
//                        .fontStyle(.poppins, size: 20, weight: .semibold)
//                        .foregroundStyle(Color.accentPurple)
//                    
//                    Spacer(minLength: 0)
//                }
//                .padding(.horizontal, 16)
//            }
        }
        //.tileEffect(for: palette)
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
            
//            Line()
        }
        .padding(.horizontal, 16)
    }
    
    fileprivate var footerContent: some View {
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
                    onTap: { showPlayerManagementView = true }
                )
                .matchedTransitionSource(id: "players", in: playersTransition)
                
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
