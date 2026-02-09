//
//  LeaderboardRowView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct LeaderboardRowView: View {
    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let onTogglePinned: Callback
    let onTap: Callback
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(placeLabel)
                    .fontStyle(.poppins, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .frame(width: 30, alignment: .center)
                
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
                
                Text(scoreLabel)
                    .fontStyle(.poppins, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 44, alignment: .center)
//                    .background(Color.orange)
                
                Text("Thru \(row.thru)")
                    .fontStyle(.poppins, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(width: 54, alignment: .center)
//                    .background(Color.yellow)
                
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

#Preview("Leaderboard Row") {
    LeaderboardRowViewPreview()
}

private struct LeaderboardRowViewPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: LiveRoundViewModel
    private let row: LiveRoundViewModel.LeaderboardRow
    
    init() {
        let snapshot = MockLiveRound2v2.snapshot
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id
        
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        
        _viewModel = StateObject(wrappedValue: vm)
        row = vm.leaderboardRows.first ?? LiveRoundViewModel.LeaderboardRow(
            participant: snapshot.participants.first!,
            thru: 0,
            scoreToPar: 0,
            isPinned: false,
            placeLabel: "-"
        )
    }
    
    var body: some View {
        let palette = DesignPalette(theme: .primary, scheme: colorScheme)
        
        return LeaderboardRowView(
            palette: palette,
            placeLabel: row.placeLabel,
            row: row,
            teamColor: viewModel.teamColor(for: row.participant),
            onTogglePinned: { },
            onTap: { }
        )
        .padding(16)
        .background(palette.backgroundColor)
    }
}
