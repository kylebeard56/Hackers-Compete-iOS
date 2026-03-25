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
    @State private var podEditorTeam: SeriesTeam?
    @State private var teamEditorContext: SeriesTeamEditorContext?

    var body: some View {
        VStack(spacing: 16) {
            rosterSection
            teamsSection
        }
        .sheet(isPresented: $showAddOfflinePlayer) {
            NewOfflinePlayerView { name in
                showAddOfflinePlayer = false
                Task { await viewModel.addOfflineMember(name: name) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $podEditorTeam) { team in
            SeriesPodEditorSheet(viewModel: viewModel, team: team)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $teamEditorContext) { context in
            SeriesTeamEditorSheet(viewModel: viewModel, team: context.team)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task(id: viewModel.series.defaultCourse?.courseID) {
            await viewModel.ensureTeeChoicesLoaded(for: viewModel.series.defaultCourse)
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
                            Label("Add offline player", systemImage: "person.fill.badge.plus")
                        }
                        Button {
                            Haptics.fire(.light)
                            teamEditorContext = .newTeam
                        } label: {
                            Label("Add team", systemImage: "flag.2.crossed")
                        }
                        if viewModel.teams.isEmpty {
                            Button {
                                Haptics.fire(.light)
                                Task { await viewModel.createDefaultTeams() }
                            } label: {
                                Label("Create teams", systemImage: "person.2")
                            }
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
                    subtitle: "Add players to build your league roster."
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
    }

    private func memberRow(_ member: SeriesMember) -> some View {
        HStack(spacing: 12) {
            PlayerAvatarView(initials: member.name.initials, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if member.role == .commissioner {
                        Icon(name: "f521", size: 12, weight: .solid)
                            .foregroundStyle(Color.accentGreen)
                    } else if member.role == .captain {
                        Icon(name: "f5fd", size: 12, weight: .solid)
                            .foregroundStyle(Color.systemBlue)
                    } else if member.role == .spectator {
                        Text("Spectator")
                            .fontStyle(kFontName, size: 11, weight: .semibold)
                            .foregroundStyle(Color.orange)
                    }
                }

                HStack(spacing: 8) {
                    if let handicap = viewModel.effectiveHandicap(for: member.id) {
                        Text("HC \(String(format: "%.1f", handicap))")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.accentGreen)
                    }

                    if let teamID = member.teamID,
                       let team = viewModel.teams.first(where: { $0.id == teamID }) {
                        Text(team.name)
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    if let pod = viewModel.pods.first(where: { $0.memberIDs.contains(member.id) && $0.isActive }) {
                        Text("Pair \(pod.resolvedLabel)")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.accentPurple)
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
        let defaultCourse = viewModel.series.defaultCourse
        Menu {
            Menu {
                ForEach(SeriesMemberRole.allCases, id: \.self) { role in
                    Button {
                        Task { await viewModel.updateMemberRole(member, role: role) }
                    } label: {
                        HStack {
                            Text(roleTitle(role))
                            if member.role == role {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Role", systemImage: "person.text.rectangle")
            }

            if viewModel.hasTeams {
                Menu {
                    Button {
                        Task { await viewModel.updateMemberTeam(member, teamID: nil) }
                    } label: {
                        HStack {
                            Text("Unassigned")
                            if member.teamID == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(viewModel.sortedTeams, id: \.id) { team in
                        Button {
                            Task { await viewModel.updateMemberTeam(member, teamID: team.id) }
                        } label: {
                            HStack {
                                Text(team.name)
                                if member.teamID == team.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Assign team", systemImage: "person.2")
                }
            }

            if let defaultCourse, defaultCourse.isConfigured {
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

                    if let course = viewModel.series.defaultCourse,
                       let teeChoices = currentTeeChoices(for: course) {
                        ForEach(teeChoices, id: \.id) { tee in
                            Button {
                                Task { await viewModel.updateMemberTeeBox(member, teeBoxID: tee.id) }
                            } label: {
                                HStack {
                                    Text(tee.name)
                                    if member.defaultTeeBoxID == tee.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label("Default tee", systemImage: "flag")
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
            HStack {
                Text("Teams & Pairs".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Spacer(minLength: 0)

                if viewModel.isCommissioner {
                    Menu {
                        Button {
                            Haptics.fire(.light)
                            teamEditorContext = .newTeam
                        } label: {
                            Label("Add team", systemImage: "plus")
                        }

                        if viewModel.teams.isEmpty {
                            Button {
                                Haptics.fire(.light)
                                Task { await viewModel.createDefaultTeams() }
                            } label: {
                                Label("Create defaults", systemImage: "person.2")
                            }
                        }
                    } label: {
                        Chip(
                            text: viewModel.teams.isEmpty ? "Set up teams" : "Manage",
                            size: .small,
                            foreground: palette.foregroundColor,
                            background: Color.neutral6
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.teams.isEmpty {
                Text("Teams are optional. Create them when you want league-wide team standings or fixed pairs.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            } else {
                ForEach(viewModel.sortedTeams, id: \.id) { team in
                    teamCard(team)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    private func teamCard(_ team: SeriesTeam) -> some View {
        let teamMembers = viewModel.activeMembers.filter { $0.teamID == team.id }
        let teamPods = viewModel.sortedPods.filter { $0.teamID == team.id && $0.isActive }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text("\(teamMembers.count) members \(kDot) \(teamPods.count) fixed pair\(teamPods.count == 1 ? "" : "s")")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)

                if viewModel.isCommissioner {
                    HStack(spacing: 8) {
                        Button("Add pair") {
                            Haptics.fire(.light)
                            podEditorTeam = team
                        }
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)

                        Menu {
                            Button {
                                Haptics.fire(.light)
                                teamEditorContext = .edit(team)
                            } label: {
                                Label("Edit team", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                Haptics.fire(.light)
                                Task { await viewModel.deleteTeam(team) }
                            } label: {
                                Label("Delete team", systemImage: "trash")
                            }
                        } label: {
                            Icon(name: "f141", size: 15, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .padding(8)
                                .background(Color.neutral6)
                                .clipShape(Circle())
                        }
                        .onTapGesture { Haptics.fire(.light) }
                    }
                }
            }

            if teamPods.isPopulated {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pairs")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    teamPodRows(teamPods)
                }
            }

            if teamMembers.isEmpty {
                Text("No members assigned")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            } else {
                teamMemberRows(teamMembers)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(cornerRadius: 12)
    }

    // MARK: - Helpers

    private func roleTitle(_ role: SeriesMemberRole) -> String {
        switch role {
        case .commissioner: return "Commissioner"
        case .captain: return "Captain"
        case .member: return "Member"
        case .spectator: return "Spectator"
        }
    }

    private func pairNames(for pod: SeriesTeamPod) -> String {
        pod.memberIDs
            .compactMap { memberID in viewModel.activeMembers.first(where: { $0.id == memberID })?.name.fullName }
            .joined(separator: " / ")
    }

    @ViewBuilder
    private func teamPodRows(_ pods: [SeriesTeamPod]) -> some View {
        ForEach(pods) { (pod: SeriesTeamPod) in
            HStack(spacing: 8) {
                Text(pod.resolvedLabel)
                    .fontStyle(kFontName, size: 12, weight: .bold)
                    .foregroundStyle(Color.accentPurple)
                    .frame(width: 18, alignment: .leading)

                Text(pairNames(for: pod))
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                if viewModel.isCommissioner {
                    Button {
                        Task { await viewModel.deletePod(pod) }
                    } label: {
                        Chip(
                            text: "Remove",
                            size: .xSmall,
                            foreground: .systemError,
                            background: Color.systemError.opacity(0.14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func teamMemberRows(_ members: [SeriesMember]) -> some View {
        ForEach(members) { (member: SeriesMember) in
            HStack(spacing: 8) {
                PlayerAvatarView(initials: member.name.initials, size: 28)
                Text(member.name.fullName)
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }
        }
    }

    private func currentTeeChoices(for course: SeriesCourseSelection) -> [Tee]? {
        let tees = viewModel.teeChoices(for: course)
        return tees.isPopulated ? tees : nil
    }
}

private struct SeriesTeamEditorContext: Identifiable {
    let id: String
    let team: SeriesTeam?

    static let newTeam = SeriesTeamEditorContext(id: "new-team", team: nil)

    static func edit(_ team: SeriesTeam) -> SeriesTeamEditorContext {
        SeriesTeamEditorContext(id: team.id, team: team)
    }
}

private struct SeriesTeamEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let team: SeriesTeam?

    @State private var name = ""
    @State private var color: TeamColor = .red
    @State private var isSaving = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: team == nil ? "Add Team" : "Edit Team",
                subtitle: "Teams are optional. Use them when you want a cleaner league structure and standings.",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    SeriesSheetCard(palette: palette) {
                        Text("Team Details".uppercased())
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        SeriesSheetRow {
                            TextField("Team name", text: $name)
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Color")
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(TeamColor.cycle, id: \.rawValue) { option in
                                        Button {
                                            color = option
                                        } label: {
                                            Chip(
                                                text: option.name,
                                                size: .small,
                                                foreground: color == option ? .white : option.value,
                                                background: color == option ? option.value : option.value.opacity(colorScheme.translucent)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Chip(
                                text: "Cancel",
                                size: .small,
                                foreground: palette.foregroundColor,
                                background: Color.neutral6
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)

                        Button {
                            guard canSave else { return }
                            isSaving = true
                            Task {
                                if let team {
                                    await viewModel.updateTeam(team, name: trimmedName, color: color.rawValue)
                                } else {
                                    _ = await viewModel.createTeam(name: trimmedName, color: color.rawValue)
                                }
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isSaving ? "Saving..." : "Save Team")
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(canSave ? Color.accentGreen : Color.neutral3)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave || isSaving)
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .task {
            if let team {
                name = team.name
                color = TeamColor(rawValue: team.color) ?? .red
            } else {
                let suggestion = TeamColor.teamValue(for: viewModel.sortedTeams.count)
                name = suggestion.1
                color = suggestion.0
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        trimmedName.isPopulated
    }
}

private struct SeriesPodEditorSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let team: SeriesTeam

    @State private var firstMemberID: String = ""
    @State private var secondMemberID: String = ""
    @State private var label: String = ""
    @State private var isSaving = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var eligibleMembers: [SeriesMember] {
        let usedMemberIDs = Set(
            viewModel.pods
                .filter { $0.teamID == team.id && $0.isActive }
                .flatMap(\.memberIDs)
        )
        return viewModel.activeMembers
            .filter { $0.teamID == team.id && !usedMemberIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: team.name,
                subtitle: "Create optional fixed pairs for pod-aligned tee groups.",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    SeriesSheetCard(palette: palette) {
                        Text("Create Pair".uppercased())
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        Text("Pairs are optional. Use them when you want pod-aligned groups like 1A vs 2A without changing your core team standings.")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)

                        SeriesSheetRow {
                            TextField("Pair label (optional)", text: $label)
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                        }

                        SeriesSheetRow {
                            selectionRow(
                                title: "First player",
                                selection: firstMemberName ?? "Choose player",
                                members: eligibleMembers,
                                selectedID: $firstMemberID
                            )
                        }

                        SeriesSheetRow {
                            selectionRow(
                                title: "Second player",
                                selection: secondMemberName ?? "Choose player",
                                members: eligibleMembers.filter { $0.id != firstMemberID },
                                selectedID: $secondMemberID
                            )
                        }
                    }

                    if existingPods.isPopulated {
                        SeriesSheetCard(palette: palette) {
                            Text("Current Pairs".uppercased())
                                .fontStyle(kFontName, size: 14, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)

                            ForEach(existingPods, id: \.id) { pod in
                                SeriesSheetRow {
                                    HStack(alignment: .top, spacing: 12) {
                                        Chip(
                                            text: pod.resolvedLabel,
                                            size: .xSmall,
                                            foreground: Color.accentPurple,
                                            background: Color.accentPurple.opacity(colorScheme.translucent)
                                        )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(pairNames(for: pod))
                                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                                .foregroundStyle(palette.foregroundColor)
                                            Text("Fixed twosome for tee-group alignment.")
                                                .fontStyle(kFontName, size: 12, weight: .regular)
                                                .foregroundStyle(Color.neutral)
                                        }

                                        Spacer(minLength: 0)

                                        Button {
                                            Task { await viewModel.deletePod(pod) }
                                        } label: {
                                            Chip(
                                                text: "Remove",
                                                size: .xSmall,
                                                foreground: .systemError,
                                                background: Color.systemError.opacity(colorScheme.translucent)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Chip(
                                text: "Cancel",
                                size: .small,
                                foreground: palette.foregroundColor,
                                background: Color.neutral6
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)

                        Button {
                            guard canSave else { return }
                            isSaving = true
                            Task {
                                _ = await viewModel.createPod(
                                    teamID: team.id,
                                    memberIDs: [firstMemberID, secondMemberID],
                                    label: normalizedLabel
                                )
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isSaving ? "Saving..." : "Save Pair")
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(canSave ? Color.accentGreen : Color.neutral3)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave || isSaving)
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private var canSave: Bool {
        firstMemberID.isPopulated && secondMemberID.isPopulated && firstMemberID != secondMemberID
    }

    private var normalizedLabel: String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isPopulated ? trimmed : nil
    }

    private var existingPods: [SeriesTeamPod] {
        viewModel.sortedPods.filter { $0.teamID == team.id && $0.isActive }
    }

    private var firstMemberName: String? {
        eligibleMembers.first(where: { $0.id == firstMemberID })?.name.fullName
            ?? viewModel.activeMembers.first(where: { $0.id == firstMemberID })?.name.fullName
    }

    private var secondMemberName: String? {
        eligibleMembers.first(where: { $0.id == secondMemberID })?.name.fullName
            ?? viewModel.activeMembers.first(where: { $0.id == secondMemberID })?.name.fullName
    }

    private func selectionRow(
        title: String,
        selection: String,
        members: [SeriesMember],
        selectedID: Binding<String>
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text(selection)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(selection == "Choose player" ? Color.neutral : palette.foregroundColor)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Menu {
                Button("Clear") {
                    selectedID.wrappedValue = ""
                }

                ForEach(members, id: \.id) { member in
                    Button {
                        selectedID.wrappedValue = member.id
                    } label: {
                        HStack {
                            Text(member.name.fullName)
                            if selectedID.wrappedValue == member.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Chip(
                    text: selectedID.wrappedValue.isEmpty ? "Choose" : "Change",
                    size: .xSmall,
                    foreground: palette.foregroundColor,
                    background: Color.neutral5
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func pairNames(for pod: SeriesTeamPod) -> String {
        pod.memberIDs
            .compactMap { memberID in viewModel.activeMembers.first(where: { $0.id == memberID })?.name.fullName }
            .joined(separator: " / ")
    }
}
