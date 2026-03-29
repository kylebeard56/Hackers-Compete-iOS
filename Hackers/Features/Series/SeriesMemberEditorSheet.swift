//
//  SeriesMemberEditorSheet.swift
//  Hackers
//

import SwiftUI

struct SeriesMemberEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let memberID: String

    @State private var editedName = ""
    @State private var showTeeSelection = false
    @State private var showBaselineScores = false
    @State private var overrideEnabled = false
    @State private var overrideText = ""
    @State private var isSavingName = false
    @State private var isSavingHandicap = false

    @FocusState private var nameFocused: Bool

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var member: SeriesMember? {
        viewModel.activeMembers.first { $0.id == memberID }
    }

    private var defaultCourse: SeriesCourseSelection? {
        viewModel.series.defaultCourse
    }

    private var teeChoices: [Tee] {
        viewModel.teeChoices(for: defaultCourse)
    }

    private var selectedTee: Tee? {
        guard let id = member?.defaultTeeBoxID, id.isPopulated else { return nil }
        return teeChoices.first { $0.id == id }
    }

    private var trimmedEditedName: String {
        editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameDirty: Bool {
        guard let m = member else { return false }
        return trimmedEditedName != m.name.trimmedFullName
    }

    private var canSaveName: Bool {
        viewModel.isCommissioner && trimmedEditedName.isPopulated && isNameDirty && !isSavingName
    }

    var body: some View {
        Group {
            if let m = member {
                editorContent(member: m)
            } else {
                missingMemberContent
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .task(id: defaultCourse?.courseID) {
            await viewModel.ensureTeeChoicesLoaded(for: defaultCourse)
        }
        .sheet(isPresented: $showTeeSelection) {
            if let course = defaultCourse, course.isConfigured {
                let parts = Self.partitionTees(teeChoices)
                TeeSelectionSheet(
                    selectedTee: selectedTee,
                    maleTees: parts.male,
                    femaleTees: parts.female,
                    otherTees: parts.other,
                    segment: course.holeSegment,
                    onChange: { tee in
                        showTeeSelection = false
                        if let m = member {
                            Task { await viewModel.updateMemberTeeBox(m, teeBoxID: tee.id) }
                        }
                    }
                )
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showBaselineScores) {
            if let m = member {
                SeriesBaselineScoresView(viewModel: viewModel, member: m)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var missingMemberContent: some View {
        VStack(spacing: 16) {
            SeriesSheetHeader(
                palette: palette,
                title: "Member",
                subtitle: "This player is no longer on the roster.",
                onClose: { dismiss() }
            )
            Spacer()
        }
    }

    @ViewBuilder
    private func editorContent(member: SeriesMember) -> some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Edit member",
                    subtitle: member.isOffline
                        ? "Offline roster name is stored only for this league."
                        : "League display name on the series roster (not your global profile).",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    nameSection(member: member)
                    if defaultCourse?.isConfigured == true {
                        teeSection()
                    }
                    roleSection(member: member)
                    if viewModel.hasTeams {
                        teamSection(member: member)
                    }
                    if member.teamID != nil {
                        pairSection(member: member)
                    }
                    handicapSection(member: member)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                footerBar(member: member)
            },
            theme: palette.theme,
            onScroll: { _ in }
        )
        .onAppear {
            editedName = member.name.trimmedFullName
            syncOverrideState()
        }
        .onChange(of: member.name.trimmedFullName) { _, new in
            if !nameFocused { editedName = new }
        }
        .onChange(of: viewModel.memberHandicaps[memberID]?.isOverridden) { _, _ in
            syncOverrideState()
        }
        .onChange(of: viewModel.memberHandicaps[memberID]?.overrideIndex) { _, _ in
            syncOverrideState()
        }
    }

    // MARK: - Sections

    private func nameSection(member: SeriesMember) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Name")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                TextField("First last", text: $editedName)
                    .fontStyle(kFontName, size: 17, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .textInputAutocapitalization(.words)
                    .focused($nameFocused)
                    .disabled(!viewModel.isCommissioner)

                Spacer(minLength: 0)

                if nameFocused && editedName.isPopulated && viewModel.isCommissioner {
                    ClearTextButton(theme: palette.theme) { editedName = "" }
                }
            }
            .borderedContentStyle(isActive: nameFocused, theme: palette.theme)
        }
    }

    private func teeSection() -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Default tee")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }

            TeeDropdown(
                tee: selectedTee,
                segment: defaultCourse?.holeSegment ?? .full18,
                placeholder: "Series default",
                onTap: {
                    guard viewModel.isCommissioner else { return }
                    showTeeSelection = true
                }
            )
            .disabled(!viewModel.isCommissioner)
            .opacity(viewModel.isCommissioner ? 1 : 0.55)

            if viewModel.isCommissioner, let m = member, m.defaultTeeBoxID != nil {
                Button {
                    Haptics.fire(.light)
                    Task { await viewModel.updateMemberTeeBox(m, teeBoxID: nil) }
                } label: {
                    Text("Use series default tee")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func roleSection(member: SeriesMember) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Role")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }

            Menu {
                ForEach(SeriesMemberRole.allCases, id: \.self) { role in
                    Button {
                        Haptics.fire(.light)
                        Task { await viewModel.updateMemberRole(member, role: role) }
                    } label: {
                        if role == member.role {
                            Label(roleTitle(role), systemImage: "checkmark")
                        } else {
                            Text(roleTitle(role))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(roleTitle(member.role))
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Spacer(minLength: 0)
                    Icon(name: "f078", size: 13, weight: .solid)
                        .foregroundStyle(Color.neutral3)
                }
                .borderedContentStyle(theme: palette.theme)
            }
            .disabled(!viewModel.isCommissioner)
        }
    }

    private func teamSection(member: SeriesMember) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Team")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }

            Menu {
                Button {
                    Haptics.fire(.light)
                    Task { await viewModel.updateMemberTeam(member, teamID: nil) }
                } label: {
                    if member.teamID == nil {
                        Label("Unassigned", systemImage: "checkmark")
                    } else {
                        Text("Unassigned")
                    }
                }

                ForEach(viewModel.sortedTeams, id: \.id) { team in
                    Button {
                        Haptics.fire(.light)
                        Task { await viewModel.updateMemberTeam(member, teamID: team.id) }
                    } label: {
                        if member.teamID == team.id {
                            Label(team.name, systemImage: "checkmark")
                        } else {
                            Text(team.name)
                        }
                    }
                }
            } label: {
                HStack {
                    if let tid = member.teamID, let team = viewModel.teams.first(where: { $0.id == tid }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(team.swatchColor)
                                .frame(width: 12, height: 12)
                            Text(team.name)
                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                        }
                    } else {
                        Text("Unassigned")
                            .fontStyle(kFontName, size: 15, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    Spacer(minLength: 0)
                    Icon(name: "f078", size: 13, weight: .solid)
                        .foregroundStyle(Color.neutral3)
                }
                .borderedContentStyle(theme: palette.theme)
            }
            .disabled(!viewModel.isCommissioner)
        }
    }

    private func pairSection(member: SeriesMember) -> some View {
        let teammates = viewModel.activeMembers.filter { $0.teamID == member.teamID && $0.id != member.id }
        let currentPod = viewModel.pods.first { $0.isActive && $0.memberIDs.contains(member.id) }
        let partnerID = currentPod?.memberIDs.first { $0 != member.id }
        let partnerName = partnerID.flatMap { id in teammates.first { $0.id == id }?.name.fullName }

        return VStack(spacing: 8) {
            HStack {
                Text("Fixed pair")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer(minLength: 0)
            }

            Text("Optional twosome for pod-aligned tee groups within this team.")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                HStack {
                    if let partnerName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(partnerName)
                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                            if let pod = currentPod {
                                Text("Label: \(pod.resolvedLabel)")
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }
                        }
                    } else {
                        Text(teammates.isEmpty ? "No teammates on this team" : "Choose partner")
                            .fontStyle(kFontName, size: 15, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    Spacer(minLength: 0)
                    Icon(name: "f078", size: 13, weight: .solid)
                        .foregroundStyle(Color.neutral3)
                }
                .borderedContentStyle(theme: palette.theme)
            }
            .disabled(!viewModel.isCommissioner || teammates.isEmpty)
        }
    }

    private func handicapSection(member: SeriesMember) -> some View {
        let hc = viewModel.memberHandicaps[member.id]
        let enabled = viewModel.series.handicapConfig.isEnabled

        return SeriesSheetCard(palette: palette) {
            Text("Handicap".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !enabled {
                Text("League handicaps are off. Turn them on in league settings to track baselines and indexes.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let eff = viewModel.effectiveHandicap(for: member.id) {
                        Text("Effective index: \(String(format: "%.1f", eff))")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                    } else {
                        Text("Effective index: --")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                    }

                    if let computed = hc?.computedIndex {
                        Text("Computed: \(String(format: "%.1f", computed))")
                            .fontStyle(kFontName, size: 12, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    if hc?.isOverridden == true, let o = hc?.overrideIndex {
                        Text("Override: \(String(format: "%.1f", o))")
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(Color.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isCommissioner {
                    Button {
                        Haptics.fire(.light)
                        showBaselineScores = true
                    } label: {
                        Text("Baseline scores")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(palette.cardEmbeddedRowBackground.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Text("Commissioner override")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Spacer(minLength: 0)
                        Toggle("", isOn: $overrideEnabled)
                            .labelsHidden()
                            .tint(.orange)
                            .onChange(of: overrideEnabled) { _, on in
                                if !on {
                                    Task {
                                        await viewModel.setHandicapOverride(
                                            memberID: member.id,
                                            value: nil,
                                            isOverridden: false
                                        )
                                    }
                                }
                            }
                    }

                    if overrideEnabled {
                        TextField("Index", text: $overrideText)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.orange)
                            .keyboardType(.decimalPad)
                            .mutedGlassTextFieldContainer(cornerRadius: 14, baseFill: palette.cardEmbeddedRowBackground)

                        Button {
                            Task {
                                isSavingHandicap = true
                                let value = Double(overrideText.trimmingCharacters(in: .whitespaces))
                                await viewModel.setHandicapOverride(
                                    memberID: member.id,
                                    value: value,
                                    isOverridden: value != nil
                                )
                                isSavingHandicap = false
                            }
                        } label: {
                            Text(isSavingHandicap ? "Saving…" : "Save override")
                                .fontStyle(kFontName, size: 15, weight: .semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(overrideSaveEnabled ? Color.accentGreen : Color.neutral3)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!overrideSaveEnabled || isSavingHandicap)
                    }
                }
            }
        }
    }

    private var overrideSaveEnabled: Bool {
        Double(overrideText.trimmingCharacters(in: .whitespaces)) != nil
    }

    @ViewBuilder
    private func footerBar(member: SeriesMember) -> some View {
        VStack(spacing: 12) {
            if viewModel.isCommissioner, canSaveName {
                Button {
                    isSavingName = true
                    Task {
                        await viewModel.updateMemberDisplayName(member, fullName: trimmedEditedName)
                        isSavingName = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSavingName {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSavingName ? "Saving…" : "Save name")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSavingName)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(palette.foregroundColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.backgroundColor)
    }

    private func syncOverrideState() {
        let hc = viewModel.memberHandicaps[memberID]
        overrideEnabled = hc?.isOverridden == true
        if let o = hc?.overrideIndex {
            overrideText = String(format: "%.1f", o)
        } else {
            overrideText = ""
        }
    }

    private func roleTitle(_ role: SeriesMemberRole) -> String {
        switch role {
        case .commissioner: return "Commissioner"
        case .captain: return "Captain"
        case .member: return "Member"
        case .spectator: return "Spectator"
        }
    }

    private static func partitionTees(_ tees: [Tee]) -> (male: [Tee], female: [Tee], other: [Tee]) {
        var male: [Tee] = []
        var female: [Tee] = []
        var other: [Tee] = []
        for tee in tees {
            switch Gender(rawValue: tee.gender) {
            case .some(.male):
                male.append(tee)
            case .some(.female):
                female.append(tee)
            case .some(.unknown), .none:
                other.append(tee)
            }
        }
        return (male, female, other)
    }
}
