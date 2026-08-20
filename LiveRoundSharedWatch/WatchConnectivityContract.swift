import Foundation

enum WatchConnectivityContract {
    static let snapshotKey = "live_round_snapshot_v1"
    static let emptyStateKey = "live_round_empty_v1"
    static let mutationKey = "score_mutation_v1"
    static let acknowledgementKey = "score_acknowledgement_v1"
    static let snapshotRequestKey = "live_round_snapshot_request_v1"

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try PropertyListDecoder().decode(type, from: data)
    }
}
