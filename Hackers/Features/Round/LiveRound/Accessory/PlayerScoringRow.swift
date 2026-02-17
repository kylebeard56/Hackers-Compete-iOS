//
//  PlayerScoringRow.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct PlayerScoringRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    let palette: DesignPalette
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    let holeNumber: Int
    var requiresTeams: Bool
    
    private var hole: Hole? { viewModel.hole(for: holeNumber) }
    private var holePar: Int { hole?.par ?? 4 }
    
    private var gross: Int? {
        viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber)
    }
    
    private var strokesReceived: Int {
        viewModel.strokesReceivedOnHole(participant: participant, holeNumber: holeNumber)
    }
    
    private var net: Int? {
        viewModel.netStrokesOnHole(participant: participant, holeNumber: holeNumber)
    }
    
    private var scoreToParLabel: String {
        viewModel.formattedScoreToPar(viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis))
    }
    
    private var useHandicaps: Bool { viewModel.snapshot.round.configuration.useHandicaps }
    
//    private var quickScores: [Int] {
//        // birdie, par, bogey / double, triple
//        [holePar - 1, holePar, holePar + 1, holePar + 2, holePar + 3]
//    }
    
    private var grid: [GridItem] {
        [
            GridItem(.fixed(32), spacing: 6),
            GridItem(.fixed(32), spacing: 6),
            GridItem(.fixed(32), spacing: 6)
        ]
    }
    
    private var glassButtonColor: Color {
        palette.buttonColor.opacity(colorScheme, 0, 0.375)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.fire(.light)
                viewModel.presentedParticipant = participant
            } label: {
                scorePill
            }
            
            VStack(alignment: .leading, spacing: 4) {

                HStack(spacing: 8) {
                    Text(participant.name.fullName)
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
//                if gross.exists {
//                    // When scored: show the net stroke value under the name (MVP)
//                    Text("Net \(net ?? (gross ?? 0))")
//                        .fontStyle(kFontName, size: 12, weight: .regular)
//                        .foregroundStyle(Color.neutral)
//                } else {
//                    handicapDots
//                }
                if useHandicaps {
                    handicapDots
                }
            }
            
            Spacer(minLength: 0)

            enterScoreButton
                .frame(height: 48)

//            LazyVGrid(columns: grid, spacing: 6) {
//                scoreButton(value: quickScores[0]) // birdie
//                scoreButton(value: quickScores[1]) // par
//                scoreButton(value: quickScores[2]) // bogey
//                scoreButton(value: quickScores[3]) // double
//                scoreButton(value: quickScores[4]) // triple
//                customButton
//            }
        }
    }
    
    @ViewBuilder
    private var scorePill: some View {
        let scp = viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)
        
        HStack(spacing: 1) {
            if scp < 0 {
                Text("-")
                    .fontStyle(kFontName, size: 12, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)
            } else if scp > 0 {
                Text("+")
                    .fontStyle(kFontName, size: 12, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            Text(viewModel.formattedScoreToPar(abs(scp)))
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        .frame(width: 48, height: 48)
        .glassCardEffect(shape: .circle, tint: glassButtonColor)
    }
    
    @ViewBuilder
    private var handicapDots: some View {
        let teamColor = viewModel.teamColor(for: participant)
        let dotColor: Color = requiresTeams ? (teamColor ?? .neutral2) : palette.foregroundColor
        let dotSize: CGFloat = 8
        
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        dotColor,
                        lineWidth: index < strokesReceived ? 0 : 1
                    )
                    .background(
                        Circle()
                            .fill(index < strokesReceived ? dotColor : .clear)
                    )
                    .frame(width: dotSize, height: dotSize)
            }
        }

//        Group {
//            if strokesReceived > 0 {
//                let teamColor = viewModel.teamColor(for: participant)
//                let dotColor: Color = requiresTeams ? (teamColor ?? Color.neutral2) : Color.neutral3
//                
//                HStack(spacing: 3) {
//                    ForEach(0..<strokesReceived, id: \.self) { _ in
//                        Circle()
//                            .fill(dotColor)
//                            .frame(width: 5, height: 5)
//                    }
//                }
//            } else {
//                EmptyView()
//            }
//        }
    }
    
//    @ViewBuilder
//    private func scoreButton(value: Int) -> some View {
//        let selected = gross == value
//        let selectedTint = viewModel.teamColor(for: participant) ?? palette.foregroundColor
//        let background = selected ? selectedTint : palette.buttonColor
//        let foreground = selected ? palette.buttonColor : palette.foregroundColor
//        
//        Button {
//            Haptics.fire(.light)
//            Task {
//                if selected {
//                    await viewModel.clearScore(participant: participant)
//                } else {
//                    await viewModel.setQuickScore(participant: participant, strokes: value)
//                }
//            }
//        } label: {
//            if selected {
//                Text("\(value)")
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .background(background)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            } else {
//                Text("\(value)")
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .glassCardEffect(cornerRadius: 10, tint: background)
//            }
//        }
//    }
    
//    @ViewBuilder
//    private var customButton: some View {
//        let selected = gross.exists && !quickScores.contains(gross ?? 0)
//        let label = selected ? "\(gross ?? 0)" : "+"
//        let selectedTint = viewModel.teamColor(for: participant) ?? palette.foregroundColor
//        let background = selected ? selectedTint : Color.clear
//        let foreground = selected ? palette.buttonColor : palette.foregroundColor
//        
//        Button {
//            viewModel.promptCustomScore(for: participant)
//        } label: {
//            if selected {
//                Text(label)
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .background(background)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            } else {
//                Text(label)
//                    .fontStyle(kFontName, size: 12, weight: .semibold)
//                    .foregroundStyle(foreground)
//                    .frame(width: 32, height: 32)
//                    .glassCardEffect(cornerRadius: 10, tint: background)
//            }
//        }
//    }

    private var enterScoreButton: some View {
        let isScored = gross.exists
        let color = (viewModel.teamColor(for: participant) ?? .accentPurple)
        let label = isScored ? viewModel.friendlyScoreLabel(strokes: gross ?? 6, par: holePar) : "Enter score"
        let tint = isScored ? color.opacity(colorScheme.ultraTranslucent) : glassButtonColor
        let foreground: Color = isScored ? color : Color.charcoal

        return Button {
            Haptics.fire(.light)
            viewModel.presentedScoringParticipant = participant
        } label: {
            VStack(spacing: 0) {
                Text(label)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(foreground)
                
                if let net, useHandicaps { //net != gross {
                    Text("Net \(viewModel.friendlyScoreLabel(strokes: net, par: holePar))")
                        .fontStyle(kFontName, size: 10, weight: .medium)
                        .foregroundStyle(foreground)
                }
            }
        }
//        .frame(height: 48)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        //.border(isScored ? Color.clear : color.opacity(0.25), width: 5, cornerRadius: 12)
        .glassCardEffect(cornerRadius: 12, tint: tint)
//        .glassCardEffect(shape: .capsule, tint: tint)
    }
}

#Preview("Player Scoring Row") {
    ZStack {
        GolfTopology()
            .frame(width: UIScreen.main.bounds.width)
        PlayerScoringRowPreview()
    }
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
            holeNumber: viewModel.currentHoleNumber,
            requiresTeams: requiresTeams
        )
        .padding(16)
        .glassCardEffect()
        .padding(16)
        //.background(palette.backgroundColor)
    }
}
