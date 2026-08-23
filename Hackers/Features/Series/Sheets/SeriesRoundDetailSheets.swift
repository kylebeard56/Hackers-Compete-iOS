//
//  SeriesRoundDetailSheets.swift
//  Hackers
//

import AlertToast
import SkeletonUI
import SwiftUI
import UIKit

struct SeriesRoundAwardsDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSession: AppSession

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    @State private var matchupOutcomes: [SeriesMatchupOutcome] = []
    @State private var outcomeNarrative: SeriesRoundOutcomeNarrative?
    @State private var isOutcomeNarrativeLoading = false
    @State private var showOutcomeCopiedToast = false

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

                    outcomeParagraphSection

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
        .toast(isPresenting: $showOutcomeCopiedToast) { .completeTile("Outcome paragraph copied") }
        .task(id: seriesRound.id) {
            isOutcomeNarrativeLoading = true
            let participantID = await viewModel.viewerParticipantID(for: seriesRound, appSession: appSession)
            async let outcomes = viewModel.matchupOutcomes(for: seriesRound, promotingParticipantID: participantID)
            async let narrative = viewModel.roundOutcomeNarrative(for: seriesRound)
            matchupOutcomes = await outcomes
            outcomeNarrative = await narrative
            isOutcomeNarrativeLoading = false
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

                    ForEach(matchupOutcomes, id: \.id) { outcome in
                        SeriesAwardMatchupOutcomeCard(
                            outcome: outcome,
                            matchIndex: outcome.matchIndex,
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

    private var outcomeParagraphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outcome Paragraph".uppercased())
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Text("Generated from this round's scores and Series handicap history.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer(minLength: 0)

                if let paragraph = outcomeNarrative?.paragraph {
                    Button {
                        Haptics.fire(.light)
                        UIPasteboard.general.string = paragraph
                        showOutcomeCopiedToast = true
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .fontStyle(kFontName, size: 13, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentGreen.opacity(colorScheme.translucent))
                    .cornerRadius(10)
                }
            }

            if isOutcomeNarrativeLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.accentGreen)
                    Text("Generating outcome paragraph...")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                .padding(.vertical, 4)
            } else if let paragraph = outcomeNarrative?.paragraph {
                Text(markdownAttributedString(paragraph))
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.cardEmbeddedRowBackground)
                    .cornerRadius(14)
            } else {
                Text("Outcome paragraph will appear once the completed round scores and snapshot are available.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func markdownAttributedString(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
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
        if award.awardTrack == .team, award.competitorType == .team {
            return teamMemberNamesSubtitle(for: award.competitorID)
                ?? award.source.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }

        if let reason = award.reason, reason.isPopulated, !reason.looksLikeOpaqueAwardReasonID {
            return reason
        }
        return award.source.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func teamMemberNamesSubtitle(for teamID: String) -> String? {
        let names = viewModel.eligibleMembers
            .filter { $0.teamID == teamID }
            .map { $0.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(\.isPopulated)

        guard names.isPopulated else { return nil }
        return names.joined(separator: ", ")
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

            if outcome.showsSubstituteScoringFootnote {
                Text("* Substitute players don't count towards competitive scoring")
                    .fontStyle(kFontName, size: 11, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                        .layoutPriority(1)

                    if outcome.showsResultChip && isWinner {
                        resultChip(outcome.resultChipLabel ?? "Winner", tint: accent)
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
                HStack(spacing: 1) {
                    Text(player.name)
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(player.scoreCounts ? palette.foregroundColor : Color.neutral2)
                        .lineLimit(1)
                    if player.isSubstitute {
                        Text("*")
                            .fontStyle(kFontName, size: 13, weight: .medium)
                            .foregroundStyle(player.scoreCounts ? palette.foregroundColor : Color.neutral2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if player.scoreCounts || player.isSubstitute {
                    Circle()
                        .fill(player.isSubstitute ? Color.clear : (player.accentColor ?? Color.accentGreen))
                        .overlay(Circle().stroke(player.accentColor ?? Color.accentGreen, lineWidth: player.isSubstitute ? 1.5 : 0))
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
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
    }
}

private extension SeriesMatchupOutcome.Player {
    var netLabel: String {
        net ?? "—"
    }
}

struct SeriesRoundTeeSheetPreviewSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var membersByID: [String: SeriesMember] {
        Dictionary(uniqueKeysWithValues: viewModel.eligibleMembers.map { ($0.id, $0) })
    }

    private var teamsByID: [String: SeriesTeam] {
        Dictionary(uniqueKeysWithValues: viewModel.sortedTeams.map { ($0.id, $0) })
    }

    private var courseSelection: SeriesCourseSelection? {
        seriesRound.resolvedCourse(using: viewModel.series)
    }

    private var plannedStructure: SeriesRoundPlannedStructure {
        SeriesRoundPlanningService.resolvedPlannedStructure(
            series: viewModel.series,
            seriesRound: seriesRound,
            members: viewModel.eligibleMembers,
            teams: viewModel.sortedTeams,
            pods: viewModel.sortedPods,
            courseSelection: courseSelection
        )
    }

    private var partnershipPlans: [SeriesRoundPartnershipPlan] {
        SeriesRoundCreationMapping.resolvedPartnershipPlans(
            seriesRound: seriesRound,
            teams: viewModel.sortedTeams,
            pods: viewModel.sortedPods,
            members: viewModel.eligibleMembers
        )
    }

    private var sortedGroups: [SeriesRoundPlannedTeeGroup] {
        plannedStructure.teeGroups.sorted { $0.index < $1.index }
    }

    private var visibleMatchups: [SeriesRoundPlannedMatchup] {
        plannedStructure.matchups.sorted { $0.matchupPlan.index < $1.matchupPlan.index }
    }

    private var unassignedMembers: [SeriesMember] {
        let assigned = Set(sortedGroups.flatMap(\.memberIDs))
        return viewModel.eligibleMembers
            .filter { !assigned.contains($0.id) }
            .sorted { $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Tee Sheet",
                subtitle: seriesRound.title.isPopulated ? seriesRound.title : "Round \(seriesRound.index + 1)",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    summarySection
                    teeGroupsSection
                    if visibleMatchups.isPopulated {
                        matchupsSection
                    }
                    if unassignedMembers.isPopulated {
                        unassignedSection
                    }
                    Spacer(minLength: 0)
                        .frame(height: 24)
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private var summarySection: some View {
        SeriesSheetCard(palette: palette) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(courseSelection?.cachedName ?? "Course TBD")
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    if let scheduledAt = seriesRound.scheduledAt {
                        Text(Date(timeIntervalSince1970: scheduledAt.unix).formatted(date: .abbreviated, time: .shortened))
                            .fontStyle(kFontName, size: 13, weight: .medium)
                            .foregroundStyle(Color.neutral)
                    }
                }

                Spacer(minLength: 0)

                Chip(
                    text: "\(sortedGroups.count) groups",
                    size: .xSmall,
                    foreground: Color.accentGreen,
                    background: Color.accentGreen.opacity(colorScheme.translucent)
                )
            }
        }
    }

    private var teeGroupsSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Tee Groups")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            if sortedGroups.isEmpty {
                Text("No tee groups have been set yet.")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedGroups) { group in
                        teeGroupCard(group)
                    }
                }
            }
        }
    }

    private var matchupsSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Matchups")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            VStack(spacing: 10) {
                ForEach(visibleMatchups) { matchup in
                    SeriesSheetRow(palette: palette) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Match \(matchup.matchupPlan.index + 1)")
                                .fontStyle(kFontName, size: 12, weight: .semibold)
                                .foregroundStyle(Color.neutral)
                            Text(matchupLabel(for: matchup.matchupPlan))
                                .fontStyle(kFontName, size: 14, weight: .semibold)
                                .foregroundStyle(palette.foregroundColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var unassignedSection: some View {
        SeriesSheetCard(palette: palette) {
            Text("Unassigned")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            VStack(spacing: 8) {
                ForEach(unassignedMembers, id: \.id) { member in
                    playerRow(memberID: member.id)
                }
            }
        }
    }

    private func teeGroupCard(_ group: SeriesRoundPlannedTeeGroup) -> some View {
        SeriesSheetRow(palette: palette, rowBackground: palette.cardNestedGroupBackground) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Group \(group.index + 1)")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text(groupSubtitle(group))
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.neutral)
                    }

                    Spacer(minLength: 0)

                    Chip(
                        text: "Hole \(group.startingHole)",
                        size: .xSmall,
                        foreground: palette.foregroundColor,
                        background: palette.cardEmbeddedRowBackground
                    )
                }

                if group.seats.isEmpty {
                    Text("No players assigned yet.")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                } else {
                    VStack(spacing: 8) {
                        ForEach(group.seats.sorted { $0.teeOrder < $1.teeOrder }) { seat in
                            playerRow(memberID: seat.memberID, teeOrder: seat.teeOrder, seat: seat)
                        }
                    }
                }
            }
        }
    }

    private func playerRow(memberID: String, teeOrder: Int? = nil, seat: SeriesRoundPlannedSeat? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let teeOrder {
                teeOrderBadge(teeOrder)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    playerTeamDot(memberID: memberID, seat: seat)

                    Text(playerName(for: memberID))
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                }

                let metadata = playerMetadata(for: memberID, seat: seat)
                if metadata.isPopulated {
                    Text(metadata)
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(palette.cardEmbeddedRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func playerTeamDot(memberID: String, seat: SeriesRoundPlannedSeat? = nil) -> some View {
        let isSubstitute = seat.map(isSubstituteSeat) ?? (membersByID[memberID]?.role == .substitute)
        if let teamID = effectiveTeamID(memberID: memberID, seat: seat),
           let team = teamsByID[teamID] {
            Circle()
                .fill(isSubstitute ? Color.clear : (team.displaySwatchColor ?? Color.neutral4))
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(team.displaySwatchColor ?? Color.neutral4, lineWidth: isSubstitute ? 1.5 : 1))
                .accessibilityHidden(true)
        } else if viewModel.hasTeams {
            Circle()
                .strokeBorder(Color.neutral4, lineWidth: 1.5)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
    }

    private func teeOrderBadge(_ teeOrder: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.neutral.opacity(0.18))
            Text("\(teeOrder)")
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 24, height: 24)
    }

    private func groupSubtitle(_ group: SeriesRoundPlannedTeeGroup) -> String {
        if let teeTime = group.teeTime, teeTime.isPopulated {
            return teeTime.formattedTeeTime
        }
        return "\(group.seats.count) players"
    }

    private func playerName(for memberID: String) -> String {
        guard let name = membersByID[memberID]?.name.trimmedFullName, name.isPopulated else {
            return "Unknown player"
        }
        return name
    }

    private func playerMetadata(for memberID: String, seat: SeriesRoundPlannedSeat? = nil) -> String {
        var components: [String] = []
        if let subtitle = substituteSubtitle(for: seat) {
            components.append(subtitle)
        }
        if let teamID = effectiveTeamID(memberID: memberID, seat: seat),
           let teamName = teamsByID[teamID]?.name,
           teamName.isPopulated {
            components.append(teamName)
        }
        if viewModel.series.handicapConfig.isEnabled,
           let handicap = handicapText(for: memberID) {
            components.append("HCP \(handicap)")
        }
        return components.joined(separator: " \(kDot) ")
    }

    private func effectiveTeamID(memberID: String, seat: SeriesRoundPlannedSeat? = nil) -> String? {
        if let representedTeamID = seat?.representedTeamID, representedTeamID.isPopulated {
            return representedTeamID
        }
        return membersByID[memberID]?.teamID
    }

    private func isSubstituteSeat(_ seat: SeriesRoundPlannedSeat) -> Bool {
        seat.isSubstitute || membersByID[seat.memberID]?.role == .substitute
    }

    private func substituteSubtitle(for seat: SeriesRoundPlannedSeat?) -> String? {
        guard let seat,
              isSubstituteSeat(seat),
              let name = seat.substituteForName,
              name.isPopulated else { return nil }
        return "Playing for \(name)"
    }

    private func handicapText(for memberID: String) -> String? {
        guard let handicap = viewModel.effectiveHandicap(for: memberID), handicap.isFinite else { return nil }
        let rounded = handicap.rounded(.toNearestOrAwayFromZero)
        if abs(handicap - rounded) < 0.05 {
            return String(Int(rounded))
        }
        let oneDecimal = String(format: "%.1f", handicap)
        return oneDecimal.hasSuffix(".0") ? String(oneDecimal.dropLast(2)) : oneDecimal
    }

    private func matchupLabel(for plan: SeriesRoundMatchupPlan) -> String {
        if plan.validTeamPairing {
            return "\(teamName(for: plan.teamAID, fallback: "Team A")) vs \(teamName(for: plan.teamBID, fallback: "Team B"))"
        }
        if let pairAID = plan.pairAID,
           let pairBID = plan.pairBID {
            return "\(pairName(for: pairAID)) vs \(pairName(for: pairBID))"
        }
        if let memberAID = plan.memberAID,
           let memberBID = plan.memberBID {
            return "\(playerName(for: memberAID)) vs \(playerName(for: memberBID))"
        }
        return "Incomplete matchup"
    }

    private func teamName(for teamID: String, fallback: String) -> String {
        let name = teamsByID[teamID]?.name
        return name?.isPopulated == true ? name! : fallback
    }

    private func pairName(for pairID: String) -> String {
        guard let plan = partnershipPlans.first(where: { $0.id == pairID }) else { return "Pair" }
        let names = plan.memberIDs.map { playerName(for: $0) }
        return names.isPopulated ? names.joined(separator: " + ") : "Pair"
    }
}

enum ScoreCorrectionEditorMode: String, CaseIterable {
    case holeByHole = "Hole by hole"
    case totalGross = "Total gross"
}

enum SeriesRoundHandicapRepairMethod: String, CaseIterable {
    case courseHandicapOverride = "Course HCP"
    case calculateFromIndex = "Index + tee"
}

struct SeriesRoundHandicapRepairDraft: Hashable {
    var method: SeriesRoundHandicapRepairMethod
    var handicapIndexText: String
    var teeBoxID: String
    var courseHandicapText: String
}

struct SeriesRoundScoreCorrectionSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    let initialSeriesMemberID: String?
    let initialParticipantID: String?
    let initialEditorMode: ScoreCorrectionEditorMode

    @State private var context: SeriesRoundCorrectionContext?
    @State private var searchText = ""
    @State private var selectedParticipant: RoundParticipant?
    @State private var draftScores: [String: Int] = [:]
    @State private var grossTargets: [String: String] = [:]
    @State private var editorModes: [String: ScoreCorrectionEditorMode] = [:]
    @State private var handicapDrafts: [String: SeriesRoundHandicapRepairDraft] = [:]
    @State private var reason = ""
    @State private var showDiscardConfirmation = false

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
        self.initialEditorMode = initialEditorMode
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: "Repair Round",
                subtitle: "Review players, collect changes, then save once.",
                onClose: requestDismiss
            )

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    if let context {
                        overview(context)
                        searchField
                        playersCard(context)
                        reasonCard
                    } else if viewModel.correctingRoundID == seriesRound.id {
                        ProgressView()
                            .tint(Color.accentGreen)
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        unavailableCard
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let context {
                saveBar(context)
            }
        }
        .task {
            guard context == nil else { return }
            guard let loaded = await viewModel.loadCorrectionContext(for: seriesRound) else {
                return
            }
            context = loaded
            grossTargets = Dictionary(uniqueKeysWithValues: loaded.snapshot.participants.map {
                ($0.id, String(originalGross($0, context: loaded)))
            })
            handicapDrafts = Dictionary(uniqueKeysWithValues: loaded.snapshot.participants.map {
                (
                    $0.id,
                    SeriesRoundHandicapRepairDraft(
                        method: .courseHandicapOverride,
                        handicapIndexText: $0.handicapIndex.map { String(format: "%.1f", $0) } ?? "",
                        teeBoxID: $0.teeBoxID,
                        courseHandicapText: String($0.adjustedHandicap)
                    )
                )
            })
            if let initialParticipantID {
                editorModes[initialParticipantID] = initialEditorMode
                selectedParticipant = loaded.snapshot.participants.first { $0.id == initialParticipantID }
            } else if let initialSeriesMemberID,
                      let participantID = viewModel.preferredRoundParticipantID(
                        seriesMemberID: initialSeriesMemberID,
                        snapshot: loaded.snapshot
                      ) {
                editorModes[participantID] = initialEditorMode
                selectedParticipant = loaded.snapshot.participants.first { $0.id == participantID }
            }
        }
        .sheet(item: $selectedParticipant) { participant in
            if let context {
                SeriesRoundPlayerRepairSheet(
                    participant: participant,
                    context: context,
                    draftScores: $draftScores,
                    grossTargets: $grossTargets,
                    editorModes: $editorModes,
                    handicapDrafts: $handicapDrafts
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .alert(
            "Correction not published",
            isPresented: Binding(
                get: { viewModel.scoreCorrectionErrorMessage != nil },
                set: { if !$0 { viewModel.scoreCorrectionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.scoreCorrectionErrorMessage = nil
            }
        } message: {
            Text(viewModel.scoreCorrectionErrorMessage ?? "")
        }
        .confirmationDialog(
            "Discard unsaved round repairs?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Score, handicap, and tee drafts have not been applied.")
        }
    }

    private func overview(_ context: SeriesRoundCorrectionContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Chip(
                    text: "Signed round stays complete",
                    size: .xSmall,
                    foreground: .accentGreen,
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
            Text("Score, tee, and frozen Course HCP repairs stay in draft until Save & Recompute.")
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.neutral)
            TextField("Search players", text: $searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
            if searchText.isPopulated {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.neutral)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear player search")
            }
        }
        .padding(14)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func playersCard(_ context: SeriesRoundCorrectionContext) -> some View {
        let players = filteredParticipants(context)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Players".uppercased())
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Spacer()
                Text("\(players.count) of \(context.snapshot.participants.count)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            if players.isEmpty {
                Text("No players match “\(searchText)”.")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(players, id: \.id) { participant in
                    playerRow(participant, context: context)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func playerRow(
        _ participant: RoundParticipant,
        context: SeriesRoundCorrectionContext
    ) -> some View {
        Button {
            Haptics.fire(.light)
            selectedParticipant = participant
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(participant.name.fullName)
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if changedParticipantIDs(context).contains(participant.id) {
                        Chip(
                            text: "Unsaved",
                            size: .tiny,
                            foreground: .orange,
                            background: Color.orange.opacity(colorScheme.translucent)
                        )
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.neutral)
                }
                HStack(spacing: 8) {
                    metric("Gross", "\(displayedGross(participant, context: context))")
                    metric("Course HCP", "\(displayedCourseHandicap(participant, context: context))")
                    metric(
                        "Holes",
                        "\(displayedHolesScored(participant, context: context))/\(context.holes.count)"
                    )
                }
                Text(teeLabel(participant, context: context))
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardEmbeddedRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(participant.name.fullName), gross \(displayedGross(participant, context: context)), "
                + "Course handicap \(displayedCourseHandicap(participant, context: context)), "
                + "\(displayedHolesScored(participant, context: context)) of \(context.holes.count) holes scored"
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .regular)
                .foregroundStyle(Color.neutral)
            Text(value)
                .fontStyle(.system, size: 14, weight: .semibold, design: .rounded)
                .foregroundStyle(palette.foregroundColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(palette.cardColor.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adjustment Note".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            TextField("Why is this round being repaired?", text: $reason, axis: .vertical)
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .padding(14)
                .background(palette.cardEmbeddedRowBackground)
                .cornerRadius(16)
                .lineLimit(2...4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func saveBar(_ context: SeriesRoundCorrectionContext) -> some View {
        let changedCount = changedParticipantIDs(context).count
        return VStack(spacing: 8) {
            HStack {
                Text(changedCount == 1 ? "1 player changed" : "\(changedCount) players changed")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(changedCount > 0 ? Color.orange : Color.neutral)
                Spacer()
                if hasInvalidHandicapDraft(context) {
                    Text("Finish handicap inputs")
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(Color.systemError)
                }
            }
            Button {
                Task {
                    let saved = await viewModel.applyScoreCorrections(
                        for: context.seriesRound,
                        changes: pendingScoreChanges(context),
                        participantChanges: pendingHandicapChanges(context),
                        reason: reason
                    )
                    if saved { dismiss() }
                }
            } label: {
                Group {
                    if viewModel.correctingRoundID == seriesRound.id {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save & Recompute")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canSave(context) ? Color.accentGreen : Color.neutral3)
                .clipShape(Capsule())
            }
            .disabled(!canSave(context) || viewModel.correctingRoundID == seriesRound.id)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round data unavailable")
                .fontStyle(kFontName, size: 18, weight: .semibold)
            Text("We couldn’t load the linked round’s players and scores.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(palette.cardColor)
        .cornerRadius(20)
    }

    private func canSave(_ context: SeriesRoundCorrectionContext) -> Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).isPopulated
            && !hasInvalidHandicapDraft(context)
            && changedParticipantIDs(context).isPopulated
    }

    private func filteredParticipants(_ context: SeriesRoundCorrectionContext) -> [RoundParticipant] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return context.snapshot.participants
            .filter { query.isEmpty || $0.name.fullName.localizedCaseInsensitiveContains(query) }
            .sorted {
                $0.name.fullName.localizedCaseInsensitiveCompare($1.name.fullName) == .orderedAscending
            }
    }

    private func draftKey(_ participantID: String, _ holeNumber: Int) -> String {
        "\(participantID)_\(holeNumber)"
    }

    private func displayedScore(
        _ participantID: String,
        holeNumber: Int,
        context: SeriesRoundCorrectionContext
    ) -> Int? {
        if let value = draftScores[draftKey(participantID, holeNumber)] {
            return value == 0 ? nil : value
        }
        return context.entriesByParticipantID[participantID]?[holeNumber]?.strokes
    }

    private func originalGross(
        _ participant: RoundParticipant,
        context: SeriesRoundCorrectionContext
    ) -> Int {
        context.holes.reduce(0) {
            $0 + (context.entriesByParticipantID[participant.id]?[$1.number]?.strokes ?? $1.par)
        }
    }

    private func displayedGross(
        _ participant: RoundParticipant,
        context: SeriesRoundCorrectionContext
    ) -> Int {
        if editorModes[participant.id] == .totalGross,
           let target = grossTargets[participant.id].flatMap(Int.init) {
            return target
        }
        return context.holes.reduce(0) {
            $0 + (displayedScore(participant.id, holeNumber: $1.number, context: context) ?? 0)
        }
    }

    private func displayedHolesScored(
        _ participant: RoundParticipant,
        context: SeriesRoundCorrectionContext
    ) -> Int {
        if editorModes[participant.id] == .totalGross,
           pendingScoreChanges(context).contains(where: { $0.participantID == participant.id }) {
            return context.holes.count
        }
        return context.holes.filter {
            displayedScore(participant.id, holeNumber: $0.number, context: context) != nil
        }.count
    }

    private func pendingScoreChanges(
        _ context: SeriesRoundCorrectionContext
    ) -> [SeriesScoreCorrectionChange] {
        context.snapshot.participants.flatMap { participant -> [SeriesScoreCorrectionChange] in
            if editorModes[participant.id] == .totalGross {
                guard context.supportsTotalGrossCorrection,
                      let target = grossTargets[participant.id].flatMap(Int.init) else {
                    return []
                }
                return viewModel.commissionerGrossCorrectionChanges(
                    context: context,
                    participantID: participant.id,
                    targetGross: target,
                    draftScores: draftScores
                ) ?? []
            }
            return context.holes.compactMap { hole in
                let original = context.entriesByParticipantID[participant.id]?[hole.number]?.strokes
                let updated = displayedScore(participant.id, holeNumber: hole.number, context: context)
                guard original != updated else { return nil }
                return .init(participantID: participant.id, holeNumber: hole.number, strokes: updated)
            }
        }
    }

    private func pendingHandicapChanges(
        _ context: SeriesRoundCorrectionContext
    ) -> [SeriesParticipantHandicapCorrectionChange] {
        context.snapshot.participants.compactMap {
            handicapChange($0, draft: handicapDrafts[$0.id], context: context)
        }
    }

    private func handicapChange(
        _ participant: RoundParticipant,
        draft: SeriesRoundHandicapRepairDraft?,
        context: SeriesRoundCorrectionContext
    ) -> SeriesParticipantHandicapCorrectionChange? {
        guard let draft else { return nil }
        switch draft.method {
        case .calculateFromIndex:
            guard let index = Double(draft.handicapIndexText),
                  let resolution = calculatedResolution(
                    participant,
                    draft: draft,
                    context: context
                  ),
                  let tee = resolution.tee else { return nil }
            guard resolution.validationIssue == nil,
                  let courseHandicap = resolution.effectiveStrokes,
                  let frozenSnapshot = resolution.snapshot(
                    selectedHandicapScoreIDs: Set(
                        participant.handicapSnapshot?.selectedHandicapScoreIDs ?? []
                    ),
                    source: .commissionerRepair
                  ),
                  participant.teeBoxID != tee.id
                    || participant.handicapIndex != index
                    || participant.adjustedHandicap != courseHandicap
                    || participant.leagueHandicapStrokesAtCreation != courseHandicap else {
                return nil
            }
            return .init(
                participantID: participant.id,
                teeBoxID: tee.id,
                handicapIndex: index,
                courseHandicap: courseHandicap,
                snapshot: frozenSnapshot
            )
        case .courseHandicapOverride:
            guard let courseHandicap = Int(draft.courseHandicapText), courseHandicap >= 0,
                  participant.teeBoxID != draft.teeBoxID
                    || participant.adjustedHandicap != courseHandicap
                    || participant.leagueHandicapStrokesAtCreation != courseHandicap else {
                return nil
            }
            let tee = context.snapshot.tees.first { $0.id == draft.teeBoxID }
            let old = participant.handicapSnapshot
            let segment = context.snapshot.holeSegment
            let frozenSnapshot = RoundParticipantHandicapSnapshot(
                authoritativeCourseHandicap: courseHandicap,
                handicapIndex: participant.handicapIndex,
                effectiveStrokes: courseHandicap,
                courseID: context.snapshot.courseInfo?.id ?? old?.courseID ?? "",
                courseName: context.snapshot.courseInfo?.name ?? old?.courseName ?? "",
                teeBoxID: draft.teeBoxID,
                teeName: tee?.name ?? old?.teeName ?? draft.teeBoxID,
                teeGender: tee?.gender ?? old?.teeGender ?? "",
                holeSegment: segment,
                courseRating: tee?.rating(for: segment) ?? old?.courseRating,
                courseSlope: tee?.slope(for: segment) ?? old?.courseSlope,
                par: tee?.par(for: segment) ?? old?.par
                    ?? context.holes.reduce(0) { $0 + $1.par },
                handicapStrokeBasis: context.snapshot.handicapStrokeBasis,
                maximumHandicap: context.snapshot.configuration.leagueHandicapMaximum,
                entryFormat: .courseHandicap,
                calculatorFingerprint: "commissioner-course-hcp-override-v1|\(courseHandicap)|\(draft.teeBoxID)",
                selectedHandicapScoreIDs: old?.selectedHandicapScoreIDs ?? [],
                calculatedAt: .init(),
                source: .commissionerRepair
            )
            return .init(
                participantID: participant.id,
                teeBoxID: draft.teeBoxID,
                handicapIndex: participant.handicapIndex,
                courseHandicap: courseHandicap,
                snapshot: frozenSnapshot
            )
        }
    }

    private func hasInvalidHandicapDraft(_ context: SeriesRoundCorrectionContext) -> Bool {
        context.snapshot.participants.contains { participant in
            guard let draft = handicapDrafts[participant.id] else { return false }
            switch draft.method {
            case .courseHandicapOverride:
                let changed = participant.teeBoxID != draft.teeBoxID
                    || draft.courseHandicapText != String(participant.adjustedHandicap)
                return changed && (Int(draft.courseHandicapText).map { $0 >= 0 } != true)
            case .calculateFromIndex:
                return calculatedResolution(participant, draft: draft, context: context)?
                    .effectiveStrokes == nil
            }
        }
    }

    private func displayedCourseHandicap(
        _ participant: RoundParticipant,
        context: SeriesRoundCorrectionContext
    ) -> Int {
        guard let draft = handicapDrafts[participant.id] else { return participant.adjustedHandicap }
        if draft.method == .courseHandicapOverride {
            return Int(draft.courseHandicapText) ?? participant.adjustedHandicap
        }
        return calculatedResolution(participant, draft: draft, context: context)?
            .effectiveStrokes ?? participant.adjustedHandicap
    }

    private func calculatedResolution(
        _ participant: RoundParticipant,
        draft: SeriesRoundHandicapRepairDraft,
        context: SeriesRoundCorrectionContext
    ) -> SeriesCourseHandicapResolution? {
        guard let index = Double(draft.handicapIndexText),
              let course = context.snapshot.courseSegment,
              let tee = course.tee(from: draft.teeBoxID) else {
            return nil
        }
        return SeriesCourseHandicapResolver.resolve(
            effectiveIndex: index,
            memberID: participant.seriesMemberID ?? participant.id,
            memberName: participant.name.fullName,
            requestedTeeID: tee.id,
            tee: tee,
            courseID: course.courseInfo.id,
            courseName: course.courseInfo.name,
            holeSegment: course.holeSegment,
            entryFormat: .courseHandicap,
            handicapStrokeBasis: context.snapshot.handicapStrokeBasis,
            maximumHandicap: context.snapshot.configuration.leagueHandicapMaximum
        )
    }

    private func teeLabel(
        _ participant: RoundParticipant,
        context: SeriesRoundCorrectionContext
    ) -> String {
        let teeID = handicapDrafts[participant.id]?.teeBoxID ?? participant.teeBoxID
        guard let tee = context.snapshot.tees.first(where: { $0.id == teeID }) else {
            return "Tee: \(teeID.isPopulated ? teeID : "Unavailable")"
        }
        return "Tee: \(tee.name) · \(tee.gender.capitalized)"
    }

    private func changedParticipantIDs(_ context: SeriesRoundCorrectionContext) -> Set<String> {
        Set(pendingScoreChanges(context).map(\.participantID))
            .union(pendingHandicapChanges(context).map(\.participantID))
    }

    private func requestDismiss() {
        guard let context, changedParticipantIDs(context).isPopulated else {
            dismiss()
            return
        }
        showDiscardConfirmation = true
    }
}

struct SeriesRoundPlayerRepairSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let participant: RoundParticipant
    let context: SeriesRoundCorrectionContext
    @Binding var draftScores: [String: Int]
    @Binding var grossTargets: [String: String]
    @Binding var editorModes: [String: ScoreCorrectionEditorMode]
    @Binding var handicapDrafts: [String: SeriesRoundHandicapRepairDraft]

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var mode: ScoreCorrectionEditorMode {
        editorModes[participant.id] ?? .holeByHole
    }
    private var handicapDraft: SeriesRoundHandicapRepairDraft {
        handicapDrafts[participant.id] ?? .init(
            method: .courseHandicapOverride,
            handicapIndexText: participant.handicapIndex.map { String(format: "%.1f", $0) } ?? "",
            teeBoxID: participant.teeBoxID,
            courseHandicapText: String(participant.adjustedHandicap)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            SeriesSheetHeader(
                palette: palette,
                title: participant.name.fullName,
                subtitle: "Changes stay in the repair batch until you save.",
                onClose: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    summaryCard
                    scoreCard
                    handicapCard
                }
                .padding(16)
            }
            .background(palette.backgroundColor)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Done") { dismiss() }
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentGreen)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .padding(16)
                .background(.ultraThinMaterial)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 10) {
            summaryMetric("Gross", "\(currentGross)")
            summaryMetric("Course HCP", "\(displayedCourseHandicap)")
            summaryMetric("Holes scored", "\(holesScored)/\(context.holes.count)")
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func summaryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .regular)
                .foregroundStyle(Color.neutral)
            Text(value)
                .fontStyle(.system, size: 17, weight: .semibold, design: .rounded)
                .foregroundStyle(palette.foregroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Picker(
                "Score correction method",
                selection: Binding(
                    get: { mode },
                    set: { editorModes[participant.id] = $0 }
                )
            ) {
                ForEach(ScoreCorrectionEditorMode.allCases, id: \.self) { option in
                    Text(option.rawValue)
                        .tag(option)
                        .disabled(option == .totalGross && !context.supportsTotalGrossCorrection)
                }
            }
            .pickerStyle(.segmented)

            if mode == .totalGross {
                totalGrossEditor
            } else {
                VStack(spacing: 10) {
                    ForEach(context.holes, id: \.number) { hole in
                        holeScoreRow(hole)
                    }
                }
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var totalGrossEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if context.supportsTotalGrossCorrection {
                Text("The total is distributed deterministically across the round. Use hole-by-hole when individual holes matter.")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                TextField(
                    "Gross score",
                    text: Binding(
                        get: { grossTargets[participant.id] ?? "" },
                        set: { grossTargets[participant.id] = $0 }
                    )
                )
                .keyboardType(.numberPad)
                .fontStyle(.system, size: 24, weight: .semibold, design: .rounded)
                .foregroundStyle(palette.foregroundColor)
                .padding(14)
                .background(palette.cardEmbeddedRowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("This scoring format requires physical hole-by-hole scores.")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(Color.systemError)
            }
        }
    }

    private func holeScoreRow(_ hole: Hole) -> some View {
        let score = displayedScore(hole.number)
        let original = context.entriesByParticipantID[participant.id]?[hole.number]?.strokes
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hole \(hole.number)")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text("Par \(hole.par)")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            Spacer(minLength: 2)
            scoreButton("minus") { adjustScore(hole, by: -1) }
            Text(score.map(String.init) ?? "—")
                .fontStyle(.system, size: 17, weight: .semibold, design: .rounded)
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 30)
            scoreButton("plus") { adjustScore(hole, by: 1) }
            Button("Clear") { setDraftScore(nil, hole: hole.number) }
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.systemError)
                .frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain)
            if score != original {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel("Edited")
            }
        }
        .padding(12)
        .background(palette.cardEmbeddedRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func scoreButton(
        _ systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 44, height: 44)
                .background(Color.neutral6)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var handicapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round Handicap".uppercased())
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Text("This changes only the handicap and tee frozen for this historical round.")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)

            Picker(
                "Handicap correction method",
                selection: Binding(
                    get: { handicapDraft.method },
                    set: { value in updateHandicapDraft { $0.method = value } }
                )
            ) {
                ForEach(SeriesRoundHandicapRepairMethod.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            teePicker

            if handicapDraft.method == .courseHandicapOverride {
                directHandicapEditor
            } else {
                indexHandicapEditor
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var teePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tee used")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            Picker(
                "Tee used",
                selection: Binding(
                    get: { handicapDraft.teeBoxID },
                    set: { value in updateHandicapDraft { $0.teeBoxID = value } }
                )
            ) {
                if !context.snapshot.tees.contains(where: { $0.id == handicapDraft.teeBoxID }) {
                    Text("Unknown tee · \(handicapDraft.teeBoxID)")
                        .tag(handicapDraft.teeBoxID)
                }
                ForEach(
                    context.snapshot.tees.sortedByDifficulty(for: context.snapshot.holeSegment),
                    id: \.id
                ) { tee in
                    Text("\(tee.name) · \(tee.gender.capitalized)")
                        .tag(tee.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.accentGreen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.cardEmbeddedRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var directHandicapEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Course HCP used")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            TextField(
                "Course HCP",
                text: Binding(
                    get: { handicapDraft.courseHandicapText },
                    set: { value in updateHandicapDraft { $0.courseHandicapText = value } }
                )
            )
            .keyboardType(.numberPad)
            .fontStyle(.system, size: 22, weight: .semibold, design: .rounded)
            .foregroundStyle(palette.foregroundColor)
            .padding(14)
            .background(palette.cardEmbeddedRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("The entered Course HCP is authoritative. Changing the tee does not silently recalculate it.")
                .fontStyle(kFontName, size: 11, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private var indexHandicapEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Handicap Index before this round")
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(Color.neutral)
            TextField(
                "Handicap Index",
                text: Binding(
                    get: { handicapDraft.handicapIndexText },
                    set: { value in updateHandicapDraft { $0.handicapIndexText = value } }
                )
            )
            .keyboardType(.decimalPad)
            .fontStyle(.system, size: 22, weight: .semibold, design: .rounded)
            .foregroundStyle(palette.foregroundColor)
            .padding(14)
            .background(palette.cardEmbeddedRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let tee = selectedTee,
               let courseHandicap = calculatedResolution?.effectiveStrokes {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Calculated Course HCP \(courseHandicap)")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                    Text(calculationMetadata(tee))
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentGreen.opacity(colorScheme.translucent))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("A valid index and tee rating, slope, and par are required.")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.systemError)
            }
        }
    }

    private var selectedTee: Tee? {
        context.snapshot.tees.first { $0.id == handicapDraft.teeBoxID }
    }

    private var currentGross: Int {
        if mode == .totalGross,
           let value = grossTargets[participant.id].flatMap(Int.init) {
            return value
        }
        return context.holes.reduce(0) {
            $0 + (displayedScore($1.number) ?? 0)
        }
    }

    private var holesScored: Int {
        mode == .totalGross
            ? context.holes.count
            : context.holes.filter { displayedScore($0.number) != nil }.count
    }

    private var displayedCourseHandicap: Int {
        if handicapDraft.method == .courseHandicapOverride {
            return Int(handicapDraft.courseHandicapText) ?? participant.adjustedHandicap
        }
        return calculatedResolution?.effectiveStrokes ?? participant.adjustedHandicap
    }

    private var calculatedResolution: SeriesCourseHandicapResolution? {
        guard let index = Double(handicapDraft.handicapIndexText),
              let course = context.snapshot.courseSegment,
              let tee = course.tee(from: handicapDraft.teeBoxID) else {
            return nil
        }
        return SeriesCourseHandicapResolver.resolve(
            effectiveIndex: index,
            memberID: participant.seriesMemberID ?? participant.id,
            memberName: participant.name.fullName,
            requestedTeeID: tee.id,
            tee: tee,
            courseID: course.courseInfo.id,
            courseName: course.courseInfo.name,
            holeSegment: course.holeSegment,
            entryFormat: .courseHandicap,
            handicapStrokeBasis: context.snapshot.handicapStrokeBasis,
            maximumHandicap: context.snapshot.configuration.leagueHandicapMaximum
        )
    }

    private func calculationMetadata(_ tee: Tee) -> String {
        let segment = context.snapshot.holeSegment
        let rating = tee.prettyRating(for: segment) ?? "missing rating"
        let slope = tee.slope(for: segment).map(String.init) ?? "missing slope"
        return "\(tee.name) · \(segment.title) · rating \(rating) · slope \(slope) · par \(tee.par(for: segment))"
    }

    private func updateHandicapDraft(
        _ mutation: (inout SeriesRoundHandicapRepairDraft) -> Void
    ) {
        var draft = handicapDraft
        mutation(&draft)
        handicapDrafts[participant.id] = draft
    }

    private func scoreKey(_ hole: Int) -> String {
        "\(participant.id)_\(hole)"
    }

    private func displayedScore(_ hole: Int) -> Int? {
        if let value = draftScores[scoreKey(hole)] {
            return value == 0 ? nil : value
        }
        return context.entriesByParticipantID[participant.id]?[hole]?.strokes
    }

    private func setDraftScore(_ score: Int?, hole: Int) {
        draftScores[scoreKey(hole)] = score ?? 0
    }

    private func adjustScore(_ hole: Hole, by delta: Int) {
        let current = displayedScore(hole.number) ?? hole.par
        setDraftScore(max(1, min(15, current + delta)), hole: hole.number)
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

                    if let chipTitle = scoreCompletenessChipTitle(playerID: playerID) {
                        scoreCompletenessChip(chipTitle)
                    }

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

    private func scoreCompletenessChipTitle(playerID: String) -> String? {
        guard let reviewSnapshot,
              let participantID = reviewParticipantsByPlayerID[playerID]?.id else {
            return nil
        }
        return RoundScoreCompleteness
            .classify(participantID: participantID, snapshot: reviewSnapshot)
            .reviewChipTitle
    }

    private func scoreCompletenessChip(_ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .semibold)
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentYellow)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.accentYellow.opacity(0.14))
        )
        .fixedSize(horizontal: true, vertical: false)
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
