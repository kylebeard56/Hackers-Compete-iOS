#if SANDBOX
import Foundation
import SwiftUI

struct DesignStudioPlayer: Identifiable, Hashable {
    let id: String
    var name: String
    var initials: String
    var teamName: String
    var teamColor: Color
    var handicap: Double?
}

@MainActor
final class DesignStudioRoundStore: ObservableObject {
    enum Format: String, CaseIterable, Identifiable {
        case strokePlay = "Stroke Play"
        case stableford = "Stableford"
        case bestBall = "Best Ball"

        var id: String { rawValue }
    }

    @Published var players: [DesignStudioPlayer]
    @Published var format: Format = .strokePlay
    @Published var teamsEnabled = true
    @Published var handicapsEnabled = true
    @Published var selectedHole = 1
    @Published var scores: [String: [Int: Int]] = [:]
    @Published var isRoundComplete = false

    let courseName = "Pineview Golf Club"
    let holePars = [4, 4, 3, 5, 4, 4, 3, 5, 4, 4, 4, 3, 5, 4, 4, 3, 5, 4]
    let holeYards = [412, 376, 168, 521, 403, 354, 147, 536, 391, 418, 362, 181, 548, 397, 344, 156, 529, 405]

    init() {
        players = [
            .init(id: "kb", name: "Kyle Beard", initials: "KB", teamName: "Forest", teamColor: DesignStudioTheme.forest, handicap: 8.2),
            .init(id: "am", name: "Andrew McCartney", initials: "AM", teamName: "Forest", teamColor: ColorValue(hex: "3B8C5A").color, handicap: 11.4),
            .init(id: "sp", name: "Santiago Pirez", initials: "SP", teamName: "Gold", teamColor: DesignStudioTheme.gold, handicap: 14.1),
            .init(id: "gl", name: "Greg Lorenz", initials: "GL", teamName: "Gold", teamColor: ColorValue(hex: "7A64C3").color, handicap: 6.7),
        ]
        scores = [
            "kb": [1: 4],
            "am": [1: 5],
            "sp": [1: 3],
            "gl": [1: 4],
        ]
    }

    var currentPar: Int { holePars[selectedHole - 1] }
    var currentYards: Int { holeYards[selectedHole - 1] }

    func score(for playerID: String, hole: Int? = nil) -> Int {
        let targetHole = hole ?? selectedHole
        return scores[playerID]?[targetHole] ?? holePars[targetHole - 1]
    }

    func adjustScore(for playerID: String, delta: Int) {
        let current = score(for: playerID)
        scores[playerID, default: [:]][selectedHole] = min(max(1, current + delta), 12)
    }

    func addMockPlayer() {
        guard players.count < 8 else { return }
        let additions: [(String, String)] = [("Taylor Reed", "TR"), ("Morgan Lee", "ML"), ("Jordan Ellis", "JE"), ("Casey Park", "CP")]
        let addition = additions[players.count - 4]
        let id = addition.1.lowercased()
        players.append(
            .init(
                id: id,
                name: addition.0,
                initials: addition.1,
                teamName: players.count.isMultiple(of: 2) ? "Forest" : "Gold",
                teamColor: players.count.isMultiple(of: 2) ? DesignStudioTheme.forest : DesignStudioTheme.gold,
                handicap: 12
            )
        )
    }

    func removePlayer(_ player: DesignStudioPlayer) {
        guard players.count > 2 else { return }
        players.removeAll { $0.id == player.id }
        scores[player.id] = nil
    }

    func updateHandicap(for playerID: String, delta: Double) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].handicap = min(max(0, (players[index].handicap ?? 0) + delta), 54)
    }

    func totalRelativeToPar(for playerID: String) -> Int {
        let entered = scores[playerID] ?? [:]
        return entered.reduce(0) { total, entry in
            total + entry.value - holePars[entry.key - 1]
        }
    }

    var leaderboard: [DesignStudioPlayer] {
        players.sorted {
            let lhs = totalRelativeToPar(for: $0.id)
            let rhs = totalRelativeToPar(for: $1.id)
            return lhs == rhs ? $0.name < $1.name : lhs < rhs
        }
    }

    func completeRound() {
        isRoundComplete = true
    }

    func reset() {
        selectedHole = 1
        isRoundComplete = false
        scores = ["kb": [1: 4], "am": [1: 5], "sp": [1: 3], "gl": [1: 4]]
    }
}

enum DesignStudioSeriesSection: String, CaseIterable, Identifiable, Hashable {
    case roundCourse
    case formatScoring
    case handicapEligibility
    case matchups
    case teeSheet
    case pointsNotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roundCourse: "Round & Course"
        case .formatScoring: "Format & Scoring"
        case .handicapEligibility: "Handicap & Eligibility"
        case .matchups: "Matchups"
        case .teeSheet: "Tee Sheet & Pairs"
        case .pointsNotes: "Series Points & Notes"
        }
    }

    var symbol: String {
        switch self {
        case .roundCourse: "flag.fill"
        case .formatScoring: "trophy.fill"
        case .handicapEligibility: "person.crop.circle.badge.checkmark"
        case .matchups: "arrow.left.arrow.right"
        case .teeSheet: "person.3.fill"
        case .pointsNotes: "medal.fill"
        }
    }

    var groupTitle: String {
        switch self {
        case .roundCourse, .formatScoring: "Play"
        case .handicapEligibility, .matchups, .teeSheet: "Field"
        case .pointsNotes: "Awards"
        }
    }
}

enum DesignStudioSeriesSectionStatus: Equatable {
    case ready
    case review(String)
    case recommended(String)
    case incomplete
    case optional
}

@MainActor
final class DesignStudioSeriesRoundStore: ObservableObject {
    enum Lifecycle { case setup, editing }

    enum Format: String, CaseIterable, Identifiable {
        case teamMatch = "Team Match Play"
        case strokePlay = "Stroke Play"
        case bestBall = "Best Ball"
        case scramble = "Captain's Choice"

        var id: String { rawValue }

        var templateID: String {
            switch self {
            case .teamMatch: FormatTemplateRegistry.bestBall.id
            case .strokePlay: FormatTemplateRegistry.strokePlay.id
            case .bestBall: FormatTemplateRegistry.bestBall.id
            case .scramble: FormatTemplateRegistry.captainsChoice.id
            }
        }

        var scoreSource: ScoreSource {
            switch self {
            case .scramble: .shared
            default: .individual
            }
        }
    }

    enum MatchupSource: String, CaseIterable, Identifiable {
        case team = "By team"
        case pair = "By pair"
        case individual = "By individual"
        var id: String { rawValue }
    }

    @Published var draft: SeriesRoundDraft
    @Published var lifecycle: Lifecycle = .setup
    @Published var format: Format = .teamMatch
    @Published var courseName = "Pineview Golf Club"
    @Published var teeName = "Blue · 6,742 yards"
    @Published var holes = "18 holes"
    @Published var handicapMissingPlayerIDs: Set<String> = ["player-14", "player-16"]
    @Published var excludedPlayerIDs: Set<String> = []
    @Published var matchupSource: MatchupSource = .team
    @Published var matchupsConfigured = false
    @Published var teeSheetGenerated = false
    @Published var pointsConfigured = true
    @Published var notes = "Cart path only. First tee opens at 8:10 AM."
    @Published var activeEditor: DesignStudioSeriesSection?
    @Published var isReviewPresented = false
    @Published var didCreateRound = false
    @Published var lastRecommendedSection: DesignStudioSeriesSection = .matchups

    let members: [DesignStudioPlayer]
    private let fixedDate: Date

    init() {
        fixedDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 25, hour: 8, minute: 30)) ?? Date()
        var settings = SeriesSettings.seeded(for: .league)
        settings.useTeams = true
        settings.useTeamStandings = true
        settings.useIndividualStandings = true
        settings.defaultRoundConfig.competitionScope = .matchup
        settings.defaultRoundConfig.formatTemplateID = FormatTemplateRegistry.bestBall.id
        settings.defaultRoundConfig.teamAssignmentMode = .seriesTeams
        settings.defaultRoundConfig.matchupMode = .teamVsTeam

        var seededDraft = SeriesRoundDraft(
            settings: settings,
            suggestedCourse: .init(
                courseID: "pineview-mock",
                cachedName: "Pineview Golf Club",
                defaultTeeBoxID: "blue",
                holeSegment: .full18
            ),
            usesTeams: true,
            scheduledDate: fixedDate
        )
        seededDraft.title = "Round 3"
        seededDraft.hasDate = true
        seededDraft.competitionScope = .matchup
        seededDraft.matchupSource = .byTeam
        seededDraft.selectedTemplateID = FormatTemplateRegistry.bestBall.id
        seededDraft.teamScoring = .init(mode: .bestN, count: 2, scope: .perHole)
        seededDraft.handicapEntryFormat = .courseHandicap
        seededDraft.handicapNormalizationMode = .matchup
        seededDraft.countsTowardHandicapPool = true
        seededDraft.notes = "Cart path only. First tee opens at 8:10 AM."
        draft = seededDraft

        let teamColors = [
            DesignStudioTheme.forest,
            DesignStudioTheme.gold,
            ColorValue(hex: "6D55BD").color,
            DesignStudioTheme.skyBlue,
        ]
        let names = [
            "Kyle Beard", "Andrew McCartney", "Santiago Pirez", "Greg Lorenz",
            "Sarah Beard", "Zac Alley", "Tim Schlosky", "Justin Allen",
            "Morgan Lee", "Taylor Reed", "Jordan Ellis", "Casey Park",
            "Rory Evans", "Drew James", "Avery Stone", "Parker Cole",
        ]
        members = names.enumerated().map { index, name in
            let pieces = name.split(separator: " ")
            let initials = pieces.compactMap(\.first).map(String.init).joined()
            let teamIndex = index / 4
            return .init(
                id: "player-\(index + 1)",
                name: name,
                initials: initials,
                teamName: ["Forest", "Gold", "Lavender", "Sky"][teamIndex],
                teamColor: teamColors[teamIndex],
                handicap: index >= 14 ? nil : Double(5 + index) + 0.4
            )
        }
    }

    var competitionScope: CompetitionScope { draft.competitionScope }

    var applicableSections: [DesignStudioSeriesSection] {
        DesignStudioSeriesSection.allCases.filter { section in
            section != .matchups || competitionScope == .matchup
        }
    }

    var readyCount: Int {
        applicableSections.filter { status(for: $0) == .ready }.count
    }

    var nextSection: DesignStudioSeriesSection? {
        if applicableSections.contains(lastRecommendedSection), status(for: lastRecommendedSection) != .ready {
            return lastRecommendedSection
        }
        return applicableSections.first { status(for: $0) != .ready && status(for: $0) != .optional }
    }

    func sections(in group: String) -> [DesignStudioSeriesSection] {
        applicableSections.filter { $0.groupTitle == group }
    }

    func status(for section: DesignStudioSeriesSection) -> DesignStudioSeriesSectionStatus {
        switch section {
        case .roundCourse, .formatScoring:
            return .ready
        case .handicapEligibility:
            return handicapMissingPlayerIDs.isEmpty
                ? .ready
                : .review("\(handicapMissingPlayerIDs.count) players need review")
        case .matchups:
            if matchupsConfigured { return .ready }
            return lastRecommendedSection == .matchups
                ? .recommended("Set 2 team matches")
                : .incomplete
        case .teeSheet:
            return teeSheetGenerated ? .ready : .incomplete
        case .pointsNotes:
            return pointsConfigured ? .ready : .optional
        }
    }

    func summary(for section: DesignStudioSeriesSection) -> String {
        switch section {
        case .roundCourse: "\(courseName) · \(holes)"
        case .formatScoring:
            competitionScope == .matchup ? "\(format.rawValue) · Head-to-head" : "\(format.rawValue) · Field"
        case .handicapEligibility:
            handicapMissingPlayerIDs.isEmpty ? "Course handicap · 16 eligible" : "\(handicapMissingPlayerIDs.count) players need review"
        case .matchups:
            matchupsConfigured ? matchupSummary : "Set 2 team matches"
        case .teeSheet:
            teeSheetGenerated ? "4 groups · Starting holes assigned" : "Manual pairs · Not generated"
        case .pointsNotes:
            pointsConfigured ? "Top 4 teams · Notes added" : "Optional"
        }
    }

    var matchupSummary: String {
        switch matchupSource {
        case .team: "Forest vs Gold · Lavender vs Sky"
        case .pair: "4 pair matches"
        case .individual: "8 player matches"
        }
    }

    func selectFormat(_ newFormat: Format) {
        format = newFormat
        draft.selectedTemplateID = newFormat.templateID
        draft.scoreOwnerScope = newFormat.scoreSource == .shared ? .teeGroup : .individual
        if newFormat == .teamMatch {
            setCompetitionScope(.matchup)
        }
    }

    func setCompetitionScope(_ scope: CompetitionScope) {
        draft.competitionScope = scope
        if scope == .field {
            draft.matchupSource = .byTeam
            matchupsConfigured = false
            lastRecommendedSection = handicapMissingPlayerIDs.isEmpty ? .teeSheet : .handicapEligibility
        } else {
            draft.matchupSource = matchupSource.draftSource
            lastRecommendedSection = .matchups
        }
    }

    func setCourseHandicapEnabled(_ enabled: Bool) {
        draft.handicapEntryFormat = enabled ? .courseHandicap : .strokes
    }

    func toggleHandicapReview(for memberID: String) {
        if handicapMissingPlayerIDs.contains(memberID) {
            handicapMissingPlayerIDs.remove(memberID)
        } else {
            handicapMissingPlayerIDs.insert(memberID)
        }
    }

    func toggleEligibility(for memberID: String) {
        if excludedPlayerIDs.contains(memberID) {
            excludedPlayerIDs.remove(memberID)
        } else {
            excludedPlayerIDs.insert(memberID)
        }
        draft.excludedHandicapMemberIDs = Array(excludedPlayerIDs)
    }

    func autoFillMatchups() {
        matchupsConfigured = true
        lastRecommendedSection = teeSheetGenerated ? .handicapEligibility : .teeSheet
    }

    func generateTeeSheet() {
        teeSheetGenerated = true
        if !handicapMissingPlayerIDs.isEmpty { lastRecommendedSection = .handicapEligibility }
    }

    func reset(section: DesignStudioSeriesSection) {
        switch section {
        case .roundCourse:
            courseName = "Pineview Golf Club"
            teeName = "Blue · 6,742 yards"
            holes = "18 holes"
            draft.title = "Round 3"
            draft.scheduledDate = fixedDate
        case .formatScoring:
            selectFormat(.teamMatch)
            draft.sharedScoreAllowanceText = "35,15"
            draft.teamScoring = .init(mode: .bestN, count: 2, scope: .perHole)
        case .handicapEligibility:
            handicapMissingPlayerIDs = ["player-14", "player-16"]
            excludedPlayerIDs = []
            draft.handicapEntryFormat = .courseHandicap
        case .matchups:
            matchupSource = .team
            matchupsConfigured = false
            lastRecommendedSection = .matchups
        case .teeSheet:
            teeSheetGenerated = false
        case .pointsNotes:
            pointsConfigured = true
            notes = "Cart path only. First tee opens at 8:10 AM."
        }
    }

    var validationIssues: [String] {
        var issues: [String] = []
        let pieces = draft.sharedScoreAllowanceText.split(separator: ",")
        if format.scoreSource == .shared,
           (pieces.isEmpty || pieces.contains(where: { Double($0.trimmingCharacters(in: .whitespaces)) == nil })) {
            issues.append("Format & Scoring: enter handicap allowances as comma-separated percentages.")
        }
        if draft.teamScoring.mode != .all, draft.teamScoring.count < 1 {
            issues.append("Format & Scoring: count at least one team score.")
        }
        if !handicapMissingPlayerIDs.isEmpty {
            issues.append("Handicap & Eligibility: review \(handicapMissingPlayerIDs.count) players.")
        }
        if competitionScope == .matchup, !matchupsConfigured {
            issues.append("Matchups: configure the head-to-head schedule.")
        }
        if !teeSheetGenerated {
            issues.append("Tee Sheet & Pairs: generate the starting groups.")
        }
        return issues
    }

    func continueSetup() {
        if let nextSection {
            activeEditor = nextSection
        } else {
            isReviewPresented = true
        }
    }

    func finishLater() {
        lifecycle = .editing
    }

    func presentReview() {
        isReviewPresented = true
    }

    func createMockRound() {
        draft.notes = notes
        didCreateRound = true
        lifecycle = .editing
        isReviewPresented = false
    }
}

private extension DesignStudioSeriesRoundStore.MatchupSource {
    var draftSource: SeriesRoundMatchupSource {
        switch self {
        case .team: .byTeam
        case .pair: .byPair
        case .individual: .byIndividual
        }
    }
}
#endif
