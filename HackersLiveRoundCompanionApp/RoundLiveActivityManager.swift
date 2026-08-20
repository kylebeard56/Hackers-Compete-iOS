import ActivityKit
import Foundation

@MainActor
final class RoundLiveActivityManager: Loggable {
    static let staleInterval: TimeInterval = 20 * 60

    private(set) var latestState: RoundLiveActivityAttributes.ContentState?

    func synchronize(
        attributes: RoundLiveActivityAttributes,
        state: RoundLiveActivityAttributes.ContentState,
        mayStartNewActivity: Bool
    ) async {
        latestState = state
        let activities = Activity<RoundLiveActivityAttributes>.activities
        for activity in activities where activity.attributes.roundID != attributes.roundID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

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
            // A single alerting update is the supported way to bring a newly started Live
            // Activity forward in Apple Watch's Smart Stack. Routine score updates stay silent.
            await activity.update(
                content,
                alertConfiguration: AlertConfiguration(
                    title: "Round is live",
                    body: "Your scorecard is ready on Apple Watch.",
                    sound: .default
                )
            )
        } catch {
            addBreadcrumb(level: .error, message: "Failed to start live round activity", error: error)
        }
    }

    func markStale() async {
        guard let latestState else { return }
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

    func end(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        latestState = nil
        for activity in Activity<RoundLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: dismissalPolicy)
        }
    }
}
