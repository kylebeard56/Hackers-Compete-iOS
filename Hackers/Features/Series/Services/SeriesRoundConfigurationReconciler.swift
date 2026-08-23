//
//  SeriesRoundConfigurationReconciler.swift
//  Hackers
//

import Foundation

enum SeriesRoundConfigurationField: String, CaseIterable, Hashable, Sendable {
    case format
    case competition
    case teamScoring = "team_scoring"
    case scoreEntry = "score_entry"
    case matchupScoring = "matchup_scoring"
    case handicap
    case course
    case teeStarts = "tee_starts"

    var displayName: String {
        switch self {
        case .format: return "format"
        case .competition: return "competition"
        case .teamScoring: return "team scoring"
        case .scoreEntry: return "score entry"
        case .matchupScoring: return "match scoring"
        case .handicap: return "handicaps"
        case .course: return "course"
        case .teeStarts: return "tee starts"
        }
    }
}

struct SeriesRoundConfigurationDivergence: Equatable, Sendable {
    let seriesRoundID: String
    let fields: Set<SeriesRoundConfigurationField>

    var summary: String {
        fields
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: ", ")
    }
}

enum SeriesRoundConfigurationReconciler {
    static func divergence(
        series: Series,
        seriesRound: SeriesRound,
        linkedRound: Round
    ) -> SeriesRoundConfigurationDivergence? {
        guard linkedRound.status == .lobby else { return nil }

        let desired = seriesRound.roundConfig
        let linked = linkedRound.configuration
        let desiredTemplate = desired.template
        let desiredFormat = SeriesRoundCreationMapping.primaryGameFormatForRound(
            series: series,
            seriesRound: seriesRound
        )
        let linkedTemplateID = linked.formatSummary?.templateID ?? linked.activeTemplate.id
        var fields = Set<SeriesRoundConfigurationField>()

        if desiredTemplate.id != linkedTemplateID
            || desiredFormat.configuration.basis != linked.primaryFormat.configuration.basis
            || desiredFormat.configuration.maxScoreOverPar != linked.primaryFormat.configuration.maxScoreOverPar {
            fields.insert(.format)
        }
        if SeriesRoundCreationMapping.resolvedCompetitionScope(for: seriesRound) != linked.resolvedCompetitionScope {
            fields.insert(.competition)
        }
        if desired.teamScoring != linked.teamScoring {
            fields.insert(.teamScoring)
        }

        let desiredOwnerScope = desiredTemplate.scoreSource == .shared ? desired.scoreOwnerScope : .individual
        if desiredOwnerScope != linked.scoreOwnerScope || desired.selectionDomain != linked.selectionDomain {
            fields.insert(.scoreEntry)
        }
        if desired.matchupResolutionStyle != linked.matchupResolutionStyle
            || desired.matchupScoringStyle != linked.matchupScoringStyle
            || desired.resolvedHoleWinPoints != (linked.holeWinPoints ?? 1)
            || desired.resolvedMatchWinnerBonusPoints != (linked.matchWinnerBonusPoints ?? 0)
            || desired.resolvedMatchTiePolicy != (linked.matchTiePolicy ?? .half) {
            fields.insert(.matchupScoring)
        }

        if desired.handicapStrokeBasis != linked.handicapStrokeBasis
            || desired.handicapEntryFormat != linked.handicapEntryFormat
            || desired.handicapNormalizationMode != linked.handicapNormalizationMode
            || desired.sharedScoreHandicapConfig != linked.sharedScoreHandicapConfig {
            fields.insert(.handicap)
        }

        if (desired.sequentialTeeStartsEnabled ?? false) != (linked.sequentialTeeStartsEnabled ?? false) {
            fields.insert(.teeStarts)
        }

        if courseIdentity(seriesRound.resolvedCourse(using: series)) != courseIdentity(linked.courses.first) {
            fields.insert(.course)
        }

        guard fields.isPopulated else { return nil }
        return SeriesRoundConfigurationDivergence(seriesRoundID: seriesRound.id, fields: fields)
    }

    static func adoptingLinkedConfiguration(
        from linkedRound: Round,
        segment: RoundSegment?,
        preserving base: SeriesRoundConfiguration
    ) -> SeriesRoundConfiguration {
        var updated = base
        let linked = linkedRound.configuration
        updated.formatTemplateID = linked.formatSummary?.templateID
            ?? segment?.templateID
            ?? linked.activeTemplate.id
        updated.competitionScope = linked.competitionScope
        updated.teamScoring = linked.teamScoring
        updated.matchupResolutionStyle = linked.matchupResolutionStyle
        let template = FormatTemplateRegistry.template(for: updated.formatTemplateID)
        updated.scoreOwnerScope = template.scoreSource == .shared ? linked.scoreOwnerScope : .individual
        updated.matchupScoringStyle = linked.matchupScoringStyle
        updated.holeWinPoints = linked.holeWinPoints
        updated.matchWinnerBonusPoints = linked.matchWinnerBonusPoints
        updated.matchTiePolicy = linked.matchTiePolicy
        updated.selectionDomain = linked.selectionDomain
        updated.sequentialTeeStartsEnabled = linked.sequentialTeeStartsEnabled ?? base.sequentialTeeStartsEnabled ?? false
        updated.scoreBasisOverride = linked.primaryFormat.configuration.basis
        updated.maxScoreOverPar = linked.primaryFormat.configuration.maxScoreOverPar
        updated.sharedScoreHandicapConfig = linked.sharedScoreHandicapConfig
        updated.handicapEntryFormat = linked.handicapEntryFormat
        updated.handicapNormalizationMode = linked.handicapNormalizationMode
        updated.handicapStrokeBasis = linked.handicapStrokeBasis
        updated.matchupMode = matchupMode(
            from: linked,
            segment: segment,
            fallback: base.matchupMode
        )
        return updated
    }

    static func courseSelection(from segment: CourseSegment?) -> SeriesCourseSelection? {
        guard let segment else { return nil }
        let defaultTee = segment.defaultTee.flatMap { segment.tee(from: $0) }
        return SeriesCourseSelection(
            courseID: segment.courseInfo.golfCourseApiID.map(String.init) ?? segment.courseInfo.id,
            cachedName: segment.courseInfo.name,
            defaultTeeBoxID: segment.defaultTee ?? "",
            defaultTeeName: defaultTee?.name,
            defaultTeeGender: defaultTee?.gender,
            holeSegment: segment.holeSegment
        )
    }

    private static func matchupMode(
        from configuration: RoundConfiguration,
        segment: RoundSegment?,
        fallback: SeriesMatchupMode
    ) -> SeriesMatchupMode {
        guard configuration.resolvedCompetitionScope == .matchup else { return .field }
        let matchups = segment?.matchups ?? []
        if matchups.contains(where: { $0.effectiveMode == .partnership }) { return .teeGroupPartnerships }
        if matchups.contains(where: { $0.effectiveMode == .team }) { return .teamVsTeam }
        if matchups.contains(where: { $0.effectiveMode == .individual }) { return .individualVsIndividual }
        if configuration.selectionDomain == .partnership && fallback == .teeGroupPartnerships {
            return .teeGroupPartnerships
        }
        return configuration.primaryFormat.configuration.requiresTeams ? .teamVsTeam : .individualVsIndividual
    }

    private struct CourseIdentity: Equatable {
        let courseID: String
        let teeID: String
        let holeSegment: HoleSegment
    }

    private static func courseIdentity(_ selection: SeriesCourseSelection?) -> CourseIdentity? {
        selection.map {
            CourseIdentity(
                courseID: $0.courseID,
                teeID: $0.defaultTeeBoxID,
                holeSegment: $0.holeSegment
            )
        }
    }

    private static func courseIdentity(_ segment: CourseSegment?) -> CourseIdentity? {
        segment.map {
            CourseIdentity(
                courseID: $0.courseInfo.golfCourseApiID.map(String.init) ?? $0.courseInfo.id,
                teeID: $0.defaultTee ?? "",
                holeSegment: $0.holeSegment
            )
        }
    }
}
