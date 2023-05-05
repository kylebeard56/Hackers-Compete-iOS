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
    var launchCount: Int { get set }
    var acceptedTerms: Bool { get set }
    var lastKnownTermsVersion: String { get set }
    var welcomeTourTaken: Bool { get set }
    var joinedDrinkingWaitlist: Bool { get set }
    var reviewPromptCount: Int { get set }
    var reviewPromptLastTimestamp: Double { get set }
    var lastReviewRequestAppVersion: String { get set }
    var maxScoreOverPar: Int { get set }
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
    
    // Tracks whether the user took or skipped the welcome tour
    var welcomeTourTaken: Bool {
        get { UserDefaults.getStoredValue() ?? false }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks whether the user submitted their email to join the drinking pack waitlist.
    var joinedDrinkingWaitlist: Bool {
        get { UserDefaults.getStoredValue() ?? false }
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
    
    // Track the user's setting for max score allowed over par.
    var maxScoreOverPar: Int {
        get { UserDefaults.getStoredValue() ?? 4 }
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
        userDefaults.setValue(value, forKey: key + id)
    }
}
