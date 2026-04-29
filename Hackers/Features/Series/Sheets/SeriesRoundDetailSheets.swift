//
//  SeriesRoundDetailSheets.swift
//  Hackers
//

import SkeletonUI
import SwiftUI
import UIKit

struct SeriesRoundAwardsDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    @State private var matchupOutcomes: [SeriesMatchupOutcome] = []

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Round Awards",
                subtitle: seriesRound.title.isEmpty ? "Round \(seriesRound.index + 1)" : seriesRound.title,
                onClose: { dismiss() }
            )

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
        .task(id: seriesRound.id) {
            matchupOutcomes = await viewModel.matchupOutcomes(for: seriesRound)
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

            if matchupOutcomes.isPopulated {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Matchups".uppercased())
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)

                    ForEach(Array(matchupOutcomes.enumerated()), id: \.element.id) { index, outcome in
                        SeriesAwardMatchupOutcomeCard(
                            outcome: outcome,
                            matchIndex: index + 1,
                            palette: palette
                        )
                    }
                }
                .padding(.top, 4)
            }

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
                .background(palette.cardEmbeddedRowBackground)
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
                                background: palette.cardEmbeddedRowBackground
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(award.competitorName)
                                    .fontStyle(kFontName, size: 15, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)

                                Text(awardSubtitle(for: award))
                                    .fontStyle(kFontName, size: 12, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }

                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(award.totalPoints.seriesPointsDisplayString) pts")
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
                        .background(palette.cardEmbeddedRowBackground)
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

    private func awardSubtitle(for award: SeriesPointAward) -> String {
        if let reason = award.reason, reason.isPopulated, !reason.looksLikeOpaqueAwardReasonID {
            return reason
        }
        return award.source.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
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

private struct SeriesAwardMatchupOutcomeCard: View {
    let outcome: SeriesMatchupOutcome
    let matchIndex: Int
    let palette: DesignPalette

    private var scoreColumnWidth: CGFloat { outcome.usesNetScores ? 44 : 52 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Match \(matchIndex)".uppercased())
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral2)

                Text(outcome.title)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(2)

                Text(outcome.detail)
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral)
            }

            VStack(spacing: 10) {
                ForEach(outcome.sides) { side in
                    sideRow(side)
                }
            }

            if outcome.players.isPopulated {
                playersTable
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardEmbeddedRowBackground)
        .cornerRadius(16)
    }

    private func sideRow(_ side: SeriesMatchupOutcome.Side) -> some View {
        let isWinner = outcome.winningSideID == side.id
        let accent = side.accentColor ?? palette.foregroundColor

        return HStack(spacing: 12) {
            Text(side.score)
                .fontStyle(kFontName, size: 19, weight: .semibold)
                .foregroundStyle(isWinner ? accent : palette.foregroundColor)
                .frame(width: 44, height: 44)
                .glassCardEffect(
                    shape: .circle,
                    interactive: false,
                    tint: palette.whiteGlassButtonColor,
                    strokeOpacity: isWinner ? 0.42 : 0.24,
                    shadowOpacity: 0.08
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(side.title)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(isWinner ? accent : palette.foregroundColor)
                        .lineLimit(2)

                    if outcome.showsResultChip && isWinner {
                        resultChip("Winner", tint: accent)
                    } else if outcome.showsResultChip && outcome.isTie {
                        resultChip("Tie", tint: Color.neutral)
                    }
                }

                if let subtitle = side.subtitle, subtitle.isPopulated {
                    Text(subtitle)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var playersTable: some View {
        VStack(spacing: 0) {
            Line(color: Color.neutral6.opacity(0.5))
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                Text("Player")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("HCP")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)

                Text("Gross")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)

                if outcome.usesNetScores {
                    Text("Net")
                        .fontStyle(kFontName, size: 12, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .frame(minWidth: scoreColumnWidth, alignment: .trailing)
                }
            }
            .padding(.bottom, 6)

            ForEach(Array(outcome.players.enumerated()), id: \.element.id) { index, player in
                playerRow(player)

                if index != outcome.players.count - 1 {
                    Divider().opacity(0.18)
                }
            }
        }
    }

    private func playerRow(_ player: SeriesMatchupOutcome.Player) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(player.name)
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(player.scoreCounts ? palette.foregroundColor : Color.neutral2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if player.scoreCounts {
                    Circle()
                        .fill(player.accentColor ?? Color.accentGreen)
                        .frame(width: 8, height: 8)
                }
            }

            Text(player.handicap)
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
                .frame(minWidth: scoreColumnWidth, alignment: .trailing)

            Text(player.gross)
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(player.scoreCounts ? palette.foregroundColor : Color.neutral2)
                .frame(minWidth: scoreColumnWidth, alignment: .trailing)

            if outcome.usesNetScores {
                Text(player.netLabel)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(player.scoreCounts ? (player.accentColor ?? palette.foregroundColor) : Color.neutral2)
                    .frame(minWidth: scoreColumnWidth, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }

    private func resultChip(_ title: String, tint: Color) -> some View {
        Text(title.uppercased())
            .fontStyle(kFontName, size: 10, weight: .semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}

private extension SeriesMatchupOutcome.Player {
    var netLabel: String {
        net ?? "—"
    }
}

enum ScoreCorrectionEditorMode: String, CaseIterable {
    case holeByHole = "Hole by hole"
    case totalGross = "Total gross"
}

struct SeriesRoundScoreCorrectionSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    /// When set (e.g. from handicap history), selects that series member’s participant row after load.
    let initialSeriesMemberID: String?
    let initialParticipantID: String?

    @State private var context: SeriesRoundCorrectionContext?
    @State private var selectedParticipantID: String = ""
    @State private var draftScores: [String: Int] = [:]
    @State private var reason: String = ""
    @State private var editorMode: ScoreCorrectionEditorMode = .holeByHole
    @State private var grossTargetText: String = ""

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    init(
        viewModel: SeriesViewModel,
        seriesRound: SeriesRound,
        initialSeriesMemberID: String? = nil,
        initialParticipantID: String? = nil,
        initialEditorMode: ScoreCorrectionEditorMode = .holeByHole
    ) {
        self.viewModel = viewModel
        self.seriesRound = seriesRound
        self.initialSeriesMemberID = initialSeriesMemberID
        self.initialParticipantID = initialParticipantID
        _editorMode = State(initialValue: initialEditorMode)
    }

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
                        Picker("Editor", selection: $editorMode) {
                            ForEach(ScoreCorrectionEditorMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        if editorMode == .holeByHole {
                            scoreEditorSection(context: context)
                        } else {
                            grossEditorSection(context: context)
                        }
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
            if let ctx = context, let initialParticipantID,
               ctx.snapshot.participants.contains(where: { $0.id == initialParticipantID }) {
                selectedParticipantID = initialParticipantID
            } else if let ctx = context, let mid = initialSeriesMemberID,
               let pid = viewModel.preferredRoundParticipantID(seriesMemberID: mid, snapshot: ctx.snapshot) {
                selectedParticipantID = pid
            } else {
                selectedParticipantID = context?.snapshot.participants.first?.id ?? ""
            }
            if let ctx = context {
                grossTargetText = String(currentParticipantGrossTotal(context: ctx))
            }
        }
        .onChange(of: selectedParticipantID) { _, _ in
            guard let ctx = context else { return }
            grossTargetText = String(currentParticipantGrossTotal(context: ctx))
        }
    }

    private func grossEditorSection(context: SeriesRoundCorrectionContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total gross".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text("Adjusts hole scores to match the total (unscored holes start at par). Uses the same save path as hole-by-hole edits.")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)

            let current = currentParticipantGrossTotal(context: context)
            Text("Current gross: \(current)")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            TextField("Target gross", text: $grossTargetText)
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .keyboardType(.numberPad)
                .padding(14)
                .background(palette.cardEmbeddedRowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func currentParticipantGrossTotal(context: SeriesRoundCorrectionContext) -> Int {
        context.holes.reduce(0) { partial, hole in
            let v = displayedScore(
                participantID: selectedParticipantID,
                holeNumber: hole.number,
                context: context
            )
            return partial + (v ?? hole.par)
        }
    }

    private func canSaveCorrection(context: SeriesRoundCorrectionContext?) -> Bool {
        guard let context else { return false }
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReason.isPopulated else { return false }
        if editorMode == .totalGross {
            guard let target = Int(grossTargetText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            let changes = viewModel.commissionerGrossCorrectionChanges(
                context: context,
                participantID: selectedParticipantID,
                targetGross: target,
                draftScores: draftScores
            ) ?? []
            return !changes.isEmpty
        }
        return !pendingChanges(context: context).isEmpty
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
                                background: selectedParticipantID == participant.id ? .accentGreen : palette.cardEmbeddedRowBackground
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

        return HStack(alignment: .top, spacing: 12) {
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
            .fixedSize(horizontal: true, vertical: false)

            if score != original {
                Chip(
                    text: "Edited",
                    size: .tiny,
                    foreground: .orange,
                    background: Color.orange.opacity(colorScheme.translucent)
                )
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardEmbeddedRowBackground)
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
                .background(palette.cardEmbeddedRowBackground)
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
                    background: palette.cardEmbeddedRowBackground
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    guard let context else { return }
                    let changes: [SeriesScoreCorrectionChange] = {
                        if editorMode == .totalGross {
                            guard let target = Int(grossTargetText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return [] }
                            return viewModel.commissionerGrossCorrectionChanges(
                                context: context,
                                participantID: selectedParticipantID,
                                targetGross: target,
                                draftScores: draftScores
                            ) ?? []
                        }
                        return pendingChanges(context: context)
                    }()
                    let didSave = await viewModel.applyScoreCorrections(
                        for: context.seriesRound,
                        changes: changes,
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
                .background(canSaveCorrection(context: context) ? Color.accentGreen : Color.neutral3)
                .clipShape(Capsule())
            }
            .disabled(!canSaveCorrection(context: context) || viewModel.correctingRoundID == seriesRound.id)
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
            .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: true)
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
    let palette: DesignPalette
    var rowBackground: Color?
    let content: Content

    init(palette: DesignPalette, rowBackground: Color? = nil, @ViewBuilder content: () -> Content) {
        self.palette = palette
        self.rowBackground = rowBackground
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground ?? palette.cardEmbeddedRowBackground)
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
                        .multilineTextAlignment(.leading)
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
    @State private var isEditingList = false

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
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: seed.title,
                    subtitle: editorSubtitle,
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 16) {
                    identitySection
                    pointsSection
                }
                .padding(16)
            },
            footer: {
                VStack(spacing: 0) {
                    Line()
                    PrimaryButton(
                        appearance: .fill,
                        title: "Save scoring profile",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        fillWidth: true,
                        isDisabled: .constant(trimmedName.isEmpty || isSaving),
                        isLoading: .constant(isSaving),
                        onTapAsync: { saveProfile() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
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
                    .padding(12)
                    .background(colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                TextField("Optional short summary", text: $summary, axis: .vertical)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

                HStack {
                    Text("Place")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .frame(width: 52, alignment: .center)
                    Spacer()
                    Text("Points")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                }
                .padding(.horizontal, 4)

                ForEach(Array(placementValues.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .fontStyle(kFontName, size: 16, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(width: 52, alignment: .center)
                            .padding(.vertical, 10)
                            .background(colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Spacer()

                        TextField("0", text: binding(forPlacementIndex: index))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                            .frame(width: 88)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if isEditingList {
                            Button {
                                withAnimation {
                                    var next = placementValues
                                    next.remove(at: index)
                                    placementValues = next
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.systemError)
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation { placementValues.append("0") }
                    } label: {
                        Chip(
                            text: "Add place",
                            size: .small,
                            foreground: .white,
                            background: Color.accentGreen
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation { isEditingList.toggle() }
                    } label: {
                        Chip(
                            text: isEditingList ? "Done" : "Edit",
                            size: .small,
                            foreground: isEditingList ? .white : palette.foregroundColor,
                            background: isEditingList ? Color.accentGreen : palette.cardEmbeddedRowBackground
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(placementValues.count <= 1)

                    Spacer(minLength: 0)
                }

            case .winTieLoss:
                Text("Use explicit points for wins, ties, and losses. This only applies to matchup-style rounds.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

                wltValueRow(title: "Win", text: $winPoints)
                wltValueRow(title: "Tie", text: $tiePoints)
                wltValueRow(title: "Loss", text: $lossPoints)

            case .accrueFromIndividual:
                Text("This profile mirrors the round's awarded individual points into the team standings by summing each team's player totals.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)

            default:
                EmptyView()
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
        .background(palette.cardEmbeddedRowBackground)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        case .accrueFromIndividual:
            return "Use awarded individual round points as the team's round total."
        default:
            return ""
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
        case .accrueFromIndividual:
            profile.tieHandling = .splitPoints
            profile.placementRules = []
            profile.resultPoints = nil
        default:
            break
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
        case .accrueFromIndividual:
            return "Sum each team's awarded individual round points."
        default:
            return ""
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

    let title: String?
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
            if let title {
                Text(title)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
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
                            background: isSelected ? Color.accentGreen : palette.cardEmbeddedRowBackground
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    @ViewBuilder
    private var profileDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summaryText(for: selectedProfile))
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .fixedSize(horizontal: false, vertical: true)

            if let selectedProfile {
                selectedProfileSection(selectedProfile)
            }
        }
    }

    private func selectedProfileSection(_ profile: SeriesScoringProfile) -> some View {
        Button {
            onEditProfile(editorSeed(for: profile.kind, profile: profile))
        } label: {
            HStack(spacing: 8) {
                Text(editButtonTitle(for: profile.kind))
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Icon(name: "f044", size: 12, weight: .solid)
                    .foregroundStyle(Color.neutral)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCardEffect(cornerRadius: 16, tint: palette.whiteGlassButtonColor)
        }
        .buttonStyle(.plain)
    }

    private var allowedKinds: [SeriesScoringProfileKind] {
        var kinds: [SeriesScoringProfileKind] = [.placement]
        if competitionScope == .matchup && supportsWinTieLoss {
            kinds.append(.winTieLoss)
        }
        if competitorType == .team {
            kinds.append(.accrueFromIndividual)
        }
        return kinds
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
        case .accrueFromIndividual:
            return "Sum player points to team"
        case .winTieLoss:
            return "Win/Tie/Loss"
        default:
            return "None"
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

    private func summaryText(for profile: SeriesScoringProfile?) -> String {
        guard let profile else {
            return "This \(audienceNoun.lowercased()) track does not award series points for the round."
        }
        switch profile.kind {
        case .placement:
            let rules = profile.placementRules
                .sorted { $0.rankStart < $1.rankStart }
                .prefix(3)
                .map { "\(ordinal($0.rankStart)) \($0.points.cleanNumberText)" }
                .joined(separator: ", ")
            return rules.isEmpty
                ? "\(audienceNoun) leaderboard awards have not been configured yet."
                : "\(audienceNoun) leaderboard awards \(rules)."
        case .accrueFromIndividual:
            return "Each team's total is the sum of its players' individual points from this round."
        case .winTieLoss:
            let points = profile.resultPoints ?? .init()
            return "Match results award Win \(points.winPoints.cleanNumberText), Tie \(points.tiePoints.cleanNumberText), Loss \(points.lossPoints.cleanNumberText)."
        case .manual:
            return "Commissioner assigns \(audienceNoun.lowercased()) points manually after the round."
        }
    }

    private var audienceNoun: String {
        competitorType == .team ? "Team" : "Individual"
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
        case .accrueFromIndividual:
            return "Accrue from Individual"
        case .winTieLoss:
            return "\(audience) Win/Tie/Loss"
        default:
            return audience
        }
    }

    private func suggestedName(for kind: SeriesScoringProfileKind) -> String {
        let audience = competitorType == .team ? "Team" : "Individual"
        switch kind {
        case .placement:
            return "\(audience) Placement"
        case .accrueFromIndividual:
            return "Accrue from Individual"
        case .winTieLoss:
            return "\(audience) Win/Tie/Loss"
        default:
            return audience
        }
    }

    private func outcomeSource(for kind: SeriesScoringProfileKind) -> SeriesOutcomeSource {
        switch kind {
        case .winTieLoss:
            return .roundMatchResult
        case .accrueFromIndividual:
            return .individualAwardsAggregateToTeam
        default:
            return competitorType == .team ? .roundTeamLeaderboard : .roundIndividualLeaderboard
        }
    }

    private func editButtonTitle(for kind: SeriesScoringProfileKind) -> String {
        switch kind {
        case .placement:
            return "Edit point spread"
        case .accrueFromIndividual:
            return "Edit profile"
        case .winTieLoss:
            return "Edit WLT points"
        default:
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

// MARK: - Commissioner Completion Review

struct SeriesCompletionReviewSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound

    @State private var isForceCompleting = false
    @State private var reviewSnapshot: RoundSnapshot?
    @State private var isLoadingReviewSnapshot = true

    @State private var showScorecardOverlay = false
    @State private var scorecardOverlayImage: UIImage?
    @State private var scorecardOverlayLoadComplete = false
    @State private var scorecardOverlayScale: CGFloat = 1
    @State private var scorecardOverlayOffset: CGSize = .zero
    @State private var scoreCorrectionLaunch: ScoreCorrectionLaunch?

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    private var linked: Round? { viewModel.linkedRound(for: seriesRound) }

    private struct ScoreCorrectionLaunch: Identifiable {
        let participantID: String

        var id: String { participantID }
    }

    private var completedIDs: Set<String> {
        Set(linked?.completedPlayers.map(\.playerID) ?? [])
    }

    private var allPlayerIDs: [String] { linked?.players ?? [] }

    private var completionEntries: [String: CompletedPlayer] {
        Dictionary(
            (linked?.completedPlayers ?? []).map { ($0.playerID, $0) },
            uniquingKeysWith: { _, last in last }
        )
    }

    private var signedScorecardPlayerIDs: Set<String> {
        Set(
            (linked?.completedPlayers ?? [])
                .filter { $0.type == .signedScorecard }
                .map(\.playerID)
        )
    }

    private var membersByPlayerID: [String: SeriesMember] {
        Dictionary(
            viewModel.activeMembers.compactMap { m -> (String, SeriesMember)? in
                guard let pid = m.playerID else { return nil }
                return (pid, m)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var membersBySeriesMemberID: [String: SeriesMember] {
        Dictionary(
            viewModel.activeMembers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var reviewParticipantsByPlayerID: [String: RoundParticipant] {
        guard let reviewSnapshot else { return [:] }
        return Dictionary(
            reviewSnapshot.participants.compactMap { participant in
                guard let playerID = participant.playerID, playerID.isPopulated else { return nil }
                return (playerID, participant)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private struct ScoreReviewTeeGroupSection: Identifiable {
        let id: String
        let title: String
        let playerIDs: [String]
    }

    private var roundFullyComplete: Bool {
        guard let linked else { return false }
        if linked.status == .complete { return true }
        return viewModel.allScoresComplete(for: seriesRound)
    }

    private var scoreReviewTeeGroupSections: [ScoreReviewTeeGroupSection] {
        guard let snap = reviewSnapshot else {
            return [ScoreReviewTeeGroupSection(id: "all", title: "", playerIDs: allPlayerIDs)]
        }
        func groupKey(forPlayerID pid: String) -> String {
            guard let gid = reviewParticipantsByPlayerID[pid]?.groupID, gid.isPopulated else { return "" }
            return gid
        }
        var buckets: [String: [String]] = [:]
        for pid in allPlayerIDs {
            let key = groupKey(forPlayerID: pid)
            buckets[key, default: []].append(pid)
        }
        func minTeeOrder(forGroupKey key: String) -> Int {
            (buckets[key] ?? []).compactMap { reviewParticipantsByPlayerID[$0]?.teeOrder }.min() ?? Int.max
        }
        let orderedKeys = buckets.keys.sorted { a, b in
            let aEmpty = a.isEmpty
            let bEmpty = b.isEmpty
            if aEmpty != bEmpty { return !aEmpty }
            return minTeeOrder(forGroupKey: a) < minTeeOrder(forGroupKey: b)
        }
        return orderedKeys.map { key in
            let title: String = {
                if key.isEmpty { return "Unassigned" }
                if let tg = snap.teeGroups.first(where: { $0.id == key }) { return tg.name }
                return "Tee group"
            }()
            var ids = buckets[key] ?? []
            func playerSignedScorecard(_ pid: String) -> Bool {
                completionEntries[pid]?.type == .signedScorecard
            }
            func sortRank(_ pid: String) -> Int {
                if playerSignedScorecard(pid) { return 0 }
                if isSoftComplete(for: pid) { return 1 }
                return 2
            }
            ids.sort { a, b in
                let ra = sortRank(a)
                let rb = sortRank(b)
                if ra != rb { return ra < rb }
                let na = resolvedScoreReviewName(playerID: a)
                let nb = resolvedScoreReviewName(playerID: b)
                return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
            }
            let sid = key.isEmpty ? "unassigned" : key
            return ScoreReviewTeeGroupSection(id: sid, title: title, playerIDs: ids)
        }
    }

    /// Includes self-signed, commissioner completion, keep-open, and tee-group proxy (peer signed scorecard).
    private var softCompleteCount: Int {
        allPlayerIDs.filter { isSoftComplete(for: $0) }.count
    }

    private var effectiveRoundConfig: SeriesRoundConfiguration {
        viewModel.effectiveRoundConfig(for: seriesRound)
    }

    private var handicapParticipationMembers: [SeriesMember] {
        viewModel.handicapParticipationMembers(for: seriesRound)
    }

    private var handicapFormatSupportsAccrual: Bool {
        if let reviewSnapshot {
            return reviewSnapshot.resolvedActiveTemplate.supportsLeagueHandicapAccrual
        }
        return effectiveRoundConfig.supportsLeagueHandicapAccrual
    }

    private var handicapExcludedCount: Int {
        let memberIDs = Set(handicapParticipationMembers.map(\.id))
        return effectiveRoundConfig.normalizedExcludedHandicapMemberIDs
            .filter { memberIDs.contains($0) }
            .count
    }

    private var handicapReviewDisclaimer: String {
        switch viewModel.series.handicapConfig.mode {
        case .off:
            return "Series handicaps are off for this series. Completing the round won't change handicap computation until handicaps are enabled."
        case .fixed:
            return "Series handicaps are fixed for scoring. Completing the round won't change the handicap pool."
        case .dynamic:
            break
        }
        if !handicapFormatSupportsAccrual {
            return "This format doesn't allow handicap accrual, so completing the round won't affect handicap updates."
        }
        if !effectiveRoundConfig.countsTowardHandicapPool {
            return "This round is excluded from handicap computation. You can still correct and re-compute later."
        }

        let total = handicapParticipationMembers.count
        let included = max(0, total - handicapExcludedCount)
        if handicapExcludedCount > 0 {
            return "Only \(included) of \(total) players in this round will count toward the handicap pool. You can still correct and re-compute later."
        }
        return "Once complete, these scores will count toward the handicap pool. You can still correct and re-compute later."
    }

    private var scoreReviewSubtitle: String {
        let total = allPlayerIDs.count
        let done = reviewSnapshot != nil ? softCompleteCount : completedIDs.count
        return "\(done) of \(total) complete"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Score Review",
                    subtitle: scoreReviewSubtitle,
                    onClose: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        if isLoadingReviewSnapshot {
                            ForEach(0..<8, id: \.self) { _ in
                                scoreReviewSkeletonRow
                            }
                        } else {
                            ForEach(scoreReviewTeeGroupSections) { section in
                                if !section.title.isEmpty {
                                    Text(section.title.uppercased())
                                        .fontStyle(kFontName, size: 12, weight: .semibold)
                                        .foregroundStyle(Color.neutral2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                }
                                ForEach(section.playerIDs, id: \.self) { playerID in
                                    playerRow(playerID: playerID)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .animation(.easeInOut(duration: 0.2), value: isLoadingReviewSnapshot)
                }

                if viewModel.isCommissioner, !viewModel.allScoresComplete(for: seriesRound) {
                    VStack(spacing: 12) {
                        Divider()
                        
                        PrimaryButton(
                            appearance: .fill,
                            title: "Complete round",
                            labelColor: .white,
                            buttonColor: Color.accentYellow,
                            theme: palette.theme,
                            height: 48,
                            fontSize: 16,
                            isDisabled: Binding(
                                get: { isForceCompleting },
                                set: { _ in }
                            ),
                            isLoading: $isForceCompleting,
                            onTapAsync: {
                                await MainActor.run { isForceCompleting = true }
                                await viewModel.forceCompleteRound(seriesRound)
                                await MainActor.run {
                                    isForceCompleting = false
                                    dismiss()
                                }
                            }
                        )

                        Text(handicapReviewDisclaimer)
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            scorecardOverlay
        }
        .task {
            isLoadingReviewSnapshot = true
            reviewSnapshot = await viewModel.loadLinkedRoundSnapshot(for: seriesRound)
            isLoadingReviewSnapshot = false
        }
        .sheet(item: $scoreCorrectionLaunch) { launch in
            SeriesRoundScoreCorrectionSheet(
                viewModel: viewModel,
                seriesRound: seriesRound,
                initialParticipantID: launch.participantID,
                initialEditorMode: .totalGross
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var scoreReviewSkeletonRow: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 1.6),
                    appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                    shape: .rounded(.radius(12))
                )
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(4))
                    )
                    .frame(width: 160, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 1.6),
                        appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                        shape: .rounded(.radius(4))
                    )
                    .frame(width: 112, height: 12)
            }

            Spacer(minLength: 8)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 1.6),
                    appearance: .solid(color: palette.skeletonColor, background: palette.skeletonBackground),
                    shape: .rounded(.radius(4))
                )
                .frame(width: 52, height: 18)
        }
        .padding(12)
        .glassCardEffect(cornerRadius: 12)
    }

    private func playerRow(playerID: String) -> some View {
        let row = scoreReviewRowState(playerID: playerID, roundFullyComplete: roundFullyComplete)
        let name = resolvedScoreReviewName(playerID: playerID)
        let trailing = reviewSnapshot.flatMap { viewModel.scoreReviewTrailingLabel(playerID: playerID, snapshot: $0) }

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: row.leadingIconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(row.leadingIconColor)
                .symbolRenderingMode(row.leadingIconFilled ? .monochrome : .hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)

                    if let asset = row.scorecardAsset {
                        Button {
                            Haptics.fire(.light)
                            presentScorecardOverlay(asset: asset)
                        } label: {
                            Image(systemName: "photo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentYellow)
                                .frame(width: 32, height: 32)
                                .background(Color.neutral6)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.accentYellow.opacity(0.45), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View scorecard photo")
                    }

                    if viewModel.isCommissioner,
                       let participantID = reviewParticipantsByPlayerID[playerID]?.id {
                        Button {
                            Haptics.fire(.light)
                            scoreCorrectionLaunch = ScoreCorrectionLaunch(participantID: participantID)
                        } label: {
                            Chip(
                                text: "Set total",
                                size: .tiny,
                                foreground: palette.foregroundColor,
                                background: palette.whiteGlassButtonColor
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Set total score for \(name)")
                    }
                }

                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .fontStyle(kFontName, size: 11, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.accentYellow)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .glassCardEffect(cornerRadius: 12)
        .accessibilityLabel(scoreReviewAccessibilityLabel(name: name, row: row, trailing: trailing))
    }

    private func resolvedScoreReviewName(playerID: String) -> String {
        if let member = membersByPlayerID[playerID] {
            return member.name.fullName
        }
        if let participant = reviewParticipantsByPlayerID[playerID] {
            let snapshotName = participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if snapshotName.isPopulated {
                return snapshotName
            }
            if let seriesMemberID = participant.seriesMemberID,
               let member = membersBySeriesMemberID[seriesMemberID] {
                return member.name.fullName
            }
        }
        return playerID.prefix(8).description
    }

    private func scoreReviewAccessibilityLabel(
        name: String,
        row: ScoreReviewRowState,
        trailing: String?
    ) -> String {
        var components: [String] = [name]
        if row.subtitle.isPopulated {
            components.append(row.subtitle)
        }
        if let trailing, trailing.isPopulated {
            components.append(trailing)
        }
        return components.joined(separator: ", ")
    }

    private func peerScorecardSignerPlayerIDs(for playerID: String) -> [String] {
        guard let snap = reviewSnapshot,
              let participant = snap.participants.first(where: { $0.playerID == playerID }),
              let gid = participant.groupID,
              gid.isPopulated
        else { return [] }
        return snap.participants
            .filter { $0.groupID == gid }
            .compactMap(\.playerID)
            .filter { $0 != playerID && signedScorecardPlayerIDs.contains($0) }
    }

    private func isSoftComplete(for playerID: String) -> Bool {
        if completedIDs.contains(playerID) { return true }
        return !peerScorecardSignerPlayerIDs(for: playerID).isEmpty
    }

    private func scoreReviewRowState(playerID: String, roundFullyComplete: Bool) -> ScoreReviewRowState {
        if let entry = completionEntries[playerID] {
            switch entry.type {
            case .signedScorecard:
                return ScoreReviewRowState(
                    subtitle: roundFullyComplete ? "" : "Signed",
                    leadingIconName: "checkmark.circle.fill",
                    leadingIconColor: Color.accentYellow,
                    leadingIconFilled: true,
                    scorecardAsset: entry.scorecardStorageID,
                    isProxyHighlight: false
                )
            case .commissionerOverride:
                return ScoreReviewRowState(
                    subtitle: roundFullyComplete ? "" : "Commissioner",
                    leadingIconName: "checkmark.circle.fill",
                    leadingIconColor: Color.accentYellow,
                    leadingIconFilled: true,
                    scorecardAsset: nil,
                    isProxyHighlight: false
                )
            case .keepOpen:
                return ScoreReviewRowState(
                    subtitle: "Keep open",
                    leadingIconName: "checkmark.circle.fill",
                    leadingIconColor: Color.accentYellow,
                    leadingIconFilled: true,
                    scorecardAsset: nil,
                    isProxyHighlight: false
                )
            }
        }

        let peerSignerIDs = peerScorecardSignerPlayerIDs(for: playerID)
        if peerSignerIDs.isEmpty {
            return ScoreReviewRowState(
                subtitle: "Pending",
                leadingIconName: "circle",
                leadingIconColor: Color.neutral3,
                leadingIconFilled: false,
                scorecardAsset: nil,
                isProxyHighlight: false
            )
        }

        return ScoreReviewRowState(
            subtitle: roundFullyComplete ? "" : "Signed",
            leadingIconName: "checkmark.circle.fill",
            leadingIconColor: Color.accentYellow,
            leadingIconFilled: true,
            scorecardAsset: nil,
            isProxyHighlight: false
        )
    }

    private func presentScorecardOverlay(asset: StorageAsset) {
        showScorecardOverlay = true
        scorecardOverlayLoadComplete = false
        scorecardOverlayImage = nil
        scorecardOverlayScale = 1
        scorecardOverlayOffset = .zero
        Task {
            scorecardOverlayImage = try? await FirebaseService.shared.fetchScorecardImage(asset: asset)
            scorecardOverlayLoadComplete = true
        }
    }

    @ViewBuilder
    private var scorecardOverlay: some View {
        if showScorecardOverlay {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissScorecardOverlay()
                    }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismissScorecardOverlay()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding()
                    }
                    Spacer()

                    if let image = scorecardOverlayImage {
                        ScorecardZoomImageView(
                            image: image,
                            scale: $scorecardOverlayScale,
                            offset: $scorecardOverlayOffset
                        )
                    } else if scorecardOverlayLoadComplete {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral5)
                            .frame(width: 200, height: 280)
                            .overlay {
                                Text("Scorecard image unavailable")
                                    .fontStyle(kFontName, size: 14, weight: .medium)
                                    .foregroundStyle(Color.neutral2)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral5)
                            .frame(width: 200, height: 280)
                            .overlay {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Color.accentYellow)
                                    Text("Loading scorecard…")
                                        .fontStyle(kFontName, size: 14, weight: .medium)
                                        .foregroundStyle(Color.neutral2)
                                }
                            }
                    }

                    Spacer()
                }
            }
        }
    }

    private func dismissScorecardOverlay() {
        showScorecardOverlay = false
        scorecardOverlayImage = nil
        scorecardOverlayLoadComplete = false
        scorecardOverlayScale = 1
        scorecardOverlayOffset = .zero
    }
}

private struct ScoreReviewRowState {
    var subtitle: String
    var leadingIconName: String
    var leadingIconColor: Color
    var leadingIconFilled: Bool
    var scorecardAsset: StorageAsset?
    var isProxyHighlight: Bool
}
