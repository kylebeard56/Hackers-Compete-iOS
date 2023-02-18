//
//  HackersApp.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import LocalConsole
import SwiftUI

let localConsole = LCManager.shared

@main
struct HackersApp: App, WindowPresentable {
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    
    @ObservedObject var appSession = AppSession()
    
    @State private var presentedAlertView: UIView?
    @State private var windowPresentable: UIView?
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $appSession.path) {
                LandingView()
                    .navigationDestination(for: Destination.self, destination: { destination in
                        ViewFactory.viewForDestination(destination)
                    })
            }
            .environmentObject(appSession)
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
                clearPresentedWindow()
            }
            .onChange(of: scenePhase, perform: { phase in
                handleApp(for: phase)
            })
            //.onTapGesture(count: 3, perform: { localConsole.isVisible.toggle() })
        }
    }
    
//    private func containedView() -> some View {
//        switch appSession.view {
//        case .landing:      return AnyView(LandingView())
//        case .play:         return AnyView(RoundView())
//        case .summary:      return AnyView(RoundSummaryView())
//        }
//    }
    
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

// MARK: - Window Presentable

extension HackersApp {
    fileprivate func handleWindowPresentable(for v: UIView) {
        if let window = UIApplication.shared.currentKeyWindow {
            var view = v
            view.frame = window.frame
            windowPresentable = view
            window.addSubview(view)
        }
    }
}
