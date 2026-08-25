//
//  Haptics.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import UIKit

struct Haptics {
    /// Fire a simple haptic for either `error`, `warning`, or `success` notifications.
    static func fire(_ feedback: UINotificationFeedbackGenerator.FeedbackType) {
        if !deviceDefaults.hapticsEnabled { return }
        UINotificationFeedbackGenerator().notificationOccurred(feedback)
    }

    /// Fire a simple haptic for either `soft`, `light`, `medium`, `heavy`, or `rigid` impacts.
    static func fire(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if !deviceDefaults.hapticsEnabled { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
