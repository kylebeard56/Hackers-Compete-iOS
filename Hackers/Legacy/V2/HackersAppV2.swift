//
//  HackersAppV2.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import SwiftUI

/**
 Test how we can add/remove subscription from App Store so that a user doesn't change it and come back and it's weird.
 */

//@main // Comment out @main when you need to go from V2 to V3 interchangeably.
struct HackersAppV2: App, WindowPresentable {
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    
    @StateObject var appSession = AppSessionV2()
    @StateObject var purchaseStore = PurchaseStore()
    
    @State private var presentedAlertView: UIView?
    @State private var windowPresentable: UIView?
    
    @State private var showMAV: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack(path: $appSession.path) {
                    LandingView()
                        .navigationDestinationV2(for: DestinationV2.self, DestinationV2: { DestinationV2 in
                            ViewFactoryV2.viewForDestinationV2(DestinationV2)
                        })
                }
                
                if showMAV {
                    AppVersionView()
                }
            }
            .environmentObject(appSession)
            .environmentObject(purchaseStore)
            .task {
                await purchaseStore.updatePurchasedProducts()
            }
            .onReceive(HackersNotification.appVersionNotMet.publisher()) { data in
                if let notMet = data.object as? Bool {
                    showMAV = notMet
                }
            }
            .onReceive(HackersNotification.presentAlert.publisher()) { data in
                if let d = data.object as? AlertData {
                    self.handleAlert(d)
                }
            }
            .onReceive(HackersNotification.presentOnWindow.publisher()) { data in
                if let d = data.object as? UIView {
                    self.handleWindowPresentable(for: d)
                }
            }
            .onReceive(HackersNotification.clearWindowPresentable.publisher()) { _ in
                removeWindowPresentable()
            }
            .onChange(of: scenePhase, perform: { phase in
                handleApp(for: phase)
            })
        }
    }
    
    /// Detect if any app scenes changed and send notifications.
    private func handleApp(for scenePhase: ScenePhase) {
        Task(operation: purchaseStore.updatePurchasedProducts)
        appSession.checkExpiration()
        
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

// MARK: - Alerts

extension HackersAppV2 {
    fileprivate func handleAlert(_ data: AlertData) {
        if dismissAlert() { return }
        
        if let window = UIApplication.shared.currentKeyWindow,
            let view = UIHostingController(rootView: buildAlert(with: data)).view {
            
            UIApplication.shared.endEditing()
            view.frame = window.frame
            view.backgroundColor = .clear
            presentedAlertView = view
            window.addSubview(presentedAlertView!)
        }
        
    }

    fileprivate func buildAlert(with data: AlertData) -> some View {
        AlertView(
            alert: data.alert,
            onTap: {
                if let onTap = data.onTap {
                    onTap()
                }
                self.dismissAlert()
            },
            onDismiss: {
                self.dismissAlert()
            })
    }
    
    @discardableResult
    fileprivate func dismissAlert() -> Bool {
        if let view = presentedAlertView {
            view.removeFromSuperview()
            presentedAlertView = nil
            return true
        }
        return false
    }
}

// MARK: - Window Presentable

extension HackersAppV2 {
    fileprivate func handleWindowPresentable(for v: UIView) {
        if let _ = windowPresentable { return }
        if let window = UIApplication.shared.currentKeyWindow {
            let view = v
            view.frame = window.frame
            windowPresentable = view
            view.alpha = 0.0
            window.addSubview(view)
            UIView.animate(withDuration: 0.2, animations: { windowPresentable?.alpha = 1.0 })
        }
    }
    
    fileprivate func removeWindowPresentable() {
        UIView.animate(withDuration: 0.15, animations: { windowPresentable?.alpha = 0.0 })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: {
            windowPresentable?.removeFromSuperview()
            windowPresentable = nil
        })
    }
}
