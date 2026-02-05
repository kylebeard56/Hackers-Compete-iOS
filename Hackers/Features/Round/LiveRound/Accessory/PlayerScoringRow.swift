//
//  PlayerScoringRow.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct PlayerScoringRow: View {
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
//                        ZStack {
//                            Circle()
//                                .fill(Color.white.opacity(0.10))
//                            
//                            Circle()
//                                .stroke(rowTint.opacity(0.85), lineWidth: 2)
//                        }
//                        .frame(width: 10, height: 10)
                        
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

            enterScoreButton

//            LazyVGrid(columns: grid, spacing: 6) {
//                scoreButton(value: quickScores[0]) // birdie
//                scoreButton(value: quickScores[1]) // par
//                scoreButton(value: quickScores[2]) // bogey
//                scoreButton(value: quickScores[3]) // double
//                scoreButton(value: quickScores[4]) // triple
//                customButton
//            }
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

    private var enterScoreButton: some View {
        let isScored = gross.exists
        let label = isScored
            ? viewModel.friendlyScoreSummary(strokes: gross ?? 0, par: holePar)
            : "Enter score"
        let tint = isScored ? palette.foregroundColor : palette.buttonColor
        let foreground: Color = isScored ? .white : palette.foregroundColor

        return Button {
            viewModel.presentedScoringParticipant = participant
        } label: {
            Text(label)
                .fontStyle(.poppins, size: 12, weight: .semibold)
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .glassCardEffect(cornerRadius: 12, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Player Scoring Row") {
    PlayerScoringRowPreview()
}

private struct PlayerScoringRowPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant
    private let requiresTeams: Bool
    
    init() {
        let snapshot = MockLiveRound2v2.snapshot
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id
        
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        
        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first!
        requiresTeams = snapshot.requiresTeams
    }
    
    var body: some View {
        let palette = DesignPalette(theme: .primary, scheme: colorScheme)
        
        return PlayerScoringRow(
            palette: palette,
            viewModel: viewModel,
            participant: participant,
            requiresTeams: requiresTeams
        )
        .padding(16)
        .background(palette.backgroundColor)
    }
}
