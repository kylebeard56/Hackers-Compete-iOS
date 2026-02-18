//
//  LeaderboardRowView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct LeaderboardRowView: View {
    @CappedScaledMetric(relativeTo: .body) var placeWidth: CGFloat = 30
    @CappedScaledMetric(relativeTo: .caption) var teamDotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body) var scoreWidth: CGFloat = 44
    @CappedScaledMetric(relativeTo: .body) var thruWidth: CGFloat = 54
    @CappedScaledMetric(relativeTo: .body) var starSize: CGFloat = 24
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 10
    
    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let onTogglePinned: Callback
    let onTap: Callback
    
    var body: some View {
        Button {
            Haptics.fire(.light)
            onTap()
        } label: {
            HStack(spacing: rowSpacing) {
                Text(placeLabel)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: placeWidth, alignment: .center)
                
                if let teamColor {
                    Circle()
                        .fill(teamColor.opacity(0.9))
                        .frame(width: teamDotSize, height: teamDotSize)
                }
                
                ViewThatFits(in: .horizontal) {
                    Text(fullParticipantName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(compactParticipantName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer(minLength: 0)
                
                Text(scoreLabel)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(minWidth: scoreWidth, alignment: .center)
                
                Text("\(row.thru)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: thruWidth, alignment: .center)
                
                Button {
                    Haptics.fire(.light)
                    onTogglePinned()
                } label: {
                    Image(systemName: row.isPinned ? "star.fill" : "star")
                        .foregroundStyle(row.isPinned ? Color.systemYellow : Color.neutral3)
                        .frame(width: starSize, height: starSize)
                }
            }
        }
    }
    
    private var scoreLabel: String {
        if row.scoreToPar == 0 { return "E" }
        if row.scoreToPar > 0 { return "+\(row.scoreToPar)" }
        return "\(row.scoreToPar)"
    }

    private var fullParticipantName: String {
        row.participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compactParticipantName: String {
        let given = row.participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = row.participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard given.isPopulated else { return fullParticipantName }
        guard let familyInitial = family.first else { return given }
        return "\(given) \(familyInitial)."
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
