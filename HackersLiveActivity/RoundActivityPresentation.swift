import Foundation

struct RoundActivityPresentation {
    enum Status {
        case live
        case attention
        case complete
    }

    enum Focus {
        case matchup(
            left: RoundLiveActivityAttributes.MatchupSideSummary,
            right: RoundLiveActivityAttributes.MatchupSideSummary,
            standing: String,
            winPercentage: Int?,
            isEarlyEstimate: Bool
        )
        case competition(
            kind: RoundLiveActivityAttributes.CompetitionSummary.Kind,
            title: String,
            position: String?,
            score: String?,
            detail: String
        )
        case hole(number: String, par: String, yardage: String, detail: String)
    }

    enum ContextKind: Equatable {
        case matchup
        case competition
        case combined
        case hole
    }

    let roundTitle: String
    let participantName: String
    let formatLabel: String?
    let holeBadge: String
    let holePositionLabel: String
    let completedHoleLabel: String
    let holeTitle: String
    let holeDetail: String
    let personalScore: RoundLiveActivityAttributes.ScoreSummary
    let grossScore: RoundLiveActivityAttributes.ScoreSummary
    let netScore: RoundLiveActivityAttributes.ScoreSummary?
    let scoreBasisLabel: String
    let scoreProgressLabel: String
    let focus: Focus
    let contextKind: ContextKind
    let contextPrimaryLabel: String
    let contextSecondaryLabel: String?
    let contextDetailLabel: String
    let compactContextLabel: String
    let contextProgress: Double?
    let progress: Double
    let progressLeadingLabel: String
    let progressTrailingLabel: String
    let combinedProgressLabel: String
    let holesRemainingLabel: String
    let compactHolesRemainingLabel: String
    let compactHoleParLabel: String
    let matchStandingLabel: String?
    let winOddsLongLabel: String?
    let winOddsShortLabel: String?
    let personalContextLabel: String
    let isPersonalScoreCounting: Bool
    let status: Status
    let statusLabel: String
    let accessibilitySummary: String

    var emphasizesMatchup: Bool {
        contextKind == .matchup || contextKind == .combined
    }

    init(state: RoundLiveActivityAttributes.ContentState, isStale: Bool) {
        let effectivelyStale = isStale || state.phase == .stale
        let status = Self.status(for: state.phase, isStale: effectivelyStale)
        let focus = Self.focus(for: state)
        let context = Self.context(for: state, focus: focus)

        roundTitle = state.roundTitle
        participantName = Self.nonEmpty(
            state.participantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? "You"
        formatLabel = state.formatLabel
        holeBadge = state.hole.map { "H\($0.number)" } ?? Self.shortHoleLabel(state.holeLabel)
        holePositionLabel = state.hole.map { "H\($0.number) / \($0.total)" } ?? state.holeLabel
        completedHoleLabel = state.hole.map { "\($0.completed) / \($0.total)" } ?? state.holeLabel
        holeTitle = state.hole.map { "Hole \($0.number)" } ?? state.holeLabel
        holeDetail = Self.holeDetail(state: state)
        personalScore = state.personalScore
        grossScore = state.grossScore ?? state.personalScore
        netScore = Self.isNetScore(state.personalScore) && state.grossScore != nil
            ? state.personalScore
            : nil
        scoreBasisLabel = Self.scoreBasisLabel(state.personalScore.title)
        scoreProgressLabel = Self.scoreProgressLabel(state: state)
        self.focus = focus
        contextKind = context.kind
        contextPrimaryLabel = context.primary
        contextSecondaryLabel = context.secondary
        contextDetailLabel = context.detail
        compactContextLabel = context.compact
        contextProgress = context.progress
        progress = min(max(state.holeProgress, 0), 1)
        progressLeadingLabel = Self.progressLeadingLabel(state: state, isStale: effectivelyStale)
        progressTrailingLabel = Self.progressTrailingLabel(state: state)
        combinedProgressLabel = Self.combinedProgressLabel(
            state: state,
            isStale: effectivelyStale
        )
        holesRemainingLabel = Self.holesRemainingLabel(state: state)
        compactHolesRemainingLabel = Self.compactHolesRemainingLabel(state: state)
        compactHoleParLabel = Self.compactHoleParLabel(state: state)
        matchStandingLabel = state.matchup?.standingLabel
        let probabilityBasis = Self.scoreBasisLabel(state.personalScore.title)
        winOddsLongLabel = state.matchup?.winPercentage.map {
            "\($0)% \(probabilityBasis) CHANCE TO WIN"
        }
        winOddsShortLabel = state.matchup?.winPercentage.map {
            "\($0)% \(probabilityBasis) WIN"
        }
        personalContextLabel = Self.personalContextLabel(state: state)
        isPersonalScoreCounting = state.isPersonalScoreCounting == true
        self.status = status
        statusLabel = Self.statusLabel(for: status)
        accessibilitySummary = Self.accessibilitySummary(state: state, focus: focus, isStale: effectivelyStale)
    }

    private static func context(
        for state: RoundLiveActivityAttributes.ContentState,
        focus: Focus
    ) -> (
        kind: ContextKind,
        primary: String,
        secondary: String?,
        detail: String,
        compact: String,
        progress: Double?
    ) {
        switch focus {
        case let .matchup(_, _, standing, winPercentage, _):
            let basis = scoreBasisLabel(state.personalScore.title)
            let probability = winPercentage.map { "\($0)% \(basis) WIN" }

            if let competition = state.competition,
               competition.kind == .individual,
               competition.position != nil {
                return (
                    .combined,
                    standing,
                    probability,
                    "",
                    standing,
                    winPercentage.map { min(max(Double($0) / 100, 0), 1) }
                )
            }

            return (
                .matchup,
                standing,
                probability,
                "",
                standing,
                winPercentage.map { min(max(Double($0) / 100, 0), 1) }
            )

        case let .competition(kind, title, position, score, detail):
            let count = state.competition?.participantCount
            if kind == .individual {
                let primary = position ?? "—"
                return (
                    .competition,
                    primary,
                    count.map { "OF \($0)" },
                    detail,
                    primary,
                    nil
                )
            }

            let primary = position.map { "#\($0)" } ?? (score ?? "—")
            let secondary = [score, title].compactMap { $0 }.joined(separator: " · ")
            return (
                .competition,
                primary,
                nonEmpty(secondary),
                detail,
                primary,
                nil
            )

        case let .hole(number, par, _, detail):
            return (
                .hole,
                "H\(number)",
                par == "—" ? nil : "PAR \(par)",
                detail,
                "H\(number)",
                nil
            )
        }
    }

    private static func holeDetail(
        state: RoundLiveActivityAttributes.ContentState
    ) -> String {
        var parts: [String] = []
        if let par = state.hole?.par { parts.append("Par \(par)") }
        return parts.isEmpty ? state.roundTitle : parts.joined(separator: " · ")
    }

    private static func scoreBasisLabel(_ title: String) -> String {
        if title.localizedCaseInsensitiveContains("net") { return "NET" }
        if title.localizedCaseInsensitiveContains("gross") { return "GROSS" }
        return "SCORE"
    }

    private static func isNetScore(
        _ score: RoundLiveActivityAttributes.ScoreSummary
    ) -> Bool {
        score.title.localizedCaseInsensitiveContains("net")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func focus(for state: RoundLiveActivityAttributes.ContentState) -> Focus {
        if let matchup = state.matchup,
           let left = matchup.left,
           let right = matchup.right {
            return .matchup(
                left: left,
                right: right,
                standing: matchup.standingLabel ?? "MATCH",
                winPercentage: matchup.winPercentage,
                isEarlyEstimate: matchup.isEarlyEstimate
            )
        }

        if let competition = state.competition {
            return .competition(
                kind: competition.kind,
                title: competition.title,
                position: competition.position,
                score: competition.score,
                detail: competition.detail
            )
        }

        let number = state.hole.map { String($0.number) } ?? Self.shortHoleLabel(state.holeLabel)
        let par = state.hole?.par.map(String.init) ?? "—"
        let yardage = state.hole?.yardage.map(String.init) ?? "—"
        var details: [String] = []
        if let score = state.hole?.currentScoreLabel {
            details.append(score)
        }
        if let strokes = state.hole?.handicapStrokes {
            details.append("\(strokes) handicap \(strokes == 1 ? "stroke" : "strokes")")
        }
        return .hole(
            number: number,
            par: par,
            yardage: yardage,
            detail: details.isEmpty ? "Round in progress" : details.joined(separator: " · ")
        )
    }

    private static func status(
        for phase: RoundLiveActivityAttributes.ContentState.Phase,
        isStale: Bool
    ) -> Status {
        if isStale { return .attention }
        switch phase {
        case .live: return .live
        case .paused, .stale: return .attention
        case .complete: return .complete
        }
    }

    private static func statusLabel(for status: Status) -> String {
        switch status {
        case .live: return "LIVE"
        case .attention: return "UPDATE"
        case .complete: return "FINAL"
        }
    }

    private static func shortHoleLabel(_ label: String) -> String {
        guard let number = label.split(separator: " ").dropFirst().first else { return label }
        return "H\(number)"
    }

    private static func progressLeadingLabel(
        state: RoundLiveActivityAttributes.ContentState,
        isStale: Bool
    ) -> String {
        if isStale { return "Open Hackers to refresh" }
        if state.phase == .complete { return "Round complete" }
        return state.personalScore.thru
    }

    private static func progressTrailingLabel(state: RoundLiveActivityAttributes.ContentState) -> String {
        guard let hole = state.hole else { return state.holeLabel }
        if hole.remaining == 0 { return "Complete" }
        return "\(hole.remaining) \(hole.remaining == 1 ? "hole" : "holes") left"
    }

    private static func combinedProgressLabel(
        state: RoundLiveActivityAttributes.ContentState,
        isStale: Bool
    ) -> String {
        if isStale { return "Open Hackers to refresh" }
        if state.phase == .complete { return "Round complete" }
        guard let hole = state.hole else { return state.personalScore.thru }
        return "Thru \(hole.completed) of \(hole.total)"
    }

    private static func holesRemainingLabel(
        state: RoundLiveActivityAttributes.ContentState
    ) -> String {
        guard let hole = state.hole else { return state.holeLabel }
        if hole.remaining == 0 { return "Complete" }
        return "\(hole.remaining) \(hole.remaining == 1 ? "hole" : "holes") left"
    }

    private static func compactHolesRemainingLabel(
        state: RoundLiveActivityAttributes.ContentState
    ) -> String {
        guard let hole = state.hole else { return "LIVE" }
        if hole.remaining == 0 { return "DONE" }
        return "\(hole.remaining) LEFT"
    }

    private static func compactHoleParLabel(
        state: RoundLiveActivityAttributes.ContentState
    ) -> String {
        guard let hole = state.hole else { return shortHoleLabel(state.holeLabel) }
        let par = hole.par.map { "P\($0)" } ?? ""
        return ["H\(hole.number)", par]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private static func personalContextLabel(
        state: RoundLiveActivityAttributes.ContentState
    ) -> String {
        if let competition = state.competition,
           competition.kind == .individual,
           let position = competition.position {
            if let count = competition.participantCount {
                return "\(position) of \(count)"
            }
            return position
        }
        return holesRemainingLabel(state: state)
    }

    private static func accessibilitySummary(
        state: RoundLiveActivityAttributes.ContentState,
        focus: Focus,
        isStale: Bool
    ) -> String {
        var parts = [state.roundTitle, state.holeLabel]
        if let grossScore = state.grossScore,
           isNetScore(state.personalScore) {
            parts.append(
                "Gross score \(grossScore.value), net score \(state.personalScore.value), \(state.personalScore.thru)."
            )
        } else {
            parts.append(
                "\(state.personalScore.title) \(state.personalScore.value), \(state.personalScore.thru)."
            )
        }

        switch focus {
        case let .matchup(left, right, standing, winPercentage, isEarlyEstimate):
            let opponent = left.isCurrentUserSide ? right.title : left.title
            let odds = winPercentage.map { ", \($0) percent chance to win" } ?? ""
            let confidence = isEarlyEstimate && winPercentage != nil ? ", early estimate" : ""
            parts.append("Your match is \(standing) versus \(opponent)\(odds)\(confidence).")
            parts.append("\(left.title) \(left.score), \(right.title) \(right.score).")
            for side in [left, right] {
                guard let players = side.countingPlayers, !players.isEmpty else { continue }
                parts.append("\(players.joined(separator: " and ")) counting for \(side.title).")
            }
            if let competition = state.competition,
               competition.kind == .individual,
               let position = competition.position {
                let fieldSize = competition.participantCount.map { " of \($0)" } ?? ""
                parts.append("Field position \(position)\(fieldSize), \(competition.detail).")
            }
        case let .competition(_, title, position, _, detail):
            let positionText = position.map { " position \($0)," } ?? ""
            parts.append("\(title),\(positionText) \(detail).")
        case let .hole(_, par, yardage, detail):
            parts.append("Par \(par), \(yardage) yards. \(detail).")
        }

        if state.isPersonalScoreCounting == true {
            parts.append("Your score is counting.")
        }

        if isStale {
            parts.append("Open Hackers to refresh.")
        }
        return parts.joined(separator: " ")
    }

    private static func scoreProgressLabel(
        state: RoundLiveActivityAttributes.ContentState
    ) -> String {
        let basis = state.personalScore.title
            .replacingOccurrences(of: "You · ", with: "")
            .replacingOccurrences(of: "You", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let hole = state.hole else {
            return basis.isEmpty ? state.personalScore.thru.uppercased() : basis
        }
        let completion = "\(hole.completed)/\(hole.total)"
        return basis.isEmpty ? completion : "\(basis) · \(completion)"
    }
}
