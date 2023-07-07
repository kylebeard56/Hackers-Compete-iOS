//
//  DeviceSettings.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/23.
//

import Foundation
import LocalAuthentication
import SwiftyUserDefaults

protocol UserDefaultable: AnyObject {
    /// Launch
    var launchCount: Int { get set }
    
    /// Legal
    var acceptedTerms: Bool { get set }
    var lastKnownTermsVersion: String { get set }
    
    /// App Store review
    var reviewPromptCount: Int { get set }
    var reviewPromptLastTimestamp: Double { get set }
    var lastReviewRequestAppVersion: String { get set }
    
    /// Session
    var sessionHistory: [String] { get set }
    
    /// User Config
    var maxScoreOverPar: Int { get set }
    var hapticsEnabled: Bool { get set }
    var pushNotificationsEnabled: Bool { get set }
    
    /// Metrics
    var roundsPlayedCount: Int { get set }
}

class DeviceSettings: UserDefaultable {
    // Track the initial launch of the app (used to clear existing keychain should it have stayed).
    var launchCount: Int {
        get { UserDefaults.getStoredValue() ?? 0 }
        set { UserDefaults.setStoredValue(newValue) }
    }

    // Tracks whether the user accepted terms of service.
    var acceptedTerms: Bool {
        get { UserDefaults.getStoredValue() ?? false }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks the last known terms updated for the user
    var lastKnownTermsVersion: String {
        get { UserDefaults.getStoredValue() ?? "0.0.0" }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Track the # of times we've attempted to prompt user for App Store review.
    var reviewPromptCount: Int {
        get { UserDefaults.getStoredValue() ?? 0 }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Track the last timestamp when an App Store review prompt was shown.
    var reviewPromptLastTimestamp: Double {
        get { UserDefaults.getStoredValue() ?? 0.0 }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Track the last app version when an App Store review prompt was shown.
    var lastReviewRequestAppVersion: String {
        get { UserDefaults.getStoredValue() ?? "" }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Track all of the user's sessions that were created on this device.
    var sessionHistory: [String] {
        get { UserDefaults.getStoredValue() ?? [] }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Track the user's setting for max score allowed over par.
    var maxScoreOverPar: Int {
        get { UserDefaults.getStoredValue() ?? 4 }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks whether the user wants haptic feedback.
    var hapticsEnabled: Bool {
        get { UserDefaults.getStoredValue() ?? true }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks whether the user opted in to push notifications.
    var pushNotificationsEnabled: Bool {
        get { UserDefaults.getStoredValue() ?? false }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Track the # of rounds a user has played
    var roundsPlayedCount: Int {
        get { UserDefaults.getStoredValue() ?? 0 }
        set { UserDefaults.setStoredValue(newValue) }
    }
}

extension UserDefaults {
    /// Get stored value of key defaulting to the standard UserDefaults
    static func getStoredValue<T>(
        with key: String = #function,
        for id: String = "",
        inUserDefaults userDefaults: UserDefaults = .standard
    ) -> T? {
        userDefaults.object(forKey: key + id) as? T
    }

    /// Set stored value of key defaulting to the standard UserDefaults
    static func setStoredValue<T>(
        _ value: T,
        with key: String = #function,
        for id: String = "",
        inUserDefaults userDefaults: UserDefaults = .standard
    ) {
        if id.isEmpty {
            userDefaults.setValue(value, forKey: key)
        } else {
            userDefaults.setValue(value, forKey: key + "-" + id)
        }
    }
}
