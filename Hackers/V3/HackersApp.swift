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
    
    @State private var showMAV: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack(path: $appSession.path) {
                    AuthView()
                        .navigationDestination(for: Destination.self, destination: { d in
                            Navigator.viewFor(destination: d)
                        })
                }
                
                if showMAV {
                    //AppVersionView()
                }
            }
//            .environmentObject(appSession)
//            .environmentObject(purchaseStore)
            .task {
                //await purchaseStore.updatePurchasedProducts()
            }
            .onReceive(HackersNotification.appVersionNotMet.publisher()) { data in
                if let notMet = data.object as? Bool {
                    showMAV = notMet
                }
            }
            .onChange(of: scenePhase) { old, new in
                handleApp(for: new)
            }
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
