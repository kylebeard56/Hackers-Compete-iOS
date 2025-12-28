//
//  HackersApp.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import SwiftUI

@main
struct HackersApp: App {
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    let appSession = AppSession()
    
    @State private var presentedAlertView: UIView?
    
    var body: some Scene {
        WindowGroup {
            LandingView()
                .environmentObject(appSession)
                .onReceive(HackersNotification.presentAlert.publisher()) { data in
                    if let d = data.object as? AlertData {
                        self.handleAlert(d)
                    }
                }
                .onChange(of: scenePhase, perform: { phase in
                    handleApp(for: phase)
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

// MARK: - Alerts

extension HackersApp {
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
