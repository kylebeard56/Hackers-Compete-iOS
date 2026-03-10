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
                    .padding(.top, UIApplication.shared.topSafeAreaInset)

                Text("Matchups".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                Line()

                if viewModel.matchupSections.isEmpty {
                    Text("No matchup results yet.")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .padding(.vertical, 24)
                        .alignCenter()
                } else {
                    ForEach(viewModel.matchupSections) { section in
                        MatchupTileView(
                            section: section,
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
    let section: MatchupLeaderboardSection
    @ObservedObject var viewModel: LiveRoundViewModel
    let palette: DesignPalette
    let snapshot: RoundSnapshot

    @State private var isExpanded = false

    private var isPointsFormat: Bool {
        viewModel.engineResult.template.leaderboardSort == .highestWins
    }

    private var isTeamMode: Bool {
        section.matchup.mode ?? .team == .team
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
        VStack(spacing: 0) {
            matchupHeaderRow

            if isTeamMode && isExpanded {
                expandedPlayerList
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private var matchupHeaderRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: score, name (leading)
            HStack(spacing: 8) {
                if let row = leftRow {
                    Text(viewModel.formattedMatchupTotal(row.total, isPointsFormat: isPointsFormat))
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
                leftEntityView
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Text("vs")
                .fontStyle(kFontName, size: 12, weight: .bold)
                .foregroundStyle(Color.neutral)

            // Right: name, score (trailing)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                rightEntityView
                if let row = rightRow {
                    Text(viewModel.formattedMatchupTotal(row.total, isPointsFormat: isPointsFormat))
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }
            }
            .frame(maxWidth: .infinity)

            // Chevron (teams only)
            if isTeamMode {
                Button {
                    Haptics.fire(.light)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Icon(
                        name: isExpanded ? "chevron.up" : "chevron.down",
                        size: 14,
                        weight: .semibold
                    )
                    .foregroundStyle(palette.foregroundColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var leftEntityView: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let id = pairingIDs.first

        if isTeamMode, let teamID = id, let team = teamMap[teamID] {
            HStack(spacing: 6) {
                Circle()
                    .fill(team.teamColor.value)
                    .frame(width: 8, height: 8)
                Text(team.name)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let participantID = id, let participant = participantMap[participantID] {
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name.givenName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(participant.name.familyName)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var rightEntityView: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let id = pairingIDs.count > 1 ? pairingIDs[1] : nil

        if isTeamMode, let teamID = id, let team = teamMap[teamID] {
            HStack(spacing: 6) {
                Text(team.name)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Circle()
                    .fill(team.teamColor.value)
                    .frame(width: 8, height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else if let participantID = id, let participant = participantMap[participantID] {
            VStack(alignment: .trailing, spacing: 2) {
                Text(participant.name.givenName)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(participant.name.familyName)
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var expandedPlayerList: some View {
        let pairingIDs = section.matchup.pairingIDs()
        let participants: [RoundParticipant] = pairingIDs.compactMap { id in
            snapshot.participants.filter { $0.teamID == id }
        }.flatMap { $0 }

        let sorted = participants.sorted { p1, p2 in
            let s1 = viewModel.scoreToPar(for: p1, basis: viewModel.scoreBasis)
            let s2 = viewModel.scoreToPar(for: p2, basis: viewModel.scoreBasis)
            if isPointsFormat { return s1 > s2 }
            return s1 < s2
        }

        return VStack(spacing: 0) {
            Line(color: Color.neutral6.opacity(0.5))
                .padding(.vertical, 12)

            ForEach(sorted, id: \.id) { participant in
                MatchupPlayerRowView(
                    participant: participant,
                    viewModel: viewModel,
                    palette: palette,
                    matchup: section.matchup,
                    isPointsFormat: isPointsFormat
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

    private var teamID: String? { participant.teamID }
    private var teamColor: Color? {
        guard let tid = teamID else { return nil }
        return viewModel.team(for: participant)?.teamColor.value
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
            Text(participant.name.fullName)
                .fontStyle(kFontName, size: 14, weight: .medium)
                .foregroundStyle(scoreCounts ? palette.foregroundColor : Color.neutral2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.handicapsEnabled {
                Text(formatScoreToPar(grossScore))
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(scoreCounts ? palette.foregroundColor : Color.neutral2)

                Text(formatScoreToPar(netScore))
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(scoreCounts ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
            } else {
                Text(formatScoreToPar(grossScore))
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(scoreCounts ? (teamColor ?? palette.foregroundColor) : Color.neutral2)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatScoreToPar(_ value: Int) -> String {
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }
}
