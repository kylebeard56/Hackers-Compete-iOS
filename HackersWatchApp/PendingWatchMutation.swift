import Foundation

struct PendingWatchMutation: Codable, Equatable, Identifiable, Sendable {
    enum State: String, Codable, Sendable {
        case pending
        case conflict
        case failed
    }

    var id: UUID { mutation.id }

    let mutation: WatchScoreMutation
    var state: State
    var message: String?
}
