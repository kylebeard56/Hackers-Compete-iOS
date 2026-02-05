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
        .sheet(item: $viewModel.presentedScoringParticipant) { participant in
            LiveHoleScoringView(viewModel: viewModel, initialParticipant: participant)
                .presentationDragIndicator(.hidden)
                .presentationDetents([.height(620)])
                .interactiveDismissDisabled(true)
        }
        .sheet(item: $viewModel.presentedParticipant) { participant in
            ScorecardSheet(viewModel: viewModel, participant: participant)
                .presentationDragIndicator(.visible)
                .presentationDetents([.height(580)])
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
