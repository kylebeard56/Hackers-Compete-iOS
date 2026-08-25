import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchConnectivityService: NSObject, ObservableObject, Loggable {
    @Published private(set) var isReachable = false
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var activationState: WCSessionActivationState = .notActivated

    var mutationHandler: ((WatchScoreMutation) async -> WatchScoreAcknowledgement)?

    private var pendingApplicationContext: [String: Any]?
    private var latestApplicationContext: [String: Any]?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        updateState(from: session)
        flushPendingApplicationContext(using: session)
    }

    func send(snapshot: WatchRoundSnapshot?) {
        let applicationContext: [String: Any]
        do {
            if let snapshot {
                let data = try WatchConnectivityContract.encode(snapshot)
                applicationContext = [
                    WatchConnectivityContract.snapshotKey: data
                ]
            } else {
                applicationContext = [
                    WatchConnectivityContract.emptyStateKey: true
                ]
            }
        } catch {
            addBreadcrumb(level: .error, message: "Failed to encode Apple Watch round context", error: error)
            return
        }
        latestApplicationContext = applicationContext
        pendingApplicationContext = applicationContext
        flushPendingApplicationContext()
    }

    private func flushPendingApplicationContext(using providedSession: WCSession? = nil) {
        guard let applicationContext = pendingApplicationContext,
              let session = providedSession ?? session,
              session.activationState == .activated else {
            return
        }
        do {
            try session.updateApplicationContext(applicationContext)
            pendingApplicationContext = nil
        } catch {
            addBreadcrumb(level: .error, message: "Failed to update Apple Watch round context", error: error)
        }
    }

    private func deliver(
        _ mutation: WatchScoreMutation,
        replyHandler: (([String: Any]) -> Void)?
    ) async {
        let acknowledgement: WatchScoreAcknowledgement
        if let mutationHandler {
            acknowledgement = await mutationHandler(mutation)
        } else {
            acknowledgement = WatchScoreAcknowledgement(
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

        guard let data = try? WatchConnectivityContract.encode(acknowledgement) else {
            replyHandler?([:])
            return
        }
        if let replyHandler {
            replyHandler([WatchConnectivityContract.acknowledgementKey: data])
        } else if let session {
            if session.isReachable {
                session.sendMessage(
                    [WatchConnectivityContract.acknowledgementKey: data],
                    replyHandler: nil,
                    errorHandler: { _ in
                        session.transferUserInfo([
                            WatchConnectivityContract.acknowledgementKey: data
                        ])
                    }
                )
            } else {
                session.transferUserInfo([
                    WatchConnectivityContract.acknowledgementKey: data
                ])
            }
        }
    }

    private func updateState(from session: WCSession) {
        isReachable = session.isReachable
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        activationState = session.activationState
    }
}

extension PhoneWatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.updateState(from: session)
            if let error {
                self?.addBreadcrumb(
                    level: .error,
                    message: "Apple Watch session activation failed",
                    error: error
                )
            } else {
                self?.flushPendingApplicationContext(using: session)
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.updateState(from: session)
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor [weak self] in
            self?.updateState(from: session)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.updateState(from: session)
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.updateState(from: session)
            self?.flushPendingApplicationContext(using: session)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message[WatchConnectivityContract.snapshotRequestKey] as? Bool == true {
            Task { @MainActor [weak self] in
                replyHandler(self?.latestApplicationContext ?? [:])
            }
            return
        }
        guard let data = message[WatchConnectivityContract.mutationKey] as? Data,
              let mutation = try? WatchConnectivityContract.decode(
                WatchScoreMutation.self,
                from: data
              ) else {
            replyHandler([:])
            return
        }
        Task { @MainActor [weak self] in
            await self?.deliver(mutation, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchConnectivityContract.mutationKey] as? Data,
              let mutation = try? WatchConnectivityContract.decode(
                WatchScoreMutation.self,
                from: data
              ) else {
            return
        }
        Task { @MainActor [weak self] in
            await self?.deliver(mutation, replyHandler: nil)
        }
    }
}
