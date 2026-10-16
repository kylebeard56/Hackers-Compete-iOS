import ActivityKit
import Foundation

@MainActor
protocol RoundLiveActivityManaging: AnyObject {
    var isEnabled: Bool { get set }
    func synchronize(
        attributes: RoundLiveActivityAttributes,
        state: RoundLiveActivityAttributes.ContentState,
        mayStartNewActivity: Bool
    ) async
    func end() async
}

@MainActor
final class RoundLiveActivityManager: RoundLiveActivityManaging, Loggable {
    static let staleInterval: TimeInterval = 20 * 60

    var isEnabled = false {
        didSet { if isEnabled != oldValue { preferenceRevision += 1 } }
    }
    private var preferenceRevision = 0
    private(set) var latestState: RoundLiveActivityAttributes.ContentState?

    func synchronize(
        attributes: RoundLiveActivityAttributes,
        state: RoundLiveActivityAttributes.ContentState,
        mayStartNewActivity: Bool
    ) async {
        guard isEnabled, !Task.isCancelled else { return }
        let revision = preferenceRevision
        latestState = state
        let activities = Activity<RoundLiveActivityAttributes>.activities
        for activity in activities where activity.attributes.roundID != attributes.roundID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard isEnabled, revision == preferenceRevision, !Task.isCancelled else { return }
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(Self.staleInterval),
            relevanceScore: 1
        )
        if let activity = activities.first(where: { $0.attributes.roundID == attributes.roundID }) {
            await activity.update(content)
            return
        }

        guard mayStartNewActivity,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        do {
            let activity = try Activity<RoundLiveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            // Let iOS choose Lock Screen, Dynamic Island, and mirrored presentations.
            // Dedicated Watch scoring is controlled separately through WatchConnectivity.
            await activity.update(content)
        } catch {
            addBreadcrumb(level: .error, message: "Failed to start live round activity", error: error)
        }
    }

    func markStale() async {
        guard isEnabled, let latestState else { return }
        let staleState = RoundLiveActivityAttributes.ContentState(
            phase: .stale,
            roundTitle: latestState.roundTitle,
            participantName: latestState.participantName,
            formatLabel: latestState.formatLabel,
            holeLabel: latestState.holeLabel,
            holeProgress: latestState.holeProgress,
            hole: latestState.hole,
            personalScore: latestState.personalScore,
            grossScore: latestState.grossScore,
            teamScore: latestState.teamScore,
            matchup: latestState.matchup,
            competition: latestState.competition,
            isPersonalScoreCounting: latestState.isPersonalScoreCounting,
            deepLinkURL: latestState.deepLinkURL,
            updatedAt: latestState.updatedAt
        )
        self.latestState = staleState
        let content = ActivityContent(
            state: staleState,
            staleDate: Date(),
            relevanceScore: 1
        )
        for activity in Activity<RoundLiveActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    func end() async {
        latestState = nil
        for activity in Activity<RoundLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
