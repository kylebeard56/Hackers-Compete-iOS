import Combine
import Foundation

/// Account-scoped preferences on this device. Round selection is deliberately separate.
@MainActor
final class UserCompanionPreferences: ObservableObject {
    struct State: Equatable {
        var userID: String?
        var appleWatch = false
        var liveActivities = false
    }

    @Published private(set) var state = State()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selectUser(_ userID: String?) {
        let userID = userID.flatMap { $0.isEmpty ? nil : $0 }
        guard userID != state.userID else { return }
        guard let userID else {
            state = State()
            return
        }
        let saved = defaults.dictionary(forKey: key(for: userID)) ?? [:]
        state = State(
            userID: userID,
            appleWatch: saved["appleWatch"] as? Bool ?? false,
            liveActivities: saved["liveActivities"] as? Bool ?? false
        )
    }

    func setAppleWatch(_ enabled: Bool) {
        update(appleWatch: enabled, liveActivities: state.liveActivities)
    }

    func setLiveActivities(_ enabled: Bool) {
        update(appleWatch: state.appleWatch, liveActivities: enabled)
    }

    private func update(appleWatch: Bool, liveActivities: Bool) {
        guard let userID = state.userID else { return }
        let next = State(userID: userID, appleWatch: appleWatch, liveActivities: liveActivities)
        guard state != next else { return }
        defaults.set([
            "appleWatch": appleWatch,
            "liveActivities": liveActivities
        ], forKey: key(for: userID))
        state = next
    }

    private func key(for userID: String) -> String {
        "user_companion_preferences_v1.\(userID)"
    }
}
