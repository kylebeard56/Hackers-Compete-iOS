import Foundation

struct WatchScoreAcknowledgement: Codable, Equatable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case accepted
        case conflict
        case rejected
        case failed
    }

    enum ErrorCategory: String, Codable, Sendable {
        case roundUnavailable = "round_unavailable"
        case roundNotLive = "round_not_live"
        case unauthorized
        case invalidSubject = "invalid_subject"
        case invalidHole = "invalid_hole"
        case invalidScore = "invalid_score"
        case staleScore = "stale_score"
        case persistence
    }

    let id: UUID
    let roundID: String
    let status: Status
    let canonicalValue: Int?
    let canonicalRevision: String?
    let errorCategory: ErrorCategory?
    let message: String?
    let acknowledgedAt: Date
}
