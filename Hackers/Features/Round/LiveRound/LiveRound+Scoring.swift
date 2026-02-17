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
        VStack(spacing: 8) {
            heroHeaderCard
                .padding(.horizontal, 16)

            holePagedScoringSections
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
                        proxy.scrollTo(newHole, anchor: .leading)
                    }
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(newHole, anchor: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Apple Sports-style background + hero card

extension LiveRound {
    private var heroHeaderCard: some View {
        VStack(spacing: 14) {
            holeSelector
            holeDetailHeader
        }
        .padding(16)
        .glassCardEffect()
        .liveRoundHeaderFrame(.heroCard)
        .scaleEffect(heroHeaderScale, anchor: .top)
        .opacity(heroHeaderOpacity)
        .offset(y: heroHeaderVerticalOffset)
        .allowsHitTesting(headerTransitionProgress < 0.98)
        .accessibilityHidden(headerTransitionProgress >= 0.98)
//        .glassCardEffect(
//            cornerRadius: 28,
//            material: .ultraThinMaterial,
//            tint: Color.accentPurple.opacity(colorScheme.isDark ? 0.18 : 0.10),
//            strokeOpacity: colorScheme.isDark ? 0.20 : 0.30,
//            shadowOpacity: colorScheme.isDark ? 0.12 : 0.08
//        )
//        .padding(.top, 8)
    }
}

// MARK: - Hole Selector + Detail

extension LiveRound {
    private var holeSelector: some View {
        HoleWindowSelector(
            holes: viewModel.holeNumbers,
            selectedHole: viewModel.currentHoleNumber,
            visibleSlotCount: 5,
            activeColor: palette.foregroundColor,
            inactiveColor: .neutral2,
            fontSize: 16,
            slotSpacing: 12,
            itemSpacing: 6,
            indicatorHeight: 3,
            rowPadding: EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0)
        ) { hole in
            viewModel.selectHole(hole)
        }
    }
    
    private var holeDetailHeader: some View {
        let hole = viewModel.hole(for: viewModel.currentHoleNumber, teeID: viewModel.selectedTeeID)
        
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
            
            if viewModel.teeSelectionOptions.count > 1 {
                Menu {
                    ForEach(viewModel.teeSelectionOptions) { option in
                        if option.participantNames.isPopulated {
                            Text(option.participantNames)
                                .font(.caption)
                                .foregroundStyle(Color.neutral)
                        }
                        
                        Button(option.tee.name) {
                            viewModel.selectedTeeID = option.id
                        }
                    }
                } label: {
                    StackedSubtitle(value: viewModel.selectedTeeName, label: "tee")
                }
                .buttonStyle(.plain)
            } else {
                StackedSubtitle(value: viewModel.selectedTeeName, label: "tee")
            }
            
            Spacer(minLength: 0)
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
//                    if let team = section.team {
//                        HStack(spacing: 10) {
//                            Text(team.name.uppercased())
//                                .fontStyle(kFontName, size: 12, weight: .semibold)
//                                .foregroundStyle(team.teamColor.value)
//                            
//                            Spacer(minLength: 0)
//                        }
//                        .padding(.top, 4)
//                    }
//                    else if snapshot.requiresTeams {
//                        HStack(spacing: 10) {
//                            Text("UNASSIGNED".uppercased())
//                                .fontStyle(kFontName, size: 12, weight: .semibold)
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
                            holeNumber: holeNumber,
                            requiresTeams: roundSession.snapshot.requiresTeams
                        )
                        
//                        if participant.id != section.participants.last?.id {
//                            Divider().opacity(0.18)
//                        }
                    }
                    
//                    if section.id != viewModel.teeGroupTeamSections.last?.id {
//                        Line(color: Color.white.opacity(colorScheme.isDark ? 0.10 : 0.16))
//                            .padding(.vertical, 2)
//                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect()
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
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCardEffect()
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
                    .frame(width: 44, height: 1)
                
                Text("Thru")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral2)
                    .frame(width: 54, alignment: .center)
                
                Color.clear
                    .frame(width: 24, height: 1)
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
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        cornerRadius: 6
                    )
                    .frame(maxWidth: .infinity, minHeight: 17, maxHeight: 17, alignment: .leading)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        cornerRadius: 5
                    )
                    .frame(width: 90, height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 10
                )
                .frame(width: 120, height: 32)
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
                .frame(width: 30, height: 15)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(maxWidth: .infinity, minHeight: 15, maxHeight: 15, alignment: .leading)
            
            Spacer(minLength: 0)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(width: 30, height: 15)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    cornerRadius: 6
                )
                .frame(width: 30, height: 15)
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

