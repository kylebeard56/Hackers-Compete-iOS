//
//  LeaderboardRowView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct LeaderboardRowView: View {
    @CappedScaledMetric(relativeTo: .body) var placeWidth: CGFloat = 38
    @CappedScaledMetric(relativeTo: .caption) var teamDotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body) var scoreWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var thruWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var starSize: CGFloat = 20
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 8

    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let nameDisplayFormat: NameDisplayFormat
    var usesFormatDisplay: Bool = false
    var isHighestWinsFormat: Bool = false
    var isScoreHidden: Bool = false
    var onHiddenScoreTap: Callback? = nil
    let onTogglePinned: Callback
    let onTap: Callback
    
    var body: some View {
        HStack(spacing: rowSpacing) {
            
            Button {
                Haptics.fire(.light)
                if isScoreHidden {
                    onHiddenScoreTap?()
                } else {
                    onTap()
                }
            } label: {
                HStack(spacing: rowSpacing) {
                    Text(placeLabel)
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: placeWidth, alignment: .center)
                        .invisibleInk(active: isScoreHidden)

                    if let teamColor {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(teamColor.opacity(0.9))
                            .frame(width: row.memberNames != nil ? 4 : teamDotSize,
                                   height: row.memberNames != nil ? (row.isSharedScoreUnit ? 36 : 28) : teamDotSize)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        ViewThatFits(in: .horizontal) {
                            Text(displayName)
                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .layoutPriority(1)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Text(compactDisplayName)
                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .lineLimit(1)
                        }

                        if let names = row.memberNames {
                            Text(names)
                                .fontStyle(kFontName, size: 12, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .lineLimit(row.isSharedScoreUnit ? 3 : 1)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    Text(scoreLabel)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: scoreWidth, alignment: .center)
                        .invisibleInk(active: isScoreHidden)
                    
                    Text("\(row.thru)")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                        .frame(width: thruWidth, alignment: .center)
                }
            }
            
            if row.memberNames == nil && !row.isSharedScoreUnit {
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
        if usesFormatDisplay, let total = row.totalPoints {
            if isHighestWinsFormat {
                let formatted = String(format: "%.1f", total)
                return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
            }
            let intVal = Int(total)
            if intVal == 0 { return "E" }
            if intVal > 0 { return "+\(intVal)" }
            return "\(intVal)"
        }
        if row.scoreToPar == 0 { return "E" }
        if row.scoreToPar > 0 { return "+\(row.scoreToPar)" }
        return "\(row.scoreToPar)"
    }

    private var displayName: String {
        if row.isSharedScoreUnit {
            return fullParticipantName
        }
        if let teamName = row.teamName, teamName.isPopulated {
            return teamName
        }
        return fullParticipantName
    }

    private var compactDisplayName: String {
        if row.isSharedScoreUnit {
            return compactParticipantName
        }
        if let teamName = row.teamName, teamName.isPopulated {
            return teamName
        }
        return compactParticipantName
    }

    private var fullParticipantName: String {
        row.participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compactParticipantName: String {
        let given = row.participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = row.participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard given.isPopulated || family.isPopulated else { return fullParticipantName }
        switch nameDisplayFormat {
        case .firstInitialLastName:
            guard let g = given.first else { return family }
            return "\(g). \(family)"
        case .firstNameLastInitial:
            guard let f = family.first else { return given }
            return "\(given) \(f)."
        }
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
            nameDisplayFormat: viewModel.nameDisplayFormat,
            onTogglePinned: { },
            onTap: { }
        )
        .padding(16)
        .background(palette.backgroundColor)
    }
}
