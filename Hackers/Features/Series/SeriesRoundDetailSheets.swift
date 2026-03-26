//
//  SeriesRoundDetailSheets.swift
//  Hackers
//

import SwiftUI

struct SeriesRoundAwardsDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    @State private var showCorrectionSheet = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Round Awards",
                subtitle: seriesRound.title.isEmpty ? "Round \(seriesRound.index + 1)" : seriesRound.title,
                onClose: { dismiss() }
            ) {
                if viewModel.isCommissioner, seriesRound.roundID != nil {
                    Button {
                        showCorrectionSheet = true
                    } label: {
                        Chip(
                            text: "Correct",
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: Color.neutral6
                        )
                    }
                    .buttonStyle(.plain)
                }

                if seriesRound.roundID != nil {
                    Button {
                        Task { _ = await viewModel.exportCSV(for: seriesRound) }
                    } label: {
                        Chip(
                            text: "Export CSV",
                            size: .xSmall,
                            foreground: palette.foregroundColor,
                            background: Color.neutral6
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    summarySection

                    awardsSection(
                        title: "Team Awards",
                        subtitle: "Weekly team points from this round.",
                        awards: viewModel.pointAwards(for: seriesRound, track: .team)
                    )

                    awardsSection(
                        title: "Individual Awards",
                        subtitle: "Weekly individual points from this round.",
                        awards: viewModel.pointAwards(for: seriesRound, track: .individual)
                    )

                    Spacer(minLength: 0)
                        .frame(height: 24)
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showCorrectionSheet) {
            SeriesRoundScoreCorrectionSheet(viewModel: viewModel, seriesRound: seriesRound)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(seriesRound.title.isEmpty ? "Round \(seriesRound.index + 1)" : seriesRound.title)
                .fontStyle(kFontName, size: 22, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            HStack(spacing: 8) {
                statusChip(
                    title: viewModel.effectiveStatus(for: seriesRound).rawValue.capitalized,
                    tint: statusTint(for: viewModel.effectiveStatus(for: seriesRound))
                )

                statusChip(
                    title: seriesRound.awardsStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    tint: seriesRound.awardsStatus == .finalized ? .accentGreen : .systemBlue
                )

                if seriesRound.isAdjusted {
                    statusChip(title: "Adjusted", tint: .orange)
                }
            }

            if let scheduledAt = seriesRound.scheduledAt {
                Text(Date(timeIntervalSince1970: scheduledAt.unix).formatted(date: .abbreviated, time: .shortened))
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral)
            }

            Text(seriesRound.resolvedCourse(using: viewModel.series)?.cachedName ?? "Course TBD")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.accentGreen)

            if let reason = seriesRound.lastScoreAdjustmentReason, reason.isPopulated {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest adjustment")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    Text(reason)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.neutral6)
                .cornerRadius(14)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func awardsSection(title: String, subtitle: String, awards: [SeriesPointAward]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text(subtitle)
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            if awards.isEmpty {
                Text("No awards published for this track yet.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(awards, id: \.id) { award in
                        HStack(spacing: 12) {
                            Chip(
                                text: award.placement.map { "#\($0)" } ?? "TBD",
                                size: .xSmall,
                                foreground: palette.foregroundColor,
                                background: Color.neutral6
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(award.competitorName)
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)

                                Text(award.reason?.isPopulated == true ? award.reason! : award.source.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }

                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: "%.1f pts", award.totalPoints))
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(Color.accentGreen)

                                if award.tieGroupSize ?? 1 > 1 {
                                    Text("Tie x\(award.tieGroupSize ?? 1)")
                                        .fontStyle(kFontName, size: 11, weight: .medium)
                                        .foregroundStyle(Color.neutral2)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.neutral6)
                        .cornerRadius(16)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func statusTint(for status: SeriesRoundStatus) -> Color {
        switch status {
        case .planned: return .neutral
        case .lobby, .live: return .accentGreen
        case .complete: return .systemBlue
        case .canceled: return .systemError
        }
    }

    private func statusChip(title: String, tint: Color) -> some View {
        Chip(
            text: title,
            size: .xSmall,
            foreground: tint,
            background: tint.opacity(colorScheme.translucent * 0.85)
        )
    }
}

struct SeriesRoundScoreCorrectionSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound

    @State private var context: SeriesRoundCorrectionContext?
    @State private var selectedParticipantID: String = ""
    @State private var draftScores: [String: Int] = [:]
    @State private var reason: String = ""

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Correct Scores",
                subtitle: "Commissioner adjustments keep the round signed and complete.",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let context {
                        overviewSection(context: context)
                        participantSelector(context: context)
                        scoreEditorSection(context: context)
                        reasonSection
                        actionSection
                    } else if viewModel.correctingRoundID == seriesRound.id {
                        ProgressView()
                            .tint(Color.accentGreen)
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        unavailableSection
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .task {
            guard context == nil else { return }
            context = await viewModel.loadCorrectionContext(for: seriesRound)
            selectedParticipantID = context?.snapshot.participants.first?.id ?? ""
        }
    }

    private func overviewSection(context: SeriesRoundCorrectionContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Chip(
                    text: "Signed round stays complete",
                    size: .xSmall,
                    foreground: Color.accentGreen,
                    background: Color.accentGreen.opacity(colorScheme.translucent)
                )
                if seriesRound.isAdjusted {
                    Chip(
                        text: "Adjusted \(seriesRound.scoreAdjustmentCount)x",
                        size: .xSmall,
                        foreground: .orange,
                        background: Color.orange.opacity(colorScheme.translucent)
                    )
                }
            }

            Text("Commissioner corrections update the linked round’s scores, then rebuild league awards, standings, handicaps, and CSV exports.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)

            Text(seriesRound.title.isEmpty ? "Round \(seriesRound.index + 1)" : seriesRound.title)
                .fontStyle(kFontName, size: 18, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func participantSelector(context: SeriesRoundCorrectionContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Player".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(context.snapshot.participants, id: \.id) { participant in
                        Button {
                            Haptics.fire(.light)
                            selectedParticipantID = participant.id
                        } label: {
                            Chip(
                                text: participant.name.fullName,
                                size: .xSmall,
                                foreground: selectedParticipantID == participant.id ? .white : palette.foregroundColor,
                                background: selectedParticipantID == participant.id ? .accentGreen : Color.neutral6
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func scoreEditorSection(context: SeriesRoundCorrectionContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hole-By-Hole".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            if let participant = context.snapshot.participants.first(where: { $0.id == selectedParticipantID }) {
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                VStack(spacing: 10) {
                    ForEach(context.holes, id: \.number) { hole in
                        scoreRow(participant: participant, hole: hole, context: context)
                    }
                }
            } else {
                Text("Choose a player to edit.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func scoreRow(
        participant: RoundParticipant,
        hole: Hole,
        context: SeriesRoundCorrectionContext
    ) -> some View {
        let score = displayedScore(
            participantID: participant.id,
            holeNumber: hole.number,
            context: context
        )
        let original = context.entriesByParticipantID[participant.id]?[hole.number]?.strokes

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hole \(hole.number)")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text("Par \(hole.par)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                scoreActionChip(title: "-", tint: Color.neutral3) {
                    adjustScore(participantID: participant.id, hole: hole, delta: -1, context: context)
                }

                Text(score.map(String.init) ?? "—")
                    .fontStyle(.system, size: 17, weight: .semibold, design: .rounded)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 42)

                scoreActionChip(title: "+", tint: Color.accentGreen) {
                    adjustScore(participantID: participant.id, hole: hole, delta: 1, context: context)
                }

                scoreActionChip(title: "Clear", tint: Color.systemError) {
                    setDraftScore(nil, participantID: participant.id, holeNumber: hole.number)
                }
            }

            if score != original {
                Chip(
                    text: "Edited",
                    size: .tiny,
                    foreground: .orange,
                    background: Color.orange.opacity(colorScheme.translucent)
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.neutral6)
        .cornerRadius(16)
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjustment Note".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text("Add a short note so the correction is visible in league history.")
                .fontStyle(kFontName, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)

            TextField("Example: Hole 7 was entered as 6 instead of 5.", text: $reason, axis: .vertical)
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.neutral6)
                .cornerRadius(16)
                .lineLimit(2...4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
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
                Task {
                    guard let context else { return }
                    let didSave = await viewModel.applyScoreCorrections(
                        for: context.seriesRound,
                        changes: pendingChanges(context: context),
                        reason: reason
                    )
                    if didSave {
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if viewModel.correctingRoundID == seriesRound.id {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Text("Save & Recompute")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .background(pendingChanges(context: context ?? emptyContext).isEmpty || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.neutral3 : Color.accentGreen)
                .clipShape(Capsule())
            }
            .disabled((context.map { pendingChanges(context: $0).isEmpty } ?? true) || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.correctingRoundID == seriesRound.id)
            .buttonStyle(.plain)
        }
    }

    private var unavailableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scores unavailable")
                .fontStyle(kFontName, size: 18, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Text("We couldn’t load the linked round scores for this league round.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private var emptyContext: SeriesRoundCorrectionContext {
        .init(seriesRound: seriesRound, snapshot: .init(), holes: [], entriesByParticipantID: [:])
    }

    private func scoreActionChip(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(
                text: title,
                size: .xSmall,
                foreground: title == "Clear" ? tint : palette.foregroundColor,
                background: title == "Clear" ? tint.opacity(colorScheme.translucent) : Color.neutral6
            )
        }
        .buttonStyle(.plain)
    }

    private func draftKey(participantID: String, holeNumber: Int) -> String {
        "\(participantID)_\(holeNumber)"
    }

    private func displayedScore(
        participantID: String,
        holeNumber: Int,
        context: SeriesRoundCorrectionContext
    ) -> Int? {
        let key = draftKey(participantID: participantID, holeNumber: holeNumber)
        if let draftValue = draftScores[key] {
            return draftValue == 0 ? nil : draftValue
        }
        return context.entriesByParticipantID[participantID]?[holeNumber]?.strokes
    }

    private func setDraftScore(_ strokes: Int?, participantID: String, holeNumber: Int) {
        let key = draftKey(participantID: participantID, holeNumber: holeNumber)
        draftScores[key] = strokes ?? 0
    }

    private func adjustScore(
        participantID: String,
        hole: Hole,
        delta: Int,
        context: SeriesRoundCorrectionContext
    ) {
        let current = displayedScore(
            participantID: participantID,
            holeNumber: hole.number,
            context: context
        ) ?? hole.par
        let nextValue = max(1, min(15, current + delta))
        setDraftScore(nextValue, participantID: participantID, holeNumber: hole.number)
    }

    private func pendingChanges(context: SeriesRoundCorrectionContext) -> [SeriesScoreCorrectionChange] {
        context.snapshot.participants.flatMap { participant in
            context.holes.compactMap { hole in
                let original = context.entriesByParticipantID[participant.id]?[hole.number]?.strokes
                let updated = displayedScore(
                    participantID: participant.id,
                    holeNumber: hole.number,
                    context: context
                )
                guard updated != original else { return nil }
                return SeriesScoreCorrectionChange(
                    participantID: participant.id,
                    holeNumber: hole.number,
                    strokes: updated
                )
            }
        }
    }
}

struct SeriesSheetCard<Content: View>: View {
    let palette: DesignPalette
    let content: Content

    init(
        palette: DesignPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.borderColor.opacity(0.45), lineWidth: 1)
        )
    }
}

struct SeriesSheetRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.neutral6)
            .cornerRadius(16)
    }
}

struct SeriesSheetHeader<Actions: View>: View {
    let palette: DesignPalette
    let title: String
    let subtitle: String?
    let onClose: Callback?
    let actions: Actions

    init(
        palette: DesignPalette,
        title: String,
        subtitle: String? = nil,
        onClose: Callback? = nil,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.palette = palette
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                if let subtitle, subtitle.isPopulated {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                actions

                if let onClose {
                    NavButton(
                        style: .glass,
                        icon: "f00d",
                        color: palette.foregroundColor,
                        onTap: onClose
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct SeriesScoringProfileEditorSeed: Identifiable {
    let id = UUID()
    let title: String
    let competitorType: SeriesCompetitorType
    let kind: SeriesScoringProfileKind
    let outcomeSource: SeriesOutcomeSource
    let profile: SeriesScoringProfile?
    let suggestedName: String
}

struct SeriesScoringProfileEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel

    let seed: SeriesScoringProfileEditorSeed
    var onSaved: (SeriesScoringProfile) -> Void

    @State private var name: String
    @State private var summary: String
    @State private var placementValues: [String]
    @State private var winPoints: String
    @State private var tiePoints: String
    @State private var lossPoints: String
    @State private var isSaving = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    init(
        viewModel: SeriesViewModel,
        seed: SeriesScoringProfileEditorSeed,
        onSaved: @escaping (SeriesScoringProfile) -> Void
    ) {
        self.viewModel = viewModel
        self.seed = seed
        self.onSaved = onSaved

        let flattenedRules = Self.flattenPlacementRules(seed.profile?.placementRules ?? [])
        let placementDefaults = flattenedRules.isEmpty ? ["3", "2", "1"] : flattenedRules
        let resultPoints = seed.profile?.resultPoints ?? .init()

        _name = State(initialValue: seed.profile?.name ?? seed.suggestedName)
        _summary = State(initialValue: seed.profile?.summary ?? "")
        _placementValues = State(initialValue: placementDefaults)
        _winPoints = State(initialValue: Self.string(from: resultPoints.winPoints))
        _tiePoints = State(initialValue: Self.string(from: resultPoints.tiePoints))
        _lossPoints = State(initialValue: Self.string(from: resultPoints.lossPoints))
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: seed.title,
                subtitle: editorSubtitle,
                onClose: { dismiss() }
            ) {
                Button {
                    saveProfile()
                } label: {
                    Chip(
                        text: isSaving ? "Saving..." : "Save profile",
                        size: .xSmall,
                        foreground: .white,
                        background: isSaving ? Color.neutral3 : Color.accentGreen
                    )
                }
                .disabled(isSaving || trimmedName.isEmpty)
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    identitySection
                    pointsSection
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private var identitySection: some View {
        SeriesSheetCard(palette: palette) {
            Text("PROFILE".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("Profile name")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                TextField("Profile name", text: $name)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .mutedGlassTextFieldContainer(cornerRadius: 14)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                TextField("Optional short summary", text: $summary, axis: .vertical)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(2...4)
                    .mutedGlassTextFieldContainer(cornerRadius: 14)
            }
        }
    }

    @ViewBuilder
    private var pointsSection: some View {
        SeriesSheetCard(palette: palette) {
            Text(seed.kind == .placement ? "POINT SPREAD".uppercased() : "POINT VALUES".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            switch seed.kind {
            case .placement:
                Text("Set exact points by place. Places beyond the last configured row default to zero.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

                ForEach(Array(placementValues.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 12) {
                        Text("\(ordinal(index + 1)) place")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)

                        Spacer(minLength: 0)

                        pointsField(text: binding(forPlacementIndex: index))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.neutral6)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button {
                        placementValues.append("0")
                    } label: {
                        Chip(
                            text: "Add place",
                            size: .small,
                            foreground: .white,
                            background: Color.accentGreen
                        )
                    }
                    .buttonStyle(.plain)

                    if placementValues.count > 1 {
                        Button {
                            placementValues.removeLast()
                        } label: {
                            Chip(
                                text: "Remove last",
                                size: .small,
                                foreground: palette.foregroundColor,
                                background: Color.neutral6
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }

            case .winTieLoss:
                Text("Use explicit points for wins, ties, and losses. This only applies to matchup-style rounds.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

                wltValueRow(title: "Win", text: $winPoints)
                wltValueRow(title: "Tie", text: $tiePoints)
                wltValueRow(title: "Loss", text: $lossPoints)

            case .manual:
                Text("Manual profiles leave the round in review so the commissioner can assign points later.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.neutral6)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func scoringValueRow(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Spacer(minLength: 0)

            pointsField(text: text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.neutral6)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func wltValueRow(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Spacer(minLength: 0)

            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .frame(minWidth: 88)
                .mutedGlassTextFieldContainer(cornerRadius: 12)
        }
    }

    private func pointsField(text: Binding<String>) -> some View {
        TextField("0", text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(Color.accentGreen)
            .frame(width: 72)
    }

    private func binding(forPlacementIndex index: Int) -> Binding<String> {
        Binding(
            get: { placementValues[index] },
            set: { placementValues[index] = $0 }
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editorSubtitle: String {
        switch seed.kind {
        case .placement:
            return "Create a reusable placement profile with exact points by finish."
        case .winTieLoss:
            return "Create reusable matchup points for wins, ties, and losses."
        case .manual:
            return "Use this when the commissioner wants to assign points later."
        }
    }

    private func saveProfile() {
        guard !isSaving else { return }
        isSaving = true

        var profile = seed.profile ?? SeriesScoringProfile(
            id: HackersID.string(),
            outcomeSource: seed.outcomeSource,
            competitorType: seed.competitorType,
            kind: seed.kind,
            parentID: viewModel.seriesID
        )

        profile.name = trimmedName
        profile.summary = trimmedSummary.isEmpty ? generatedSummary(for: profile) : trimmedSummary
        profile.outcomeSource = seed.outcomeSource
        profile.competitorType = seed.competitorType
        profile.kind = seed.kind
        profile.lastUpdatedAt = .init()
        profile.parentID = viewModel.seriesID

        switch seed.kind {
        case .placement:
            profile.tieHandling = .splitPoints
            profile.resultPoints = nil
            profile.placementRules = placementValues.enumerated().compactMap { index, value in
                guard let points = Self.parsePoints(value) else { return nil }
                return SeriesPlacementRule(
                    id: seed.profile?.placementRules[safe: index]?.id ?? HackersID.string(),
                    rankStart: index + 1,
                    rankEnd: index + 1,
                    points: points
                )
            }
        case .winTieLoss:
            profile.tieHandling = .splitPoints
            profile.placementRules = []
            profile.resultPoints = .init(
                winPoints: Self.parsePoints(winPoints) ?? 1,
                tiePoints: Self.parsePoints(tiePoints) ?? 0.5,
                lossPoints: Self.parsePoints(lossPoints) ?? 0
            )
        case .manual:
            profile.tieHandling = .commissionerDecision
            profile.placementRules = []
            profile.resultPoints = nil
        }

        Task {
            if let saved = await viewModel.saveScoringProfile(profile) {
                onSaved(saved)
                dismiss()
            }
            isSaving = false
        }
    }

    private var trimmedSummary: String {
        summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generatedSummary(for profile: SeriesScoringProfile) -> String {
        switch profile.kind {
        case .placement:
            let values = profile.placementRules
                .sorted { $0.rankStart < $1.rankStart }
                .prefix(4)
                .map { "\(ordinal($0.rankStart)) \($0.points.cleanNumberText)" }
            return values.joined(separator: " • ")
        case .winTieLoss:
            let points = profile.resultPoints ?? .init()
            return "Win \(points.winPoints.cleanNumberText) • Tie \(points.tiePoints.cleanNumberText) • Loss \(points.lossPoints.cleanNumberText)"
        case .manual:
            return "Commissioner assigns points after the round."
        }
    }

    private func ordinal(_ value: Int) -> String {
        switch value % 100 {
        case 11, 12, 13:
            return "\(value)th"
        default:
            switch value % 10 {
            case 1: return "\(value)st"
            case 2: return "\(value)nd"
            case 3: return "\(value)rd"
            default: return "\(value)th"
            }
        }
    }

    private static func parsePoints(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated else { return 0 }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private static func flattenPlacementRules(_ rules: [SeriesPlacementRule]) -> [String] {
        let sorted = rules.sorted {
            if $0.rankStart != $1.rankStart { return $0.rankStart < $1.rankStart }
            return $0.rankEnd < $1.rankEnd
        }
        var values: [String] = []
        for rule in sorted {
            guard rule.rankEnd >= rule.rankStart else { continue }
            for _ in rule.rankStart...rule.rankEnd {
                values.append(string(from: rule.points))
            }
        }
        return values
    }

    private static func string(from value: Double) -> String {
        value.cleanNumberText
    }
}

struct SeriesScoringProfileSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: SeriesViewModel

    let title: String
    let subtitle: String
    let competitorType: SeriesCompetitorType
    let competitionScope: CompetitionScope
    let supportsWinTieLoss: Bool
    @Binding var selectedProfileID: String?
    var onEditProfile: (SeriesScoringProfileEditorSeed) -> Void

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            kindSelectorSection
            profileDetailsSection
        }
    }

    private var selectedProfile: SeriesScoringProfile? {
        guard let selectedProfileID else { return nil }
        return viewModel.scoringProfiles.first { $0.id == selectedProfileID }
    }

    private var selectedKind: SeriesScoringProfileKind? {
        selectedProfile?.kind
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Text(subtitle)
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private var kindSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allowedKindsWithNone.indices, id: \.self) { index in
                    let kind = allowedKindsWithNone[index]
                    let isSelected = selectedKind == kind

                    Button {
                        Haptics.fire(.light)
                        setSelectedKind(kind)
                    } label: {
                        Chip(
                            text: label(for: kind),
                            size: .small,
                            foreground: isSelected ? .white : palette.foregroundColor,
                            background: isSelected ? Color.accentGreen : Color.neutral6
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var profileDetailsSection: some View {
        if let selectedProfile {
            selectedProfileSection(selectedProfile)
        } else {
            Text("This track will not award series points for the round.")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private func selectedProfileSection(_ profile: SeriesScoringProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(filteredProfiles(for: profile.kind), id: \.id) { option in
                        Button {
                            selectedProfileID = option.id
                        } label: {
                            HStack {
                                Text(option.name)
                                if option.id == selectedProfileID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                        Icon(name: "f078", size: 12, weight: .solid)
                            .foregroundStyle(Color.neutral)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassCardEffect(cornerRadius: 16, tint: palette.whiteGlassButtonColor)
                }
                .buttonStyle(.plain)

                if profile.kind == .placement || profile.kind == .winTieLoss {
                    Button {
                        onEditProfile(editorSeed(for: profile.kind, profile: profile))
                    } label: {
                        Chip(
                            text: editButtonTitle(for: profile.kind),
                            size: .small,
                            foreground: .white,
                            background: Color.accentGreen
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            Text(profileSummary(for: profile))
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private var allowedKinds: [SeriesScoringProfileKind] {
        competitionScope == .matchup && supportsWinTieLoss
            ? [.placement, .winTieLoss, .manual]
            : [.placement, .manual]
    }

    private var allowedKindsWithNone: [SeriesScoringProfileKind?] {
        [nil] + allowedKinds
    }

    private func filteredProfiles(for kind: SeriesScoringProfileKind) -> [SeriesScoringProfile] {
        viewModel.scoringProfiles
            .filter {
                !$0.isArchived
                    && $0.competitorType == competitorType
                    && $0.kind == kind
                    && isProfileValid($0)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isProfileValid(_ profile: SeriesScoringProfile) -> Bool {
        if (competitionScope != .matchup || !supportsWinTieLoss), profile.kind == .winTieLoss {
            return false
        }
        return true
    }

    private func label(for kind: SeriesScoringProfileKind?) -> String {
        switch kind {
        case nil:
            return "None"
        case .placement:
            return "Placement"
        case .winTieLoss:
            return "Win/Tie/Loss"
        case .manual:
            return "Manual"
        }
    }

    private func setSelectedKind(_ kind: SeriesScoringProfileKind?) {
        guard let kind else {
            selectedProfileID = nil
            return
        }

        if selectedProfile?.kind == kind, let selectedProfileID {
            self.selectedProfileID = selectedProfileID
            return
        }

        if let profile = filteredProfiles(for: kind).first {
            selectedProfileID = profile.id
        } else {
            selectedProfileID = nil
            onEditProfile(editorSeed(for: kind, profile: nil))
        }
    }

    private func profileSummary(for profile: SeriesScoringProfile) -> String {
        if let summary = profile.summary, summary.isPopulated {
            return summary
        }

        switch profile.kind {
        case .placement:
            let rules = profile.placementRules
                .sorted { $0.rankStart < $1.rankStart }
                .prefix(4)
                .map { "\(ordinal($0.rankStart)) \($0.points.cleanNumberText)" }
            return rules.isEmpty ? "No placement points set yet." : rules.joined(separator: " • ")
        case .winTieLoss:
            let points = profile.resultPoints ?? .init()
            return "Win \(points.winPoints.cleanNumberText) • Tie \(points.tiePoints.cleanNumberText) • Loss \(points.lossPoints.cleanNumberText)"
        case .manual:
            return "Commissioner assigns points after the round."
        }
    }

    private func editorSeed(for kind: SeriesScoringProfileKind, profile: SeriesScoringProfile?) -> SeriesScoringProfileEditorSeed {
        SeriesScoringProfileEditorSeed(
            title: seedTitle(for: kind),
            competitorType: competitorType,
            kind: kind,
            outcomeSource: outcomeSource(for: kind),
            profile: profile,
            suggestedName: suggestedName(for: kind)
        )
    }

    private func seedTitle(for kind: SeriesScoringProfileKind) -> String {
        let audience = competitorType == .team ? "Team" : "Individual"
        switch kind {
        case .placement:
            return "\(audience) Placement"
        case .winTieLoss:
            return "\(audience) Win/Tie/Loss"
        case .manual:
            return "\(audience) Manual"
        }
    }

    private func suggestedName(for kind: SeriesScoringProfileKind) -> String {
        let audience = competitorType == .team ? "Team" : "Individual"
        switch kind {
        case .placement:
            return "\(audience) Placement"
        case .winTieLoss:
            return "\(audience) Win/Tie/Loss"
        case .manual:
            return "\(audience) Manual"
        }
    }

    private func outcomeSource(for kind: SeriesScoringProfileKind) -> SeriesOutcomeSource {
        switch kind {
        case .winTieLoss:
            return .roundMatchResult
        case .manual:
            return .manual
        case .placement:
            return competitorType == .team ? .roundTeamLeaderboard : .roundIndividualLeaderboard
        }
    }

    private func editButtonTitle(for kind: SeriesScoringProfileKind) -> String {
        switch kind {
        case .placement:
            return "Set point spread"
        case .winTieLoss:
            return "Edit WLT points"
        case .manual:
            return "Edit"
        }
    }

    private func ordinal(_ value: Int) -> String {
        switch value % 100 {
        case 11, 12, 13:
            return "\(value)th"
        default:
            switch value % 10 {
            case 1: return "\(value)st"
            case 2: return "\(value)nd"
            case 3: return "\(value)rd"
            default: return "\(value)th"
            }
        }
    }
}

private extension Double {
    var cleanNumberText: String {
        let formatted = String(format: "%.2f", self)
        if formatted.hasSuffix("00") {
            return String(formatted.dropLast(3))
        }
        if formatted.hasSuffix("0") {
            return String(formatted.dropLast(1))
        }
        return formatted
    }
}
