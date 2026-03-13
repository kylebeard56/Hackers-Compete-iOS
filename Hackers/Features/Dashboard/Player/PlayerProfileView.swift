//
//  PlayerProfileView.swift
//  Hackers
//
//  Player profile sheet: name, stats, rounds together.
//

import SkeletonUI
import SwiftUI

struct PlayerProfileView: View {
    let entry: PlayerHistoryEntry
    let palette: DesignPalette
    let sortedRounds: [Round]
    let currentPlayerID: String?
    let onRoundTap: (Round) -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel = PlayerProfileViewModel()
    @Environment(\.colorScheme) var colorScheme

    private var sharedRounds: [(Round, RoundPlayedRef)] {
        let roundIDs = Set(entry.rounds.map(\.roundID))
        return entry.rounds
            .compactMap { ref in
                guard let round = sortedRounds.first(where: { $0.id == ref.roundID }) else { return nil }
                return (round, ref)
            }
            .sorted { $0.1.playedAt.unix > $1.1.playedAt.unix }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    if viewModel.isLoading {
                        statsSkeleton
                    } else {
                        statsSection
                    }
                    roundsTogetherSection
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(palette.backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Haptics.fire(.light)
                        onDismiss()
                    }
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
                }
            }
        }
        .task {
            await viewModel.load(playerID: entry.playerID)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            PlayerAvatarView(
                initials: entry.name.initials,
                size: 64,
                fillColor: .accentGreen.opacity(0.6),
                glassTint: .neutral6,
                badgeText: nil,
                badgeStyle: nil
            )
            Text(entry.name.fullName)
                .fontStyle(kFontName, size: 22, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    @ViewBuilder
    private var statsSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: palette.skeletonColor,
                        background: palette.skeletonBackground
                    ),
                    shape: .rounded(.radius(8)),
                    lines: 1,
                    scales: [1: 0.6]
                )
                .frame(height: 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: palette.skeletonColor,
                        background: palette.skeletonBackground
                    ),
                    shape: .rounded(.radius(8)),
                    lines: 1,
                    scales: [1: 0.4]
                )
                .frame(height: 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let player = viewModel.player {
                Text("\(player.rounds.count) rounds played")
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                if player.createdAt.unix > 0 {
                    Text("Joined \(player.createdAt.formattedDate)")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            } else {
                Text("\(entry.roundsPlayed) round\(entry.roundsPlayed.pluralized) with you")
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var roundsTogetherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rounds with you")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            if sharedRounds.isEmpty {
                Text("No rounds together yet")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(sharedRounds, id: \.1.roundID) { round, ref in
                        Button {
                            Haptics.fire(.light)
                            onRoundTap(round)
                            onDismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let course = round.configuration.courses.first {
                                        Text(course.courseInfo.name)
                                            .fontStyle(kFontName, size: 15, weight: .semibold)
                                            .foregroundStyle(palette.foregroundColor)
                                            .lineLimit(1)
                                    }
                                    Text(ref.playedAt.weekdayShortMonthDay)
                                        .fontStyle(kFontName, size: 13, weight: .regular)
                                        .foregroundStyle(Color.neutral)
                                }
                                Spacer(minLength: 0)
                                Icon(name: "chevron.right", size: 14, weight: .semibold)
                                    .foregroundStyle(Color.neutral3)
                            }
                            .padding(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - PlayerProfileViewModel

@MainActor
final class PlayerProfileViewModel: ObservableObject {
    @Published private(set) var player: Player?
    @Published private(set) var isLoading = true

    func load(playerID: String) async {
        isLoading = true
        defer { isLoading = false }
        switch await FirebaseService.shared.getPlayerByID(playerID) {
        case .success(let p): player = p
        case .failure: player = nil
        }
    }
}
