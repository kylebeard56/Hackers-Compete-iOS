//
//  LiveRound.swift
//  Hackers
//
//  Created by Kyle Beard on 1/21/26.
//

import SwiftUI

private enum Tab: String {
    case scoring, games, map, chat
}

struct LiveRound: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    @StateObject private var viewModel: LiveRoundViewModel = .init()
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                NavButton() { dismiss() }
                Spacer(minLength: 0)
                
                // [CURSOR]: Course name and high-level round detail
                headerTitle
                
                Spacer(minLength: 0)
                NavButton(icon: "gear") { print("todo: round configuration") }
            }

            // [CURSOR] Add swipeable holes here (refer to @Legacy/UI/Round/Hole/HoleListView.swift) as an exmaple. Instructinos below:
            // The current hole should be styled with text and underline color as palette.foregroundColor.
            // If the hole was skipped, it should be styled as yellow to flag for it being skipped.
            // Any future scored holes will be styled as grey if unscored and accentPurple if scored.
            // Swiping back and forth changes the hole index and refreshes the view content.
            // The holes should be ranged from i...j following the pattern of the holeRange variable in the roundSession (primaryFormat, not roundSegments).
            holeSelector
            
            // [CURSOR] Add a display here that shows the par, yardage, and difficulty of the hole. It should be styled  like the GameLobby+Course section where the data is vertically stacked.
            holeDetailHeader

            // [FUTURE] TODO: Make custom tab bar like Instagram
            TabView(selection: $selectedTab) {
                scoringContent
                    .tabItem {
                        Image(systemName: "menucard")
                    }
                    .tag(Tab.scoring)

                gameContent
                    .tabItem {
                        Image(systemName: "figure.golf")
                    }
                    .tag(Tab.games)

                mapContent
                    .tabItem {
                        Image(systemName: "map")
                    }
                    .tag(Tab.map)

                chatContent
                    .tabItem {
                        Image(systemName: "bubble")
                    }
                    .tag(Tab.chat)
            }
            .tint(palette.foregroundColor)
            .toolbarBackground(palette.backgroundColor, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
//            .scaleEffect(tabBarScale, anchor: .bottom)
        }
        .padding(.horizontal, 16)
        .navigationBarBackButtonHidden(true)
        .task {
            print("LIVE ROUND:")
            printPretty(roundSession.snapshot)
            viewModel.bind(appSession: appSession, roundSession: roundSession)
        }
    }
    
    // MARK: - Scoring
    
//    @State private var tabBarScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    @State private var previousOffset: CGFloat = 0
    
    private var scoringContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // [CURSOR] For each player in the current player's tee group (refer to the AppData.shared.user primary profile and map the player ID to the round participant's playerID.)
                // You should have a row for each player in this tee group to add their scores.
                // From left to right... The row has the leader score for the user's accrued score through the number of holes player.
                // Then, it has their name and dots below their name representing the number of strokes they get (handicap integer compared to course data handicap value)
                // On the right side, it has small cube shortcut buttons to in a 3x2 grid where it's birdie, par, bogey across the top, then double, triple, and + for custom entry. These values should be in reference to the hole par and not a label (i.e. par 4 shows 3, 4, 5 then, 6, 7, +)
                // If the user clicks the custom score, an alert pops up asking the user to enter an integer for their score. Entry is the GROSS value.
                // When the button is scored, you it highlights with a green accent color. We will need to display their net score somewhere. Likely replacing the dots with the net score underneath their name.
                // When scores change remotely, they should be updated in real-time. The ScoreEntry has a unique canonical path representing the score.
                
                teeGroupScorecard
                
                Line()
                
                // [CURSOR] Below the score card for the tee group, there should be a leaderboard section. This displays the scores for each participant in the group.
                // THe leaderboard should have players ranked 1 through N based on their current accrued score.
                // Scoring is computed based off of the game configuration. For starters in this MVP state, stroke play is the only.
                // The row for each player should look like: [Place index i.e. 1.] [Name] [Thru # (number of holes scored)] [Score] [Star to favorite this player and pin to the top of the list also sorted by index]
                // There should be a chip somewhere in the leaderboard to toggle between net and gross scoring.
                // If you tap on a player row, a scorecard half sheet should popup that allows you to see their full scorecard, with classic golf shapes around the scores like outline circle for birdie, solid circle for eagle or better, nothing for par, outline square for bogey, solid square for double or worse.
                leaderboardSection

                // [CURSOR] This app is being retrofit from the existing version. Please refer to the @Legacy/UI/Hole folder to see how the app used to look. Take liberties to keep or tweak this style based on current app UX.
            }
            .padding(.top, 8)
//            .background(offsetReader)
        }
        .task {
            if let id = appSession.activeRoundID, !roundSession.isRunning {
                await roundSession.start(for: id)
            }
        }
//        .coordinateSpace(name: "liveround_scroll")
        .padding(16)
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
    
//    func updateTabBarScale(
//        shrinkSpeed: CGFloat = 0.015,
//        expandSpeed: CGFloat = 0.02,
//        minScale: CGFloat = 0.7,
//        maxScale: CGFloat = 1.0
//    ) {
//        let delta = offset - previousOffset
//        previousOffset = offset
//        
//        // Scrolling down → content moves up → shrink
//        if delta < 0 {
//            tabBarScale = max(minScale, tabBarScale + delta * shrinkSpeed)
//        }
//        
//        // Scrolling up → expand
//        else if delta > 0 {
//            tabBarScale = min(maxScale, tabBarScale + delta * expandSpeed)
//        }
//    }

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
    private var headerTitle: some View {
        VStack(spacing: 2) {
            Text((snapshot.courseInfo?.name ?? "Live round").uppercased())
                .fontStyle(.poppins, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .alignCenter()
            
            Text("\(snapshot.gameFormat.type.displayName) • \(snapshot.holeSegment.title)")
                .fontStyle(.poppins, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .alignCenter()
        }
    }
}

// MARK: - Hole Selector + Detail

extension LiveRound {
    private var holeSelector: some View {
        let currentHole = viewModel.currentHoleNumber
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(viewModel.holeNumbers, id: \.self) { hole in
                    let isCurrent = hole == currentHole
                    let isScored = viewModel.grossStrokes(for: viewModel.currentParticipantID ?? "", holeNumber: hole).exists
                    let isPickedUp = viewModel.pickedUp(for: viewModel.currentParticipantID ?? "", holeNumber: hole)
                    let progress = viewModel.holeCompletionProgress(holeNumber: hole)
                    
                    let tint: Color = {
                        if isCurrent { return palette.foregroundColor }
                        if isPickedUp { return .systemYellow }
                        if isScored { return .accentPurple }
                        return .neutral3
                    }()
                    
                    Button {
                        viewModel.selectHole(hole)
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(hole)")
                                .fontStyle(.poppins, size: 16, weight: isCurrent ? .semibold : .regular)
                                .foregroundStyle(tint)
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.neutral3.opacity(0.35))
                                
                                Capsule()
                                    .fill(tint)
                                    .frame(width: 28 * max(0, min(1, progress)))
                            }
                            .frame(width: 28, height: 3)
                        }
                        .frame(width: 28)
                    }
                    .buttonStyle(.plain)
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
            
            StackedSubtitle(value: "Hole \(viewModel.currentHoleNumber)", label: "current", tint: palette.foregroundColor)
            
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scoring".uppercased())
                    .fontStyle(.poppins, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
                
                // MVP: allow net/gross chip here as well (mirrors leaderboard)
                Picker("", selection: $viewModel.scoreBasis) {
                    Text("Gross").tag(ScoreBasis.gross)
                    Text("Net").tag(ScoreBasis.net)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            
            if viewModel.teeGroupParticipants.isEmpty {
                Text("Waiting for tee group assignments…")
                    .fontStyle(.poppins, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                ForEach(viewModel.teeGroupParticipants) { participant in
                    PlayerScoringRow(
                        palette: palette,
                        viewModel: viewModel,
                        participant: participant
                    )
                    
                    if participant.id != viewModel.teeGroupParticipants.last?.id {
                        Divider().opacity(0.25)
                    }
                }
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.borderColor.opacity(0.6), lineWidth: 1)
        }
    }
}

private struct PlayerScoringRow: View {
    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    
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
        HStack(spacing: 12) {
            scorePill
            
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name.fullName)
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
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
                .fontStyle(.poppins, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            Text("Thru \(viewModel.holesPlayedCount(for: participant.id))")
                .fontStyle(.poppins, size: 10, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .frame(width: 52)
        .padding(.vertical, 8)
        .background(palette.buttonColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var handicapDots: some View {
        HStack(spacing: 3) {
            if strokesReceived <= 0 {
                Text("No strokes")
                    .fontStyle(.poppins, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral3)
            } else {
                ForEach(0..<min(strokesReceived, 6), id: \.self) { _ in
                    Circle()
                        .fill(Color.neutral3)
                        .frame(width: 5, height: 5)
                }
                
                if strokesReceived > 6 {
                    Text("+\(strokesReceived - 6)")
                        .fontStyle(.poppins, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
        }
    }
    
    private func scoreButton(value: Int) -> some View {
        let selected = gross == value
        return Button {
            Task { await viewModel.setQuickScore(participant: participant, strokes: value) }
        } label: {
            Text("\(value)")
                .fontStyle(.poppins, size: 12, weight: .semibold)
                .foregroundStyle(selected ? Color.white : palette.foregroundColor)
                .frame(width: 32, height: 32)
                .background(selected ? Color.accentGreen : palette.buttonColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.borderColor.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
    
    private var customButton: some View {
        Button {
            viewModel.promptCustomScore(for: participant)
        } label: {
            Text("+")
                .fontStyle(.poppins, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 32, height: 32)
                .background(palette.buttonColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.borderColor.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Leaderboard

extension LiveRound {
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard".uppercased())
                    .fontStyle(.poppins, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }
            
            if viewModel.leaderboardRows.isEmpty {
                Text("No players in this tee group yet.")
                    .fontStyle(.poppins, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.leaderboardRows.enumerated()), id: \.element.id) { index, row in
                        LeaderboardRowView(
                            palette: palette,
                            place: index + 1,
                            row: row,
                            onTogglePinned: { viewModel.togglePinned(row.participant) },
                            onTap: { viewModel.presentedParticipant = row.participant }
                        )
                        
                        if row.id != viewModel.leaderboardRows.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.borderColor.opacity(0.6), lineWidth: 1)
        }
    }
}

private struct LeaderboardRowView: View {
    let palette: DesignPalette
    let place: Int
    let row: LiveRoundViewModel.LeaderboardRow
    let onTogglePinned: Callback
    let onTap: Callback
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("\(place).")
                    .fontStyle(.poppins, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .frame(width: 26, alignment: .leading)
                
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
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
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
                .frame(maxWidth: 240)
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

//extension LiveRound {
//    private var offsetReader: some View {
//        GeometryReader { geo in
//            Color.clear
//                .preference(
//                    key: ScrollOffsetKey.self,
//                    value: geo.frame(in: .named("liveround_scroll")).minY
//                )
//        }
//        .frame(height: 0)
//        .onPreferenceChange(ScrollOffsetKey.self) { value in
//            offset = value
//            updateTabBarScale()
//        }
//    }
//}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

@MainActor
private enum Mock {
    static var appSesssion: AppSession {
        return .init()
    }
    
    static var roundSesssion: RoundSession {
        return .init()
    }
}

#Preview {
    LiveRound()
        .environmentObject(Mock.appSesssion)
        .environmentObject(Mock.roundSesssion)
}
