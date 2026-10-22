//
//  ManagePlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/12/25.
//

import AlertToast
import SwiftUI

struct ManagePlayerView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @StateObject var roundSession: RoundSession

    /// When true and user is not a series commissioner, strokes are read-only in the sheet.
    let seriesHandicapLockActive: Bool
    let isSeriesCommissioner: Bool
    let canTransferHost: Bool
    let seriesHandicapMaximum: Int?
    let approvalUserID: String?

    var snapshot: RoundSnapshot { roundSession.snapshot }
    @State var participant: RoundParticipant?

    init(
        roundSession: RoundSession,
        participant: RoundParticipant,
        seriesHandicapLockActive: Bool = false,
        isSeriesCommissioner: Bool = false,
        canTransferHost: Bool = false,
        seriesHandicapMaximum: Int? = nil,
        approvalUserID: String? = nil
    ) {
        _roundSession = StateObject(wrappedValue: roundSession)
        _participant = State(initialValue: participant)
        self.seriesHandicapLockActive = seriesHandicapLockActive
        self.isSeriesCommissioner = isSeriesCommissioner
        self.canTransferHost = canTransferHost
        self.seriesHandicapMaximum = seriesHandicapMaximum
        self.approvalUserID = approvalUserID
    }
    
    @State private var name = ""
    @State private var tee: Tee? = nil
    @State private var showTeeSelection = false
    @State private var handicapDraft = RoundHandicapEntryDraft()
    private var handicapString: String {
        get { handicapDraft.text }
        nonmutating set { handicapDraft.text = newValue }
    }
    private var handicapValue: Double { handicapDraft.value ?? 0 }
    @State private var hasConfirmedHandicapOverride = false
    @State private var showHandicapOverrideAlert = false
    private var indexBasis: SeriesHandicapStrokeBasis? {
        if !snapshot.round.status.allowsCourseHandicapSetupEdits {
            return participant?.handicapResolution?.calculation?.indexBasis ?? snapshot.handicapIndexBasis
        }
        return HandicapCalculator.entryIndexBasis(for: participant ?? .init(), configured: snapshot.handicapIndexBasis)
    }
    @State private var estimateApproved = false
    @State private var showCourseData = false
    @State private var groupID: String? = nil
    @State private var teamID: String? = nil
    
    @State private var showHostChangeSheet = false
    private var isHost: Bool { participant?.isHost ?? false }
    
    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    
    @FocusState private var focus: FocusField?
    private enum FocusField { case name, handicap }
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var mayEditHandicapInput: Bool {
        snapshot.round.status.allowsCourseHandicapSetupEdits || (seriesHandicapLockActive && isSeriesCommissioner)
    }
    private var canSave: Bool {
        name.isPopulated && tee.exists && (!mayEditHandicapInput || strokesHandicapReadOnly || HandicapCalculator.isValidDraft(handicapString, format: effectiveHandicapEntryFormat))
    }

    private var strokesHandicapReadOnly: Bool {
        seriesHandicapLockActive && !isSeriesCommissioner
    }

    private var leagueHandicapBaseline: Int? {
        participant?.leagueHandicapComputedBaseline
    }

    private var isRoundHandicapOverridden: Bool {
        guard seriesHandicapLockActive, let leagueHandicapBaseline else { return false }
        return Int(handicapValue.rounded()) != leagueHandicapBaseline
    }

    private var effectiveHandicapEntryFormat: HandicapEntryFormat {
        seriesHandicapLockActive ? .strokes : handicapDraft.format
    }

    private var commissionerStrokesValueColor: Color {
        guard seriesHandicapLockActive, isSeriesCommissioner,
              let baseline = leagueHandicapBaseline else {
            return palette.foregroundColor
        }
        return Int(handicapValue.rounded()) != baseline ? Color.orange : palette.foregroundColor
    }

    private var maximumHandicapValue: Int {
        seriesHandicapLockActive ? (seriesHandicapMaximum ?? 36) : 36
    }
    
    private var maximumStrokeAllowance: Int? {
        if seriesHandicapLockActive,
           snapshot.configuration.handicapEntryFormat == .courseHandicap || participant?.handicapSnapshot?.entryFormat == .courseHandicap {
            return nil
        }
        return maximumHandicapValue
    }

    private var strokeLimitLabel: String {
        maximumStrokeAllowance.map { "Max: \($0)" } ?? "Strokes this round"
    }

    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            theme: palette.theme,
            onScroll: { _ in }
        )
        .resignKeyboardOnTapGesture()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focus != nil { HandicapKeyboardDismissBar { focus = nil } }
        }
        .sheet(isPresented: $showTeeSelection) {
            TeeSelectionSheet(
                selectedTee: tee,
                maleTees: snapshot.course?.tees.male ?? [],
                femaleTees: snapshot.course?.tees.female ?? [],
                otherTees: snapshot.course?.tees.other ?? [],
                segment: snapshot.holeSegment,
                onChange: { t in
                    showTeeSelection = false
                    tee.toggle(to: t)
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCourseData) {
            CourseSelectionView(
                viewModel: .init(course: snapshot.course, tee: tee, holeSegment: snapshot.holeSegment),
                presentationType: .sheet,
                onModification: { segment in
                    Task {
                        await roundSession.setCourseSegment(to: segment)
                        tee = segment.defaultTee.flatMap { segment.tee(from: $0) }
                        showCourseData = false
                    }
                },
                onRemoveModification: { }
            )
        }
        .onChange(of: courseHandicapCalculation) { estimateApproved = false }
        .onChange(of: snapshot.round.status) {
            if !snapshot.round.status.allowsCourseHandicapSetupEdits {
                showTeeSelection = false
                showCourseData = false
            }
        }
        .sheet(isPresented: $showHostChangeSheet) {
            ChangeHostView(snapshot: snapshot) { newHost in
                Task {
                    do {
                        try await roundSession.changeHost(to: newHost)
                        showHostChangeSheet = false
                        participant = snapshot.participants.first(where: { $0.id == participant?.id })
                    } catch {
                        // TODO: Handle error
                    }
                }
            }
        }
        .task {
            name = participant?.name.fullName ?? ""
            tee = snapshot.tees.first(where: { $0.id == participant?.teeBoxID }) ?? snapshot.defaultTee
            handicapDraft = RoundHandicapEntryDraft(participant: participant ?? .init(),
                defaultFormat: seriesHandicapLockActive ? .strokes : snapshot.configuration.handicapEntryFormat)
            if seriesHandicapLockActive {
                handicapDraft.format = .strokes
                handicapDraft.strokesText = String(participant?.adjustedHandicap ?? 0)
            }
            groupID = participant?.groupID
            teamID = participant?.teamID
            
        }
        .alert(
            "Are you sure you want to remove \(participant?.name.fullName ?? "this player") from this round?",
            isPresented: $showRemoveAlert
        ) {
            Button("Yes, remove", role: .destructive) {
                isRemoving = true
                if let participant { onRemove(participant) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Override handicap?", isPresented: $showHandicapOverrideAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Override handicap", action: confirmHandicapOverride)
        } message: {
            Text("This changes the strokes used for this round only. The league-computed value remains available to restore.")
        }
    }
}

// MARK: - Content

extension ManagePlayerView {
    private var content: some View {
        VStack(spacing: 16) {
            nameSection
            teeBoxSection.disabled(!snapshot.round.status.allowsCourseHandicapSetupEdits)
            teeGroupSection
            if snapshot.requiresTeams {
                teamSection
            }
            strokesSection.disabled(!mayEditHandicapInput)
            if !snapshot.round.status.allowsCourseHandicapSetupEdits {
                Text(mayEditHandicapInput ? "Course and tees are locked. League overrides apply only to this round." : "Course, tees and handicap inputs are locked after the round starts.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
    
    private var nameSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Name")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 12) {
                TextField("First last", text: $name)
                    .fontStyle(kFontName, size: 17, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .textInputAutocapitalization(.words)
                    .focused($focus, equals: .name)
                
                Spacer(minLength: 0)
                
                if focus == .name && name.isPopulated {
                    ClearTextButton(theme: palette.theme, onTap: { name = "" })
                }
            }
            .borderedContentStyle(isActive: focus == .name, theme: palette.theme)
            
            Text("Name changes are applied to only this round.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var teeBoxSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Tee Box")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
            }

            TeeDropdown(
                tee: tee,
                segment: snapshot.holeSegment,
                onTap: { showTeeSelection = true }
            )
        }
    }
    
    private var teeGroupSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Tee Group")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
            }
            
            teeGroupDropdown
        }
    }
    
    private var teamSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Team")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
            }
            
            teamDropdown
        }
    }
    
    private var strokesSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(effectiveHandicapEntryFormat == .courseHandicap
                     ? RoundHandicapEntryPresentation.indexLabel(handicapComputationParticipant, basis: indexBasis)
                     : "Strokes this round")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)
            }

            if !seriesHandicapLockActive {
                if snapshot.configuration.handicapEntryFormat == .courseHandicap {
                    HandicapEntryModePicker(selection: Binding(
                        get: { handicapDraft.format },
                        set: { handicapDraft.format = $0; focus = nil }
                    ))
                }
                if effectiveHandicapEntryFormat == .strokes {
                    if let index = Double(handicapDraft.indexText) {
                        Text("Handicap Index: \(ManualPersonalHandicap.display(index)) · preserved")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }
                    if let value = handicapDraft.value {
                        Text("Strokes Received: \(min(Int(value), maximumHandicapValue))")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                    }
                    Text("Whole-number strokes for this round only. Saved personal and league Indexes are unchanged.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                if handicapDraft.value == nil {
                    Text(effectiveHandicapEntryFormat == .courseHandicap ? "Enter an Index to one decimal place." : "Enter a whole-number stroke allowance.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            if strokesHandicapReadOnly {
                HStack(spacing: 10) {
                    Text("\(computedHandicapValue)")
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.neutral3)
                    Spacer(minLength: 0)
                    Text(strokeLimitLabel)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.cardEmbeddedRowBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Handicap comes from the league. A commissioner can override it for this round.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            } else if seriesHandicapLockActive && !isRoundHandicapOverridden && !hasConfirmedHandicapOverride {
                Button(action: requestHandicapOverride) {
                    HStack(spacing: 10) {
                        Text("\(computedHandicapValue)")
                            .fontStyle(kFontName, size: 17, weight: .regular)
                            .foregroundStyle(Color.neutral3)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.neutral3)
                        Spacer(minLength: 0)
                        Text(strokeLimitLabel)
                            .fontStyle(kFontName, size: 15, weight: .regular)
                            .foregroundStyle(Color.neutral3)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(palette.cardEmbeddedRowBackground.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Handicap \(computedHandicapValue), league locked")
                .accessibilityHint("Double tap to override the handicap for this round")
            } else {
                HStack(spacing: 12) {
                    TextField(effectiveHandicapEntryFormat == .courseHandicap ? "Index" : "Strokes", text: Binding(get: { handicapString }, set: { handicapString = $0 }))
                        .accessibilityLabel(effectiveHandicapEntryFormat.displayName)
                        .accessibilityIdentifier("managePlayerHandicapInput")
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .foregroundStyle(commissionerStrokesValueColor)
                        .keyboardType(effectiveHandicapEntryFormat == .courseHandicap ? .numbersAndPunctuation : .numberPad)
                        .focused($focus, equals: .handicap)

                    if seriesHandicapLockActive {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isRoundHandicapOverridden ? Color.orange : Color.neutral3)
                            .accessibilityHidden(true)
                    }

                    Spacer(minLength: 0)

                    if focus == .handicap && handicapString.isPopulated {
                        ClearTextButton(theme: palette.theme, onTap: { handicapString = "" })
                    }

                    if seriesHandicapLockActive && isRoundHandicapOverridden {
                        Button("Use computed value", systemImage: "arrow.uturn.backward", action: revertHandicapOverride)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color.orange)
                            .frame(width: 44, height: 44)
                            .accessibilityHint("Restores the league-computed handicap for this round")
                    }

                    Text(effectiveHandicapEntryFormat == .courseHandicap ? "Handicap Index" : strokeLimitLabel)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral3)
                }
                .borderedContentStyle(isActive: focus == .handicap, theme: palette.theme)

            }

            if effectiveHandicapEntryFormat == .courseHandicap {
                if let input = participant?.personalHandicapInput {
                    Text("Profile Index: \(ManualPersonalHandicap.display(input.index)) · \(input.source == .calculated ? "Hackers calculated" : "Manual starting"). Changes here apply only to this round.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                CourseHandicapStatusView(
                    calculation: courseHandicapCalculation,
                    strokes: courseHandicapCalculation.allowedStrokes(maximum: maximumHandicapValue, estimateApproved: estimateIsApproved),
                    estimateApproved: estimateIsApproved,
                    onUseEstimate: { estimateApproved = true },
                    onFixCourseData: { showCourseData = true },
                    onEnterStrokes: {
                        handicapDraft.format = .strokes
                        focus = .handicap
                    }
                )
            }

            if !snapshot.configuration.useHandicaps {
                Text("Net scoring using handicap is not enabled yet for this round, but you can still enter a value.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.leading)
                    .alignLeading()

                // TODO: Shortcut toggle to use handicaps here?
            }
        }
    }
}

extension ManagePlayerView {
    fileprivate func onFinish(_ p: RoundParticipant) {
        Task {
            // TODO: handle error display here before dismissing?
            try? await roundSession.update(participant: p)
            dismiss()
        }
    }
    
    fileprivate func onRemove(_ p: RoundParticipant) {
        Task {
            // TODO: handle error display here before dismissing?
            try? await roundSession.remove(participant: p)
            dismiss()
        }
    }
}

extension ManagePlayerView {
    fileprivate var teeGroupDropdown: some View {
        Menu {
            ForEach(snapshot.teeGroups.sortedForGameLobbyDisplay()) { group in
                Button {
                    Haptics.fire(.light)
                    groupID = group.id
                } label: {
                    if group.id == groupID {
                        Label(group.name, systemImage: "checkmark")
                    } else {
                        Text(group.name)
                    }
                }
            }
        } label: {
            HStack {
                if let groupID, let group = snapshot.teeGroups.first(where: { $0.id == groupID }) {
                    let startingHoleLabel = group.startingHoleDisplayLabel(in: snapshot.teeGroups)
                    VStack(spacing: 4) {
                        Text(group.name)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()
                        
                        HStack {
                            Text("Starting on Hole \(startingHoleLabel)")
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)
                            
                            if let teeTime = group.teeTime {
                                Dot()
                                
                                Text(teeTime.formattedTeeTime)
                                    .fontStyle(kFontName, size: 14, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                } else {
                    Text("Select tee time group")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
                
                Icon(name: "f078", size: 13, weight: .solid)
                    .foregroundStyle(Color.neutral3)
            }
            .borderedContentStyle(theme: palette.theme)
        }
    }
    
    fileprivate var teamDropdown: some View {
        Menu {
            ForEach(snapshot.teams.sortedForGameLobbyDisplay()) { team in
                Button {
                    Haptics.fire(.light)
                    teamID = team.id
                } label: {
                    if team.id == teamID {
                        Label(team.name, systemImage: "checkmark")
                    } else {
                        Text(team.name)
                    }
                }
            }
        } label: {
            HStack {
                if let teamID, let team = snapshot.teams.first(where: { $0.id == teamID }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(team.displaySwatchColor ?? Color.neutral6)
                            .frame(width: 12, height: 12)
                        
                        Text(team.name)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()
                        
                        // [FUTURE] TODO: Add other plays on the team here?
                    }
                } else {
                    Text("Select team")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)
                
                Icon(name: "f078", size: 13, weight: .solid)
                    .foregroundStyle(Color.neutral3)
            }
            .borderedContentStyle(theme: palette.theme)
        }
    }
}

// MARK: - Header

extension ManagePlayerView {
    fileprivate var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Edit player")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", theme: palette.theme, onTap: { dismiss() })
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
}

// MARK: - Footer

extension ManagePlayerView {
    
    @ViewBuilder
    fileprivate var footer: some View {
        if focus.exists {
            EmptyView()
        } else {
            VStack(spacing: 16) {
                Line()
                
                HStack(spacing: 12) {
                    if !isHost || canTransferHost {
                        PrimaryButton(
                            appearance: .fill,
                            title: isHost ? "Change host" : "Remove",
                            labelColor: isHost ? palette.foregroundColor : .white,
                            buttonColor: isHost ? palette.buttonColor : .systemError,
                            theme: palette.theme,
                            fillWidth: false,
                            isDisabled: .false,
                            isLoading: $isRemoving,
                            onTap: {
                                if isHost {
                                    showHostChangeSheet = true
                                } else {
                                    showRemoveAlert = true
                                }
                            }
                        )
                    }
                    
                    PrimaryButton(
                        appearance: .fill,
                        title: "Update player",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .constant(!canSave),
                        isLoading: .false,
                        onTap: finish
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func finish() {
        var p = participant ?? .init()
        p.name = Name(name)
        if snapshot.round.status.allowsCourseHandicapSetupEdits { p.teeBoxID = tee?.id ?? "" }
        if seriesHandicapLockActive && isSeriesCommissioner {
            if Int(handicapValue.rounded()) != p.lockedHandicapAllowance {
                p = p.applyingLeagueHandicapOverride(
                    Int(handicapValue.rounded()), maximum: maximumStrokeAllowance
                )
            }
        } else if !seriesHandicapLockActive && snapshot.round.status.allowsCourseHandicapSetupEdits {
            p = handicapDraft.applying(to: p, courseSegment: participantCourseSegment,
                indexBasis: indexBasis, maximum: maximumHandicapValue, approveEstimate: estimateIsApproved, approvedBy: approvalUserID)
        }
        p.groupID = groupID
        p.teamID = teamID
        onFinish(p)
    }

    private var participantCourseSegment: CourseSegment? {
        guard var segment = snapshot.courseSegment else { return nil }
        if let teeID = tee?.id {
            segment.defaultTee = teeID
        }
        return segment
    }

    private var computedHandicapValue: Int {
        HandicapCalculator.strokes(
            for: handicapValue,
            format: effectiveHandicapEntryFormat,
            participant: handicapComputationParticipant,
            courseSegment: participantCourseSegment,
            maximumHandicap: maximumStrokeAllowance,
            handicapStrokeBasis: snapshot.handicapIndexBasis
        ) ?? participant?.adjustedHandicap ?? 0
    }

    private var courseHandicapCalculation: CourseHandicapCalculation {
        HandicapCalculator.calculation(
            index: Double(handicapDraft.indexText), participant: handicapComputationParticipant,
            courseSegment: participantCourseSegment, indexBasis: indexBasis
        )
    }

    private var estimateIsApproved: Bool {
        estimateApproved || (participant?.handicapResolution?.calculation == courseHandicapCalculation
            && participant?.handicapResolution?.estimateApprovedAt != nil)
    }

    private var handicapComputationParticipant: RoundParticipant {
        var p = participant ?? .init()
        p.teeBoxID = tee?.id ?? p.teeBoxID
        p.handicapIndex = Double(handicapDraft.indexText)
        return p
    }

    private func requestHandicapOverride() {
        showHandicapOverrideAlert = true
    }

    private func confirmHandicapOverride() {
        hasConfirmedHandicapOverride = true
        focus = .handicap
    }

    private func revertHandicapOverride() {
        guard let updated = participant?.restoringLeagueHandicapComputedBaseline(),
              let baseline = updated.leagueHandicapComputedBaseline else { return }
        handicapString = String(baseline)
        hasConfirmedHandicapOverride = false
        focus = nil

        Task {
            do {
                try await roundSession.update(participant: updated)
                participant = updated
            } catch {
                addBreadcrumb(level: .error, message: "Failed to restore computed handicap", error: error)
            }
        }
    }

}

#Preview {
    Color.neutral
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: .true) {
            ManagePlayerView(roundSession: .init(), participant: .init())
                .presentationDragIndicator(.visible)
        }
}
