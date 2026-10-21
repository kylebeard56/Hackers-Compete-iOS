import ActivityKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class LiveRoundCompanionCoordinator: ObservableObject, Loggable {
    @Published private(set) var selectedRoundID: String?
    @Published private(set) var liveActivityRoundID: String?
    @Published private(set) var watchIsReachable = false
    @Published private(set) var watchIsPaired = false
    @Published private(set) var watchAppIsInstalled = false
    @Published private(set) var lastProjection: WatchRoundSnapshot?

    let preferences: UserCompanionPreferences
    @Published private(set) var liveActivitiesAvailable = ActivityAuthorizationInfo().areActivitiesEnabled

    private let selectionStore: SelectedLiveRoundStore
    private let watchConnectivity: PhoneWatchConnectivityService
    private let processedMutations: ProcessedWatchMutationStore
    private let companionRoundSession: RoundSession
    private let liveRoundViewModel: LiveRoundViewModel
    private let activityRoundSession: RoundSession
    private let activityViewModel: LiveRoundViewModel
    private let activityManager: any RoundLiveActivityManaging
    private let scoreService = RoundScoreCommandService()
    private let subjectBuilder = RoundScoringSubjectBuilder()
    private let watchCompetitionBuilder = WatchCompetitionProjectionBuilder()
    private let activityStateBuilder = RoundLiveActivityStateBuilder()

    private weak var appSession: AppSession?
    private var cancellables = Set<AnyCancellable>()
    private var watchActivationTask: Task<Void, Never>?
    private var watchProjectionTask: Task<Void, Never>?
    private var activityActivationTask: Task<Void, Never>?
    private var activityProjectionTask: Task<Void, Never>?
    private var watchPublishGeneration = 0
    private var activityPublishGeneration = 0
    private var isAppActive = true
    private var didStart = false

    init(
        selectionStore: SelectedLiveRoundStore? = nil,
        watchConnectivity: PhoneWatchConnectivityService? = nil,
        processedMutations: ProcessedWatchMutationStore? = nil,
        companionRoundSession: RoundSession? = nil,
        liveRoundViewModel: LiveRoundViewModel? = nil,
        activityRoundSession: RoundSession? = nil,
        activityViewModel: LiveRoundViewModel? = nil,
        activityManager: (any RoundLiveActivityManaging)? = nil,
        preferences: UserCompanionPreferences? = nil
    ) {
        let resolvedPreferences = preferences ?? UserCompanionPreferences()
        self.preferences = resolvedPreferences
        let resolvedSelectionStore = selectionStore ?? SelectedLiveRoundStore()
        if let userID = resolvedPreferences.state.userID {
            resolvedSelectionStore.selectUser(userID)
        }
        let resolvedWatchConnectivity = watchConnectivity ?? PhoneWatchConnectivityService()
        self.selectionStore = resolvedSelectionStore
        self.watchConnectivity = resolvedWatchConnectivity
        self.processedMutations = processedMutations ?? ProcessedWatchMutationStore()
        self.companionRoundSession = companionRoundSession ?? RoundSession()
        self.liveRoundViewModel = liveRoundViewModel ?? LiveRoundViewModel()
        self.activityRoundSession = activityRoundSession ?? RoundSession()
        self.activityViewModel = activityViewModel ?? LiveRoundViewModel()
        self.activityManager = activityManager ?? RoundLiveActivityManager()
        self.activityManager.isEnabled = resolvedPreferences.state.liveActivities
        selectedRoundID = resolvedSelectionStore.roundID
        liveActivityRoundID = resolvedSelectionStore.liveActivityRoundID

        resolvedPreferences.$state
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] state in self?.preferencesDidChange(to: state) }
            .store(in: &cancellables)

        resolvedSelectionStore.$roundID
            .removeDuplicates()
            .sink { [weak self] roundID in
                guard let self else { return }
                selectedRoundID = roundID
                scheduleWatchActivation(for: roundID)
            }
            .store(in: &cancellables)

        resolvedSelectionStore.$liveActivityRoundID
            .removeDuplicates()
            .sink { [weak self] roundID in
                guard let self else { return }
                liveActivityRoundID = roundID
                scheduleActivityActivation(for: roundID)
            }
            .store(in: &cancellables)

        resolvedWatchConnectivity.$isReachable
            .removeDuplicates()
            .sink { [weak self] in self?.watchIsReachable = $0 }
            .store(in: &cancellables)

        resolvedWatchConnectivity.$isPaired
            .removeDuplicates()
            .sink { [weak self] in self?.watchIsPaired = $0 }
            .store(in: &cancellables)

        resolvedWatchConnectivity.$isWatchAppInstalled
            .removeDuplicates()
            .sink { [weak self] in self?.watchAppIsInstalled = $0 }
            .store(in: &cancellables)

        self.companionRoundSession.$snapshot
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleWatchProjectionPublish() }
            .store(in: &cancellables)

        self.activityRoundSession.$snapshot
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleActivityProjectionPublish() }
            .store(in: &cancellables)

        self.liveRoundViewModel.$matchupProbabilities
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWatchProjectionPublish()
                self?.scheduleActivityProjectionPublish()
            }
            .store(in: &cancellables)

        resolvedWatchConnectivity.mutationHandler = { [weak self] mutation in
            guard let self else {
                return Self.unavailableAcknowledgement(for: mutation)
            }
            return await self.handle(mutation)
        }
        resolvedWatchConnectivity.activate()
    }

    deinit {
        watchActivationTask?.cancel()
        watchProjectionTask?.cancel()
        activityActivationTask?.cancel()
        activityProjectionTask?.cancel()
    }

    func start(appSession: AppSession) async {
        guard !didStart else { return }
        self.appSession = appSession
        appSession.$settingsUserID
            .removeDuplicates()
            .sink { [weak self] in self?.preferences.selectUser($0) }
            .store(in: &cancellables)
        liveRoundViewModel.bind(
            appSession: appSession,
            roundSession: companionRoundSession
        )
        liveRoundViewModel.startMatchupProbabilityPrecomputation()
        activityViewModel.bind(
            appSession: appSession,
            roundSession: activityRoundSession
        )
        didStart = true
        await activateWatch(roundID: selectionStore.roundID)
        await activateLiveActivity(roundID: selectionStore.liveActivityRoundID)
    }

    func reconcileEligibleRounds(_ rounds: [Round], currentPlayerID: String?) {
        guard let currentPlayerID else {
            // Player data can still be loading during same-account restoration.
            // Sign-out clears selections explicitly in resetSelections().
            return
        }
        let eligibleRoundIDs = rounds.filter {
            $0.status == .live && $0.players.contains(currentPlayerID)
        }.map(\.id)
        selectionStore.reconcile(eligibleRoundIDs: eligibleRoundIDs)
    }

    func select(roundID: String?) {
        let normalized = roundID?.isPopulated == true ? roundID : nil
        if selectedRoundID == normalized {
            if normalized != nil {
                lastProjection = nil
                scheduleWatchActivation(for: normalized)
                scheduleActivityActivation(for: normalized)
            }
            return
        }
        lastProjection = nil
        selectionStore.select(normalized)
    }

    func resetSelections() {
        preferences.selectUser(nil)
        selectionStore.selectUser(nil)
        selectionStore.select(nil)
    }

    private func preferencesDidChange(to state: UserCompanionPreferences.State) {
        let previous = preferences.state
        let identityChanged = previous.userID != state.userID
        let selectionOwnerChanged = identityChanged && selectionStore.selectUser(state.userID)
        if identityChanged || previous.appleWatch != state.appleWatch {
            watchActivationTask?.cancel()
            watchProjectionTask?.cancel()
            watchPublishGeneration += 1
            companionRoundSession.stop()
            lastProjection = nil
            watchConnectivity.send(snapshot: nil)
            scheduleWatchActivation(for: selectedRoundID)
        }
        if identityChanged || previous.liveActivities != state.liveActivities {
            activityManager.isEnabled = state.liveActivities
            activityProjectionTask?.cancel()
            activityPublishGeneration += 1
            activityRoundSession.stop()
            scheduleActivityActivation(
                for: liveActivityRoundID,
                endExistingActivity: selectionOwnerChanged || !state.liveActivities
            )
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        isAppActive = phase == .active
        switch phase {
        case .active:
            liveActivitiesAvailable = ActivityAuthorizationInfo().areActivitiesEnabled
            watchProjectionTask?.cancel()
            watchProjectionTask = Task { [weak self] in
                guard let self,
                      preferences.state.appleWatch,
                      let selectedRoundID else { return }
                await companionRoundSession.refreshOneShotSnapshot(for: selectedRoundID)
                await publishWatchProjection()
            }
            activityProjectionTask?.cancel()
            activityProjectionTask = Task { [weak self] in
                guard let self,
                      preferences.state.liveActivities,
                      let liveActivityRoundID else { return }
                await activityRoundSession.refreshOneShotSnapshot(for: liveActivityRoundID)
                await publishLiveActivity()
            }
        case .background:
            break
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func scheduleWatchActivation(for roundID: String?) {
        guard didStart else { return }
        watchActivationTask?.cancel()
        watchActivationTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            await self?.activateWatch(roundID: roundID)
        }
    }

    private func activateWatch(roundID: String?) async {
        guard preferences.state.appleWatch, let roundID, roundID.isPopulated else {
            companionRoundSession.stop()
            lastProjection = nil
            watchConnectivity.send(snapshot: nil)
            return
        }
        await companionRoundSession.activate(roundID: roundID, profile: .liveRound)
        guard !Task.isCancelled else { return }
        await liveRoundViewModel.ensureParticipantResolved()
        await publishWatchProjection()
    }

    private func scheduleActivityActivation(for roundID: String?, endExistingActivity: Bool = false) {
        guard didStart else { return }
        let previousTask = activityActivationTask
        let previousProjection = activityProjectionTask
        previousTask?.cancel()
        previousProjection?.cancel()
        activityActivationTask = Task { [weak self] in
            // Complete native work in order. An OFF transition must end the activity even
            // if another preference change cancels this task before it starts.
            await previousTask?.value
            await previousProjection?.value
            if endExistingActivity {
                await self?.activityManager.end()
                if self?.preferences.state.liveActivities != true { return }
            }
            guard !Task.isCancelled else { return }
            await self?.activateLiveActivity(roundID: roundID)
        }
    }

    private func activateLiveActivity(roundID: String?) async {
        guard preferences.state.liveActivities, let roundID, roundID.isPopulated else {
            activityRoundSession.stop()
            await activityManager.end()
            return
        }
        await activityRoundSession.activate(roundID: roundID, profile: .liveRound)
        guard !Task.isCancelled else { return }
        await activityViewModel.ensureParticipantResolved()
        await publishLiveActivity()
    }

    private func scheduleWatchProjectionPublish() {
        guard didStart else { return }
        watchProjectionTask?.cancel()
        watchProjectionTask = Task { [weak self] in
            await self?.publishWatchProjection()
        }
    }

    private func scheduleActivityProjectionPublish() {
        guard didStart else { return }
        activityProjectionTask?.cancel()
        activityProjectionTask = Task { [weak self] in
            await self?.publishLiveActivity()
        }
    }

    private func publishWatchProjection() async {
        watchPublishGeneration += 1
        let generation = watchPublishGeneration
        guard preferences.state.appleWatch, let selectedRoundID,
              companionRoundSession.snapshot.round.id == selectedRoundID else {
            return
        }
        await liveRoundViewModel.ensureParticipantResolved()
        guard !Task.isCancelled, generation == watchPublishGeneration, preferences.state.appleWatch else { return }
        guard let participantID = liveRoundViewModel.currentParticipantID else {
            lastProjection = nil
            watchConnectivity.send(snapshot: nil)
            return
        }
        do {
            let basis = competitionScoreBasis(for: companionRoundSession.snapshot)
            if liveRoundViewModel.matchupScoreBasis != basis {
                liveRoundViewModel.matchupScoreBasis = basis
            }
            let nameDisplayFormat = NameDisplayFormat.persisted
            let competitions = watchCompetitionBuilder.build(
                viewModel: liveRoundViewModel,
                participantID: participantID,
                nameDisplayFormat: nameDisplayFormat,
                matchupProbabilities: liveRoundViewModel.publishableMatchupProbabilities,
                scoreBasis: basis
            )
            let projection = try subjectBuilder.build(
                snapshot: companionRoundSession.snapshot,
                participantID: participantID,
                competitions: competitions,
                nameDisplayFormat: nameDisplayFormat,
                acknowledgedMutationIDs: processedMutations.acceptedMutationIDs(for: selectedRoundID)
            )
            guard !Task.isCancelled, generation == watchPublishGeneration, preferences.state.appleWatch else { return }
            lastProjection = projection
            watchConnectivity.send(snapshot: projection)
        } catch {
            lastProjection = nil
            watchConnectivity.send(snapshot: nil)
            addBreadcrumb(
                level: .error,
                message: "Failed to build Apple Watch round projection",
                error: error
            )
        }
    }

    private func publishLiveActivity() async {
        activityPublishGeneration += 1
        let generation = activityPublishGeneration
        guard preferences.state.liveActivities, let liveActivityRoundID,
              activityRoundSession.snapshot.round.id == liveActivityRoundID else {
            return
        }
        await activityViewModel.ensureParticipantResolved()
        guard !Task.isCancelled, generation == activityPublishGeneration, preferences.state.liveActivities else { return }
        guard let participantID = activityViewModel.currentParticipantID else {
            await activityManager.end()
            return
        }
        do {
            let projection = try subjectBuilder.build(
                snapshot: activityRoundSession.snapshot,
                participantID: participantID,
                acknowledgedMutationIDs: processedMutations.acceptedMutationIDs(for: liveActivityRoundID)
            )
            let basis = competitionScoreBasis(for: activityRoundSession.snapshot)
            if liveRoundViewModel.matchupScoreBasis != basis {
                liveRoundViewModel.matchupScoreBasis = basis
            }
            if activityViewModel.matchupScoreBasis != basis {
                activityViewModel.matchupScoreBasis = basis
            }
            let probabilities: [String: MatchupProbability]
            if liveRoundViewModel.snapshot.round.id == liveActivityRoundID,
               liveRoundViewModel.projectionRevision(scoreBasis: basis)
                == activityViewModel.projectionRevision(scoreBasis: basis) {
                probabilities = liveRoundViewModel.publishableMatchupProbabilities
            } else {
                probabilities = [:]
            }
            guard let contentState = activityStateBuilder.build(
                viewModel: activityViewModel,
                watchSnapshot: projection,
                matchupProbabilities: probabilities,
                scoreBasis: basis
            ) else {
                await activityManager.end()
                return
            }
            guard !Task.isCancelled, generation == activityPublishGeneration, preferences.state.liveActivities else { return }
            await activityManager.synchronize(
                attributes: .init(
                    roundID: liveActivityRoundID,
                    participantID: participantID
                ),
                state: contentState,
                mayStartNewActivity: isAppActive && projection.phase == .live
            )
        } catch {
            await activityManager.end()
        }
    }

    private func competitionScoreBasis(for snapshot: RoundSnapshot) -> ScoreBasis {
        snapshot.configuration.useHandicaps ? .net : .gross
    }

    private func handle(_ mutation: WatchScoreMutation) async -> WatchScoreAcknowledgement {
        let userID = preferences.state.userID
        guard preferences.state.appleWatch, userID != nil else {
            return Self.disabledAcknowledgement(for: mutation)
        }
        if let existing = processedMutations.acknowledgement(for: mutation.id) {
            return existing
        }

        let commandSession: RoundSession
        let shouldStopCommandSession: Bool
        if companionRoundSession.snapshot.round.id == mutation.roundID {
            commandSession = companionRoundSession
            shouldStopCommandSession = false
        } else {
            let temporarySession = RoundSession()
            do {
                temporarySession.snapshot = try await companionRoundSession.fetchSingleInstance(
                    for: mutation.roundID,
                    preferServer: true
                )
            } catch {
                let acknowledgement = WatchScoreAcknowledgement(
                    id: mutation.id,
                    roundID: mutation.roundID,
                    status: .failed,
                    canonicalValue: nil,
                    canonicalRevision: nil,
                    errorCategory: .roundUnavailable,
                    message: "The round could not be refreshed on iPhone.",
                    acknowledgedAt: Date()
                )
                processedMutations.insert(acknowledgement)
                return acknowledgement
            }
            commandSession = temporarySession
            shouldStopCommandSession = true
        }

        guard let participantID = await resolveParticipantID(in: commandSession.snapshot) else {
            let acknowledgement = WatchScoreAcknowledgement(
                id: mutation.id,
                roundID: mutation.roundID,
                status: .rejected,
                canonicalValue: nil,
                canonicalRevision: nil,
                errorCategory: .unauthorized,
                message: "You are no longer a participant in this round.",
                acknowledgedAt: Date()
            )
            processedMutations.insert(acknowledgement)
            return acknowledgement
        }

        guard preferences.state.appleWatch, preferences.state.userID == userID else {
            if shouldStopCommandSession { commandSession.stop() }
            return Self.disabledAcknowledgement(for: mutation)
        }
        let acknowledgement = await scoreService.execute(
            mutation,
            in: commandSession,
            participantID: participantID
        )
        processedMutations.insert(acknowledgement)
        if shouldStopCommandSession {
            commandSession.stop()
        } else {
            await publishWatchProjection()
        }
        return acknowledgement
    }

    private func resolveParticipantID(in snapshot: RoundSnapshot) async -> String? {
        if let ephemeral = appSession?.ephemeralParticipantID,
           snapshot.participants.contains(where: { $0.id == ephemeral }) {
            return ephemeral
        }
        if let primaryPlayerID = await AppData.shared.getPrimaryPlayer()?.id,
           let participant = snapshot.participants.first(where: { $0.playerID == primaryPlayerID }) {
            return participant.id
        }
        if let userID = await AppData.shared.user?.id,
           let participant = snapshot.participants.first(where: { $0.userID == userID }) {
            return participant.id
        }
        return nil
    }

    private nonisolated static func disabledAcknowledgement(
        for mutation: WatchScoreMutation
    ) -> WatchScoreAcknowledgement {
        WatchScoreAcknowledgement(
            id: mutation.id,
            roundID: mutation.roundID,
            status: .rejected,
            canonicalValue: nil,
            canonicalRevision: nil,
            errorCategory: .unauthorized,
            message: "Apple Watch is off. Enable it in Settings on iPhone to enter scores.",
            acknowledgedAt: Date()
        )
    }

    private nonisolated static func unavailableAcknowledgement(
        for mutation: WatchScoreMutation
    ) -> WatchScoreAcknowledgement {
        WatchScoreAcknowledgement(
            id: mutation.id,
            roundID: mutation.roundID,
            status: .failed,
            canonicalValue: nil,
            canonicalRevision: nil,
            errorCategory: .roundUnavailable,
            message: "Open Hackers on iPhone to finish syncing.",
            acknowledgedAt: Date()
        )
    }
}
