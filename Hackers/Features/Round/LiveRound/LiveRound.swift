//
//  LiveRound.swift
//  Hackers
//
//  Created by Kyle Beard on 1/21/26.
//

import MapKit
import SwiftUI

private enum Tab: String, CaseIterable {
    case scoring, games, map, chat
    
    var icon: String {
        switch self {
        case .scoring: "menucard"
        case .games: "figure.golf"
        case .map: "map"
        case .chat: "bubble"
        }
    }
}

struct LiveRound: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    @StateObject private var viewModel: LiveRoundViewModel = .init()
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    @State private var tabBarScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    @State private var previousOffset: CGFloat = 0
    
    private var mapCoordinate: CLLocationCoordinate2D {
        if let userLocation = locationService.location {
            return userLocation.coordinate
        } else if let courseLocation = snapshot.course?.location {
            return .init(latitude: courseLocation.latitude, longitude: courseLocation.longitude)
        } else {
            return .init()
        }
    }
    
    @State private var region = MKCoordinateRegion(center: .init(), latitudinalMeters: 50, longitudinalMeters: 50)
    @State private var mapInit = false
    
    var body: some View {
        ZStack {
            if selectedTab == .map {
                Map(
                    coordinateRegion: $region,
                    interactionModes: [.all],
                    showsUserLocation: true,
                    userTrackingMode: .constant(.followWithHeading)
                )
                .mapStyle(.imagery(elevation: .realistic))
                .ignoresSafeArea()
            } else {
                GolfTopology()
                    .frame(width: UIScreen.main.bounds.width)
            }
            VStack(spacing: 16) {
                if selectedTab == .scoring {
                    ScrollView(showsIndicators: false) {
                        Spacer(minLength: 0)
                            .frame(height: 56)
                        
                        scoringContent
                            .padding(.horizontal, 16)
                        
                        Spacer(minLength: 0)
                            .frame(height: 120)
                    }
                } else if selectedTab == .games {
                    gameContent
                        .padding(.horizontal, 16)
                } else if selectedTab == .map {
                    EmptyView()
                        .alignMiddle()
                } else if selectedTab == .chat {
                    chatContent
                        .padding(.horizontal, 16)
                }
            }

            navigationTitleView
                .padding(.horizontal, 16)
                .alignTop()
            
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabItem(for: tab)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .glassCardEffect(
                cornerRadius: 100,
                material: .ultraThinMaterial,
                tint: Color.accentPurple.opacity(colorScheme.isDark ? 0.18 : 0.10),
                strokeOpacity: colorScheme.isDark ? 0.20 : 0.30,
                shadowOpacity: colorScheme.isDark ? 0.12 : 0.08
            )
            //.frame(maxWidth: UIScreen.main.bounds.width * 0.618) // golden ratio
            //.scaleEffect(tabBarScale)
            .alignBottom()
        }
        //.background(GolfTopology())
        .navigationBarBackButtonHidden(true)
        .task {
            print("LIVE ROUND:")
            printPretty(roundSession.snapshot)
            if let id = appSession.activeRoundID, !roundSession.isRunning {
                await roundSession.start(for: id)
            }
            viewModel.bind(appSession: appSession, roundSession: roundSession)
        }
        .onReceive(roundSession.$snapshot, perform: { _ in
            if mapInit { return }
            region.center = mapCoordinate
            mapInit = true
        })
    }
    
    private func tabItem(for tab: Tab) -> some View {
        Button {
            Haptics.fire(.light)
            selectedTab = tab
        } label: {
            ZStack {
                if selectedTab == tab {
                    Capsule()
                        .fill(.clear)
                        .frame(width: 72, height: 48)
                        .glassCardEffect(
                            cornerRadius: 24,
                            material: .ultraThinMaterial,
                            tint: selectedTab == tab
                                ? Color.accentPurple.opacity(colorScheme.isDark ? 0.18 : 0.10)
                                : Color.clear,
                            strokeOpacity: colorScheme.isDark ? 0.20 : 0.30,
                            shadowOpacity: colorScheme.isDark ? 0.12 : 0.08
                        )
                } else {
                    Capsule()
                        .fill(.clear)
                        .frame(width: 72, height: 48)
                }
                
                Icon(name: tab.icon, size: 20, weight: selectedTab == tab ? .semibold : .regular)
                    .foregroundStyle(selectedTab == tab ? palette.foregroundColor : Color.charcoal)
            }
        }
    }
    
    func updateTabBarScale(
        shrinkSpeed: CGFloat = 0.015,
        expandSpeed: CGFloat = 0.02,
        minScale: CGFloat = 0.7,
        maxScale: CGFloat = 1.0
    ) {
        let delta = offset - previousOffset
        previousOffset = offset
        
        // Scrolling down → content moves up → shrink
        if delta < 0 {
            tabBarScale = max(minScale, tabBarScale + delta * shrinkSpeed)
        }
        
        // Scrolling up → expand
        else if delta > 0 {
            tabBarScale = min(maxScale, tabBarScale + delta * expandSpeed)
        }
    }
    
    // MARK: - Scoring
    
//    @State private var tabBarScale: CGFloat = 1.0
//    @State private var offset: CGFloat = 0.0
//    @State private var previousOffset: CGFloat = 0
    
    private var scoringContent: some View {
//        ObservableScrollView(offset: $offset, showsIndicators: false) {
////            ScrollView(showsIndicators: false) {
//            VStack(spacing: 16) {
//                heroHeaderCard
//                
//                teeGroupScorecard
//                
//                leaderboardSection
//            }
//            .padding(.horizontal, 16)
//            
//            Spacer(minLength: 0)
//                .frame(height: 120)
//        }
        VStack(spacing: 16) {
            heroHeaderCard
            
            teeGroupScorecard
            
            leaderboardSection
        }
        //.onChange(of: offset) { updateTabBarScale() }
        .alert("Enter score", isPresented: $viewModel.showCustomScorePrompt) {
            TextField("Strokes", text: $viewModel.customScoreText)
                .keyboardType(.numberPad)
            Button("Save") {
                Task { await viewModel.submitCustomScore() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter the gross strokes for this hole.")
        }
        .sheet(item: $viewModel.presentedParticipant) { participant in
            ScorecardSheet(viewModel: viewModel, participant: participant)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Game Content
    
    private var gameContent: some View {
        // Alternative side games, or bets.
        VStack {
            Text("Side game content coming soon")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
    
    // MARK: - Map Content
    
    private var mapContent: some View {
        // Ideas: Have users enter their stock yardage per club. Then you have Bushnell-like map where you can tap
        // and drag waypoints and along the straight line, you can see distance, suggested club with power so you
        // can decide whether you're driver-wedge, 5i-8i, 6i-6i etc to balance what's best and strategize the hole.
        // The user has to be the one to know where the are on the map.
        VStack {
            Text("Map content coming soon")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
    
    // MARK: - Chat Content
    
    private var chatContent: some View {
        // Place for players to chat, share pics, post announcements.
        VStack {
            Text("In-round chat coming soon")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
}

// MARK: - Header

extension LiveRound {
    private var navigationTitleView: some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                dismiss()
            }
            
            Spacer(minLength: 0)
            
            headerTitle
                .padding(.vertical, 3)
                .padding(.horizontal, 24)
                .glassCardEffect()
            
            Spacer(minLength: 0)
            
            NavButton(style: .glass, icon: "gear", weight: .regular, color: palette.foregroundColor) {
                print("todo: round configuration")
            }
        }
    }
    
    private var headerTitle: some View {
        VStack(spacing: 2) {
            Text((snapshot.courseInfo?.name ?? "Live round").uppercased())
                .fontStyle(.poppins, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            
            Text("\(snapshot.gameFormat.type.displayName) • \(snapshot.holeSegment.title)")
                .fontStyle(.poppins, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Apple Sports-style background + hero card

extension LiveRound {
//    private var sportsBackground: some View {
//        ZStack {
//            palette.backgroundColor
//            
//            GolfTopology()
//            
////            GolfTopology()
////                .opacity(colorScheme.translucent / 2.0)
////                .blur(radius: 28)
//        }
//        .ignoresSafeArea()
//    }
    
    private var heroHeaderCard: some View {
        VStack(spacing: 14) {
            // [CURSOR] Add swipeable holes here...
            holeSelector
            
            // [CURSOR] Add a display here that shows the par, yardage, and difficulty...
            holeDetailHeader
        }
        .padding(16)
        .glassCardEffect(
            cornerRadius: 28,
            material: .ultraThinMaterial,
            tint: Color.accentPurple.opacity(colorScheme.isDark ? 0.18 : 0.10),
            strokeOpacity: colorScheme.isDark ? 0.20 : 0.30,
            shadowOpacity: colorScheme.isDark ? 0.12 : 0.08
        )
        .padding(.top, 8)
    }
}

// MARK: - Hole Selector + Detail

extension LiveRound {
    private var holeSelector: some View {
        let currentHole = viewModel.currentHoleNumber
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(viewModel.holeNumbers, id: \.self) { hole in
                    let isCurrent = hole == currentHole
                    let isScored = viewModel.grossStrokes(for: viewModel.currentParticipantID ?? "", holeNumber: hole).exists
                    let isPickedUp = viewModel.pickedUp(for: viewModel.currentParticipantID ?? "", holeNumber: hole)
                    let progress = viewModel.holeCompletionProgress(holeNumber: hole)
                    
//                    let tint: Color = {
//                        if isCurrent { return palette.foregroundColor }
//                        if isPickedUp { return .systemYellow }
//                        if isScored { return .accentPurple }
//                        return .neutral2
//                    }()
                    
                    Button {
                        viewModel.selectHole(hole)
                    } label: {
                        VStack(spacing: 6) {
                            Text("Hole \(hole)")
                                .fontStyle(.poppins, size: 16, weight: isCurrent ? .semibold : .regular)
                                .foregroundStyle(isCurrent ? palette.foregroundColor : Color.neutral2)
                            
                            Capsule()
                                .fill(isCurrent ? palette.foregroundColor : Color.clear)
                                .frame(height: 3)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let dx = value.translation.width
                    if dx <= -40 {
                        viewModel.swipeHole(direction: 1)
                    } else if dx >= 40 {
                        viewModel.swipeHole(direction: -1)
                    }
                }
        )
    }
    
    private var holeDetailHeader: some View {
        let hole = viewModel.hole(for: viewModel.currentHoleNumber)
        
        return HStack(spacing: 32) {
            Spacer(minLength: 0)
            
//            StackedSubtitle(value: "Hole \(viewModel.currentHoleNumber)", label: "current", tint: palette.foregroundColor)
            
            if let hole {
                StackedSubtitle(value: "\(hole.par)", label: "par")
                StackedSubtitle(value: "\(hole.yardage)", label: "yards")
                StackedSubtitle(value: "\(hole.handicap ?? 0)", label: "hcp")
            } else {
                StackedSubtitle(value: "—", label: "par")
                StackedSubtitle(value: "—", label: "yards")
                StackedSubtitle(value: "—", label: "hcp")
            }
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Tee Group UI

extension LiveRound {
    private var teeGroupScorecard: some View {
        VStack(spacing: 12) {
            Text("Scorecard for Hole \(viewModel.currentHoleNumber)".uppercased())
                .fontStyle(.poppins, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            Line()
            
            if viewModel.teeGroupParticipants.isEmpty {
                Text("Waiting for tee group assignments.")
                    .fontStyle(.poppins, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                ForEach(viewModel.teeGroupTeamSections) { section in
//                    if let team = section.team {
//                        HStack(spacing: 10) {
//                            Text(team.name.uppercased())
//                                .fontStyle(.poppins, size: 12, weight: .semibold)
//                                .foregroundStyle(team.teamColor.value)
//                            
//                            Spacer(minLength: 0)
//                        }
//                        .padding(.top, 4)
//                    }
//                    else if snapshot.requiresTeams {
//                        HStack(spacing: 10) {
//                            Text("UNASSIGNED".uppercased())
//                                .fontStyle(.poppins, size: 12, weight: .semibold)
//                                .foregroundStyle(Color.neutral2)
//                            
//                            Spacer(minLength: 0)
//                        }
//                        .padding(.top, 4)
//                    }
                    
                    ForEach(section.participants) { participant in
                        PlayerScoringRow(
                            palette: palette,
                            viewModel: viewModel,
                            participant: participant,
                            requiresTeams: roundSession.snapshot.requiresTeams
                        )
                        
                        if participant.id != section.participants.last?.id {
                            Divider().opacity(0.18)
                        }
                    }
                    
//                    if section.id != viewModel.teeGroupTeamSections.last?.id {
//                        Line(color: Color.white.opacity(colorScheme.isDark ? 0.10 : 0.16))
//                            .padding(.vertical, 2)
//                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect(
            cornerRadius: 24,
            material: .ultraThinMaterial,
            tint: Color.accentGreen.opacity(colorScheme.isDark ? 0.12 : 0.08),
            strokeOpacity: colorScheme.isDark ? 0.18 : 0.28,
            shadowOpacity: colorScheme.isDark ? 0.10 : 0.08
        )
    }
}

private struct PlayerScoringRow: View {
    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    var requiresTeams: Bool
    
    private var hole: Hole? { viewModel.hole(for: viewModel.currentHoleNumber) }
    private var holePar: Int { hole?.par ?? 4 }
    
    private var gross: Int? { viewModel.grossStrokes(for: participant.id, holeNumber: viewModel.currentHoleNumber) }
    private var strokesReceived: Int { viewModel.strokesReceivedOnHole(participant: participant, holeNumber: viewModel.currentHoleNumber) }
    private var net: Int? { viewModel.netStrokesOnHole(participant: participant, holeNumber: viewModel.currentHoleNumber) }
    
    private var scoreToParLabel: String {
        viewModel.formattedScoreToPar(viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis))
    }
    
    private var quickScores: [Int] {
        // birdie, par, bogey / double, triple
        [holePar - 1, holePar, holePar + 1, holePar + 2, holePar + 3]
    }
    
    private var grid: [GridItem] {
        [
            GridItem(.fixed(32), spacing: 6),
            GridItem(.fixed(32), spacing: 6),
            GridItem(.fixed(32), spacing: 6)
        ]
    }
    
    var body: some View {
        let teamColor = viewModel.teamColor(for: participant)
        let rowTint = teamColor ?? palette.foregroundColor
        
        HStack(spacing: 12) {
            scorePill
            
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    viewModel.presentedParticipant = participant
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.10))
                            
                            Circle()
                                .stroke(rowTint.opacity(0.85), lineWidth: 2)
                        }
                        .frame(width: 10, height: 10)
                        
                        Text(participant.name.fullName)
                            .fontStyle(.poppins, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                
                if gross.exists {
                    // When scored: show the net stroke value under the name (MVP)
                    Text("Net \(net ?? (gross ?? 0))")
                        .fontStyle(.poppins, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                } else {
                    handicapDots
                }
            }
            
            Spacer(minLength: 0)
            
            LazyVGrid(columns: grid, spacing: 6) {
                scoreButton(value: quickScores[0]) // birdie
                scoreButton(value: quickScores[1]) // par
                scoreButton(value: quickScores[2]) // bogey
                scoreButton(value: quickScores[3]) // double
                scoreButton(value: quickScores[4]) // triple
                customButton
            }
        }
        .padding(.vertical, 6)
    }
    
    private var scorePill: some View {
        VStack(spacing: 2) {
            Text(scoreToParLabel)
                .fontStyle(.poppins, size: 22, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
             Text("Thru \(viewModel.holesPlayedCount(for: participant.id))")
                 .fontStyle(.poppins, size: 11, weight: .regular)
                 .foregroundStyle(Color.neutral)
        }
        //.frame(width: 48)
        .padding(8)
        .glassCardEffect(cornerRadius: 12, tint: palette.buttonColor)
        //.background(palette.buttonColor)
        //.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var handicapDots: some View {
        Group {
            if strokesReceived > 0 {
                let teamColor = viewModel.teamColor(for: participant)
                let dotColor: Color = requiresTeams ? (teamColor ?? Color.neutral2) : Color.neutral3
                
                HStack(spacing: 3) {
                    ForEach(0..<strokesReceived, id: \.self) { _ in
                        Circle()
                            .fill(dotColor)
                            .frame(width: 5, height: 5)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private func scoreButton(value: Int) -> some View {
        let selected = gross == value
        let selectedTint = viewModel.teamColor(for: participant) ?? palette.foregroundColor
        let background = selected ? selectedTint : palette.buttonColor
        let foreground = selected ? palette.buttonColor : palette.foregroundColor
        
        Button {
            Task {
                if selected {
                    await viewModel.clearScore(participant: participant)
                } else {
                    await viewModel.setQuickScore(participant: participant, strokes: value)
                }
            }
        } label: {
            if selected {
                Text("\(value)")
                    .fontStyle(.poppins, size: 12, weight: .semibold)
                    .foregroundStyle(foreground)
                    .frame(width: 32, height: 32)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text("\(value)")
                    .fontStyle(.poppins, size: 12, weight: .semibold)
                    .foregroundStyle(foreground)
                    .frame(width: 32, height: 32)
                    .glassCardEffect(cornerRadius: 10, tint: background)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var customButton: some View {
        let selected = gross.exists && !quickScores.contains(gross ?? 0)
        let label = selected ? "\(gross ?? 0)" : "+"
        let selectedTint = viewModel.teamColor(for: participant) ?? palette.foregroundColor
        let background = selected ? selectedTint : palette.buttonColor
        let foreground = selected ? palette.buttonColor : palette.foregroundColor
        
        Button {
            viewModel.promptCustomScore(for: participant)
        } label: {
//            Text(label)
//                .fontStyle(.poppins, size: 14, weight: .semibold)
//                .foregroundStyle(foreground)
//                .frame(width: 32, height: 32)
//                .background(background)
//                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if selected {
                Text(label)
                    .fontStyle(.poppins, size: 12, weight: .semibold)
                    .foregroundStyle(foreground)
                    .frame(width: 32, height: 32)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(label)
                    .fontStyle(.poppins, size: 12, weight: .semibold)
                    .foregroundStyle(foreground)
                    .frame(width: 32, height: 32)
                    .glassCardEffect(cornerRadius: 10, tint: background)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Leaderboard

extension LiveRound {
    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            Text("Leaderboard".uppercased())
                .fontStyle(.poppins, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            Line()
            
            if viewModel.leaderboardRows.isEmpty {
                Text("No players in this round yet.")
                    .fontStyle(.poppins, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignCenter()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.leaderboardRows.enumerated()), id: \.element.id) { index, row in
                        LeaderboardRowView(
                            palette: palette,
                            place: index + 1,
                            row: row,
                            teamColor: viewModel.teamColor(for: row.participant),
                            onTogglePinned: { viewModel.togglePinned(row.participant) },
                            onTap: { viewModel.presentedParticipant = row.participant }
                        )
                        
                        if row.id != viewModel.leaderboardRows.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            Picker("", selection: $viewModel.scoreBasis) {
                Text("Gross").tag(ScoreBasis.gross)
                Text("Net").tag(ScoreBasis.net)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(16)
        .glassCardEffect(
            cornerRadius: 24,
            material: .ultraThinMaterial,
            tint: Color.accentPurple.opacity(colorScheme.isDark ? 0.12 : 0.08),
            strokeOpacity: colorScheme.isDark ? 0.18 : 0.28,
            shadowOpacity: colorScheme.isDark ? 0.10 : 0.08
        )
    }
}

private struct LeaderboardRowView: View {
    let palette: DesignPalette
    let place: Int
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let onTogglePinned: Callback
    let onTap: Callback
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("\(place).")
                    .fontStyle(.poppins, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .frame(width: 26, alignment: .leading)
                
                if let teamColor {
                    Circle()
                        .fill(teamColor.opacity(0.9))
                        .frame(width: 8, height: 8)
                }
                
                Text(row.participant.name.fullName)
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer(minLength: 0)
                
                Text("Thru \(row.thru)")
                    .fontStyle(.poppins, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(width: 54, alignment: .trailing)
                
                Text(scoreLabel)
                    .fontStyle(.poppins, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 44, alignment: .trailing)
                
                Button(action: onTogglePinned) {
                    Image(systemName: row.isPinned ? "star.fill" : "star")
                        .foregroundStyle(row.isPinned ? Color.systemYellow : Color.neutral3)
                        .frame(width: 24, height: 24)
                }
               // .buttonStyle(.plain)
            }
        }
        //.buttonStyle(.plain)
    }
    
    private var scoreLabel: String {
        if row.scoreToPar == 0 { return "E" }
        if row.scoreToPar > 0 { return "+\(row.scoreToPar)" }
        return "\(row.scoreToPar)"
    }
}

// MARK: - Scorecard Sheet

private struct ScorecardSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(participant.name.fullName)
                    .fontStyle(.poppins, size: 18, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()
                
                Picker("", selection: $viewModel.scoreBasis) {
                    Text("Gross").tag(ScoreBasis.gross)
                    Text("Net").tag(ScoreBasis.net)
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, 8)
            
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(viewModel.holeNumbers, id: \.self) { holeNumber in
                        ScorecardHoleCell(
                            palette: palette,
                            holeNumber: holeNumber,
                            par: viewModel.hole(for: holeNumber)?.par,
                            gross: viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber),
                            net: viewModel.netStrokesOnHole(participant: participant, holeNumber: holeNumber),
                            basis: viewModel.scoreBasis
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            
            HStack {
                Text("Total \(viewModel.scoreBasis == .gross ? "gross" : "net")")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                
                Spacer(minLength: 0)
                
                Text(viewModel.formattedScoreToPar(viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)))
                    .fontStyle(.poppins, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(palette.backgroundColor)
    }
}

private struct ScorecardHoleCell: View {
    let palette: DesignPalette
    let holeNumber: Int
    let par: Int?
    let gross: Int?
    let net: Int?
    let basis: ScoreBasis
    
    private var displayed: Int? { basis == .gross ? gross : net }
    
    var body: some View {
        VStack(spacing: 6) {
            Text("H\(holeNumber)")
                .fontStyle(.poppins, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            
            ZStack {
                decoration
                
                Text(displayed.map(String.init) ?? "—")
                    .fontStyle(.poppins, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            .frame(height: 36)
            
            Text(par.map { "Par \($0)" } ?? "Par —")
                .fontStyle(.poppins, size: 11, weight: .regular)
                .foregroundStyle(Color.neutral3)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderColor.opacity(0.6), lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private var decoration: some View {
        if let par, let strokes = displayed {
            let diff = strokes - par
            
            // Eagle or better: solid circle
            if diff <= -2 {
                Circle()
                    .fill(palette.foregroundColor.opacity(0.14))
                    .frame(width: 34, height: 34)
            }
            
            // Birdie: outline circle
            else if diff == -1 {
                Circle()
                    .stroke(palette.foregroundColor, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }
            
            // Bogey: outline square
            else if diff == 1 {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(palette.foregroundColor, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }
            
            // Double or worse: solid square
            else if diff >= 2 {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.foregroundColor.opacity(0.14))
                    .frame(width: 34, height: 34)
            }
            
            else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - Scroll Offset (tab bar scaling)

extension LiveRound {
    private var offsetReader: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetKey.self,
                    value: geo.frame(in: .named("liveround_scroll")).minY
                )
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            offset = value
            updateTabBarScale()
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

@MainActor
private enum Mock {
    static var appSesssion: AppSession {
        let session = AppSession()
        return session
    }
    
    static var roundSesssion: RoundSession {
        let session = RoundSession()
        session.snapshot.participants = MockParticipants.all
        return session
    }
}

#Preview {
    LiveRound()
        .environmentObject(Mock.appSesssion)
        .environmentObject(LocationService())
        .environmentObject(Mock.roundSesssion)
}
