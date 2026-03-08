//
//  MatchupCardView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import SwiftUI

struct MatchupCardView: View {
    @Environment(\.colorScheme) var colorScheme

    let matchup: TeamMatchup
    let matchIndex: Int
    let snapshot: RoundSnapshot
    let onSelectTeam: (Int, String?) -> Void  // slotIndex 0 or 1, teamID to assign

    private var palette: DesignPalette { PaletteTheme.primary.palette(for: colorScheme) }

    var body: some View {
        VStack(spacing: 12) {
            Text("Match \(matchIndex + 1)")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                teamSlot(teamID: matchup.teamIDs.count > 0 ? matchup.teamIDs[0] : nil, slotIndex: 0)
                vsDivider
                teamSlot(teamID: matchup.teamIDs.count > 1 ? matchup.teamIDs[1] : nil, slotIndex: 1)
            }
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.borderColor, style: StrokeStyle(lineWidth: 1, dash: []))
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
    }

    private var vsDivider: some View {
        Text("VS")
            .fontStyle(kFontName, size: 12, weight: .bold)
            .foregroundStyle(Color.neutral)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func teamSlot(teamID: String?, slotIndex: Int) -> some View {
        let team = teamID.flatMap { id in snapshot.teams.first(where: { $0.id == id }) }
        let isEmpty = teamID == nil || team == nil

        Button {
            Haptics.fire(.light)
            onSelectTeam(slotIndex, teamID)
        } label: {
            VStack(spacing: 4) {
                if let team {
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

                    if let subtitle = compactTeamSubtitle(for: team) {
                        Text(subtitle)
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("Tap to assign")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.neutral)
                    Text("(Empty)")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEmpty ? palette.borderColor : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEmpty ? Color.neutral6.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func compactTeamSubtitle(for team: RoundTeam) -> String? {
        let participants = snapshot.participants.filter { $0.teamID == team.id }
        let names = participants
            .map { p in
                let given = p.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if given.isPopulated { return given }
                let family = p.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                return family.isPopulated ? family : p.name.fullName
            }
            .filter(\.isPopulated)

        guard names.isPopulated else { return nil }
        let visible = names.prefix(3)
        let overflow = names.count - visible.count
        if overflow > 0 {
            return visible.joined(separator: ", ") + ", +\(overflow) more"
        }
        return visible.joined(separator: ", ")
    }
}
