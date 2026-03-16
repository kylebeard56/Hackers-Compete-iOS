//
//  SeriesRosterView.swift
//  Hackers
//

import SwiftUI

struct SeriesRosterView: View {
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette
    var onAddPlayers: (() -> Void)?

    @State private var showAddOfflinePlayer = false

    var body: some View {
        VStack(spacing: 16) {
            rosterSection
            if !viewModel.teams.isEmpty {
                teamsSection
            }
        }
    }

    // MARK: - Roster

    private var rosterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Roster".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                if viewModel.isCommissioner {
                    Menu {
                        Button {
                            Haptics.fire(.light)
                            onAddPlayers?()
                        } label: {
                            Label("Add player", systemImage: "person.badge.plus")
                        }
                        Button {
                            Haptics.fire(.light)
                            showAddOfflinePlayer = true
                        } label: {
                            Label("Add offline player", systemImage: "person.badge.plus")
                            Text("Managed by commissioner")
                        }
                    } label: {
                        Icon(name: "f234", size: 18, weight: .solid)
                            .foregroundStyle(Color.accentGreen)
                            .padding(10)
                            .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                    }
                    .onTapGesture { Haptics.fire(.light) }
                }
            }

            if viewModel.activeMembers.isEmpty {
                EmptyStateView(
                    imageName: "GolferIsometric",
                    title: "No players yet",
                    subtitle: "Add players to the series roster."
                )
                .frame(minHeight: 200)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.activeMembers, id: \.id) { member in
                        memberRow(member)
                    }
                }
            }
        }
        .padding(16)
        .glassCardEffect()
        .sheet(isPresented: $showAddOfflinePlayer) {
            NewOfflinePlayerView { name in
                showAddOfflinePlayer = false
                Task { await viewModel.addOfflineMember(name: name) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func memberRow(_ member: SeriesMember) -> some View {
        HStack(spacing: 12) {
            PlayerAvatarView(initials: member.name.initials, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if member.role == .commissioner {
                        Icon(name: "f521", size: 12, weight: .solid)
                            .foregroundStyle(Color.accentGreen)
                    }
                }

                HStack(spacing: 6) {
                    if let hc = viewModel.effectiveHandicap(for: member.id) {
                        Text("HC \(String(format: "%.1f", hc))")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.accentGreen)
                    }

                    if let teamID = member.teamID,
                       let team = viewModel.teams.first(where: { $0.id == teamID }) {
                        Text(team.name)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    if member.isOffline {
                        Text("Offline")
                            .fontStyle(kFontName, size: 11, weight: .medium)
                            .foregroundStyle(Color.neutral2)
                    }
                }
            }

            Spacer(minLength: 0)

            if viewModel.isCommissioner {
                memberMenu(member)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private func memberMenu(_ member: SeriesMember) -> some View {
        let defaultCourse = viewModel.series.defaults.defaultCourse
        Menu {
            if let defaultCourse, !defaultCourse.courseID.isEmpty {
                let currentTee = member.defaultTeeBoxID ?? defaultCourse.defaultTeeID
                Menu {
                    Button {
                        Task { await viewModel.updateMemberTeeBox(member, teeBoxID: nil) }
                    } label: {
                        HStack {
                            Text("Series default")
                            if member.defaultTeeBoxID == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Label("Default tee", systemImage: "flag")
                    if !currentTee.isEmpty {
                        Text(currentTee)
                    }
                }
            }
        } label: {
            Icon(name: "f141", size: 16, weight: .regular)
                .foregroundStyle(Color.neutral)
                .padding(8)
                .contentShape(Rectangle())
        }
        .onTapGesture { Haptics.fire(.light) }
    }

    // MARK: - Teams

    private var teamsSection: some View {
        VStack(spacing: 12) {
            Text("Teams".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()

            ForEach(viewModel.teams.sorted(by: { $0.index < $1.index }), id: \.id) { team in
                VStack(alignment: .leading, spacing: 8) {
                    Text(team.name)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    let teamMembers = viewModel.activeMembers.filter { $0.teamID == team.id }
                    if teamMembers.isEmpty {
                        Text("No members assigned")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    } else {
                        ForEach(teamMembers, id: \.id) { member in
                            HStack(spacing: 8) {
                                PlayerAvatarView(initials: member.name.initials, size: 28)
                                Text(member.name.fullName)
                                    .fontStyle(kFontName, size: 13, weight: .medium)
                                    .foregroundStyle(palette.foregroundColor)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCardEffect(cornerRadius: 12)
            }
        }
        .padding(16)
        .glassCardEffect()
    }
}

// MARK: - Helpers

extension SeriesMember {
    var isOffline: Bool { userID == nil }
}
