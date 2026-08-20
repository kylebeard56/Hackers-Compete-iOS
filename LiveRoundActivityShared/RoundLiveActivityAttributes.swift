import ActivityKit
import Foundation

struct RoundLiveActivityAttributes: ActivityAttributes {
    struct ScoreSummary: Codable, Hashable, Sendable {
        let title: String
        let value: String
        let thru: String
    }

    struct HoleSummary: Codable, Hashable, Sendable {
        let number: Int
        let total: Int
        let completed: Int
        let remaining: Int
        let par: Int?
        let yardage: Int?
        let handicapStrokes: Int?
        let currentScoreLabel: String?

        init(
            number: Int,
            total: Int,
            completed: Int,
            remaining: Int,
            par: Int?,
            yardage: Int?,
            handicapStrokes: Int? = nil,
            currentScoreLabel: String? = nil
        ) {
            self.number = number
            self.total = total
            self.completed = completed
            self.remaining = remaining
            self.par = par
            self.yardage = yardage
            self.handicapStrokes = handicapStrokes
            self.currentScoreLabel = currentScoreLabel
        }
    }

    struct MatchupSideSummary: Codable, Hashable, Sendable {
        let title: String
        let score: String
        let winPercentage: Int?
        let isCurrentUserSide: Bool
        let countingPlayers: [String]?

        init(
            title: String,
            score: String,
            winPercentage: Int?,
            isCurrentUserSide: Bool,
            countingPlayers: [String]? = nil
        ) {
            self.title = title
            self.score = score
            self.winPercentage = winPercentage
            self.isCurrentUserSide = isCurrentUserSide
            self.countingPlayers = countingPlayers
        }
    }

    struct MatchupSummary: Codable, Hashable, Sendable {
        let opponent: String
        let standingLabel: String?
        let differentialLabel: String?
        let winPercentage: Int?
        let tiePercentage: Int?
        let isEarlyEstimate: Bool
        let left: MatchupSideSummary?
        let right: MatchupSideSummary?
    }

    struct CompetitionSummary: Codable, Hashable, Sendable {
        enum Kind: String, Codable, Sendable {
            case team
            case individual
        }

        let kind: Kind
        let title: String
        let position: String?
        let score: String?
        let detail: String
        let participantCount: Int?

        init(
            kind: Kind,
            title: String,
            position: String?,
            score: String?,
            detail: String,
            participantCount: Int? = nil
        ) {
            self.kind = kind
            self.title = title
            self.position = position
            self.score = score
            self.detail = detail
            self.participantCount = participantCount
        }
    }

    struct ContentState: Codable, Hashable, Sendable {
        enum Phase: String, Codable, Sendable {
            case live
            case paused
            case stale
            case complete
        }

        let phase: Phase
        let roundTitle: String
        let participantName: String?
        let formatLabel: String?
        let holeLabel: String
        let holeProgress: Double
        let hole: HoleSummary?
        let personalScore: ScoreSummary
        let grossScore: ScoreSummary?
        let teamScore: ScoreSummary?
        let matchup: MatchupSummary?
        let competition: CompetitionSummary?
        let isPersonalScoreCounting: Bool?
        let deepLinkURL: URL
        let updatedAt: Date

        init(
            phase: Phase,
            roundTitle: String,
            participantName: String? = nil,
            formatLabel: String? = nil,
            holeLabel: String,
            holeProgress: Double,
            hole: HoleSummary?,
            personalScore: ScoreSummary,
            grossScore: ScoreSummary? = nil,
            teamScore: ScoreSummary?,
            matchup: MatchupSummary?,
            competition: CompetitionSummary? = nil,
            isPersonalScoreCounting: Bool? = nil,
            deepLinkURL: URL,
            updatedAt: Date
        ) {
            self.phase = phase
            self.roundTitle = roundTitle
            self.participantName = participantName
            self.formatLabel = formatLabel
            self.holeLabel = holeLabel
            self.holeProgress = holeProgress
            self.hole = hole
            self.personalScore = personalScore
            self.grossScore = grossScore
            self.teamScore = teamScore
            self.matchup = matchup
            self.competition = competition
            self.isPersonalScoreCounting = isPersonalScoreCounting
            self.deepLinkURL = deepLinkURL
            self.updatedAt = updatedAt
        }
    }

    let roundID: String
    let participantID: String
}
