import Foundation

@MainActor
final class ProcessedWatchMutationStore {
    private let defaults: UserDefaults
    private let key: String
    private let maximumAcknowledgements: Int
    private var acknowledgements: [WatchScoreAcknowledgement]

    init(
        defaults: UserDefaults = .standard,
        key: String = "processed_watch_score_mutations_v1",
        maximumAcknowledgements: Int = 500
    ) {
        self.defaults = defaults
        self.key = key
        self.maximumAcknowledgements = maximumAcknowledgements
        acknowledgements = defaults.data(forKey: key)
            .flatMap { try? PropertyListDecoder().decode([WatchScoreAcknowledgement].self, from: $0) }
            ?? []
    }

    func acknowledgement(for mutationID: UUID) -> WatchScoreAcknowledgement? {
        acknowledgements.first { $0.id == mutationID }
    }

    func insert(_ acknowledgement: WatchScoreAcknowledgement) {
        acknowledgements.removeAll { $0.id == acknowledgement.id }
        acknowledgements.append(acknowledgement)
        acknowledgements.sort { $0.acknowledgedAt > $1.acknowledgedAt }
        if acknowledgements.count > maximumAcknowledgements {
            acknowledgements.removeLast(acknowledgements.count - maximumAcknowledgements)
        }
        guard let data = try? PropertyListEncoder().encode(acknowledgements) else { return }
        defaults.set(data, forKey: key)
    }

    func acceptedMutationIDs(for roundID: String) -> Set<UUID> {
        Set(acknowledgements.lazy.filter {
            $0.roundID == roundID && $0.status == .accepted
        }.map(\.id))
    }
}
