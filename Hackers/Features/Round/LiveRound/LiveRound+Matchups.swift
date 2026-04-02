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
            .padding(.horizontal, 20)
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

    private var isTeamMode: Bool {
        let mode = section.matchup.mode ?? (snapshot.requiresTeams ? .team : .individual)
        return mode == .team
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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("Match \(matchIndex)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                    .padding(.bottom, 8)

                matchupHeaderRow

                if isTeamMode && isExpanded {
                    expandedPlayerList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isTeamMode ? 44 : 0)

            if isTeamMode {
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
            tint: nil,
            strokeOpacity: 0.38,
            shadowOpacity: 0.16
        )
    }

    @ViewBuilder
    private var matchupHeaderRow: some View {
        if isTeamMode {
            teamMatchupHeader
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
                teamEntityRow(team: team1, total: leftRow?.total, leadingPill: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("vs")
                .fontStyle(kFontName, size: 12, weight: .bold)
                .foregroundStyle(Color.neutral)
            if let team2 {
                teamEntityRow(team: team2, total: rightRow?.total, leadingPill: true)
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
                    individualEntityRow(participant: participant1, total: leftRow?.total, leadingPill: true)
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
                    individualEntityRow(participant: participant2, total: rightRow?.total, leadingPill: false)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func teamEntityRow(team: RoundTeam, total: Double?, leadingPill: Bool) -> some View {
        let entityContent = HStack(spacing: 6) {
            Circle()
                .fill(team.displaySwatchColor ?? Color.neutral6)
                .frame(width: 8, height: 8)
            Text(team.name)
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
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

    private func individualEntityRow(participant: RoundParticipant, total: Double?, leadingPill: Bool) -> some View {
        let nameContent = VStack(alignment: leadingPill ? .leading : .trailing, spacing: 2) {
            Text(participant.name.givenName)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
            Text(participant.name.familyName)
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
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

    @ViewBuilder
    private func matchupScorePill(total: Double?) -> some View {
        let label = total.map { viewModel.formattedMatchupTotal($0, isPointsFormat: isPointsFormat) } ?? "E"
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
        let participants: [RoundParticipant] = pairingIDs.flatMap { id in
            snapshot.participants.filter { $0.teamID == id }
        }

        let sorted = participants.sorted { p1, p2 in
            let s1 = viewModel.scoreToPar(for: p1, basis: viewModel.scoreBasis)
            let s2 = viewModel.scoreToPar(for: p2, basis: viewModel.scoreBasis)
            if isPointsFormat { return s1 > s2 }
            return s1 < s2
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

            ForEach(sorted, id: \.id) { participant in
                MatchupPlayerRowView(
                    participant: participant,
                    viewModel: viewModel,
                    palette: palette,
                    matchup: section.matchup,
                    isPointsFormat: isPointsFormat,
                    scoreColumnWidth: scoreColumnWidth
                )

                if participant.id != sorted.last?.id {
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
    let matchup: TeamMatchup
    let isPointsFormat: Bool
    var scoreColumnWidth: CGFloat = 44

    private var teamID: String? { participant.teamID }
    private var teamColor: Color? {
        viewModel.teamColor(for: participant)
    }

    private var scoreCounts: Bool {
        guard let tid = teamID else { return false }
        return viewModel.doesParticipantScoreCount(participantID: participant.id, teamID: tid, matchup: matchup)
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
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(scoreCounts ? palette.foregroundColor : Color.neutral2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if scoreCounts {
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
                    .foregroundStyle(scoreCounts ? palette.foregroundColor : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)

                Text(formatScoreToPar(netScore))
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(scoreCounts ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)
            } else {
                Text(formatScoreToPar(grossScore))
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(scoreCounts ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
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
