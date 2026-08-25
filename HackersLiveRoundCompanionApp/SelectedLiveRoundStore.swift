import Foundation

@MainActor
final class SelectedLiveRoundStore: ObservableObject {
    @Published private(set) var roundID: String?
    @Published private(set) var liveActivityRoundID: String?

    private let defaults: UserDefaults
    private let key: String
    private let liveActivityKey: String
    private let legacyLiveActivityEnabledKey: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "selected_live_round_for_watch_v1",
        liveActivityKey: String = "selected_live_activity_round_v1",
        legacyLiveActivityEnabledKey: String = "live_round_activity_enabled_v1"
    ) {
        self.defaults = defaults
        self.key = key
        self.liveActivityKey = liveActivityKey
        self.legacyLiveActivityEnabledKey = legacyLiveActivityEnabledKey
        let storedWatchRoundID = defaults.string(forKey: key).flatMap {
            $0.isPopulated ? $0 : nil
        }
        let storedActivityRoundID = defaults.string(forKey: liveActivityKey).flatMap {
            $0.isPopulated ? $0 : nil
        }
        let activeRoundID = storedWatchRoundID ?? storedActivityRoundID
        roundID = activeRoundID
        liveActivityRoundID = activeRoundID

        // Migrate the former independent opt-ins into one greedy active-round selection.
        if let activeRoundID {
            defaults.set(activeRoundID, forKey: key)
            defaults.set(activeRoundID, forKey: liveActivityKey)
        }
        defaults.removeObject(forKey: legacyLiveActivityEnabledKey)
    }

    func select(_ roundID: String?) {
        let normalized = roundID?.isPopulated == true ? roundID : nil
        guard normalized != self.roundID || normalized != liveActivityRoundID else { return }
        self.roundID = normalized
        liveActivityRoundID = normalized
        if let normalized {
            defaults.set(normalized, forKey: key)
            defaults.set(normalized, forKey: liveActivityKey)
        } else {
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: liveActivityKey)
        }
    }

    func reconcile(eligibleRoundIDs: [String]) {
        let eligibleRoundIDs = eligibleRoundIDs.filter(\.isPopulated)
        let eligibleIDs = Set(eligibleRoundIDs)
        if let roundID, eligibleIDs.contains(roundID) {
            select(roundID)
        } else {
            select(eligibleRoundIDs.first)
        }
    }

    func selectLiveActivity(roundID: String?) {
        select(roundID)
    }

    func reconcileLiveActivity(eligibleRoundIDs: [String]) {
        reconcile(eligibleRoundIDs: eligibleRoundIDs)
    }
}
