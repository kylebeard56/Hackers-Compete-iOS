//
//  SeriesRosterView.swift
//  Hackers
//

import SwiftUI

struct SeriesRosterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette
    var onAddPlayers: (() -> Void)?

    @State private var showAddOfflinePlayer = false
    @State private var podEditorTeam: SeriesTeam?
    @State private var teamEditorContext: SeriesTeamEditorContext?
    @State private var memberPendingRemoval: SeriesMember?
    @State private var memberEditorItem: MemberEditorSheetItem?

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
        .sheet(item: $memberEditorItem) { item in
            SeriesMemberEditorSheet(viewModel: viewModel, memberID: item.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: viewModel.series.defaultCourse?.courseID) {
            await viewModel.ensureTeeChoicesLoaded(for: viewModel.series.defaultCourse)
        }
        .confirmationDialog(
            "Remove from league?",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let m = memberPendingRemoval {
                    Task { await viewModel.removeMember(m) }
                }
                memberPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                memberPendingRemoval = nil
            }
        } message: {
            Text("\(memberPendingRemoval?.name.fullName ?? "") will lose access to this series.")
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
                    Button {
                        Haptics.fire(.light)
                        onAddPlayers?()
                    } label: {
                        Icon(name: "f234", size: 18, weight: .solid)
                            .foregroundStyle(Color.accentGreen)
                            .padding(10)
                            .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                    }
                    .buttonStyle(.plain)
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
                } label: {
                    Text("Add players")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                        .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                }
                .onTapGesture { Haptics.fire(.light) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCardEffect()
    }

    @ViewBuilder
    private func memberRow(_ member: SeriesMember) -> some View {
        let hcRow = viewModel.memberHandicaps[member.id]
        let isOverridden = hcRow?.isOverridden == true
        
        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: member.name.initials,
                size: 40,
                glassTint: palette.whiteGlassButtonColor
            )
            .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if !member.isOffline {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentPurple)
                    }
                }

                if member.role != .member {
                    roleChip(for: member.role)
                }

                if isOverridden {
                    Chip(
                        text: "Override",
                        size: .xSmall,
                        foreground: .orange,
                        background: Color.orange.opacity(colorScheme.translucent)
                    )
                }

                HStack(spacing: 8) {
                    if let handicap = viewModel.effectiveHandicap(for: member.id) {
                        Text("HC \(String(format: "%.1f", handicap))")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(isOverridden ? Color.orange : Color.accentGreen)
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
    private func roleChip(for role: SeriesMemberRole) -> some View {
        switch role {
        case .spectator:
            Chip(
                text: "Spectator",
                size: .xSmall,
                foreground: .orange,
                background: Color.orange.opacity(colorScheme.translucent)
            )
        case .commissioner:
            Chip(
                text: "Commish",
                icon: "f521",
                iconWeight: .solid,
                size: .xSmall,
                foreground: Color.accentYellow,
                background: Color.accentYellow.opacity(colorScheme.translucent)
            )
        case .captain:
            Chip(
                text: "Captain",
                icon: "f8a2",
                iconWeight: .solid,
                size: .xSmall,
                foreground: Color.systemBlue,
                background: Color.systemBlue.opacity(colorScheme.translucent)
            )
        case .member:
            EmptyView()
        }
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

            Button {
                Haptics.fire(.light)
                memberEditorItem = MemberEditorSheetItem(id: member.id)
            } label: {
                Label("Edit member", systemImage: "square.and.pencil")
            }

            if member.id != viewModel.currentMemberID, member.role != .commissioner {
                Button(role: .destructive) {
                    memberPendingRemoval = member
                } label: {
                    Label("Remove from league", systemImage: "person.fill.xmark")
                }
            }
        } label: {
            Icon(name: "f303", size: 17, weight: .solid)
                .foregroundStyle(Color.neutral)
                .padding(10)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
        }
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
                    Button {
                        Haptics.fire(.light)
                        teamEditorContext = .newTeam
                    } label: {
                        Icon(name: "f067", size: 14, weight: .solid)
                            .foregroundStyle(Color.accentGreen)
                            .padding(10)
                            .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCardEffect()
    }

    private func teamCard(_ team: SeriesTeam) -> some View {
        let teamMembers = viewModel.activeMembers.filter { $0.teamID == team.id }
        let teamPods = viewModel.sortedPods.filter { $0.teamID == team.id && $0.isActive }

        let addPlayerCandidates = viewModel.activeMembers.filter { $0.teamID != team.id }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(team.swatchColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.neutral4.opacity(0.35), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        Text("\(teamMembers.count) members \(kDot) \(teamPods.count) fixed pair\(teamPods.count == 1 ? "" : "s")")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                }

                Spacer(minLength: 0)

                if viewModel.isCommissioner {
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
                            .background(palette.cardEmbeddedRowBackground)
                            .clipShape(Circle())
                    }
                    .onTapGesture { Haptics.fire(.light) }
                }
            }

            if viewModel.isCommissioner {
                HStack(spacing: 10) {
                    Menu {
                        if addPlayerCandidates.isEmpty {
                            Button("No available players") {}
                                .disabled(true)
                        }
                        ForEach(addPlayerCandidates, id: \.id) { member in
                            Button {
                                Haptics.fire(.light)
                                Task { await viewModel.updateMemberTeam(member, teamID: team.id) }
                            } label: {
                                Label(member.name.fullName, systemImage: "person.badge.plus")
                            }
                        }
                    } label: {
                        Text("Add players")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(addPlayerCandidates.isEmpty ? Color.neutral : palette.foregroundColor)
                            .alignCenter()
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                            .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                    }
                    .disabled(addPlayerCandidates.isEmpty)

                    Button {
                        Haptics.fire(.light)
                        podEditorTeam = team
                    } label: {
                        Text("Add pair")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignCenter()
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                    }
                    .buttonStyle(.plain)
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
                PlayerAvatarView(
                    initials: member.name.initials,
                    size: 28,
                    glassTint: palette.whiteGlassButtonColor
                )
                .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
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

private struct MemberEditorSheetItem: Identifiable, Hashable {
    let id: String
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
    @State private var useCustomHex = false
    @State private var customHexText = ""
    @State private var isSaving = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: team == nil ? "Add Team" : "Edit Team",
                    subtitle: "Teams are optional. Use them when you want a cleaner league structure and standings.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    SeriesSheetCard(palette: palette) {
                        Text("Team Details".uppercased())
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        TextField("Team name", text: $name)
                            .fontStyle(kFontName, size: 15, weight: .regular)
                            .foregroundStyle(palette.foregroundColor)
                            .mutedGlassTextFieldContainer(cornerRadius: 14, baseFill: palette.cardEmbeddedRowBackground)

                        HStack(spacing: 12) {
                            Text("Preview")
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            Circle()
                                .fill(previewSwatchColor)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.neutral4.opacity(0.4), lineWidth: 1))
                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Preset colors")
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(TeamColor.cycle, id: \.rawValue) { option in
                                        Button {
                                            useCustomHex = false
                                            color = option
                                        } label: {
                                            Chip(
                                                text: option.name,
                                                size: .small,
                                                foreground: !useCustomHex && color == option ? .white : option.value,
                                                background: !useCustomHex && color == option ? option.value : option.value.opacity(colorScheme.translucent)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Toggle(isOn: $useCustomHex) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Custom hex color")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                                Text("Optional #RGB or #RRGGBB. Overrides preset swatches.")
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }
                        }
                        .tint(.accentGreen)

                        if useCustomHex {
                            TextField("RRGGBB or RGB", text: $customHexText)
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(palette.foregroundColor)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .mutedGlassTextFieldContainer(cornerRadius: 14, baseFill: palette.cardEmbeddedRowBackground)

                            if !customHexText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isValidCustomHex {
                                Text("Enter 3- or 6-digit hex (letters A–F).")
                                    .fontStyle(kFontName, size: 12, weight: .medium)
                                    .foregroundStyle(Color.orange)
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(palette.cardEmbeddedRowBackground.opacity(0.45))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                Button {
                    guard canSave else { return }
                    isSaving = true
                    Task {
                        let hexArg = useCustomHex ? customHexText : nil
                        if let team {
                            await viewModel.updateTeam(team, name: trimmedName, presetColorKey: color.rawValue, customColorHex: hexArg)
                        } else {
                            _ = await viewModel.createTeam(name: trimmedName, presetColorKey: color.rawValue, customColorHex: hexArg)
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
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave && !isSaving ? Color.accentGreen : Color.neutral3)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .task(id: team?.id) {
            if let team {
                name = team.name
                if let hex = team.customColorHex, hex.contains("#") {
                    useCustomHex = true
                    customHexText = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                } else {
                    useCustomHex = false
                    customHexText = ""
                    color = TeamColor(rawValue: team.color) ?? .red
                }
            } else {
                let suggestion = TeamColor.teamValue(for: viewModel.sortedTeams.count)
                name = suggestion.1
                color = suggestion.0
                useCustomHex = false
                customHexText = ""
            }
        }
    }

    private var previewSwatchColor: Color {
        if useCustomHex, isValidCustomHex {
            let t = hexStringForColorValue
            return ColorValue(hex: t).color
        }
        return color.value
    }

    private var hexStringForColorValue: String {
        var t = customHexText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.hasPrefix("#") { t = "#\(t)" }
        return t
    }

    private var isValidCustomHex: Bool {
        var t = customHexText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("#") { t = String(t.dropFirst()) }
        guard t.count == 3 || t.count == 6 else { return false }
        return t.allSatisfy { $0.isHexDigit }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard trimmedName.isPopulated else { return false }
        if useCustomHex { return isValidCustomHex }
        return true
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

                        TextField("Pair label (optional)", text: $label)
                            .fontStyle(kFontName, size: 15, weight: .regular)
                            .foregroundStyle(palette.foregroundColor)
                            .mutedGlassTextFieldContainer(cornerRadius: 14, baseFill: palette.cardEmbeddedRowBackground)

                        SeriesSheetRow(palette: palette) {
                            selectionRow(
                                title: "First player",
                                selection: firstMemberName ?? "Choose player",
                                members: eligibleMembers,
                                selectedID: $firstMemberID
                            )
                        }

                        SeriesSheetRow(palette: palette) {
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
                                SeriesSheetRow(palette: palette) {
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
                                background: palette.cardEmbeddedRowBackground
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
