//
//  Notifications.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation

typealias HackersNotification = Notification.Name

extension HackersNotification {
    func send() {
        NotificationCenter.default.post(name: self, object: nil)
    }

    func send(with data: Any?) {
        NotificationCenter.default.post(name: self, object: data)
    }

    func publisher() -> NotificationCenter.Publisher {
        return NotificationCenter.default.publisher(for: self)
    }
    
    /// Shortcut for setting up observer without needing `@objc` selector.
    func observe(listener: @escaping (Notification) -> Void) {
        NotificationCenter.default.addObserver(forName: self, object: nil, queue: .main, using: { n in
            listener(n)
        })
    }
}

extension HackersNotification {
    
    // MARK: - App
    static let appSceneDidBecomeActive = HackersNotification("app scene did become active")
    static let appSceneDidBecomeInactive = HackersNotification("app scene did become inactive")
    static let appSceneDidEnterBackground = HackersNotification("app scene did enter background")
    
    // MARK: - Operation
    static let triggerLogout = HackersNotification("trigger logout")
    
    // MARK: - Configuration
    static let appVersionNotMet = HackersNotification("minimum app version not met")
    static let minimumAppVersionDetected = HackersNotification("minimum app version not met")
    
    // MARK: - Alerts
    static let presentAlert = HackersNotification("present alert for handler")
    
    // MARK: - Session
    static let sessionUpdated = HackersNotification("active session updated")
    
    // MARK: - Round
    static let displayPlayerScorecard = HackersNotification("display player scorecard")
    static let sideGameResultsTapped = HackersNotification("side game results tapped")
    static let showNewHoleAnimation = HackersNotification("show new hole animation")
    
    // MARK: - Games
    static let chaosRedraw = HackersNotification("chaos redraw")
    static let refreshChaosRules = HackersNotification("refresh chaos rules")
    
    // MARK: - Window Presentable
    static let presentOnWindow = HackersNotification("present view on window")
    static let clearWindowPresentable = HackersNotification("clear view from window")
}
