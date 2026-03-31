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
                appSession.reset()
            }
            .onChange(of: scenePhase) { old, new in
                handleApp(for: new)
            }
            .onOpenURL(perform: { url in
                addBreadcrumb(message: "onOpenURL: \(url.absoluteString)")
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
                HackersNotification.joinFromDeepLink.send()
            })
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
