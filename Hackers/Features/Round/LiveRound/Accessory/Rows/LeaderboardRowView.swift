//
//  LeaderboardRowView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct LeaderboardRowView: View {
    @CappedScaledMetric(relativeTo: .body) var placeWidth: CGFloat = 38
    @CappedScaledMetric(relativeTo: .body) var handicapWidth: CGFloat = 42
    @CappedScaledMetric(relativeTo: .caption) var teamDotSize: CGFloat = 8
    @CappedScaledMetric(relativeTo: .body) var scoreWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var thruWidth: CGFloat = 40
    @CappedScaledMetric(relativeTo: .body) var rowSpacing: CGFloat = 8

    let palette: DesignPalette
    let placeLabel: String
    let row: LiveRoundViewModel.LeaderboardRow
    let teamColor: Color?
    let nameDisplayFormat: NameDisplayFormat
    var usesFormatDisplay: Bool = false
    var isHighestWinsFormat: Bool = false
    var isScoreHidden: Bool = false
    var showsHandicap: Bool = false
    let onTap: Callback

    private var showsSubstituteMarker: Bool {
        row.participant.isSubstitute && row.memberNames == nil && !row.isSharedScoreUnit
    }
    
    var body: some View {
        Button {
            Haptics.fire(.light)
            onTap()
        } label: {
            rowContent
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    private var rowContent: some View {
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
                    .fill(showsSubstituteMarker ? Color.clear : teamColor.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(teamColor.opacity(0.9), lineWidth: showsSubstituteMarker ? 1.5 : 0)
                    )
                    .frame(width: row.memberNames != nil ? 4 : teamDotSize,
                           height: row.memberNames != nil ? accentBarHeight : teamDotSize)
            }

            nameStack

            Spacer(minLength: 0)

            if showsHandicap {
                Text(handicapValue)
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(Color.neutral2)
                    .frame(width: handicapWidth, alignment: .center)
            }

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

    @ViewBuilder
    private var nameStack: some View {
        if row.isSharedScoreUnit {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(row.participants) { participant in
                    compactNameText(participant.name)
                }
            }
            .clipped()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if let teamName = row.teamName, teamName.isPopulated {
                    Text(teamName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 1) {
                        compactNameText(row.participant.name)
                        if row.participant.isSubstitute {
                            Text("*")
                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                        }
                    }
                }

                if let names = row.memberNames {
                    Text(names)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(1)
                }
            }
        }
    }

    private func compactNameText(_ name: Name) -> some View {
        Text(nameDisplayFormat.displayName(for: name))
            .fontStyle(kFontName, size: 15, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var handicapValue: String {
        if row.isSharedScoreUnit {
            return row.sharedHandicapLabel?
                .replacingOccurrences(of: "HCP ", with: "") ?? "—"
        }
        return "\(row.participant.lockedHandicapAllowance)"
    }

    private var accessibilityValue: String {
        var values = ["Place \(placeLabel)"]
        if showsHandicap {
            values.append("handicap \(handicapValue)")
        }
        values.append("score \(isScoreHidden ? "hidden" : scoreLabel)")
        values.append("through \(row.thru)")
        return values.joined(separator: ", ")
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

    private var accentBarHeight: CGFloat {
        row.isSharedScoreUnit || row.memberNames != nil ? 46 : 28
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
            onTap: { }
        )
        .padding(16)
        .background(palette.backgroundColor)
    }
}
