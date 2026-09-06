//
//  LiveRound+Scoring.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

// MARK: - Scoring

extension LiveRound {
    var scoringContent: some View {
        holePagedScoringSections
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
            .alert("Can't update status", isPresented: Binding(
                get: { viewModel.presenceErrorMessage != nil },
                set: { if !$0 { viewModel.presenceErrorMessage = nil } }
            ), presenting: viewModel.presenceErrorMessage) { _ in
                Button("OK", role: .cancel) {
                    viewModel.presenceErrorMessage = nil
                }
            } message: { message in
                Text(message)
            }
            .sheet(item: $viewModel.presentedScoringSession) { session in
                LiveHoleScoringView(
                    viewModel: viewModel,
                    scoringSession: session
                )
                .presentationDragIndicator(.hidden)
                .presentationDetents([.height(700)])
                //.presentationBackground(.ultraThinMaterial)
                .interactiveDismissDisabled(true)
            }
            .alert("Reveal Scores", isPresented: $showRevealConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reveal") {
                    Task { await roundSession.revealScores() }
                }
            } message: {
                Text("Reveal all scores? This cannot be undone.")
            }
    }
    
    private var holePagedScoringSections: some View {
        let holes = viewModel.holeNumbers
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                PagedHoleScrollView(
                    holeNumbers: holes,
                    scoringPageHole: $scoringPageHole,
                    coordinator: pageCoordinator,
                    resetIdentity: pagerResetIdentity
                ) { holeNumber in
                    VStack(spacing: 16) {
                        navPadding
                        holeDetailsCard(for: holeNumber)
                        teeGroupScorecard(for: holeNumber)
                    }
                }
                .padding(.top, UIApplication.shared.topSafeAreaInset)

                swipeHintTile
                    .padding(.horizontal, 16)

                Color.clear.frame(height: 100)
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            guard !holes.isEmpty else { return }
            if let current = scoringPageHole, holes.contains(current) { return }
            scoringPageHole = viewModel.currentHoleNumber
        }
        .onChange(of: scoringPageHole) { old, new in
            if old != nil && old != new {
                dismissSwipeHintIfNeeded()
            }
        }
    }

    func liveSeriesScoreboardTile(_ scoreboard: SeriesScoreboardSnapshot) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(liveScoreboardTitle(scoreboard))
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .textCase(.uppercase)
                Spacer(minLength: 12)
                if scoreboard.usesProjectedTotals {
                    Text("Live")
                        .fontStyle(kFontName, size: 11, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentGreen.opacity(0.14)))
                }
            }

            HStack(spacing: 16) {
                if let first = scoreboard.entries.first {
                    liveScoreboardEntryColumn(first, isTrailing: false)
                }

                Rectangle()
                    .fill(Color.neutral.opacity(0.28))
                    .frame(width: 1, height: 54)

                if scoreboard.entries.count > 1 {
                    liveScoreboardEntryColumn(scoreboard.entries[1], isTrailing: true)
                }
            }

            Text(liveScoreboardFooter(scoreboard))
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(Color.neutral)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false, forceMaterial: true, tint: palette.cardColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(liveScoreboardAccessibilityLabel(scoreboard))
    }

    private func liveScoreboardEntryColumn(
        _ entry: SeriesScoreboardEntry,
        isTrailing: Bool
    ) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 6) {
            Text(entry.projectedPoints.seriesPointsDisplayString)
                .fontStyle(kFontName, size: 36, weight: .semibold)
                .foregroundStyle(liveScoreboardAccentColor(for: entry))
                .contentTransition(.numericText())
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            HStack(spacing: 6) {
                Circle()
                    .fill(liveScoreboardAccentColor(for: entry))
                    .frame(width: 10, height: 10)

                Text(entry.competitorName)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text("Start \(entry.officialPoints.seriesPointsDisplayString)")
                .fontStyle(kFontName, size: 11, weight: .regular)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }

    private func liveScoreboardTitle(_ scoreboard: SeriesScoreboardSnapshot) -> String {
        let completed = scoreboard.roundSummaries.filter(\.isFinalized).count
        if completed > 0 {
            return "Series after round \(completed)"
        }
        return scoreboard.usesProjectedTotals ? "Series live" : "Series scoreboard"
    }

    private func liveScoreboardFooter(_ scoreboard: SeriesScoreboardSnapshot) -> String {
        let startingScores = scoreboard.entries
            .prefix(2)
            .map { "\($0.competitorName) \($0.officialPoints.seriesPointsDisplayString)" }
            .joined(separator: " · ")
        return "Starting score: \(startingScores)"
    }

    private func liveScoreboardAccessibilityLabel(_ scoreboard: SeriesScoreboardSnapshot) -> String {
        let entries = scoreboard.entries
            .map { "\($0.competitorName) projected \($0.projectedPoints.seriesPointsDisplayString) points, starting \($0.officialPoints.seriesPointsDisplayString)" }
            .joined(separator: ", ")
        return "Series scoreboard. \(entries). \(liveScoreboardFooter(scoreboard))."
    }

    private func liveScoreboardAccentColor(for entry: SeriesScoreboardEntry) -> Color {
        guard entry.competitorType == .team,
              let team = viewModel.snapshot.teams.first(where: { $0.id == entry.competitorID }) else {
            return palette.foregroundColor
        }
        return team.displaySwatchColor ?? palette.foregroundColor
    }

    @ViewBuilder
    private func holeDetailsCard(for holeNumber: Int) -> some View {
        if shouldShowScoringSkeleton {
            holeDetailSkeleton
        } else {
            HoleDetailTilesView(viewModel: viewModel, palette: palette, holeNumber: holeNumber)
        }
    }

    @ViewBuilder
    private func teeGroupScorecard(for holeNumber: Int) -> some View {
        if !viewModel.canScoreVisibleGroup {
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
                    scoringRows(for: holeNumber)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .glassCardEffect(interactive: false, forceMaterial: true, tint: palette.cardColor)
        }
    }

    @ViewBuilder
    private func scoringRows(for holeNumber: Int) -> some View {
        switch snapshot.configuration.scoreOwnerScope {
        case .teeGroup:
            teeGroupSharedRows(for: holeNumber)
        case .partnership:
            if snapshot.isSharedScoreSource {
                partnershipSharedRows(for: holeNumber)
            } else {
                partnershipIndividualRows(for: holeNumber)
            }
        case .individual:
            if snapshot.isSharedScoreSource {
                teamSharedRows(for: holeNumber)
            } else {
                participantRows(for: holeNumber)
            }
        }
    }

    @ViewBuilder
    private func participantRows(for holeNumber: Int) -> some View {
        ForEach(viewModel.teeGroupTeamSections) { section in
            ForEach(section.participants) { participant in
                PlayerScoringRow(
                    palette: palette,
                    viewModel: viewModel,
                    participant: participant,
                    holeNumber: holeNumber,
                    requiresTeams: roundSession.snapshot.requiresTeams,
                    onRowTap: {
                        viewModel.presentedScoringSession = viewModel.scoringSession(
                            for: $0,
                            holeNumber: holeNumber
                        )
                    },
                    onEnterScoreTap: {
                        viewModel.presentedScoringSession = viewModel.scoringSession(
                            for: $0,
                            holeNumber: holeNumber
                        )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func teamSharedRows(for holeNumber: Int) -> some View {
        sharedSubjectRows(
            subjects: viewModel.visibleSharedScoringSubjects,
            holeNumber: holeNumber,
            emptyMessage: "Waiting for tee group assignments before entering shared scores."
        )
    }

    @ViewBuilder
    private func partnershipSharedRows(for holeNumber: Int) -> some View {
        sharedSubjectRows(
            subjects: viewModel.visibleSharedScoringSubjects,
            holeNumber: holeNumber,
            emptyMessage: "Set up pair scoring groups in the lobby before entering scores."
        )
    }

    @ViewBuilder
    private func partnershipIndividualRows(for holeNumber: Int) -> some View {
        ForEach(viewModel.teeGroupTeamSections) { section in
            let partnershipGroups = viewModel.partnershipGroups(in: section.participants)
            let partnershipIDs = Set(partnershipGroups.flatMap(\.memberIDs))

            VStack(spacing: 12) {
                ForEach(partnershipGroups) { scoringGroup in
                    partnershipHeader(for: scoringGroup, holeNumber: holeNumber)

                    ForEach(viewModel.participants(for: scoringGroup)) { participant in
                        PlayerScoringRow(
                            palette: palette,
                            viewModel: viewModel,
                            participant: participant,
                            holeNumber: holeNumber,
                            requiresTeams: roundSession.snapshot.requiresTeams,
                            onRowTap: {
                                let roster = viewModel.participants(for: scoringGroup)
                                viewModel.presentedScoringSession = viewModel.scoringSession(
                                    for: $0,
                                    holeNumber: holeNumber,
                                    roster: roster
                                )
                            },
                            onEnterScoreTap: {
                                let roster = viewModel.participants(for: scoringGroup)
                                viewModel.presentedScoringSession = viewModel.scoringSession(
                                    for: $0,
                                    holeNumber: holeNumber,
                                    roster: roster
                                )
                            }
                        )
                        .padding(.leading, 18)
                    }
                }

                ForEach(section.participants.filter { !partnershipIDs.contains($0.id) }) { participant in
                    PlayerScoringRow(
                        palette: palette,
                        viewModel: viewModel,
                        participant: participant,
                        holeNumber: holeNumber,
                        requiresTeams: roundSession.snapshot.requiresTeams,
                        onRowTap: {
                            viewModel.presentedScoringSession = viewModel.scoringSession(
                                for: $0,
                                holeNumber: holeNumber
                            )
                        },
                        onEnterScoreTap: {
                            viewModel.presentedScoringSession = viewModel.scoringSession(
                                for: $0,
                                holeNumber: holeNumber
                            )
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func teeGroupSharedRows(for holeNumber: Int) -> some View {
        sharedSubjectRows(
            subjects: viewModel.visibleSharedScoringSubjects,
            holeNumber: holeNumber,
            emptyMessage: "Set up a group scoring owner in the lobby before entering scores."
        )
    }

    @ViewBuilder
    private func sharedSubjectRows(
        subjects: [LiveRoundViewModel.SharedScoringSubject],
        holeNumber: Int,
        emptyMessage: String
    ) -> some View {
        if subjects.isPopulated {
            VStack(spacing: 12) {
                ForEach(subjects) { subject in
                    if let session = viewModel.sharedScoringSession(for: subject, holeNumber: holeNumber) {
                        SharedScoreOwnerRow(
                            palette: palette,
                            viewModel: viewModel,
                            title: subject.title,
                            subtitle: subject.subtitle,
                            participants: session.participants,
                            holeNumber: holeNumber,
                            scoringUnitID: session.scoringUnitID,
                            accentColor: subject.accentColor,
                            onEnterScoreTap: {
                                viewModel.presentedScoringSession = session
                            }
                        )
                    }
                }
            }
        } else {
            Text(emptyMessage)
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .padding(.vertical, 12)
        }
    }

    private func partnershipHeader(for scoringGroup: RoundScoringGroup, holeNumber: Int) -> some View {
        let accent = viewModel.scoringGroupAccentColor(scoringGroup) ?? palette.foregroundColor
        let title = viewModel.scoringGroupLabel(scoringGroup)
        let subtitle = viewModel.countedBallLabel(for: scoringGroup, holeNumber: holeNumber)

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(accent.opacity(0.4))
                .frame(width: 4, height: subtitle?.isPopulated == true ? 34 : 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Icon(name: "link", size: 12, weight: .semibold)
                        .foregroundStyle(accent)

                    Text(title)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(accent)
                }

                if let subtitle, subtitle.isPopulated {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                }
            }

            Spacer(minLength: 0)

        }
        .padding(.top, 4)
    }
}

// MARK: - Hole Detail Tiles

/// Shared hole detail tiles for LiveRound scoring.
struct HoleDetailTilesView: View {
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let holeNumber: Int

    private var hole: Hole? {
        viewModel.hole(for: holeNumber, teeID: viewModel.selectedTeeID)
    }

    var body: some View {
        HStack(spacing: 8) {
            cube(value: hole.map { "\($0.par)" } ?? "—", label: "par")
            cube(value: hole.map { "\($0.yardage)" } ?? "—", label: "yards")
            cube(value: hole.map { "\($0.handicap ?? 0)" } ?? "—", label: "hcp")

            Menu {
                if viewModel.teeOptionsForMenuMale.isPopulated {
                    Menu {
                        ForEach(viewModel.teeOptionsForMenuMale) { option in teeButton(option) }
                    } label: { Text("Men's") }
                }
                if viewModel.teeOptionsForMenuFemale.isPopulated {
                    Menu {
                        ForEach(viewModel.teeOptionsForMenuFemale) { option in teeButton(option) }
                    } label: { Text("Women's") }
                }
                if viewModel.teeOptionsForMenuOther.isPopulated {
                    Menu {
                        ForEach(viewModel.teeOptionsForMenuOther) { option in teeButton(option) }
                    } label: { Text("Other") }
                }
            } label: {
                cube(value: viewModel.selectedTeeName, label: "tees", icon: "chevron.right", lineLimit: 2)
            }
        }
    }

    private func cube(value: String, label: String, icon: String? = nil, lineLimit: Int = 2) -> some View {
        StackedSubtitle(value: value, label: label, icon: icon, size: 20, lineLimit: lineLimit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 72)
            .glassCardEffect(cornerRadius: 12, interactive: false, forceMaterial: true, tint: palette.cardColor, shadowOpacity: 0)
    }

    private func teeButton(_ option: LiveRoundViewModel.TeeSelectionOption) -> some View {
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
}

// MARK: - Swipe Hint

private struct SwipeHintTileView: View {
    let palette: DesignPalette

    @State private var swipeOffset: CGFloat = -25
    var onTap: Callback? = nil
    
    var body: some View {
        Button {
            Haptics.fire(.light)
            onTap?()
        } label: {
            VStack(spacing: 8) {
                Icon(name: "e1a2", size: 28, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .offset(x: swipeOffset)
                Text("Swipe left and right above to navigate holes")
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 1.2).repeatForever(autoreverses: true)) {
                swipeOffset = 25
            }
        }
    }
}

// MARK: - Leaderboard

extension LiveRound {
    private var pagerResetIdentity: String {
        let groupID = viewModel.visibleTeeGroupID ?? "all"
        let holeOrder = viewModel.holeNumbers.map(String.init).joined(separator: ",")
        return "\(groupID)|\(holeOrder)"
    }

    func dismissSwipeHintIfNeeded() {
        guard showSwipeHint else { return }
        withAnimation {
            showSwipeHint = false
        }
    }

    private var displayedScoringHole: Int {
        scoringPageHole ?? viewModel.currentHoleNumber
    }

    private var isDisplayedHoleUnscored: Bool {
        viewModel.holeCompletionProgress(holeNumber: displayedScoringHole) == 0
    }

    @ViewBuilder
    private var swipeHintTile: some View {
        if showSwipeHint && !shouldShowScoringSkeleton && isDisplayedHoleUnscored {
            SwipeHintTileView(palette: palette, onTap: {
                dismissSwipeHintIfNeeded()
            })
        }
    }

    @ViewBuilder
    var vegasSummaryTile: some View {
        if !shouldShowScoringSkeleton, let summary = viewModel.vegasLiveSummary {
            VegasSummaryTileView(summary: summary, palette: palette, viewModel: viewModel)
        }
    }

    var leaderboardSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Leaderboard".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                if let subtitle = viewModel.leaderboardRankSelectionSubtitle {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                        .alignCenter()
                }
            }

            Line()

            if !shouldShowScoringSkeleton {
                // Do we swap these?
                leaderboardScoringChips
                leaderboardPickers
            }

            if shouldShowScoringSkeleton {
                VStack(spacing: 10) {
                    leaderboardSkeletonPickers
                    
                    ForEach(0..<6, id: \.self) { index in
                        leaderboardSkeletonRow
                        
                        if index != 5 {
                            Divider().opacity(0.25)
                        }
                    }
                }
            } else if viewModel.effectiveLeaderboardRows.isEmpty {
                Text(viewModel.snapshot.isSharedScoreSource && viewModel.snapshot.participants.contains(where: viewModel.isPresenceActive)
                     ? "No shared scoring groups are set up yet."
                     : "No players in this round yet.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignCenter()
            } else {
                leaderboardColumnHeaders

                switch viewModel.leaderboardMode {
                case .individual:
                    individualLeaderboardList
                case .team:
                    groupedLeaderboardList(sections: viewModel.displayTeamLeaderboardSections)
                case .teeGroup:
                    groupedLeaderboardList(sections: viewModel.displayTeeGroupLeaderboardSections)
                }
            }
            
            Line()
            
            leaderboardFooter
            
//            if let snapshot = weatherService.currentSnapshot {
//                Line()
//                weatherDetails(for: snapshot)
//            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false, forceMaterial: true, tint: palette.cardColor)
    }
    
    private var leaderboardFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = snapshot.courseInfo?.name, name.isPopulated {
                Text(name.uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            HStack {
                Text("Last updated at \(formattedLastUpdated)")
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                Spacer(minLength: 0)
                
                LiveStatusView(color: viewModel.theme.color)
            }
        }
        .padding(.top, 4)
    }
    
//    private func weatherDetails(for weather: WeatherSnapshot) -> some View {
//        HStack(spacing: 12) {
//            HStack(spacing: 4) {
//                Icon(name: "thermometer", size: 13, weight: .medium)
//                    .foregroundStyle(Color.neutral2)
//                
//                Text("\(weather.temperature)° F")
//                    .fontStyle(kFontName, size: 13, weight: .semibold)
//                    .foregroundStyle(palette.foregroundColor)
//            }
//            
//
//            if let humidity = weather.humidity {
//                HStack(spacing: 4) {
//                    Icon(name: "humidity", size: 13, weight: .medium)
//                        .foregroundStyle(Color.neutral2)
//                    
//                    Text("\(Int(humidity * 100))%")
//                        .fontStyle(kFontName, size: 13, weight: .semibold)
//                        .foregroundStyle(palette.foregroundColor)
//                }
//            }
//            
//            if let wind = weather.windSpeedMph, let direction = weather.windDirection {
//                HStack(spacing: 4) {
//                    Icon(name: "wind", size: 13, weight: .medium)
//                        .foregroundStyle(Color.neutral2)
//                    
//                    Text("\(Int(wind))mph \(direction)")
//                        .fontStyle(kFontName, size: 13, weight: .semibold)
//                        .foregroundStyle(palette.foregroundColor)
//                }
//            }
//            
//            Spacer(minLength: 0)
//            
//            if let logoURL = weatherService.attribution(for: colorScheme),
//               let legalURL = weatherService.attributionLegalPageURL ?? weatherService.kLegal {
//                Link(destination: legalURL) {
//                    AsyncImage(url: logoURL) { image in
//                        image.resizable().aspectRatio(contentMode: .fit)
//                    } placeholder: { Color.clear }
//                    .frame(height: 12)
//                }
//            }
//        }
//    }
    
    /// Newer of: snapshot received, local score write, most recent score entry, or round.lastUpdatedAt.
    private var formattedLastUpdated: String {
        let fallback = Date(timeIntervalSince1970: snapshot.round.lastUpdatedAt.unix)
        let dates: [Date] = [
            viewModel.lastSnapshotReceivedAt,
            viewModel.lastLocalScoreAt,
            snapshot.scoring.map { Date(timeIntervalSince1970: $0.lastUpdatedAt.unix) }.max()
        ].compactMap { $0 }
        let date = (dates + [fallback]).max() ?? fallback
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Leaderboard Scoring Chips

    @ViewBuilder
    private var leaderboardScoringChips: some View {
        let chips = viewModel.availableLeaderboardChips
        if chips.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.rawValue) { chip in
                        let isSelected = viewModel.effectiveLeaderboardChip == chip
                        Button {
                            Haptics.fire(.light)
                            viewModel.selectedLeaderboardChip = chip
                        } label: {
                            Text(chip.label)
                                .fontStyle(kFontName, size: 13, weight: isSelected ? .semibold : .medium)
                                .foregroundStyle(isSelected ? viewModel.theme.color : Color.neutral2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    isSelected ? (viewModel.theme.color.opacity(colorScheme.translucent)) : Color.clear
                                )
                        )
                    }
                }
            }
            .padding(.bottom, 8)
        }
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
                Text(viewModel.leaderboardModeLabel(for: mode)).tag(mode)
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

    private var leaderboardColumnHeaders: some View {
        leaderboardColumnHeaderRow(showsHandicapColumn: viewModel.handicapsEnabled)
            .accessibilityHidden(true)
    }

    private func leaderboardColumnHeaderRow(showsHandicapColumn: Bool) -> some View {
        HStack(spacing: 8) {
            Text("#")
                .frame(width: 38, alignment: .center)

            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsHandicapColumn {
                Text("HCP")
                    .frame(width: 42, alignment: .center)
            }

            Text(viewModel.scoreBasis == .gross ? "Gross" : "Net")
                .frame(width: 40, alignment: .center)

            Text("Thru")
                .frame(width: 40, alignment: .center)

        }
        .fontStyle(kFontName, size: 10, weight: .semibold)
        .foregroundStyle(Color.neutral3)
        .textCase(.uppercase)
    }
    
    private var individualLeaderboardList: some View {
        let rows = viewModel.displayLeaderboardRows
        let isHighestWins = viewModel.snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins
        let avgRows = viewModel.rowsEligibleForAverageDisplay
        let avg = viewModel.averageForDisplay(rows: avgRows)
        let isSecretActive = snapshot.isSecretScoring && !snapshot.areScoresRevealed
        let myTeamID = viewModel.currentParticipant?.teamID
        let avgBreakParticipantID: String? = {
            guard let avg else { return nil }
            let scoreOrdered = rows.filter { !$0.isPinned }.sorted {
                let a = $0.totalPoints ?? Double($0.scoreToPar)
                let b = $1.totalPoints ?? Double($1.scoreToPar)
                if a != b { return isHighestWins ? a > b : a < b }
                return ($0.teamName ?? $0.participant.alphabeticName) < ($1.teamName ?? $1.participant.alphabeticName)
            }
            return scoreOrdered.first(where: { row in
                let score = row.totalPoints ?? Double(row.scoreToPar)
                return isHighestWins ? score <= avg : score >= avg
            })?.participant.id
        }()
        let showAvgLineAfterLast = avgBreakParticipantID == nil && avg != nil

        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if let id = avgBreakParticipantID, let avg, row.participant.id == id {
                    avgBreaklineDivider(avg)
                }

                let hideScore = isSecretActive && row.teamID != myTeamID && row.participant.teamID != myTeamID

                LeaderboardRowView(
                    palette: palette,
                    placeLabel: row.placeLabel,
                    row: row,
                    teamColor: row.teamColor ?? viewModel.teamColor(for: row.participant),
                    nameDisplayFormat: viewModel.nameDisplayFormat,
                    usesFormatDisplay: row.totalPoints != nil,
                    isHighestWinsFormat: viewModel.snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins,
                    isScoreHidden: hideScore,
                    showsHandicap: viewModel.handicapsEnabled,
                    onTap: { viewModel.presentedParticipant = row.participant }
                )

                if row.id != rows.last?.id {
                    Divider().opacity(0.25)
                } else if showAvgLineAfterLast, let avg {
                    avgBreaklineDivider(avg)
                }
            }
        }
    }

    private func avgBreaklineDivider(_ avg: Double) -> some View {
        HStack(spacing: 12) {
            Line(color: .neutral3)
            Text("AVG: \(viewModel.formattedAvgForDisplay(avg))")
                .fontStyle(kFontName, size: 12, weight: .medium)
                .foregroundStyle(Color.neutral3)
            Line(color: .neutral3)
        }
    }
    
    // MARK: - Grouped List (Team / Tee Group)
    
    private func groupedLeaderboardList(sections: [LiveRoundViewModel.GroupedLeaderboardSection]) -> some View {
        let isSecretActive = snapshot.isSecretScoring && !snapshot.areScoresRevealed
        let myTeamID = viewModel.currentParticipant?.teamID

        return VStack(spacing: 4) {
            ForEach(sections) { section in
                groupSectionHeader(section)
                
                VStack(spacing: 8) {
                    ForEach(section.rows) { row in
                        let hideScore = isSecretActive && row.teamID != myTeamID && row.participant.teamID != myTeamID

                        LeaderboardRowView(
                            palette: palette,
                            placeLabel: row.placeLabel,
                            row: row,
                            teamColor: row.teamColor ?? viewModel.teamColor(for: row.participant),
                            nameDisplayFormat: viewModel.nameDisplayFormat,
                            usesFormatDisplay: row.totalPoints != nil,
                            isHighestWinsFormat: viewModel.snapshot.resolvedActiveTemplate.leaderboardSort == .highestWins,
                            isScoreHidden: hideScore,
                            showsHandicap: viewModel.handicapsEnabled,
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
                if viewModel.showsGroupedLeaderboardSectionTotal {
                    groupStatLabel("Tot", value: viewModel.formattedGroupedSectionSum(section.sumAggregatedScore))
                }
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

private struct VegasSummaryTileView: View {
    let summary: LiveRoundViewModel.VegasLiveSummary
    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Vegas".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                Text(summary.basis == .net ? "Net" : "Gross")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                    .alignCenter()
            }

            Line()

            VStack(spacing: 10) {
                ForEach(summary.standings) { standing in
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(standing.placeLabel)
                                .fontStyle(kFontName, size: 13, weight: .medium)
                                .foregroundStyle(Color.neutral2)
                                .frame(width: 38, alignment: .center)

                            if let color = standing.color {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color.opacity(0.9))
                                    .frame(width: 4, height: standing.breakdowns.isEmpty ? 18 : 28)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(standing.teamName)
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                                    .lineLimit(1)

                                if standing.memberNames.isPopulated {
                                    Text(standing.memberNames)
                                        .fontStyle(kFontName, size: 12, weight: .regular)
                                        .foregroundStyle(Color.neutral)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)

                            Text(viewModel.formattedVegasTotal(standing.total))
                                .fontStyle(kFontName, size: 16, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)

                            Text("\(standing.thru)")
                                .fontStyle(kFontName, size: 14, weight: .medium)
                                .foregroundStyle(Color.neutral2)
                                .frame(width: 32, alignment: .center)
                        }

                        if summary.mode == .partnershipAggregate, standing.breakdowns.isPopulated {
                            Text(standing.breakdowns.map {
                                "\($0.title) \(viewModel.formattedVegasTotal($0.total))"
                            }.joined(separator: " + ") + " = \(viewModel.formattedVegasTotal(standing.total))")
                                .fontStyle(kFontName, size: 12, weight: .medium)
                                .foregroundStyle(Color.neutral2)
                                .alignLeading()
                                .padding(.leading, 50)
                        }
                    }

                    if standing.id != summary.standings.last?.id {
                        Divider().opacity(0.22)
                    }
                }
            }

            Line()

            HStack {
                Text(summary.leaderText)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                Text("Thru \(summary.thru)")
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false, forceMaterial: true, tint: palette.cardColor)
    }
}

// MARK: - Skeleton Rows

extension LiveRound {
    private var holeDetailSkeleton: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        themeColor: viewModel.theme.color,
                        cornerRadius: 12
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
            }
        }
    }

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

    private var leaderboardSkeletonRow: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(width: 38, height: skeletonCellHeight)
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .liveRoundSkeleton(
                    palette: palette,
                    themeColor: viewModel.theme.color,
                    cornerRadius: 6
                )
                .frame(maxWidth: .infinity, minHeight: skeletonCellHeight, maxHeight: skeletonCellHeight, alignment: .leading)
            
            Spacer(minLength: 0)

            if viewModel.handicapsEnabled {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .liveRoundSkeleton(
                        palette: palette,
                        themeColor: viewModel.theme.color,
                        cornerRadius: 6
                    )
                    .frame(width: 42, height: skeletonCellHeight)
            }

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
            
        }
    }
}

private struct LiveRoundSkeletonModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let palette: DesignPalette
    let themeColor: Color?
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        let color = themeColor.map { $0.opacity(0.4) } ?? palette.skeletonColor
        let background = themeColor.map { $0.opacity(0.12) } ?? palette.skeletonBackground

        content
            .hidden()
            .overlay {
                GeometryReader { geometry in
                    let width = max(geometry.size.width, 1)
                    let shimmerWidth = max(width * 0.55, 44)
                    let shape = RoundedRectangle(cornerRadius: cornerRadius)

                    if accessibilityReduceMotion {
                        shape
                            .fill(background)
                            .overlay {
                                shape
                                    .fill(color.opacity(0.45))
                            }
                    } else {
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                            let duration: TimeInterval = 1.6
                            let phase = timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: duration) / duration

                            shape
                                .fill(background)
                                .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, color, .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: shimmerWidth)
                                    .offset(x: phase * (width + shimmerWidth) - shimmerWidth)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .accessibilityHidden(true)
            .transaction { transaction in
                transaction.animation = nil
            }
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

#Preview("2v2 Red vs Blue") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRound2v2.snapshot)
}

#Preview("Ryder Cup (16, Mixed Groups)") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRoundRyderCup.snapshot)
}

#Preview("Four Teams (4x4)") {
    LiveRound.ImmediatePreview(snapshot: MockLiveRoundFourTeams.snapshot)
}

#Preview("Vegas Tile - 2 Teams") {
    VegasSummaryTilePreview(summary: VegasSummaryPreviewData.twoTeamExactPair)
}

#Preview("Vegas Tile - 4 Teams") {
    VegasSummaryTilePreview(summary: VegasSummaryPreviewData.fourTeamField)
}

#Preview("Vegas Tile - Partnerships") {
    VegasSummaryTilePreview(summary: VegasSummaryPreviewData.oversizedPartnershipAggregate)
}

#Preview("Vegas Tile - Selected Pair") {
    VegasSummaryTilePreview(summary: VegasSummaryPreviewData.oversizedSelectedPair)
}

private struct VegasSummaryTilePreview: View {
    let summary: LiveRoundViewModel.VegasLiveSummary

    @StateObject private var viewModel = LiveRoundViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VegasSummaryTileView(
            summary: summary,
            palette: DesignPalette(theme: .primary, scheme: colorScheme),
            viewModel: viewModel
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

private enum VegasSummaryPreviewData {
    static let twoTeamExactPair = LiveRoundViewModel.VegasLiveSummary(
        basis: .net,
        standings: [
            .init(
                id: "team_a",
                teamID: "team_a",
                teamName: "Team A",
                memberNames: "John Smith, Mike Jones",
                placeLabel: "1",
                total: 101,
                thru: 2,
                color: .red,
                breakdowns: []
            ),
            .init(
                id: "team_b",
                teamID: "team_b",
                teamName: "Team B",
                memberNames: "Tom Davis, Alex Lee",
                placeLabel: "2",
                total: 112,
                thru: 2,
                color: .blue,
                breakdowns: []
            )
        ],
        leaderText: "Team A leads Team B by 11",
        thru: 2,
        mode: .exactPair
    )

    static let fourTeamField = LiveRoundViewModel.VegasLiveSummary(
        basis: .gross,
        standings: [
            .init(
                id: "red",
                teamID: "red",
                teamName: "Red Team",
                memberNames: "Evan Cole, Noah Bishop",
                placeLabel: "1",
                total: 146,
                thru: 3,
                color: .red,
                breakdowns: []
            ),
            .init(
                id: "green",
                teamID: "green",
                teamName: "Green Team",
                memberNames: "Rowan Park, Reese Murray",
                placeLabel: "2",
                total: 151,
                thru: 3,
                color: .green,
                breakdowns: []
            ),
            .init(
                id: "blue",
                teamID: "blue",
                teamName: "Blue Team",
                memberNames: "Luca Mason, Sawyer Hale",
                placeLabel: "3",
                total: 154,
                thru: 3,
                color: .blue,
                breakdowns: []
            ),
            .init(
                id: "gold",
                teamID: "gold",
                teamName: "Gold Team",
                memberNames: "Quincy Holt, Blair Hughes",
                placeLabel: "4",
                total: 160,
                thru: 3,
                color: .orange,
                breakdowns: []
            )
        ],
        leaderText: "Red Team leads by 5",
        thru: 3,
        mode: .exactPair
    )

    static let oversizedPartnershipAggregate = LiveRoundViewModel.VegasLiveSummary(
        basis: .net,
        standings: [
            .init(
                id: "north",
                teamID: "north",
                teamName: "North",
                memberNames: "Smith, Jones, Brown, Lee",
                placeLabel: "1",
                total: 101,
                thru: 2,
                color: .teal,
                breakdowns: [
                    .init(id: "north_pair_1", title: "Smith/Jones", total: 45),
                    .init(id: "north_pair_2", title: "Brown/Lee", total: 56)
                ]
            ),
            .init(
                id: "south",
                teamID: "south",
                teamName: "South",
                memberNames: "Davis, Patel, Young, Clark",
                placeLabel: "2",
                total: 108,
                thru: 2,
                color: .indigo,
                breakdowns: [
                    .init(id: "south_pair_1", title: "Davis/Patel", total: 52),
                    .init(id: "south_pair_2", title: "Young/Clark", total: 56)
                ]
            )
        ],
        leaderText: "North leads South by 7",
        thru: 2,
        mode: .partnershipAggregate
    )

    static let oversizedSelectedPair = LiveRoundViewModel.VegasLiveSummary(
        basis: .net,
        standings: [
            .init(
                id: "captains",
                teamID: "captains",
                teamName: "Captains",
                memberNames: "Parker, Shaw, Ellis, Monroe",
                placeLabel: "1",
                total: 149,
                thru: 3,
                color: .mint,
                breakdowns: []
            ),
            .init(
                id: "chargers",
                teamID: "chargers",
                teamName: "Chargers",
                memberNames: "Hayes, Quinn, Stone, Reed",
                placeLabel: "2",
                total: 153,
                thru: 3,
                color: .purple,
                breakdowns: []
            ),
            .init(
                id: "trail",
                teamID: "trail",
                teamName: "Trail Team",
                memberNames: "Cole, Brooks, Flynn, Ward",
                placeLabel: "3",
                total: 158,
                thru: 3,
                color: .brown,
                breakdowns: []
            )
        ],
        leaderText: "Captains leads by 4",
        thru: 3,
        mode: .selectedPair
    )
}
