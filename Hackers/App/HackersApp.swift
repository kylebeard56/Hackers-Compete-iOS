//
//  HackersApp.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import SwiftUI

@main
struct HackersApp: App, Loggable {
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    
    @StateObject var appSession = AppSession()
    @StateObject var locationService = LocationService()
    @StateObject var roundSession = RoundSession()
    @StateObject var liveRoundCompanion = LiveRoundCompanionCoordinator()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $appSession.path) {
                AuthView()
                    .navigationDestination(for: Destination.self, destination: { d in
                        Navigator.viewFor(destination: d)
                    })
            }
            .environmentObject(appSession)
            .environmentObject(locationService)
            .environmentObject(roundSession)
            .environmentObject(liveRoundCompanion)
            .task {
                await liveRoundCompanion.start(appSession: appSession)
            }
            .task {
                /// Ensure app version is sufficient, will route automatically if not.
                await FirebaseService.shared.observeMinimumAppVersion()
            }
            .onReceive(HackersNotification.minimumAppVersionDetected.publisher()) { data in
                if let isSufficient = data.object as? Bool, !isSufficient {
                    if isSufficient {
                        appSession.routeTo(.auth)
                    } else {
                        appSession.routeTo(.minimumAppVersion)
                    }
                }
            }
            .onReceive(HackersNotification.triggerLogout.publisher()) { _ in
                roundSession.stop()
                liveRoundCompanion.resetSelections()
                appSession.reset()
            }
            .onChange(of: scenePhase) { old, new in
                liveRoundCompanion.handleScenePhase(new)
                handleApp(for: new)
            }
            .onOpenURL(perform: { url in
                addBreadcrumb(message: "onOpenURL: \(url.absoluteString)")
                if let payload = url.liveRoundDeepLinkPayload {
                    Task {
                        await openLiveRoundDeepLink(payload)
                    }
                    return
                }
                addEvent(
                    "join.deep_link_opened",
                    eventProps: ["url": url.absoluteString]
                )

                guard let payload = url.joinDeepLinkPayload else {
                    addBreadcrumb(message: "deep link URL undiscoverable")
                    addEvent("join.deep_link_failed")
                    return
                }

                let token = payload.token
                let kind: String = {
                    switch payload {
                    case .roundID:      return "round_id"
                    case .seriesID:     return "series_id"
                    case .legacyCode:   return "legacy_code"
                    }
                }()
                addBreadcrumb(message: "join deep link token resolved, kind: \(kind)")
                addEvent(
                    "join.deep_link_resolved",
                    eventProps: [
                        "token_length": token.count,
                        "link_kind": kind
                    ]
                )

                switch payload {
                case .roundID(let value):
                    appSession.pendingJoinLink = .round(token: value)
                case .seriesID(let value):
                    appSession.pendingJoinLink = .series(token: value)
                case .legacyCode(let value):
                    appSession.pendingJoinLink = .round(token: value)
                    appSession.shareCode = value
                }
                if appSession.isUserAuthenticated {
                    appSession.routeTo(.dashboard)
                }
                HackersNotification.joinFromDeepLink.send()
            })
        }
    }

    @MainActor
    private func openLiveRoundDeepLink(_ payload: LiveRoundDeepLinkPayload) async {
        guard case .success(let round) = await FirebaseService.shared.getRoundDocument(byID: payload.roundID) else {
            appSession.routeTo(.dashboard)
            return
        }
        appSession.activeRoundID = round.id
        switch RoundResumeRouter.resolve(status: round.status) {
        case .lobby:
            appSession.routeTo(.lobby)
        case .liveRound:
            appSession.persistRoundResume(
                destination: .liveRound,
                selectedHole: payload.holeNumber,
                selectedTab: .scoring
            )
            appSession.routeTo(.liveRound)
        case .outcome:
            appSession.roundOutcomeAllowsEditing = true
            appSession.routeTo(.roundOutcome)
        case .discard:
            appSession.routeTo(.dashboard)
        }
    }
    
    /// Detect if any app scenes changed and send notifications.
    private func handleApp(for scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            HackersNotification.appSceneDidBecomeActive.send()
        case .inactive:
            HackersNotification.appSceneDidBecomeInactive.send()
        case .background:
            HackersNotification.appSceneDidEnterBackground.send()
        @unknown default:
            print("App scene unknown")
        }
    }
}
