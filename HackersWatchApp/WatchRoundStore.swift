import Foundation
import WatchConnectivity
import WatchKit

@MainActor
final class WatchRoundStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchRoundSnapshot?
    @Published var selectedHole: Int = 1
    @Published private(set) var pendingMutations: [PendingWatchMutation] = []
    @Published private(set) var isPhoneReachable = false
    @Published private(set) var deepLinkNavigationRevision = 0

    private let defaults: UserDefaults
    private var deviceSequence: Int64
    private var pendingDeepLinkRoundID: String?
    private var pendingDeepLinkHole: Int?

    private enum StorageKey {
        static let snapshot = "watch_round_snapshot_v1"
        static let pending = "watch_score_outbox_v1"
        static let sequence = "watch_score_sequence_v1"
        static let selectedHole = "watch_selected_hole_v1"
    }

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    init(
        snapshot: WatchRoundSnapshot? = nil,
        defaults: UserDefaults = .standard,
        activateSession: Bool = true
    ) {
        let restoredSnapshot = snapshot ?? defaults.data(forKey: StorageKey.snapshot)
            .flatMap { try? WatchConnectivityContract.decode(WatchRoundSnapshot.self, from: $0) }
        self.defaults = defaults
        self.snapshot = restoredSnapshot
        pendingMutations = defaults.data(forKey: StorageKey.pending)
            .flatMap { try? WatchConnectivityContract.decode([PendingWatchMutation].self, from: $0) }
            ?? []
        deviceSequence = Int64(defaults.integer(forKey: StorageKey.sequence))
        let restoredHole = defaults.integer(forKey: StorageKey.selectedHole)
        selectedHole = restoredSnapshot?.holes.contains(where: { $0.number == restoredHole }) == true
            ? restoredHole
            : restoredSnapshot?.selectedHole ?? 1
        super.init()
        if activateSession {
            activate()
        }
    }

    func value(for subject: WatchRoundSnapshot.Subject, holeNumber: Int) -> Int? {
        guard let unit = subject.unit(for: holeNumber) else { return nil }
        if let pending = pendingMutation(for: unit.scoringUnitID, holeNumber: holeNumber),
           pending.state == .pending,
           case .set(let value) = pending.mutation.operation {
            return value
        }
        if let pending = pendingMutation(for: unit.scoringUnitID, holeNumber: holeNumber),
           case .clear = pending.mutation.operation,
           pending.state == .pending {
            return nil
        }
        return snapshot?.score(for: unit.scoringUnitID, holeNumber: holeNumber)?.value
    }

    func grossValue(for subject: WatchRoundSnapshot.Subject, holeNumber: Int) -> Int? {
        guard let snapshot,
              let value = value(for: subject, holeNumber: holeNumber) else {
            return nil
        }
        guard snapshot.inputMode == .relativeToPar else { return value }
        let par = snapshot.holes.first { $0.number == holeNumber }?.par ?? 4
        return max(1, par + value)
    }

    func grossTotal(for subject: WatchRoundSnapshot.Subject) -> Int? {
        guard let snapshot else { return nil }
        let values = snapshot.holes.compactMap {
            grossValue(for: subject, holeNumber: $0.number)
        }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    func cumulativeScore(
        for subject: WatchRoundSnapshot.Subject,
        basis: WatchScoreBasis
    ) -> WatchCumulativeScoreSummary {
        guard let snapshot else {
            return .init(displayValue: "—", completedHoles: 0, totalHoles: 0, isComplete: false)
        }
        return snapshot.cumulativeScore(for: subject, basis: basis) {
            value(for: $0, holeNumber: $1)
        }
    }

    func completedSubjectCount(on holeNumber: Int) -> Int {
        snapshot?.subjects.count { value(for: $0, holeNumber: holeNumber) != nil } ?? 0
    }

    func completedHoleCount() -> Int {
        guard let snapshot, !snapshot.subjects.isEmpty else { return 0 }
        return snapshot.holes.filter { hole in
            snapshot.subjects.allSatisfy { value(for: $0, holeNumber: hole.number) != nil }
        }.count
    }

    func competition(ofKind kind: WatchRoundSnapshot.Competition.Kind) -> WatchRoundSnapshot.Competition? {
        snapshot?.competitions.first { $0.kind == kind }
    }

    func status(
        for subject: WatchRoundSnapshot.Subject,
        holeNumber: Int
    ) -> PendingWatchMutation.State? {
        guard let unit = subject.unit(for: holeNumber) else { return nil }
        return pendingMutation(for: unit.scoringUnitID, holeNumber: holeNumber)?.state
    }

    func statusMessage(
        for subject: WatchRoundSnapshot.Subject,
        holeNumber: Int
    ) -> String? {
        guard let unit = subject.unit(for: holeNumber) else { return nil }
        return pendingMutation(for: unit.scoringUnitID, holeNumber: holeNumber)?.message
    }

    func save(
        value: Int,
        subject: WatchRoundSnapshot.Subject,
        holeNumber: Int
    ) {
        enqueue(operation: .set(value), subject: subject, holeNumber: holeNumber)
    }

    func clear(subject: WatchRoundSnapshot.Subject, holeNumber: Int) {
        enqueue(operation: .clear, subject: subject, holeNumber: holeNumber)
    }

    func selectPreviousHole() {
        guard let holes = snapshot?.holes,
              let index = holes.firstIndex(where: { $0.number == selectedHole }),
              index > holes.startIndex else { return }
        selectedHole = holes[holes.index(before: index)].number
        persistSelectedHole()
    }

    func selectNextHole() {
        guard let holes = snapshot?.holes,
              let index = holes.firstIndex(where: { $0.number == selectedHole }),
              index < holes.index(before: holes.endIndex) else { return }
        selectedHole = holes[holes.index(after: index)].number
        persistSelectedHole()
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let roundID = items.first(where: { $0.name == "round_id" })?.value,
              !roundID.isEmpty,
              let rawHole = items.first(where: { $0.name == "hole" })?.value,
              let hole = Int(rawHole) else {
            return false
        }
        pendingDeepLinkRoundID = roundID
        pendingDeepLinkHole = hole
        applyPendingDeepLinkIfPossible()
        requestSnapshotIfPossible()
        return true
    }

    private func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        isPhoneReachable = session.isReachable
    }

    private func requestSnapshotIfPossible() {
        guard let session,
              session.activationState == .activated,
              session.isReachable else { return }
        session.sendMessage(
            [WatchConnectivityContract.snapshotRequestKey: true],
            replyHandler: { [weak self] payload in
                Task { @MainActor in
                    self?.applyApplicationContext(payload)
                }
            },
            errorHandler: nil
        )
    }

    private func enqueue(
        operation: WatchScoreMutation.Operation,
        subject: WatchRoundSnapshot.Subject,
        holeNumber: Int
    ) {
        guard snapshot?.phase == .live,
              let snapshot,
              let unit = subject.unit(for: holeNumber) else {
            return
        }
        if pendingMutation(for: unit.scoringUnitID, holeNumber: holeNumber)?.state == .pending {
            return
        }
        pendingMutations.removeAll {
            $0.mutation.roundID == snapshot.roundID
                && $0.mutation.holeNumber == holeNumber
                && $0.mutation.scoringUnitID == unit.scoringUnitID
        }
        deviceSequence += 1
        defaults.set(Int(deviceSequence), forKey: StorageKey.sequence)
        let mutation = WatchScoreMutation(
            deviceSequence: deviceSequence,
            roundID: snapshot.roundID,
            holeNumber: holeNumber,
            scoringUnitID: unit.scoringUnitID,
            participantIDs: unit.participantIDs,
            anchorParticipantID: subject.anchorParticipantID,
            operation: operation,
            observedScoreRevision: snapshot.score(
                for: unit.scoringUnitID,
                holeNumber: holeNumber
            )?.revision
        )
        pendingMutations.append(
            PendingWatchMutation(mutation: mutation, state: .pending, message: nil)
        )
        persistOutbox()
        deliver(mutation)
    }

    private func deliver(_ mutation: WatchScoreMutation) {
        guard let session,
              let data = try? WatchConnectivityContract.encode(mutation) else {
            markFailed(mutation.id, message: "Could not prepare this score.")
            return
        }
        let message = [WatchConnectivityContract.mutationKey: data]
        if session.isReachable {
            session.sendMessage(
                message,
                replyHandler: { [weak self] reply in
                    guard let acknowledgementData = reply[WatchConnectivityContract.acknowledgementKey] as? Data,
                          let acknowledgement = try? WatchConnectivityContract.decode(
                            WatchScoreAcknowledgement.self,
                            from: acknowledgementData
                          ) else {
                        return
                    }
                    Task { @MainActor in
                        self?.apply(acknowledgement)
                    }
                },
                errorHandler: { _ in
                    session.transferUserInfo(message)
                }
            )
        } else {
            session.transferUserInfo(message)
        }
    }

    private func apply(_ acknowledgement: WatchScoreAcknowledgement) {
        guard let index = pendingMutations.firstIndex(where: { $0.id == acknowledgement.id }) else {
            return
        }
        let mutation = pendingMutations[index].mutation
        switch acknowledgement.status {
        case .accepted:
            applyCanonicalValue(acknowledgement, mutation: mutation)
            pendingMutations.remove(at: index)
            WKInterfaceDevice.current().play(.success)
        case .conflict:
            applyCanonicalValue(acknowledgement, mutation: mutation)
            pendingMutations[index].state = .conflict
            pendingMutations[index].message = acknowledgement.message
            WKInterfaceDevice.current().play(.failure)
        case .rejected, .failed:
            pendingMutations[index].state = .failed
            pendingMutations[index].message = acknowledgement.message
            WKInterfaceDevice.current().play(.failure)
        }
        persistSnapshot()
        persistOutbox()
    }

    private func applyCanonicalValue(
        _ acknowledgement: WatchScoreAcknowledgement,
        mutation: WatchScoreMutation
    ) {
        guard var snapshot else { return }
        snapshot.scores.removeAll {
            $0.holeNumber == mutation.holeNumber
                && $0.scoringUnitID == mutation.scoringUnitID
        }
        snapshot.scores.append(
            .init(
                holeNumber: mutation.holeNumber,
                scoringUnitID: mutation.scoringUnitID,
                value: acknowledgement.canonicalValue,
                revision: acknowledgement.canonicalRevision
            )
        )
        self.snapshot = snapshot
    }

    private func apply(_ incomingSnapshot: WatchRoundSnapshot) {
        guard WatchRoundSnapshot.supports(schemaVersion: incomingSnapshot.schemaVersion) else { return }
        if let current = snapshot,
           current.roundID == incomingSnapshot.roundID,
           incomingSnapshot.revision < current.revision {
            return
        }
        let switchedRounds = snapshot?.roundID != incomingSnapshot.roundID
        snapshot = incomingSnapshot
        pendingMutations.removeAll {
            incomingSnapshot.acknowledgedMutationIDs.contains($0.id)
        }
        if switchedRounds
            || !incomingSnapshot.holes.contains(where: { $0.number == selectedHole }) {
            selectedHole = incomingSnapshot.selectedHole
        }
        applyPendingDeepLinkIfPossible()
        persistSelectedHole()
        persistSnapshot()
        persistOutbox()
    }

    private func clearRound() {
        snapshot = nil
        selectedHole = 1
        pendingDeepLinkRoundID = nil
        pendingDeepLinkHole = nil
        defaults.removeObject(forKey: StorageKey.snapshot)
        defaults.removeObject(forKey: StorageKey.selectedHole)
    }

    private func applyPendingDeepLinkIfPossible() {
        guard let roundID = pendingDeepLinkRoundID,
              let hole = pendingDeepLinkHole,
              snapshot?.roundID == roundID,
              snapshot?.holes.contains(where: { $0.number == hole }) == true else {
            return
        }
        selectedHole = hole
        pendingDeepLinkRoundID = nil
        pendingDeepLinkHole = nil
        persistSelectedHole()
        deepLinkNavigationRevision &+= 1
    }

    private func pendingMutation(for scoringUnitID: String, holeNumber: Int) -> PendingWatchMutation? {
        pendingMutations.last {
            $0.mutation.scoringUnitID == scoringUnitID
                && $0.mutation.holeNumber == holeNumber
        }
    }

    private func markFailed(_ mutationID: UUID, message: String) {
        guard let index = pendingMutations.firstIndex(where: { $0.id == mutationID }) else { return }
        pendingMutations[index].state = .failed
        pendingMutations[index].message = message
        persistOutbox()
    }

    private func persistSnapshot() {
        guard let snapshot,
              let data = try? WatchConnectivityContract.encode(snapshot) else { return }
        defaults.set(data, forKey: StorageKey.snapshot)
    }

    private func persistOutbox() {
        guard let data = try? WatchConnectivityContract.encode(pendingMutations) else { return }
        defaults.set(data, forKey: StorageKey.pending)
    }

    private func persistSelectedHole() {
        defaults.set(selectedHole, forKey: StorageKey.selectedHole)
    }
}

extension WatchRoundStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = session.isReachable
            if error == nil {
                self?.applyApplicationContext(session.receivedApplicationContext)
                self?.requestSnapshotIfPossible()
                self?.pendingMutations
                    .filter { $0.state == .pending }
                    .forEach { self?.deliver($0.mutation) }
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = session.isReachable
            self?.requestSnapshotIfPossible()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.applyApplicationContext(applicationContext)
        }
    }

    private func applyApplicationContext(_ applicationContext: [String: Any]) {
        if applicationContext[WatchConnectivityContract.emptyStateKey] as? Bool == true {
            clearRound()
            return
        }
        guard let data = applicationContext[WatchConnectivityContract.snapshotKey] as? Data,
              let snapshot = try? WatchConnectivityContract.decode(
                WatchRoundSnapshot.self,
                from: data
              ) else {
            return
        }
        apply(snapshot)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyAcknowledgement(from: message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        applyAcknowledgement(from: userInfo)
    }

    nonisolated private func applyAcknowledgement(from payload: [String: Any]) {
        guard let data = payload[WatchConnectivityContract.acknowledgementKey] as? Data,
              let acknowledgement = try? WatchConnectivityContract.decode(
                WatchScoreAcknowledgement.self,
                from: data
              ) else {
            return
        }
        Task { @MainActor [weak self] in self?.apply(acknowledgement) }
    }
}
