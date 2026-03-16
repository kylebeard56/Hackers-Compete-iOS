//
//  SeriesLeaderboardView.swift
//  Hackers
//

import SwiftUI

struct SeriesLeaderboardView: View {
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette

    var body: some View {
        VStack(spacing: 16) {
            individualSection
            if viewModel.hasTeams {
                teamSection
            }
        }
    }

    // MARK: - Individual

    private var individualSection: some View {
        VStack(spacing: 12) {
            Text("Individual Standings".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            if viewModel.individualStandings.isEmpty {
                EmptyStateView(
                    imageName: "LeaderboardIsometric",
                    title: "No standings yet",
                    subtitle: "Complete a round to see standings."
                )
                .frame(minHeight: 200)
            } else {
                standingsHeader
                ForEach(Array(viewModel.individualStandings.enumerated()), id: \.element.id) { index, standing in
                    standingRow(standing, rank: index + 1)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    // MARK: - Team

    private var teamSection: some View {
        VStack(spacing: 12) {
            Text("Team Standings".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            if viewModel.teamStandings.isEmpty {
                Text("No team standings yet")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 16)
            } else {
                standingsHeader
                ForEach(Array(viewModel.teamStandings.enumerated()), id: \.element.id) { index, standing in
                    standingRow(standing, rank: index + 1)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    // MARK: - Shared

    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 28, alignment: .center)
            Text("Name")
                .alignLeading()
            Text("Pts")
                .frame(width: 44, alignment: .trailing)
            Text("W")
                .frame(width: 32, alignment: .trailing)
            Text("Rds")
                .frame(width: 36, alignment: .trailing)
        }
        .fontStyle(kFontName, size: 12, weight: .semibold)
        .foregroundStyle(Color.neutral)
    }

    private func standingRow(_ standing: SeriesStanding, rank: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(rank)")
                .frame(width: 28, alignment: .center)
                .fontStyle(kFontName, size: 15, weight: rank <= 3 ? .bold : .semibold)
                .foregroundStyle(rank <= 3 ? Color.accentGreen : palette.foregroundColor)

            Text(standing.competitorName)
                .fontStyle(kFontName, size: 14, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .alignLeading()

            Text(String(format: "%.1f", standing.totalPoints))
                .frame(width: 44, alignment: .trailing)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text("\(standing.wins)")
                .frame(width: 32, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            Text("\(standing.roundsCounted)")
                .frame(width: 36, alignment: .trailing)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .padding(.vertical, 6)
    }
}
