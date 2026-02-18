//
//  LiveRound+Scoring.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI
import SkeletonUI

// MARK: - Scoring

extension LiveRound {
    var scoringContent: some View {
        holePagedScoringSections
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
        .sheet(item: $viewModel.presentedScoringParticipant) { participant in
            LiveHoleScoringView(viewModel: viewModel, initialParticipant: participant)
                .presentationDragIndicator(.hidden)
                .presentationDetents([.height(700)])
                .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $viewModel.presentedParticipant) { participant in
            FullScorecardView(viewModel: viewModel, participant: participant)
        }
    }

    private var holePagedScoringSections: some View {
        let holes = viewModel.holeNumbers

        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(holes, id: \.self) { holeNumber in
                        VStack(spacing: 16) {
                            teeGroupScorecard(for: holeNumber)
                                .padding(.horizontal, 16)
                            leaderboardSection
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .containerRelativeFrame(.horizontal)
                        .id(holeNumber)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scoringPageHole)
            .onAppear {
                guard !holes.isEmpty else { return }
                if let scoringPageHole, holes.contains(scoringPageHole) { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(viewModel.currentHoleNumber, anchor: .leading)
                }
            }
            .onChange(of: scoringPageHole) { _, newHole in
                guard let newHole else { return }
                
                if let pendingHole = pendingProgrammaticScoringPageHole {
                    if newHole == pendingHole {
                        pendingProgrammaticScoringPageHole = nil
                    }
                    return
                }
                
                guard newHole != viewModel.currentHoleNumber else { return }
                viewModel.selectHole(newHole)
            }
            .onChange(of: viewModel.currentHoleNumber) { oldHole, newHole in
                guard scoringPageHole != newHole else {
                    pendingProgrammaticScoringPageHole = nil
                    return
                }
                
                pendingProgrammaticScoringPageHole = newHole
                
                let holeDistance = abs(newHole - oldHole)
                let shouldAnimatePageChange = !accessibilityReduceMotion && holeDistance > 0
                if shouldAnimatePageChange {
                    let duration = holeScrollDuration(for: holeDistance, totalHoles: holes.count)
                    withAnimation(.easeInOut(duration: duration)) {
                        scoringPageHole = newHole
                    }
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        scoringPageHole = newHole
                    }
                }
            }
        }
    }
}

// MARK: - Tee Group UI

extension LiveRound {
    private func teeGroupScorecard(for holeNumber: Int) -> some View {
        VStack(spacing: 16) {
            Text("Scorecard for Hole \(holeNumber)".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            Line()
            
            if shouldShowScoringSkeleton {
                ForEach(0..<4, id: \.self) { index in
                    teeGroupSkeletonRow
                    if index != 3 {
                        Divider().opacity(0.18)
                    }
                }
            } else if viewModel.teeGroupParticipants.isEmpty {
                Text("Waiting for tee group assignments...")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.teeGroupTeamSections) { section in
                    ForEach(section.participants) { participant in
                        PlayerScoringRow(
                            palette: palette,
                            viewModel: viewModel,
                            participant: participant,
                            holeNumber: holeNumber,
                            requiresTeams: roundSession.snapshot.requiresTeams
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }
}

// MARK: - Leaderboard

extension LiveRound {
    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            Text("Leaderboard".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            Line()
            
            leaderboardPickers
            
            ScrollView(.vertical, showsIndicators: false) {
                if shouldShowScoringSkeleton {
                    VStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { index in
                            leaderboardSkeletonRow
                            
                            if index != 5 {
                                Divider().opacity(0.25)
                            }
                        }
                    }
                } else if viewModel.leaderboardRows.isEmpty {
                    Text("No players in this round yet.")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignCenter()
                } else {
                    switch viewModel.leaderboardMode {
                    case .individual:
                        individualLeaderboardList
                    case .team:
                        groupedLeaderboardList(sections: viewModel.teamLeaderboardSections)
                    case .teeGroup:
                        groupedLeaderboardList(sections: viewModel.teeGroupLeaderboardSections)
                    }
                }
            }
            .frame(maxHeight: leaderboardScrollMaxHeight)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }
    
    // MARK: - Leaderboard Pickers
    
    private var leaderboardPickers: some View {
        let modes = viewModel.availableLeaderboardModes
        let showModePicker = modes.count > 1
        
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                if showModePicker {
                    leaderboardModePicker(modes: modes)
                }
                Spacer(minLength: 0)
                if viewModel.handicapsEnabled {
                    scoreBasisPicker
                }
            }
            
            VStack(spacing: 8) {
                if showModePicker {
                    leaderboardModePicker(modes: modes)
                }
                if viewModel.handicapsEnabled {
                    scoreBasisPicker
                }
            }
        }
    }
    
    private func leaderboardModePicker(modes: [LiveRoundViewModel.LeaderboardMode]) -> some View {
        Picker("", selection: $viewModel.leaderboardMode) {
            ForEach(modes, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        //.frame(maxWidth: modes.count > 2 ? 220 : 160)
    }
    
    private var scoreBasisPicker: some View {
        Picker("", selection: $viewModel.scoreBasis) {
            Text("Gross").tag(ScoreBasis.gross)
            Text("Net").tag(ScoreBasis.net)
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
    }
    
    // MARK: - Individual List
    
    private var individualLeaderboardList: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                groupStatLabel("Best", value: formatGroupScore(viewModel.overallBestScoreToPar))
                groupStatLabel("Avg", value: viewModel.formattedAvgScore(viewModel.overallAvgScoreToPar))
                
                Spacer(minLength: 0)
                
                Color.clear
                    .frame(width: leaderboardHeaderScoreWidth, height: 1)
                
                Text("Thru")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral2)
                    .frame(width: leaderboardHeaderThruWidth, alignment: .center)
                
                Color.clear
                    .frame(width: leaderboardHeaderStarWidth, height: 1)
            }
            .padding(.vertical, 4)
            
            ForEach(viewModel.leaderboardRows) { row in
                LeaderboardRowView(
                    palette: palette,
                    placeLabel: row.placeLabel,
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
    
    // MARK: - Grouped List (Team / Tee Group)
    
    private func groupedLeaderboardList(sections: [LiveRoundViewModel.GroupedLeaderboardSection]) -> some View {
        VStack(spacing: 4) {
            ForEach(sections) { section in
                groupSectionHeader(section)
                
                VStack(spacing: 8) {
                    ForEach(section.rows) { row in
                        LeaderboardRowView(
                            palette: palette,
                            placeLabel: row.placeLabel,
                            row: row,
                            teamColor: viewModel.teamColor(for: row.participant),
                            onTogglePinned: { viewModel.togglePinned(row.participant) },
                            onTap: { viewModel.presentedParticipant = row.participant }
                        )
                        
                        if row.id != section.rows.last?.id {
                            Divider().opacity(0.15)
                        }
                    }
                }
                .padding(.leading, 6)
                
                if section.id != sections.last?.id {
                    Line(color: Color.white.opacity(colorScheme.isDark ? 0.10 : 0.16))
                        .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func groupSectionHeader(_ section: LiveRoundViewModel.GroupedLeaderboardSection) -> some View {
        HStack(spacing: 8) {
            // This shows a team color circle, which isn't necessary
//            if let color = section.color {
//                Circle()
//                    .fill(color.opacity(0.9))
//                    .frame(width: 10, height: 10)
//            }
            
            Text(section.name.uppercased())
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(section.color ?? Color.neutral)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                groupStatLabel("Best", value: formatGroupScore(section.bestScoreToPar))
                groupStatLabel("Avg", value: viewModel.formattedAvgScore(section.avgScoreToPar))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatGroupScore(_ value: Int) -> String {
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }
    
    private func groupStatLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .fontStyle(kFontName, size: 11, weight: .regular)
                .foregroundStyle(Color.neutral2)
            Text(value)
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
    }
}

// MARK: - Skeleton Rows

extension LiveRound {
    private var teeGroupSkeletonRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 24
                )
                .frame(width: skeletonAvatarSize, height: skeletonAvatarSize)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        cornerRadius: 6
                    )
                    .frame(maxWidth: .infinity, minHeight: skeletonNameHeight, maxHeight: skeletonNameHeight, alignment: .leading)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        cornerRadius: 5
                    )
                    .frame(width: 90, height: skeletonSubtitleHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 10
                )
                .frame(width: skeletonButtonWidth, height: skeletonButtonHeight)
        }
    }
    
    private var leaderboardSkeletonRow: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(width: skeletonCellSize, height: skeletonCellHeight)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(maxWidth: .infinity, minHeight: skeletonCellHeight, maxHeight: skeletonCellHeight, alignment: .leading)
            
            Spacer(minLength: 0)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(width: skeletonCellSize, height: skeletonCellHeight)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(width: skeletonCellSize, height: skeletonCellHeight)
        }
    }
}

private struct LiveRoundSkeletonModifier: ViewModifier {
    let palette: DesignPalette
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content.skeleton(
            with: true,
            animation: .linear(duration: 2.0),
            appearance: .solid(
                color: palette.skeletonColor,
                background: palette.skeletonBackground
            ),
            shape: .rounded(.radius(cornerRadius)),
            lines: 1,
            scales: [1: 0.125] // Auto-scales to 25% width minimum if height isn't explicitly set
        )
    }
}

private extension View {
    func liveRoundSkeleton(
        palette: DesignPalette,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(
            LiveRoundSkeletonModifier(
                palette: palette,
                cornerRadius: cornerRadius
            )
        )
    }
}

// MARK: - Preview

private let kMinSkeletonTime: CGFloat = 1.2

#Preview("2v2 Red vs Blue") {
    LiveRound.DelayedHydrationPreview(
        hydratedSnapshot: MockLiveRound2v2.snapshot,
        simulatedLoadDelay: TimeInterval(kMinSkeletonTime)
    )
}

#Preview("Ryder Cup (16, Mixed Groups)") {
    LiveRound.DelayedHydrationPreview(
        hydratedSnapshot: MockLiveRoundRyderCup.snapshot,
        simulatedLoadDelay: TimeInterval(kMinSkeletonTime)
    )
}

#Preview("Four Teams (4x4)") {
    LiveRound.DelayedHydrationPreview(
        hydratedSnapshot: MockLiveRoundFourTeams.snapshot,
        simulatedLoadDelay: TimeInterval(kMinSkeletonTime)
    )
}

