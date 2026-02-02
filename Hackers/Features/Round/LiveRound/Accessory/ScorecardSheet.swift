//
//  ScorecardSheet.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct ScorecardSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    
    @State private var selectedNine: HoleSegment = .front9
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private var isFull18: Bool { viewModel.snapshot.holeSegment == .full18 }
    
    private var scoreLabel: String {
        viewModel.formattedScoreToPar(viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis))
    }
    
    private var displayedHoles: [Int] {
        let base = viewModel.holeNumbers
        guard isFull18 else { return base }
        let range = selectedNine.holeRange
        return base.filter { range.contains($0) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                HStack {
                    Text(participant.name.fullName)
                        .fontStyle(.poppins, size: 22, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Spacer(minLength: 0)
                    
                    Text(scoreLabel)
                        .fontStyle(.poppins, size: 22, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
                
                HStack(spacing: 8) {
                    if let team = viewModel.team(for: participant) {
                        Text(team.name)
                            .fontStyle(.poppins, size: 12, weight: .medium)
                            .foregroundStyle(team.teamColor.value)
                        Dot()
                        
                    }
                    Text("\(participant.adjustedHandicap) HCP")
                        .fontStyle(.poppins, size: 12, weight: .medium)
                        .foregroundStyle(palette.foregroundColor)//Color.neutral)
                    
                    Spacer(minLength: 0)
                }
            }
            .background(Color.accentGreen)
            //.padding(.top, 8)
            
            Spacer(minLength: 0)
            
            if isFull18 {
                Picker("", selection: $selectedNine) {
                    Text("Front 9").tag(HoleSegment.front9)
                    Text("Back 9").tag(HoleSegment.back9)
                }
                .pickerStyle(.segmented)
            } else {
                Text(viewModel.snapshot.holeSegment.title)
                    .fontStyle(.poppins, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral)
            }
            
            Spacer(minLength: 0)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(displayedHoles, id: \.self) { holeNumber in
                    ScorecardHoleCell(
                        palette: palette,
                        holeNumber: holeNumber,
                        par: viewModel.hole(for: holeNumber)?.par,
                        gross: viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber),
                        net: viewModel.netStrokesOnHole(participant: participant, holeNumber: holeNumber),
                        strokesReceived: viewModel.strokesReceivedOnHole(participant: participant, holeNumber: holeNumber),
                        basis: viewModel.scoreBasis
                    )
                }
            }
            .padding(.vertical, 8)
            
            Spacer(minLength: 0)
            
            Picker("", selection: $viewModel.scoreBasis) {
                Text("Gross").tag(ScoreBasis.gross)
                Text("Net").tag(ScoreBasis.net)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(16)
        .background(palette.backgroundColor)
        .onAppear {
            guard isFull18 else { return }
            selectedNine = viewModel.currentHoleNumber >= 10 ? .back9 : .front9
        }
    }
}

#Preview("Scorecard Sheet") {
    ScorecardSheetPreview()
}

private struct ScorecardSheetPreview: View {
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant
    
    init() {
        let snapshot = MockLiveRoundRyderCup.snapshot
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id
        
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        
        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first!
    }
    
    var body: some View {
        ScorecardSheet(viewModel: viewModel, participant: participant)
    }
}
