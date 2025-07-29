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
//    @StateObject var purchaseStore = PurchaseStore()
    
//    @State private var presentedAlertView: UIView?
//    @State private var windowPresentable: UIView?
    
//    @State private var showLegal = false
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $appSession.path) {
                AuthView()
                    .navigationDestination(for: Destination.self, destination: { d in
                        Navigator.viewFor(destination: d)
                    })
            }
            .environmentObject(appSession)
//            .environmentObject(purchaseStore)
            .task {
                //await purchaseStore.updatePurchasedProducts()
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
                addBreadcrumb("onOpenURL: \(url.absoluteString)")
                
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let roundID = components?
                    .queryItems?
                    .first(where: { $0.name == "round_id" })?
                    .value, url.path == "/join" {
                    addBreadcrumb("join round from deep link for id: \(roundID)")
                    HackersNotification.joinRoundFromDeepLink.send(with: roundID)
                } else {
                    addBreadcrumb("deep link URL undiscoverable")
                }
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
