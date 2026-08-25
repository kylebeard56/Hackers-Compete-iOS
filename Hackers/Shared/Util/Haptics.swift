//
//  Haptics.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
final class Haptics {
    /// Fire a simple haptic for either `error`, `warning`, or `success` notifications.
    static func fire(_ feedback: UINotificationFeedbackGenerator.FeedbackType) {
        print(#function)
        //if await Defaults.shared.getHapticsEnabled() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(feedback)
        //}
    }

    /// Fire a simple haptic for either `soft`, `light`, `medium`, `heavy`, or `rigid` impacts.
    static func fire(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        print(#function)
        //if await Defaults.shared.getHapticsEnabled() {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        //UIImpactFeedbackGenerator(style: style).impactOccurred()
        //}
    }
}
