//
//  LiveRound+Matchups.swift
//  Hackers
//
//  Created by Kyle Beard on 3/9/26.
//

import SwiftUI

// MARK: - Matchups Content

extension LiveRound {
    var matchupsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                navPadding

                if viewModel.matchupSections.isEmpty {
                    Text("No matchup results yet.")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .padding(.vertical, 24)
                        .alignCenter()
                } else {
                    ForEach(Array(viewModel.matchupSections.enumerated()), id: \.element.id) { index, section in
                        MatchupTileView(
                            section: section,
                            matchIndex: index + 1,
                            viewModel: viewModel,
                            palette: palette,
                            snapshot: snapshot
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Matchup Tile

private struct MatchupTileView: View {
    @CappedScaledMetric(relativeTo: .body) var pillSize: CGFloat = 44

    let section: MatchupLeaderboardSection
    let matchIndex: Int
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let snapshot: RoundSnapshot

    @State private var isExpanded = false

    private var isPointsFormat: Bool {
        viewModel.engineResult.template.leaderboardSort == .highestWins
    }

    private var matchupMode: MatchupMode {
        section.matchup.mode ?? viewModel.expectedMatchupMode
    }

    private var isTeamMode: Bool {
        matchupMode == .team
    }

    private var isScoreOwnerMode: Bool {
        matchupMode == .scoreOwner
    }

    private var showsExpandedMembers: Bool {
        isTeamMode || isScoreOwnerMode
    }

    private var leftRow: LeaderboardRow? {
        section.rows.first
    }

    private var rightRow: LeaderboardRow? {
        section.rows.count > 1 ? section.rows[1] : nil
    }

    private var teamMap: [String: RoundTeam] {
        Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0) })
    }

    private var participantMap: [String: RoundParticipant] {
        Dictionary(uniqueKeysWithValues: snapshot.participants.map { ($0.id, $0) })
    }

    private var scoringGroupMap: [String: RoundScoringGroup] {
        Dictionary(uniqueKeysWithValues: snapshot.scoringGroups.map { ($0.id, $0) })
    }

    private var matchupPresentation: MatchupResultPresentation {
        viewModel.matchupPresentation(in: section)
    }

    private var sidePresentations: [String: MatchupResultPresentation.Side] {
        Dictionary(uniqueKeysWithValues: matchupPresentation.sides.map { ($0.id, $0) })
    }

    private var rangeMismatch: RoundSegmentHoleRangeMismatch? {
        snapshot.primarySegmentHoleRangeMismatch
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("Match \(matchIndex)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                    .padding(.bottom, 8)

                if let rangeMismatch {
                    matchupRangeMismatchView(rangeMismatch)
                } else {
                    matchupHeaderRow

                    if showsExpandedMembers && isExpanded {
                        expandedPlayerList
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, showsExpandedMembers && rangeMismatch == nil ? 44 : 0)

            if showsExpandedMembers && rangeMismatch == nil {
                NavButton(
                    style: .glass,
                    icon: isExpanded ? "chevron.down" : "chevron.right",
                    size: 14,
                    color: palette.foregroundColor,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(
            interactive: false,
            forceMaterial: true,
            tint: palette.cardColor,
            strokeOpacity: 0.38,
            shadowOpacity: 0.16
        )
    }

    private func matchupRangeMismatchView(_ mismatch: RoundSegmentHoleRangeMismatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mismatch.diagnosticTitle)
                .fontStyle(kFontName, size: 16, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(mismatch.diagnosticDetail)
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var matchupHeaderRow: some View {
        if isTeamMode {
            teamMatchupHeader
        } else if isScoreOwnerMode {
            scoreOwnerMatchupHeader
        } else {
            individualMatchupHeader
        }
    }

    private var teamMatchupHeader: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let team1 = pairingIDs.count > 0 ? teamMap[pairingIDs[0]] : nil
        let team2 = pairingIDs.count > 1 ? teamMap[pairingIDs[1]] : nil

        return VStack(alignment: .leading, spacing: 8) {
            if let team1 {
                teamEntityRow(team: team1, total: sidePresentations[team1.id]?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pairingIDs.count > 0 {
                sharedEntityRow(scoringUnitID: pairingIDs[0], total: sidePresentations[pairingIDs[0]]?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("vs")
                .fontStyle(kFontName, size: 12, weight: .bold)
                .foregroundStyle(Color.neutral)
            if let team2 {
                teamEntityRow(team: team2, total: sidePresentations[team2.id]?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pairingIDs.count > 1 {
                sharedEntityRow(scoringUnitID: pairingIDs[1], total: sidePresentations[pairingIDs[1]]?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreOwnerMatchupHeader: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let owner1 = pairingIDs.count > 0 ? scoringGroupMap[pairingIDs[0]] : nil
        let owner2 = pairingIDs.count > 1 ? scoringGroupMap[pairingIDs[1]] : nil

        return VStack(alignment: .leading, spacing: 8) {
            if let owner1 {
                scoreOwnerEntityRow(owner: owner1, side: sidePresentations[owner1.id], leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pairingIDs.count > 0 {
                sharedEntityRow(scoringUnitID: pairingIDs[0], total: sidePresentations[pairingIDs[0]]?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("vs")
                .fontStyle(kFontName, size: 12, weight: .bold)
                .foregroundStyle(Color.neutral)
            if let owner2 {
                scoreOwnerEntityRow(owner: owner2, side: sidePresentations[owner2.id], leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pairingIDs.count > 1 {
                sharedEntityRow(scoringUnitID: pairingIDs[1], total: sidePresentations[pairingIDs[1]]?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var individualMatchupHeader: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let participant1 = pairingIDs.count > 0 ? participantMap[pairingIDs[0]] : nil
        let participant2 = pairingIDs.count > 1 ? participantMap[pairingIDs[1]] : nil

        return HStack(alignment: .top, spacing: 12) {
            if let participant1 {
                Button {
                    Haptics.fire(.light)
                    viewModel.presentedParticipant = participant1
                } label: {
                    individualEntityRow(participant: participant1, total: sidePresentations[participant1.id]?.total, leadingPill: true)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("vs")
                .fontStyle(kFontName, size: 12, weight: .bold)
                .foregroundStyle(Color.neutral)
            if let participant2 {
                Button {
                    Haptics.fire(.light)
                    viewModel.presentedParticipant = participant2
                } label: {
                    individualEntityRow(participant: participant2, total: sidePresentations[participant2.id]?.total, leadingPill: false)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sortedTeamParticipants(teamID: String) -> [RoundParticipant] {
        let members = snapshot.participants.filter { $0.teamID == teamID }
        return members.sorted { lhs, rhs in
            let s1 = viewModel.scoreToPar(for: lhs, basis: viewModel.scoreBasis)
            let s2 = viewModel.scoreToPar(for: rhs, basis: viewModel.scoreBasis)
            if isPointsFormat { return s1 > s2 }
            return s1 < s2
        }
    }

    private func teamRosterSubtitle(teamID: String) -> String? {
        let participants = sortedTeamParticipants(teamID: teamID)
        let fallbackParticipants = participants.isPopulated
            ? participants
            : viewModel.matchupSideParticipants(scoringUnitID: teamID, matchup: section.matchup)
        let names = fallbackParticipants.map { viewModel.formatDisplayName(for: $0) }
        guard names.isPopulated else { return nil }
        return names.joined(separator: ", ")
    }

    private func teamEntityRow(team: RoundTeam, total: Double?, leadingPill: Bool) -> some View {
        let nameRow = HStack(alignment: .center, spacing: 6) {
            Circle()
                .fill(team.displaySwatchColor ?? Color.neutral6)
                .frame(width: 8, height: 8)
            Text(team.name)
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
            resultChip(for: team.id, accent: team.displaySwatchColor)
        }
        let textColumn = VStack(alignment: .leading, spacing: 3) {
            nameRow
            if let roster = teamRosterSubtitle(teamID: team.id) {
                Text(roster)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if leadingPill {
                HStack(alignment: .top, spacing: 12) {
                    matchupScorePill(total: total)
                    textColumn
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    textColumn
                    matchupScorePill(total: total)
                }
            }
        }
    }

    private func sharedEntityRow(scoringUnitID: String, total: Double?, leadingPill: Bool) -> some View {
        let title = viewModel.outcomeMatchupSideName(scoringUnitID: scoringUnitID, matchup: section.matchup)
        let names = viewModel.matchupSideParticipants(scoringUnitID: scoringUnitID, matchup: section.matchup)
            .map { viewModel.formatDisplayName(for: $0) }
            .filter(\.isPopulated)
            .joined(separator: ", ")
        let entityContent = VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                resultChip(for: scoringUnitID, accent: sidePresentations[scoringUnitID]?.accentColor)
            }

            if names.isPopulated {
                Text(names)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return Group {
            if leadingPill {
                HStack(alignment: .top, spacing: 12) {
                    matchupScorePill(total: total)
                    entityContent
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    entityContent
                    matchupScorePill(total: total)
                }
            }
        }
    }

    private func individualEntityRow(participant: RoundParticipant, total: Double?, leadingPill: Bool) -> some View {
        let nameContent = VStack(alignment: leadingPill ? .leading : .trailing, spacing: 2) {
            Text(participant.name.givenName)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
            HStack(alignment: .center, spacing: 6) {
                if !leadingPill {
                    resultChip(for: participant.id, accent: viewModel.teamColor(for: participant))
                }
                Text(participant.name.familyName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                if leadingPill {
                    resultChip(for: participant.id, accent: viewModel.teamColor(for: participant))
                }
            }
        }
        return Group {
            if leadingPill {
                HStack(spacing: 12) {
                    matchupScorePill(total: total)
                    nameContent
                }
            } else {
                HStack(spacing: 12) {
                    nameContent
                    matchupScorePill(total: total)
                }
            }
        }
    }

    private func scoreOwnerEntityRow(
        owner: RoundScoringGroup,
        side: MatchupResultPresentation.Side?,
        leadingPill: Bool
    ) -> some View {
        let accent = side?.accentColor ?? viewModel.scoringGroupAccentColor(owner) ?? palette.foregroundColor
        let total = side?.total
        let title = side.map(\.title) ?? viewModel.scoringGroupLabel(owner)
        let subtitle = side.flatMap(\.subtitle) ?? viewModel.scoringGroupSubtitle(owner)
        let entityContent = VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                resultChip(for: owner.id, accent: accent)
            }

            if let subtitle {
                Text(subtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(2)
            }
        }

        return Group {
            if leadingPill {
                HStack(spacing: 12) {
                    matchupScorePill(total: total)
                    entityContent
                }
            } else {
                HStack(spacing: 12) {
                    entityContent
                    matchupScorePill(total: total)
                }
            }
        }
    }

    @ViewBuilder
    private func resultChip(for sideID: String, accent: Color?) -> some View {
        if matchupPresentation.hasCompleteSides, matchupPresentation.winningSideID == sideID {
            liveResultChip("Winner", tint: accent ?? palette.foregroundColor)
        } else if matchupPresentation.hasCompleteSides, matchupPresentation.isTie {
            liveResultChip("Tie", tint: Color.neutral)
        }
    }

    private func liveResultChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .fontStyle(kFontName, size: 9, weight: .bold)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.32), lineWidth: 0.8)
            )
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func matchupScorePill(total: Double?) -> some View {
        let label = total.map { viewModel.formattedMatchupTotal($0, isPointsFormat: isPointsFormat) } ?? "—"
        Text(label)
            .fontStyle(kFontName, size: 20, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(width: pillSize, height: pillSize)
            .glassCardEffect(
                shape: .circle,
                interactive: false,
                tint: palette.whiteGlassButtonColor,
                strokeOpacity: 0.32,
                shadowOpacity: 0.12
            )
    }

    private var expandedPlayerList: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let sideMap = sidePresentations
        let participants: [(participant: RoundParticipant, side: MatchupResultPresentation.Side)] = pairingIDs.flatMap { id in
            guard let side = sideMap[id] else {
                return [(participant: RoundParticipant, side: MatchupResultPresentation.Side)]()
            }
            return side.participants.map { ($0, side) }
        }

        let sorted = participants.sorted { lhs, rhs in
            viewModel.matchupParticipantDisplaySort(
                lhs: lhs.participant,
                rhs: rhs.participant,
                isPointsFormat: isPointsFormat
            )
        }

        let scoreColumnWidth: CGFloat = 44

        return VStack(spacing: 0) {
            Line(color: Color.neutral6.opacity(0.5))
                .padding(.vertical, 12)

            HStack(spacing: 12) {
                Text("Player")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Thru")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)
                Text("Gross")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)
                if viewModel.handicapsEnabled {
                    Text("Net")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .frame(minWidth: scoreColumnWidth, alignment: .trailing)
                }
            }
            .padding(.bottom, 8)

            if let label = viewModel.matchupCountingScopeLabel {
                Text(label)
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
            }

            ForEach(sorted, id: \.participant.id) { item in
                MatchupPlayerRowView(
                    participant: item.participant,
                    viewModel: viewModel,
                    palette: palette,
                    isActive: item.side.isParticipantActive(item.participant),
                    isPointsFormat: isPointsFormat,
                    scoreColumnWidth: scoreColumnWidth
                )

                if item.participant.id != sorted.last?.participant.id {
                    Divider().opacity(0.2)
                }
            }
        }
    }
}

// MARK: - Matchup Player Row (Expanded)

private struct MatchupPlayerRowView: View {
    let participant: RoundParticipant
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let isActive: Bool
    let isPointsFormat: Bool
    var scoreColumnWidth: CGFloat = 44

    private var teamColor: Color? {
        viewModel.teamColor(for: participant)
    }

    private var grossScore: Int {
        viewModel.scoreToPar(for: participant, basis: .gross)
    }

    private var netScore: Int {
        viewModel.scoreToPar(for: participant, basis: .net)
    }

    private var useNet: Bool { viewModel.handicapsEnabled }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                LiveRoundAdaptiveNameText(
                    name: participant.name,
                    format: viewModel.nameDisplayFormat,
                    fontSize: 14,
                    weight: .medium,
                    color: isActive ? palette.foregroundColor : Color.neutral2
                )
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isActive {
                    Circle()
                        .fill(teamColor ?? Color.accentGreen)
                        .frame(width: 8, height: 8)
                }
            }

            Text("\(viewModel.holesPlayedCount(for: participant.id))")
                .fontStyle(kFontName, size: 14, weight: .medium)
                .foregroundStyle(Color.neutral)
                .frame(minWidth: scoreColumnWidth, alignment: .trailing)

            if viewModel.handicapsEnabled {
                Text(formatScoreToPar(grossScore))
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(isActive ? palette.foregroundColor : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)

                Text(formatScoreToPar(netScore))
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(isActive ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)
            } else {
                Text(formatScoreToPar(grossScore))
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(isActive ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
    }

    private func formatScoreToPar(_ value: Int) -> String {
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }
}
