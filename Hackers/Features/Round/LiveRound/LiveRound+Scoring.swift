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
                .presentationBackground(.ultraThinMaterial)
                .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $viewModel.presentedParticipant) { participant in
            FullScorecardView(viewModel: viewModel, participant: participant)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var holePagedScoringSections: some View {
        let holes = viewModel.holeNumbers

        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(holes, id: \.self) { holeNumber in
                        VStack(spacing: 16) {
                            navPadding
                            holeDetailsCard(for: holeNumber)
                            teeGroupScorecard(for: holeNumber)
                            leaderboardSection
                        }
                        .padding(.top, 8)
                        .frame(width: UIScreen.main.bounds.width - 32)
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
                isProgrammaticHoleScroll = true
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(viewModel.currentHoleNumber, anchor: .leading)
                }
            }
            .onChange(of: scoringPageHole) { _, newHole in
                guard let newHole else { return }

                if isProgrammaticHoleScroll {
                    isProgrammaticHoleScroll = false
                    return
                }

                guard newHole != viewModel.currentHoleNumber else { return }
                viewModel.selectHole(newHole)
            }
            .onChange(of: viewModel.currentHoleNumber) { oldHole, newHole in
                guard scoringPageHole != newHole else { return }
                isProgrammaticHoleScroll = true

                let distance = abs(newHole - oldHole)
                if !accessibilityReduceMotion && distance > 0 {
                    let duration = holeScrollDuration(for: distance, totalHoles: holes.count)
                    withAnimation(.snappy(duration: duration)) {
                        proxy.scrollTo(newHole, anchor: .leading)
                    }
                } else {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        proxy.scrollTo(newHole, anchor: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Hole details card

extension LiveRound {
    /// Four glass cubes: Par, Yards, Hcp, Tee. Tee is tappable for muscle memory.
    private func holeDetailsCard(for holeNumber: Int) -> some View {
        let hole = viewModel.hole(for: holeNumber, teeID: viewModel.selectedTeeID)
        
        return HStack(spacing: 8) {
            holeDetailCube(value: hole.map { "\($0.par)" } ?? "—", label: "par")
            holeDetailCube(value: hole.map { "\($0.yardage)" } ?? "—", label: "yards")
            holeDetailCube(value: hole.map { "\($0.handicap ?? 0)" } ?? "—", label: "hcp")
            
            Menu {
                if viewModel.teeOptionsForMenuMale.isPopulated {
                    Menu {
                        ForEach(viewModel.teeOptionsForMenuMale) { option in
                            teeMenuButton(option: option)
                        }
                    } label: {
                        Text("Men's")
                    }
                }
                if viewModel.teeOptionsForMenuFemale.isPopulated {
                    Menu {
                        ForEach(viewModel.teeOptionsForMenuFemale) { option in
                            teeMenuButton(option: option)
                        }
                    } label: {
                        Text("Women's")
                    }
                }
            } label: {
                holeDetailCube(value: viewModel.selectedTeeName, label: "tees", icon: "chevron.right", lineLimit: 2)
            }
        }
    }
    
    private func holeDetailCube(value: String, label: String, icon: String? = nil, lineLimit: Int = 2) -> some View {
        StackedSubtitle(value: value, label: label, icon: icon, size: 20, lineLimit: lineLimit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 72)
            .glassCardEffect(cornerRadius: 12, interactive: false)
    }

    private func teeMenuButton(option: LiveRoundViewModel.TeeSelectionOption) -> some View {
        Button {
            Haptics.fire(.light)
            viewModel.selectedTeeID = option.id
        } label: {
            if option.participantNames.isPopulated {
                Text(option.tee.name)
                Text(option.participantNames)
            } else {
                Text(option.tee.name)
            }
        }
    }
    
//    private var teeBoxCube: some View {
//        Menu {
//            ForEach(viewModel.teeOptionsForMenu) { option in
//                Button {
//                    viewModel.selectedTeeID = option.id
//                } label: {
//                    if option.participantNames.isPopulated {
//                        VStack(alignment: .leading, spacing: 2) {
//                            Text(option.tee.name)
//                            Text(option.participantNames)
//                                .font(.caption)
//                                .foregroundStyle(Color.neutral)
//                        }
//                    } else {
//                        Text(option.tee.name)
//                    }
//                }
//            }
//        } label: {
//            VStack(spacing: 4) {
//                Text(viewModel.selectedTeeName)
//                    .fontStyle(kFontName, size: 17, weight: .semibold)
//                    .foregroundStyle(palette.foregroundColor)
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.6)
//                HStack(spacing: 4) {
//                    Text("TEE")
//                        .fontStyle(kFontName, size: 13, weight: .medium)
//                        .foregroundStyle(Color.neutral)
//                    Icon(name: "chevron.right", size: 10, weight: .semibold)
//                        .foregroundStyle(Color.neutral3)
//                }
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 12)
//            .padding(.horizontal, 8)
//            .glassCardEffect(cornerRadius: 12, tint: palette.glassButtonColor, shadowOpacity: 0)
//        }
//        .buttonStyle(.plain)
//    }
}

// MARK: - Tee Group UI

extension LiveRound {
    @ViewBuilder
    private func teeGroupScorecard(for holeNumber: Int) -> some View {
        if viewModel.isSpectator {
            EmptyView()
        } else {
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
            
//            ScrollView(.vertical, showsIndicators: false) {
//
//            }
//            .frame(maxHeight: leaderboardScrollMaxHeight)
            
            if shouldShowScoringSkeleton {
                VStack(spacing: 10) {
                    leaderboardSkeletonPickers
                    
                    leaderboardSkeletonHeader
                        .padding(.vertical, 4)
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
            
            Line()
            
            leaderboardFooter
            
            if let snapshot = weatherService.currentSnapshot {
                Line()
                weatherDetails(for: snapshot)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }
    
    private var leaderboardFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = snapshot.courseInfo?.name, name.isPopulated {
                Text(name.uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Text("Last updated at \(formattedLastUpdated)")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
    
    private func weatherDetails(for weather: WeatherSnapshot) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Icon(name: "thermometer", size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                
                Text("\(weather.temperature)° F")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            

            if let humidity = weather.humidity {
                HStack(spacing: 4) {
                    Icon(name: "humidity", size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                    
                    Text("\(Int(humidity * 100))%")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            
            if let wind = weather.windSpeedMph, let direction = weather.windDirection {
                HStack(spacing: 4) {
                    Icon(name: "wind", size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                    
                    Text("\(Int(wind))mph \(direction)")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            
            Spacer(minLength: 0)
            
            if let logoURL = weatherService.attribution(for: colorScheme),
               let legalURL = weatherService.attributionLegalPageURL ?? weatherService.kLegal {
                Link(destination: legalURL) {
                    AsyncImage(url: logoURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: { Color.clear }
                    .frame(height: 12)
                }
            }
        }
    }
    
    private var formattedLastUpdated: String {
        let date = Date(timeIntervalSince1970: snapshot.round.lastUpdatedAt.unix)
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        let rows = viewModel.leaderboardRows
        let avg = viewModel.overallAvgScoreToPar
        let avgBreakIndex = rows.firstIndex(where: { Double($0.scoreToPar) > avg }) ?? rows.count

        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index == avgBreakIndex {
                    avgBreaklineDivider(avg)
                }

                LeaderboardRowView(
                    palette: palette,
                    placeLabel: row.placeLabel,
                    row: row,
                    teamColor: viewModel.teamColor(for: row.participant),
                    nameDisplayFormat: viewModel.nameDisplayFormat,
                    onTogglePinned: { viewModel.togglePinned(row.participant) },
                    onTap: { viewModel.presentedParticipant = row.participant }
                )

                if row.id != rows.last?.id {
                    Divider().opacity(0.25)
                } else if avgBreakIndex == rows.count {
                    avgBreaklineDivider(avg)
                }
            }
        }
    }

    private func avgBreaklineDivider(_ avg: Double) -> some View {
        HStack(spacing: 12) {
            Line(color: .neutral3)
            Text("AVG: \(viewModel.formattedAvgScore(avg))")
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(Color.neutral3)
            Line(color: .neutral3)
        }
        .padding(.vertical, 6)
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
                            nameDisplayFormat: viewModel.nameDisplayFormat,
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
                .fontStyle(kFontName, size: 13, weight: .semibold)
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
        HStack(spacing: 4) {
            Text(label + ":")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral2)
            Text(value)
                .fontStyle(kFontName, size: 13, weight: .semibold)
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
                    themeColor: viewModel.theme.color,
                    cornerRadius: 24
                )
                .frame(width: skeletonAvatarSize, height: skeletonAvatarSize)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        themeColor: viewModel.theme.color,
                        cornerRadius: 6
                    )
                    .frame(maxWidth: .infinity, minHeight: skeletonNameHeight, maxHeight: skeletonNameHeight, alignment: .leading)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        themeColor: viewModel.theme.color,
                        cornerRadius: 5
                    )
                    .frame(width: 90, height: skeletonSubtitleHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 10
                )
                .frame(width: skeletonButtonWidth, height: skeletonButtonHeight)
        }
    }
    
    private var leaderboardSkeletonPickers: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .liveRoundSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 8)
                .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .liveRoundSkeleton(palette: palette, themeColor: viewModel.theme.color, cornerRadius: 8)
                .frame(width: 130, height: 32)
        }
    }

    private var leaderboardSkeletonHeader: some View {
        HStack(spacing: 10) {
            groupStatLabel("Best", value: "E")
            groupStatLabel("Avg", value: "E")
            Spacer(minLength: 0)
//            Color.clear
//                .frame(width: leaderboardHeaderScoreWidth, height: 1)
//            Text("Thru")
//                .fontStyle(kFontName, size: 11, weight: .regular)
//                .foregroundStyle(Color.neutral2)
//                .frame(width: leaderboardHeaderThruWidth, alignment: .center)
//            Color.clear
//                .frame(width: leaderboardHeaderStarWidth, height: 1)
        }
    }

    private var leaderboardSkeletonRow: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(width: 30, height: skeletonCellHeight)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(maxWidth: .infinity, minHeight: skeletonCellHeight, maxHeight: skeletonCellHeight, alignment: .leading)
            
            Spacer(minLength: 0)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(width: leaderboardHeaderScoreWidth, height: skeletonCellHeight)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(width: leaderboardHeaderThruWidth, height: skeletonCellHeight)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(width: leaderboardHeaderStarWidth, height: skeletonCellHeight)
        }
    }
}

private struct LiveRoundSkeletonModifier: ViewModifier {
    let palette: DesignPalette
    let themeColor: Color?
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        let color = themeColor.map { $0.opacity(0.4) } ?? palette.skeletonColor
        let background = themeColor.map { $0.opacity(0.12) } ?? palette.skeletonBackground
        return content.skeleton(
            with: true,
            animation: .linear(duration: 2.0),
            appearance: .solid(
                color: color,
                background: background
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
        themeColor: Color? = nil,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(
            LiveRoundSkeletonModifier(
                palette: palette,
                themeColor: themeColor,
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

