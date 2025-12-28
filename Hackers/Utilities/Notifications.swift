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
    
    // MARK: - Alerts
    
    static let presentAlert = HackersNotification("present alert for handler")
}
