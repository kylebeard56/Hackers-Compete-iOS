//
//  SeriesRosterView.swift
//  Hackers
//

import SwiftUI

struct SeriesRosterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SeriesViewModel
    let palette: DesignPalette
    var onAddPlayers: (() -> Void)?

    @State private var showAddOfflinePlayer = false
    @State private var podEditorTeam: SeriesTeam?
    @State private var teamEditorContext: SeriesTeamEditorContext?
    @State private var memberPendingRemoval: SeriesMember?
    @State private var memberEditorItem: MemberEditorSheetItem?
    @State private var rosterSort: SeriesRosterSortOrder = .abc
    @State private var showLeaveLeagueConfirmation = false
    @State private var showCommissionerLeaveLeagueInfo = false
    @State private var pendingSelfRoleDemotion: SeriesMemberRole?

    private enum SeriesRosterSortOrder: String, CaseIterable {
        case abc = "ABC"
        case team = "Team"
        case hcp = "HCP"

        var label: String { rawValue }
    }

    /// Status glyphs next to the name; slightly smaller so the badge fits the title row.
    private var rosterStatusBadgeDiameter: CGFloat { 22 }
    private var rosterStatusGlyphSize: CGFloat { 11 }

    @ViewBuilder
    private func rosterStatusAccentBadge(circleTint: Color, @ViewBuilder glyph: () -> some View) -> some View {
        ZStack {
            Circle()
                .fill(circleTint.opacity(colorScheme.translucent))
            glyph()
        }
        .frame(width: rosterStatusBadgeDiameter, height: rosterStatusBadgeDiameter)
        .contentShape(Circle())
    }

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
                .presentationDetents([.large])
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
        .alert("Leave League", isPresented: $showLeaveLeagueConfirmation) {
            Button("Leave", role: .destructive) {
                Task {
                    await viewModel.leaveLeague()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your membership will be removed. Your historical scores and round data will be preserved, but you will lose access to this series.")
        }
        .alert("Leave league", isPresented: $showCommissionerLeaveLeagueInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Transfer the commissioner role to another member in League settings first. After that, you can leave from the roster or the league menu.")
        }
        .alert("Lower your role?", isPresented: Binding(
            get: { pendingSelfRoleDemotion != nil },
            set: { if !$0 { pendingSelfRoleDemotion = nil } }
        )) {
            Button("Change role", role: .destructive) {
                if let role = pendingSelfRoleDemotion, let m = viewModel.currentMemberRecord {
                    Task { await viewModel.updateMemberRole(m, role: role) }
                }
                pendingSelfRoleDemotion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingSelfRoleDemotion = nil
            }
        } message: {
            if let role = pendingSelfRoleDemotion {
                Text("You are about to change your role to \(roleTitle(role)). You may lose commissioner or captain privileges.")
            }
        }
    }

    private var sortedRosterMembers: [SeriesMember] {
        let list = viewModel.activeMembers
        let hcpOn = viewModel.series.handicapConfig.isEnabled
        switch rosterSort {
        case .abc:
            return list.sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
        case .team:
            return list.sorted { a, b in
                compareMembersForTeamRosterSort(a, b, hcpOn: hcpOn)
            }
        case .hcp:
            return list.sorted { a, b in
                let ha = viewModel.effectiveHandicap(for: a.id)
                let hb = viewModel.effectiveHandicap(for: b.id)
                switch (ha, hb) {
                case (nil, nil): break
                case (nil, _): return false
                case (_, nil): return true
                case (let x?, let y?):
                    if x != y { return x < y }
                }
                return a.name.fullName.localizedCaseInsensitiveCompare(b.name.fullName) == .orderedAscending
            }
        }
    }

    private func rosterTeamGroupKey(for member: SeriesMember) -> String {
        member.teamID ?? ""
    }

    private func rosterTeamHasActivePods(teamID: String) -> Bool {
        guard !teamID.isEmpty else { return false }
        return viewModel.pods.contains { $0.teamID == teamID && $0.isActive }
    }

    /// Active pod for this member when the pod belongs to the member’s team (if any).
    private func rosterActivePod(for member: SeriesMember) -> SeriesTeamPod? {
        viewModel.pods.first { pod in
            guard pod.isActive, pod.memberIDs.contains(member.id) else { return false }
            guard let tid = member.teamID else { return true }
            return pod.teamID == tid
        }
    }

    private func rosterPodSortPlacement(for member: SeriesMember) -> (podIndex: Int, slot: Int)? {
        guard let tid = member.teamID, rosterTeamHasActivePods(teamID: tid) else { return nil }
        guard let pod = rosterActivePod(for: member), pod.teamID == tid else { return nil }
        guard let slot = pod.memberIDs.firstIndex(of: member.id) else { return nil }
        return (pod.index, slot)
    }

    private func compareHandicapThenName(_ a: SeriesMember, _ b: SeriesMember, hcpOn: Bool) -> Bool {
        if hcpOn {
            let ha = viewModel.effectiveHandicap(for: a.id)
            let hb = viewModel.effectiveHandicap(for: b.id)
            switch (ha, hb) {
            case (nil, nil): break
            case (nil, _): return false
            case (_, nil): return true
            case (let x?, let y?):
                if x != y { return x < y }
            }
        }
        return a.name.fullName.localizedCaseInsensitiveCompare(b.name.fullName) == .orderedAscending
    }

    private func compareMembersForTeamRosterSort(_ a: SeriesMember, _ b: SeriesMember, hcpOn: Bool) -> Bool {
        let ta = a.teamID ?? ""
        let tb = b.teamID ?? ""
        if ta != tb { return ta < tb }

        if ta.isEmpty {
            return compareHandicapThenName(a, b, hcpOn: hcpOn)
        }

        if rosterTeamHasActivePods(teamID: ta) {
            let pa = rosterPodSortPlacement(for: a)
            let pb = rosterPodSortPlacement(for: b)
            let aPaired = pa != nil
            let bPaired = pb != nil
            if aPaired != bPaired { return aPaired }
            if aPaired, bPaired, let pa, let pb {
                if pa.podIndex != pb.podIndex { return pa.podIndex < pb.podIndex }
                if pa.slot != pb.slot { return pa.slot < pb.slot }
                return a.name.fullName.localizedCaseInsensitiveCompare(b.name.fullName) == .orderedAscending
            }
            return compareHandicapThenName(a, b, hcpOn: hcpOn)
        }

        return compareHandicapThenName(a, b, hcpOn: hcpOn)
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
                        Icon(name: "f067", size: 14, weight: .solid)
                            .foregroundStyle(Color.charcoal)
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
                HStack(spacing: 12) {
                    Menu {
                        ForEach(SeriesRosterSortOrder.allCases, id: \.self) { order in
                            Button {
                                Haptics.fire(.light)
                                rosterSort = order
                            } label: {
                                HStack {
                                    Text(order.label)
                                    if rosterSort == order {
                                        Icon(name: "f00c", size: 12, weight: .solid)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Icon(name: "chevron.down", size: 11, weight: .semibold)
                                .foregroundStyle(Color.neutral3)

                            Text(rosterSort.label)
                                .fontStyle(kFontName, size: 13, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
                        .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 8) {
                    ForEach(Array(sortedRosterMembers.enumerated()), id: \.element.id) { index, member in
                        if rosterSort == .team {
                            let isStartOfTeamGroup = index == 0
                                || rosterTeamGroupKey(for: member) != rosterTeamGroupKey(for: sortedRosterMembers[index - 1])
                            if isStartOfTeamGroup {
                                rosterTeamGroupHeader(for: member)
                                    .padding(.top, index > 0 ? 10 : 2)
                            }
                        }

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
        let isOverridden = viewModel.memberHandicaps[member.id]?.isOverridden == true
        let hcpEnabled = viewModel.series.handicapConfig.isEnabled
        let handicap = viewModel.effectiveHandicap(for: member.id)
        let handicapBadgeText: String? = {
            guard hcpEnabled, let h = handicap else { return nil }
            return String(format: "%.1f", h)
        }()
        let handicapBadgeStyle = AvatarBadgeStyle(
            shape: .circle,
            tint: palette.whiteGlassButtonColor,
            shadowColor: palette.shadowColor,
            shadowRadius: 12,
            foregroundColor: isOverridden ? Color.orange : Color.accentGreen
        )

        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: member.name.initials,
                size: 40,
                glassTint: palette.whiteGlassButtonColor,
                badgeText: handicapBadgeText,
                badgeStyle: handicapBadgeText != nil ? handicapBadgeStyle : nil
            )
            .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if member.role == .commissioner {
                        rosterStatusAccentBadge(circleTint: Color.accentYellow) {
                            Icon(name: "f521", size: rosterStatusGlyphSize, weight: .solid)
                                .foregroundStyle(Color.accentYellow)
                        }
                    } else if member.role == .captain {
                        rosterStatusAccentBadge(circleTint: Color.systemBlue) {
                            Icon(name: "f1f9", size: rosterStatusGlyphSize, weight: .solid)
                                .foregroundStyle(Color.systemBlue)
                        }
                    } else if member.hasLinkedUserID {
                        rosterStatusAccentBadge(circleTint: Color.accentPurple) {
                            Icon(name: "f00c", size: rosterStatusGlyphSize, weight: .solid)
                                .foregroundStyle(Color.accentPurple)
                        }
                    }
                }

                if member.role != .member {
                    roleChip(for: member.role)
                }

                memberRowSubtitle(member)
            }

            Spacer(minLength: 0)

            if viewModel.isCommissioner {
                if viewModel.isAlignByPairGroupingEnabled, member.teamID != nil {
                    commissionerPartnerMenuButton(member)
                }
                memberMenu(member)
            } else if viewModel.isCaptain, member.id != viewModel.currentMemberID {
                captainRoleMenu(member)
            } else if member.id == viewModel.currentMemberID {
                memberSelfLeaveMenu(member: member)
            }
        }
        .padding(8)
    }

    private func rosterSubtitleLabelText(teamName: String, pod: SeriesTeamPod?) -> String {
        if let pod {
            return "\(teamName) \(kDot) \(pod.resolvedLabel)"
        }
        return teamName
    }

    @ViewBuilder
    private func rosterTeamGroupHeader(for member: SeriesMember) -> some View {
        HStack(spacing: 10) {
            if let tid = member.teamID, let team = viewModel.teams.first(where: { $0.id == tid }) {
                if let dot = team.displaySwatchColor {
                    Circle()
                        .fill(dot)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.neutral4.opacity(0.35), lineWidth: 1))
                }
                Text(team.name)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral)
            } else {
                Circle()
                    .fill(Color.neutral4)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.neutral4.opacity(0.35), lineWidth: 1))
                Text("Unassigned")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
    }

    /// First active pod containing this member (same resolution as legacy roster subtitle text).
    private func rosterSubtitlePod(_ member: SeriesMember) -> SeriesTeamPod? {
        viewModel.pods.first { $0.isActive && $0.memberIDs.contains(member.id) }
    }

    @ViewBuilder
    private func memberRowSubtitle(_ member: SeriesMember) -> some View {
        let subtitlePod = rosterSubtitlePod(member)

        if rosterSort == .team {
            if let subtitlePod {
                Text(subtitlePod.resolvedLabel)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        } else if let tid = member.teamID, let team = viewModel.teams.first(where: { $0.id == tid }) {
            HStack(alignment: .center, spacing: 8) {
                if let dot = team.displaySwatchColor {
                    Circle()
                        .fill(dot)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.neutral4.opacity(0.35), lineWidth: 1))
                }
                Text(rosterSubtitleLabelText(teamName: team.name, pod: subtitlePod))
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        } else if let subtitlePod {
            Text(subtitlePod.resolvedLabel)
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
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
            EmptyView()
        case .captain:
            EmptyView()
        case .member:
            EmptyView()
        }
    }

    @ViewBuilder
    private func memberMenu(_ member: SeriesMember) -> some View {
        let defaultCourse = viewModel.series.defaultCourse
        Menu {
            Menu {
                ForEach(viewModel.assignableRoles(for: member), id: \.self) { role in
                    Button {
                        requestRoleChange(member: member, to: role)
                    } label: {
                        HStack {
                            Text(roleTitle(role))
                            if member.role == role {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(role == .commissioner && !member.hasLinkedUserID)
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

            if member.id == viewModel.currentMemberID {
                Button(role: .destructive) {
                    Haptics.fire(.light)
                    showCommissionerLeaveLeagueInfo = true
                } label: {
                    Label("Leave league", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            if viewModel.isCommissioner, member.id != viewModel.currentMemberID, member.role != .commissioner {
                Button(role: .destructive) {
                    memberPendingRemoval = member
                } label: {
                    Label("Remove from league", systemImage: "person.fill.xmark")
                }
            }
        } label: {
            Icon(name: "f303", size: 14, weight: .solid)
                .foregroundStyle(Color.charcoal)
                .padding(8)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
        }
    }

    private func captainRoleMenu(_ member: SeriesMember) -> some View {
        Menu {
            Menu {
                ForEach(viewModel.assignableRoles(for: member), id: \.self) { role in
                    Button {
                        requestRoleChange(member: member, to: role)
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
        } label: {
            Icon(name: "f303", size: 14, weight: .solid)
                .foregroundStyle(Color.charcoal)
                .padding(8)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
        }
    }

    private func memberSelfLeaveMenu(member: SeriesMember) -> some View {
        let roleChoices = viewModel.assignableRoles(for: member)
        let showRoleMenu = roleChoices.count > 1

        return Menu {
            if showRoleMenu {
                Menu {
                    ForEach(roleChoices, id: \.self) { role in
                        Button {
                            requestRoleChange(member: member, to: role)
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
            }

            Button(role: .destructive) {
                Haptics.fire(.light)
                showLeaveLeagueConfirmation = true
            } label: {
                Label("Leave league", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Icon(name: "f303", size: 14, weight: .solid)
                .foregroundStyle(Color.charcoal)
                .padding(8)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
        }
    }

    private func requestRoleChange(member: SeriesMember, to role: SeriesMemberRole) {
        Haptics.fire(.light)
        if viewModel.shouldConfirmSelfRoleChange(member: member, to: role) {
            pendingSelfRoleDemotion = role
        } else {
            Task { await viewModel.updateMemberRole(member, role: role) }
        }
    }

    @ViewBuilder
    private func commissionerPartnerMenuButton(_ member: SeriesMember) -> some View {
        let teammates = viewModel.activeMembers.filter { $0.teamID == member.teamID && $0.id != member.id }
        let currentPod = viewModel.pods.first { $0.isActive && $0.memberIDs.contains(member.id) }
        let partnerID = currentPod?.memberIDs.first { $0 != member.id }

        Menu {
            Button {
                Haptics.fire(.light)
                Task { await viewModel.setMemberFixedPair(member: member, partnerMemberID: nil) }
            } label: {
                if partnerID == nil {
                    Label("No pair", systemImage: "checkmark")
                } else {
                    Text("No pair")
                }
            }

            ForEach(teammates, id: \.id) { mate in
                Button {
                    Haptics.fire(.light)
                    Task { await viewModel.setMemberFixedPair(member: member, partnerMemberID: mate.id) }
                } label: {
                    if mate.id == partnerID {
                        Label(mate.name.fullName, systemImage: "checkmark")
                    } else {
                        Text(mate.name.fullName)
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.charcoal)
                .padding(8)
                .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor)
                .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
        }
        .menuStyle(.borderlessButton)
        .disabled(teammates.isEmpty)
        .opacity(teammates.isEmpty ? 0.45 : 1)
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
                            .foregroundStyle(Color.charcoal)
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
                    if let dot = team.displaySwatchColor {
                        Circle()
                            .fill(dot)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.neutral4.opacity(0.35), lineWidth: 1))
                    }

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
                        } else {
                            addPlayersMenuContent(targetTeam: team, candidates: addPlayerCandidates)
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
            } else if teamPods.isPopulated {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Players")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    teamMemberRows(teamMembers)
                }
            } else {
                teamMemberRows(teamMembers)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(cornerRadius: 12)
    }

    @ViewBuilder
    private func addPlayersMenuContent(targetTeam: SeriesTeam, candidates: [SeriesMember]) -> some View {
        let otherTeams = viewModel.sortedTeams.filter { $0.id != targetTeam.id }

        ForEach(otherTeams, id: \.id) { otherTeam in
            let members = candidates
                .filter { $0.teamID == otherTeam.id }
                .sorted { $0.name.fullName < $1.name.fullName }

            if !members.isEmpty {
                Menu {
                    ForEach(members, id: \.id) { member in
                        Button(member.name.fullName) {
                            Haptics.fire(.light)
                            Task { await viewModel.updateMemberTeam(member, teamID: targetTeam.id) }
                        }
                    }
                } label: {
                    Text(otherTeam.name)
                    Text("\(members.count) \(members.count == 1 ? "player" : "players")")
                }
            }
        }

        let unassigned = candidates
            .filter { $0.teamID == nil }
            .sorted { $0.name.fullName < $1.name.fullName }

        if !unassigned.isEmpty {
            Section("Unassigned") {
                ForEach(unassigned, id: \.id) { member in
                    Button(member.name.fullName) {
                        Haptics.fire(.light)
                        Task { await viewModel.updateMemberTeam(member, teamID: targetTeam.id) }
                    }
                }
            }
        }
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
    @State private var lastPreset: TeamColor = .red
    @State private var useCustomColor = false
    @State private var customBaseColor = Color.red
    @State private var customBrightnessAdjust: CGFloat = 0
    @State private var isSaving = false

    @FocusState private var nameFieldFocused: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var effectiveCustomColor: Color {
        if customBrightnessAdjust > 0 {
            return customBaseColor.lighten(by: customBrightnessAdjust)
        }
        if customBrightnessAdjust < 0 {
            return customBaseColor.darken(by: -customBrightnessAdjust)
        }
        return customBaseColor
    }

    private var customChipForeground: Color {
        guard useCustomColor else { return palette.foregroundColor }
        return ColorValue(color: effectiveCustomColor).preferredContrastingLabelColor
    }

    private var customChipBackground: Color {
        useCustomColor
            ? effectiveCustomColor
            : palette.cardEmbeddedRowBackground.opacity(colorScheme == .dark ? 0.35 : 0.65)
    }

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
                    TextField("Team name", text: $name)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .focused($nameFieldFocused)
                        .borderedContentStyle(
                            isActive: nameFieldFocused,
                            theme: palette.theme,
                            fill: palette.cardEmbeddedRowBackground
                        )

                    SeriesSheetCard(palette: palette) {
                        Text("Team color".uppercased())
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(TeamColor.cycle, id: \.rawValue) { option in
                                    Button {
                                        useCustomColor = false
                                        color = option
                                        lastPreset = option
                                        Haptics.fire(.light)
                                    } label: {
                                        Chip(
                                            text: option.name,
                                            size: .small,
                                            foreground: !useCustomColor && color == option ? .white : option.value,
                                            background: !useCustomColor && color == option ? option.value : option.value.opacity(colorScheme.translucent)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    if !useCustomColor {
                                        customBaseColor = (color == .none || color == .unknown) ? TeamColor.red.value : color.value
                                        customBrightnessAdjust = 0
                                    }
                                    useCustomColor = true
                                    Haptics.fire(.light)
                                } label: {
                                    Chip(
                                        text: "Custom",
                                        size: .small,
                                        foreground: customChipForeground,
                                        background: customChipBackground
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    useCustomColor = false
                                    color = .none
                                    Haptics.fire(.light)
                                } label: {
                                    Chip(
                                        text: "None",
                                        size: .small,
                                        foreground: !useCustomColor && color == .none ? .white : palette.foregroundColor,
                                        background: !useCustomColor && color == .none
                                            ? Color.neutral4
                                            : palette.cardEmbeddedRowBackground.opacity(colorScheme == .dark ? 0.35 : 0.65)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)

                        if useCustomColor {
                            VStack(spacing: 10) {
                                SeriesSheetRow(palette: palette) {
                                    HStack {
                                        Text("Color")
                                            .fontStyle(kFontName, size: 13, weight: .semibold)
                                            .foregroundStyle(palette.foregroundColor)
                                        Spacer(minLength: 0)
                                        ColorPicker("", selection: $customBaseColor, supportsOpacity: false)
                                            .labelsHidden()
                                    }
                                }

                                SeriesSheetRow(palette: palette) {
                                    HStack {
                                        Text("Brightness")
                                            .fontStyle(kFontName, size: 13, weight: .semibold)
                                            .foregroundStyle(palette.foregroundColor)
                                        Spacer(minLength: 0)
                                        HStack(spacing: 12) {
                                            Button {
                                                customBrightnessAdjust -= 5
                                                customBrightnessAdjust = max(-100, customBrightnessAdjust)
                                                Haptics.fire(.light)
                                            } label: {
                                                Icon(name: "f056", size: 20, maxSize: 20, weight: .regular)
                                                    .foregroundStyle(customBrightnessAdjust == -100 ? Color.neutral3 : palette.foregroundColor)
                                                    .padding(4)
                                            }
                                            .buttonStyle(.plain)

                                            Text("\(Int(customBrightnessAdjust))")
                                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                                .foregroundStyle(palette.foregroundColor)
                                                .frame(minWidth: 36)

                                            Button {
                                                customBrightnessAdjust += 5
                                                customBrightnessAdjust = min(100, customBrightnessAdjust)
                                                Haptics.fire(.light)
                                            } label: {
                                                Icon(name: "f055", size: 20, maxSize: 20, weight: .regular)
                                                    .foregroundStyle(customBrightnessAdjust == 100 ? Color.neutral3 : palette.foregroundColor)
                                                    .padding(4)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                Button {
                    guard canSave else { return }
                    isSaving = true
                    let presetKey: String
                    let hexArg: String?
                    if useCustomColor {
                        presetKey = lastPreset.rawValue
                        hexArg = ColorValue(color: effectiveCustomColor).hex
                    } else if color == .none {
                        presetKey = TeamColor.none.rawValue
                        hexArg = nil
                    } else {
                        presetKey = color.rawValue
                        hexArg = nil
                    }
                    Task {
                        if let team {
                            await viewModel.updateTeam(team, name: trimmedName, presetColorKey: presetKey, customColorHex: hexArg)
                        } else {
                            _ = await viewModel.createTeam(name: trimmedName, presetColorKey: presetKey, customColorHex: hexArg)
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
            customBrightnessAdjust = 0
            if let team {
                name = team.name
                if let raw = team.customColorHex?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isPopulated {
                    useCustomColor = true
                    var h = raw
                    if !h.hasPrefix("#") { h = "#\(h)" }
                    customBaseColor = ColorValue(hex: h).color
                    let p = TeamColor(rawValue: team.color)
                    if let p, TeamColor.cycle.contains(p) {
                        lastPreset = p
                    } else {
                        lastPreset = .red
                    }
                } else {
                    useCustomColor = false
                    if team.color == TeamColor.none.rawValue {
                        color = .none
                        lastPreset = .red
                    } else if let tc = TeamColor(rawValue: team.color), TeamColor.cycle.contains(tc) {
                        color = tc
                        lastPreset = tc
                    } else {
                        lastPreset = .red
                        color = .red
                    }
                }
            } else {
                let suggestion = TeamColor.teamValue(for: viewModel.sortedTeams.count)
                name = suggestion.1
                color = suggestion.0
                lastPreset = suggestion.0
                useCustomColor = false
                customBaseColor = suggestion.0.value
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

    @FocusState private var pairLabelFocused: Bool

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
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: team.name,
                    subtitle: "Set partners in a pair for easier round structure matchups.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    if eligibleMembers.count >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Pair label")
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)
                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 12) {
                                TextField("Pair label (optional)", text: $label)
                                    .fontStyle(kFontName, size: 17, weight: .regular)
                                    .foregroundStyle(palette.foregroundColor)
                                    .focused($pairLabelFocused)

                                Spacer(minLength: 0)
                            }
                            .borderedContentStyle(isActive: pairLabelFocused, theme: palette.theme)

                            if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Defaults to A/B pairs")
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        SeriesSheetRow(palette: palette, rowBackground: Color.neutral6) {
                            selectionRow(
                                title: "First player",
                                selection: firstMemberName ?? "Choose player",
                                members: eligibleMembers,
                                selectedID: $firstMemberID
                            )
                        }

                        SeriesSheetRow(palette: palette, rowBackground: Color.neutral6) {
                            selectionRow(
                                title: "Second player",
                                selection: secondMemberName ?? "Choose player",
                                members: eligibleMembers.filter { $0.id != firstMemberID },
                                selectedID: $secondMemberID
                            )
                        }
                    } else if !existingPods.isPopulated {
                        Text("Not enough unpaired members on this team to add a pair.")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                                            Text("Used together for matchups and round structure.")
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    HStack(spacing: 12) {
                        PrimaryButton(
                            appearance: .fill,
                            title: "Cancel",
                            buttonColor: Color.neutral6,
                            fillWidth: false,
                            isDisabled: .constant(false),
                            isLoading: .constant(false),
                            onTap: { dismiss() }
                        )

                        PrimaryButton(
                            appearance: .fill,
                            title: "Save pair",
                            labelColor: .white,
                            buttonColor: Color.accentGreen,
                            fillWidth: true,
                            isDisabled: .constant(!canSave),
                            isLoading: $isSaving,
                            onTapAsync: {
                                isSaving = true
                                _ = await viewModel.createPod(
                                    teamID: team.id,
                                    memberIDs: [firstMemberID, secondMemberID],
                                    label: normalizedLabel
                                )
                                isSaving = false
                                dismiss()
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(palette.backgroundColor)
                }
            },
            theme: palette.theme,
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .onChange(of: eligibleMembers.count) { _, count in
            if count < 2 {
                firstMemberID = ""
                secondMemberID = ""
            }
        }
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
                Text(selectedID.wrappedValue.isEmpty ? "Choose" : "Change")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
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
